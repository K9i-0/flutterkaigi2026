import assets from "./clip-assets.json";

const assetByPath = new Map(assets.map((asset) => [asset.path, asset]));

// Only published manifest entries are public. Keys include a content digest, so
// immutable caching never changes the bytes behind a previously shared URL.
export async function serveClipAsset(request: Request, bucket: R2Bucket): Promise<Response> {
  const url = new URL(request.url);
  const asset = assetByPath.get(url.pathname);
  if (!asset) return new Response(null, { status: 404 });
  if (request.method !== "GET" && request.method !== "HEAD") {
    return new Response(null, { status: 405, headers: { allow: "GET, HEAD" } });
  }
  const etag = `"${asset.key.split("/")[1]}"`;
  const headers = new Headers({
    "content-type": asset.contentType,
    "cache-control": "public, max-age=31536000, immutable",
    "accept-ranges": "bytes",
    "etag": etag,
    "x-content-type-options": "nosniff",
  });
  if (url.searchParams.has("download")) {
    headers.set("content-disposition", `attachment; filename="${asset.name}"; filename*=UTF-8''${encodeURIComponent(asset.downloadName)}`);
  }
  if (request.headers.get("if-none-match")?.split(",").some((value) => value.trim().replace(/^W\//, "") === etag || value.trim() === "*")) {
    return new Response(null, { status: 304, headers });
  }
  let offset = 0;
  let length = asset.bytes;
  const ifRange = request.headers.get("if-range");
  const range = request.method === "GET" && (!ifRange || ifRange === etag) ? request.headers.get("range") : null;
  if (range) {
    const match = /^bytes=(\d*)-(\d*)$/.exec(range);
    if (!match || (!match[1] && !match[2])) {
      headers.set("content-range", `bytes */${asset.bytes}`);
      return new Response(null, { status: 416, headers });
    }
    offset = match[1] ? Number(match[1]) : Math.max(0, asset.bytes - Number(match[2]));
    const end = match[1] && match[2] ? Math.min(Number(match[2]), asset.bytes - 1) : asset.bytes - 1;
    length = end - offset + 1;
    if (!Number.isSafeInteger(offset) || !Number.isSafeInteger(length) || offset >= asset.bytes || length <= 0) {
      headers.set("content-range", `bytes */${asset.bytes}`);
      return new Response(null, { status: 416, headers });
    }
    headers.set("content-range", `bytes ${offset}-${end}/${asset.bytes}`);
  }
  headers.set("content-length", String(length));
  if (request.method === "HEAD") {
    if (!await bucket.head(asset.key)) return new Response(null, { status: 404 });
    return new Response(null, { headers });
  }
  const object = await bucket.get(asset.key, range ? { range: { offset, length } } : undefined);
  if (!object) return new Response(null, { status: 404 });
  return new Response(object.body, { status: range ? 206 : 200, headers });
}
