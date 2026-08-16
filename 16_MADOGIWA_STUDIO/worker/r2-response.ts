import { HttpError } from "./http";

export async function serveR2Object(
  request: Request,
  bucket: R2Bucket,
  key: string,
  contentDisposition?: string,
): Promise<Response> {
  const rangeHeader = request.headers.get("range");
  const object = await bucket.get(key, rangeHeader ? { range: request.headers } : undefined);
  if (!object) throw new HttpError(404, "ファイルが見つかりません");

  const headers = new Headers();
  object.writeHttpMetadata(headers);
  headers.set("etag", object.httpEtag);
  headers.set("accept-ranges", "bytes");
  headers.set("cache-control", "public, max-age=3600");
  if (contentDisposition) headers.set("content-disposition", contentDisposition);

  const range = object.range;
  if (
    rangeHeader &&
    range &&
    "offset" in range &&
    "length" in range &&
    typeof range.offset === "number" &&
    typeof range.length === "number"
  ) {
    const end = range.offset + range.length - 1;
    headers.set("content-range", `bytes ${range.offset}-${end}/${object.size}`);
    headers.set("content-length", String(range.length));
    return new Response(object.body, { status: 206, headers });
  }

  headers.set("content-length", String(object.size));
  return new Response(object.body, { status: 200, headers });
}
