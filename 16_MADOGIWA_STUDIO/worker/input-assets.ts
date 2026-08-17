import { HttpError, json } from "./http";
import { createInputAsset, getInputAsset, type CreateInputAssetInput } from "./repository";
import { serveR2Object } from "./r2-response";
import { requireAdmin } from "./auth";

type InputUploadTicketRow = {
  id: string;
  asset_id: string;
  token_hash: string;
  expires_at: string;
  consumed_at: string | null;
};

function bytesToHex(bytes: ArrayBuffer): string {
  return Array.from(new Uint8Array(bytes), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

async function hashToken(token: string): Promise<string> {
  return bytesToHex(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(token)));
}

function createToken(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return btoa(String.fromCharCode(...bytes)).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

async function hashesMatch(actual: string, expected: string): Promise<boolean> {
  const encoder = new TextEncoder();
  const [actualDigest, expectedDigest] = await Promise.all([
    crypto.subtle.digest("SHA-256", encoder.encode(actual)),
    crypto.subtle.digest("SHA-256", encoder.encode(expected)),
  ]);
  const actualBytes = new Uint8Array(actualDigest);
  const expectedBytes = new Uint8Array(expectedDigest);
  let difference = actualBytes.length ^ expectedBytes.length;
  for (let index = 0; index < actualBytes.length; index += 1) difference |= actualBytes[index] ^ (expectedBytes[index] ?? 0);
  return difference === 0;
}

export async function createInputUpload(
  env: Env,
  origin: string,
  input: CreateInputAssetInput,
): Promise<{ assetId: string; uploadUrl: string; expiresAt: string }> {
  const asset = await createInputAsset(env.DB, input);
  const ticketId = crypto.randomUUID();
  const token = createToken();
  const tokenHash = await hashToken(token);
  const expiresAt = new Date(Date.now() + 60 * 60 * 1000).toISOString();
  await env.DB.prepare(
    "INSERT INTO input_upload_tickets (id, asset_id, token_hash, expires_at) VALUES (?, ?, ?, ?)",
  )
    .bind(ticketId, asset.id, tokenHash, expiresAt)
    .run();

  return {
    assetId: asset.id,
    uploadUrl: `${origin}/api/input-uploads/${ticketId}?token=${encodeURIComponent(token)}`,
    expiresAt,
  };
}

export async function consumeInputUpload(request: Request, env: Env, ticketId: string): Promise<Response> {
  if (!request.body) throw new HttpError(400, "入力ファイルが空です");
  const token = new URL(request.url).searchParams.get("token");
  if (!token) throw new HttpError(401, "アップロードトークンがありません");

  const ticket = await env.DB.prepare("SELECT * FROM input_upload_tickets WHERE id = ?")
    .bind(ticketId)
    .first<InputUploadTicketRow>();
  if (!ticket || ticket.consumed_at) throw new HttpError(410, "アップロードURLは使用済みか無効です");
  if (new Date(ticket.expires_at).getTime() <= Date.now()) throw new HttpError(410, "アップロードURLの期限が切れています");
  if (!(await hashesMatch(await hashToken(token), ticket.token_hash))) {
    throw new HttpError(401, "アップロードトークンが無効です");
  }

  const asset = await getInputAsset(env.DB, ticket.asset_id);
  if (!asset) throw new HttpError(404, "入力アセット情報が見つかりません");
  const contentLength = request.headers.get("content-length");
  const size = contentLength ? Number.parseInt(contentLength, 10) : Number.NaN;
  const object = await env.MEDIA.put(asset.r2_key, request.body, {
    httpMetadata: { contentType: asset.content_type },
    customMetadata: { assetId: asset.id, episodeId: asset.episode_id, kind: asset.kind },
  });

  await env.DB.batch([
    env.DB.prepare("UPDATE input_upload_tickets SET consumed_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now') WHERE id = ?").bind(ticket.id),
    env.DB
      .prepare(
        `UPDATE input_assets SET status = 'ready', size_bytes = ?,
         updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now') WHERE id = ?`,
      )
      .bind(Number.isFinite(size) ? size : object.size, asset.id),
  ]);
  return json({ assetId: asset.id, assetUrl: `/inputs/${asset.id}`, size: object.size }, { status: 201 });
}

async function requireInputAccess(request: Request, env: Env, ctx: ExecutionContext, assetId: string): Promise<void> {
  const episode = await env.DB.prepare(
    `SELECT episodes.status,
      EXISTS(SELECT 1 FROM videos
        WHERE videos.generation_id = input_assets.generation_id
          AND videos.status NOT IN ('archived', 'upload_pending')) AS has_public_video
     FROM input_assets JOIN episodes ON episodes.id = input_assets.episode_id
     WHERE input_assets.id = ?`,
  ).bind(assetId).first<{ status: string; has_public_video: number }>();
  if (!episode) throw new HttpError(404, "入力アセットが見つかりません");
  if (episode.status !== "published" || episode.has_public_video !== 1) await requireAdmin(request, env, ctx);
}

export async function serveInputAsset(request: Request, env: Env, ctx: ExecutionContext, assetId: string): Promise<Response> {
  await requireInputAccess(request, env, ctx, assetId);
  const asset = await getInputAsset(env.DB, assetId);
  if (!asset || asset.status !== "ready") throw new HttpError(404, "入力アセットが見つかりません");
  const safeFilename = asset.filename.replaceAll('"', "");
  const disposition = `${asset.kind === "document" || asset.kind === "other" ? "attachment" : "inline"}; filename="${safeFilename}"`;
  return serveR2Object(request, env.MEDIA, asset.r2_key, disposition);
}
