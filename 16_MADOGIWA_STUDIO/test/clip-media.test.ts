import { env } from "cloudflare:workers";
import { beforeEach, describe, expect, it } from "vitest";
import { serveClipAsset } from "../worker/clip-media";
import assets from "../worker/clip-assets.json";
import clips from "../src/features/clips/catalog.json";

const asset = assets.find((item) => item.name === "taxi.mp4")!;
const request = (init?: RequestInit, query = "") => new Request(`https://madogiwa.work${asset.path}${query}`, init);

describe("published clip media", () => {
  beforeEach(async () => { await env.MEDIA.delete(asset.key); });
  it("has a unique public asset for every clip, thumbnail and exact source", () => {
    expect(new Set(assets.map((item) => item.path)).size).toBe(assets.length);
    for (const clip of clips) {
      for (const path of [clip.video, clip.poster, clip.source]) {
        expect(assets.some((item) => item.path === path && item.bytes > 0)).toBe(true);
        expect(path).toMatch(/^\/clip-media\/[a-f0-9]{64}\/[a-z0-9-]+\.(mp4|jpg)$/);
      }
    }
  });
  it("streams media, supports HEAD, byte and suffix ranges, attachment names and conditional caching", async () => {
    const bytes = new Uint8Array(asset.bytes);
    bytes.set([1, 2, 3, 4], 10);
    await env.MEDIA.put(asset.key, bytes);
    const full = await serveClipAsset(request(), env.MEDIA);
    expect(full.status).toBe(200);
    expect((await full.arrayBuffer()).byteLength).toBe(asset.bytes);
    const head = await serveClipAsset(request({ method: "HEAD" }), env.MEDIA);
    expect(head.headers.get("content-length")).toBe(String(asset.bytes));
    expect(await head.text()).toBe("");
    const partial = await serveClipAsset(request({ headers: { range: "bytes=10-13" } }), env.MEDIA);
    expect(partial.status).toBe(206);
    expect(partial.headers.get("content-range")).toBe(`bytes 10-13/${asset.bytes}`);
    expect(new Uint8Array(await partial.arrayBuffer())).toEqual(new Uint8Array([1, 2, 3, 4]));
    const suffix = await serveClipAsset(request({ headers: { range: "bytes=-5" } }), env.MEDIA);
    expect(suffix.status).toBe(206);
    expect((await suffix.arrayBuffer()).byteLength).toBe(5);
    const download = await serveClipAsset(request({ method: "HEAD" }, "?download=1"), env.MEDIA);
    expect(download.headers.get("content-disposition")).toContain(encodeURIComponent(asset.downloadName));
    expect(download.headers.get("cache-control")).toContain("immutable");
    expect((await serveClipAsset(request({ headers: { "if-none-match": head.headers.get("etag")! } }), env.MEDIA)).status).toBe(304);
    const changed = await serveClipAsset(request({ headers: { range: "bytes=10-13", "if-range": '"other"' } }), env.MEDIA);
    expect(changed.status).toBe(200);
    await changed.arrayBuffer();
  });
  it("rejects invalid ranges, missing files, methods and unlisted object keys", async () => {
    expect((await serveClipAsset(request(), env.MEDIA)).status).toBe(404);
    expect((await serveClipAsset(request({ method: "HEAD" }), env.MEDIA)).status).toBe(404);
    expect((await serveClipAsset(request({ method: "POST" }), env.MEDIA)).status).toBe(405);
    expect((await serveClipAsset(new Request("https://madogiwa.work/clip-media/private.mp4"), env.MEDIA)).status).toBe(404);
    for (const range of ["bytes=-0", `bytes=${asset.bytes}-`, "bytes=9-1", "bytes=0-1,4-5", "invalid"]) {
      const response = await serveClipAsset(request({ headers: { range } }), env.MEDIA);
      expect(response.status).toBe(416);
      expect(response.headers.get("content-range")).toBe(`bytes */${asset.bytes}`);
    }
  });
});
