import { getGalleryItem } from "./content-repository";
import { HttpError, json } from "./http";
import { serveR2Object } from "./r2-response";

const MAX_GALLERY_IMAGE_BYTES = 10 * 1024 * 1024;

type GalleryImageUploadTicketRow = {
  id: string;
  gallery_item_id: string;
  r2_key: string;
  filename: string;
  content_type: string;
  token_hash: string;
  uploaded_by: string | null;
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

export async function createGalleryImageUpload(
  env: Env,
  origin: string,
  input: { galleryItemId: string; filename: string; contentType: string; uploadedBy: string },
): Promise<{ galleryItemId: string; uploadUrl: string; expiresAt: string }> {
  const item = await getGalleryItem(env.DB, input.galleryItemId);
  if (!item) throw new HttpError(404, "ギャラリー項目が見つかりません");
  const ticketId = crypto.randomUUID();
  const safeFilename = input.filename.replace(/[^a-zA-Z0-9._-]+/g, "-").replace(/^-+|-+$/g, "") || "image.webp";
  const r2Key = `site/gallery/${item.id}/${ticketId}/${safeFilename}`;
  const token = createToken();
  const tokenHash = await hashToken(token);
  const expiresAt = new Date(Date.now() + 60 * 60 * 1000).toISOString();

  await env.DB.prepare(
    `INSERT INTO gallery_image_upload_tickets
     (id, gallery_item_id, r2_key, filename, content_type, token_hash, uploaded_by, expires_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
  )
    .bind(ticketId, item.id, r2Key, input.filename, input.contentType, tokenHash, input.uploadedBy, expiresAt)
    .run();

  return {
    galleryItemId: item.id,
    uploadUrl: `${origin}/api/gallery-image-uploads/${ticketId}?token=${encodeURIComponent(token)}`,
    expiresAt,
  };
}

export async function consumeGalleryImageUpload(request: Request, env: Env, ticketId: string): Promise<Response> {
  if (!request.body) throw new HttpError(400, "画像ファイルが空です");
  const token = new URL(request.url).searchParams.get("token");
  if (!token) throw new HttpError(401, "アップロードトークンがありません");

  const ticket = await env.DB.prepare("SELECT * FROM gallery_image_upload_tickets WHERE id = ?")
    .bind(ticketId)
    .first<GalleryImageUploadTicketRow>();
  if (!ticket || ticket.consumed_at) throw new HttpError(410, "アップロードURLは使用済みか無効です");
  if (new Date(ticket.expires_at).getTime() <= Date.now()) throw new HttpError(410, "アップロードURLの期限が切れています");
  if (!(await hashesMatch(await hashToken(token), ticket.token_hash))) {
    throw new HttpError(401, "アップロードトークンが無効です");
  }

  const contentType = request.headers.get("content-type")?.split(";", 1)[0].trim().toLowerCase() ?? "";
  if (contentType !== ticket.content_type) throw new HttpError(415, "発行時と同じ画像Content-Typeを指定してください");
  const contentLength = Number.parseInt(request.headers.get("content-length") ?? "", 10);
  if (!Number.isFinite(contentLength)) throw new HttpError(411, "Content-Lengthを指定してください");
  if (contentLength <= 0 || contentLength > MAX_GALLERY_IMAGE_BYTES) {
    throw new HttpError(413, "ギャラリー画像は10MB以下にしてください");
  }

  const consumed = await env.DB
    .prepare(
      `UPDATE gallery_image_upload_tickets
       SET consumed_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
       WHERE id = ? AND consumed_at IS NULL`,
    )
    .bind(ticket.id)
    .run();
  if (consumed.meta.changes !== 1) throw new HttpError(410, "アップロードURLは使用済みか無効です");

  const object = await env.MEDIA.put(ticket.r2_key, request.body, {
    httpMetadata: { contentType: ticket.content_type },
    customMetadata: { galleryItemId: ticket.gallery_item_id, uploadedBy: ticket.uploaded_by ?? "" },
  });
  if (object.size > MAX_GALLERY_IMAGE_BYTES) {
    await env.MEDIA.delete(ticket.r2_key);
    throw new HttpError(413, "ギャラリー画像は10MB以下にしてください");
  }

  await env.DB
    .prepare(
      `UPDATE gallery_items SET image_r2_key = ?, image_content_type = ?, image_size_bytes = ?, updated_by = ?,
       updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now') WHERE id = ?`,
    )
    .bind(ticket.r2_key, ticket.content_type, object.size, ticket.uploaded_by, ticket.gallery_item_id)
    .run();
  return json(
    {
      galleryItemId: ticket.gallery_item_id,
      imageUrl: `/gallery-images/${ticket.gallery_item_id}`,
      size: object.size,
    },
    { status: 201 },
  );
}

export async function serveGalleryImage(request: Request, env: Env, galleryItemId: string): Promise<Response> {
  const item = await getGalleryItem(env.DB, galleryItemId);
  if (!item?.image_r2_key) throw new HttpError(404, "ギャラリー画像が見つかりません");
  return serveR2Object(request, env.MEDIA, item.image_r2_key, "inline", "public, max-age=31536000, immutable");
}
