import { HttpError, json } from "./http";
import { createVideo, getVideo, type CreateVideoInput } from "./repository";

type UploadTicketRow = {
  id: string;
  video_id: string;
  token_hash: string;
  expires_at: string;
  consumed_at: string | null;
};

type PosterUploadTicketRow = {
  id: string;
  video_id: string;
  token_hash: string;
  expires_at: string;
  consumed_at: string | null;
};

const posterFormats = {
  "image/jpeg": "jpg",
  "image/png": "png",
  "image/webp": "webp",
} as const;

type PosterContentType = keyof typeof posterFormats;

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

export async function createUpload(
  env: Env,
  origin: string,
  input: CreateVideoInput,
): Promise<{ videoId: string; uploadUrl: string; posterUploadUrl: string; expiresAt: string }> {
  const video = await createVideo(env.DB, input);
  const ticketId = crypto.randomUUID();
  const token = createToken();
  const tokenHash = await hashToken(token);
  const posterTicketId = crypto.randomUUID();
  const posterToken = createToken();
  const posterTokenHash = await hashToken(posterToken);
  const expiresAt = new Date(Date.now() + 60 * 60 * 1000).toISOString();

  await env.DB.batch([
    env.DB
      .prepare("INSERT INTO upload_tickets (id, video_id, token_hash, expires_at) VALUES (?, ?, ?, ?)")
      .bind(ticketId, video.id, tokenHash, expiresAt),
    env.DB
      .prepare("INSERT INTO poster_upload_tickets (id, video_id, token_hash, expires_at) VALUES (?, ?, ?, ?)")
      .bind(posterTicketId, video.id, posterTokenHash, expiresAt),
  ]);

  return {
    videoId: video.id,
    uploadUrl: `${origin}/api/uploads/${ticketId}?token=${encodeURIComponent(token)}`,
    posterUploadUrl: `${origin}/api/poster-uploads/${posterTicketId}?token=${encodeURIComponent(posterToken)}`,
    expiresAt,
  };
}

export async function consumeUpload(request: Request, env: Env, ticketId: string): Promise<Response> {
  if (!request.body) throw new HttpError(400, "動画ファイルが空です");
  const token = new URL(request.url).searchParams.get("token");
  if (!token) throw new HttpError(401, "アップロードトークンがありません");

  const ticket = await env.DB.prepare("SELECT * FROM upload_tickets WHERE id = ?")
    .bind(ticketId)
    .first<UploadTicketRow>();
  if (!ticket || ticket.consumed_at) throw new HttpError(410, "アップロードURLは使用済みか無効です");
  if (new Date(ticket.expires_at).getTime() <= Date.now()) throw new HttpError(410, "アップロードURLの期限が切れています");

  const providedHash = await hashToken(token);
  if (!(await hashesMatch(providedHash, ticket.token_hash))) throw new HttpError(401, "アップロードトークンが無効です");

  const video = await getVideo(env.DB, ticket.video_id);
  if (!video) throw new HttpError(404, "動画情報が見つかりません");
  if (!video.poster_r2_key) throw new HttpError(409, "先に動画サムネイルをアップロードしてください");

  const contentLength = request.headers.get("content-length");
  const size = contentLength ? Number.parseInt(contentLength, 10) : Number.NaN;
  const object = await env.MEDIA.put(video.r2_key, request.body, {
    httpMetadata: { contentType: video.content_type },
    customMetadata: { videoId: video.id, episodeId: video.episode_id },
  });

  await env.DB.batch([
    env.DB.prepare("UPDATE upload_tickets SET consumed_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now') WHERE id = ?").bind(ticket.id),
    env.DB
      .prepare(
        `UPDATE videos SET status = 'ready', size_bytes = ?,
         updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now') WHERE id = ?`,
      )
      .bind(Number.isFinite(size) ? size : object.size, video.id),
  ]);
  return json({ videoId: video.id, mediaUrl: `/media/${video.id}`, size: object.size }, { status: 201 });
}

export async function consumePosterUpload(request: Request, env: Env, ticketId: string): Promise<Response> {
  if (!request.body) throw new HttpError(400, "サムネイル画像が空です");
  const token = new URL(request.url).searchParams.get("token");
  if (!token) throw new HttpError(401, "アップロードトークンがありません");

  const ticket = await env.DB.prepare("SELECT * FROM poster_upload_tickets WHERE id = ?")
    .bind(ticketId)
    .first<PosterUploadTicketRow>();
  if (!ticket || ticket.consumed_at) throw new HttpError(410, "アップロードURLは使用済みか無効です");
  if (new Date(ticket.expires_at).getTime() <= Date.now()) throw new HttpError(410, "アップロードURLの期限が切れています");

  const providedHash = await hashToken(token);
  if (!(await hashesMatch(providedHash, ticket.token_hash))) throw new HttpError(401, "アップロードトークンが無効です");

  const contentType = request.headers.get("content-type")?.split(";", 1)[0]?.trim().toLowerCase();
  if (!contentType || !(contentType in posterFormats)) {
    throw new HttpError(415, "サムネイルはJPEG、PNG、WebPのいずれかにしてください");
  }
  const contentLength = Number.parseInt(request.headers.get("content-length") ?? "", 10);
  if (!Number.isFinite(contentLength) || contentLength <= 0) {
    throw new HttpError(411, "サムネイルのContent-Lengthを指定してください");
  }
  if (Number.isFinite(contentLength) && contentLength > 5 * 1024 * 1024) {
    throw new HttpError(413, "サムネイルは5MB以下にしてください");
  }

  const video = await getVideo(env.DB, ticket.video_id);
  if (!video) throw new HttpError(404, "動画情報が見つかりません");
  const directory = video.r2_key.slice(0, video.r2_key.lastIndexOf("/"));
  const extension = posterFormats[contentType as PosterContentType];
  const posterR2Key = `${directory}/poster.${extension}`;
  const object = await env.MEDIA.put(posterR2Key, request.body, {
    httpMetadata: { contentType, cacheControl: "public, max-age=604800, immutable" },
    customMetadata: { videoId: video.id, episodeId: video.episode_id, kind: "poster" },
  });

  await env.DB.batch([
    env.DB
      .prepare("UPDATE poster_upload_tickets SET consumed_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now') WHERE id = ?")
      .bind(ticket.id),
    env.DB
      .prepare(
        `UPDATE videos SET poster_r2_key = ?,
         updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now') WHERE id = ?`,
      )
      .bind(posterR2Key, video.id),
  ]);

  return json({ videoId: video.id, posterUrl: `/posters/${video.id}`, size: object.size }, { status: 201 });
}
