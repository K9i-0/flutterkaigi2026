// Cache public data, never HTML (which includes the visitor's theme cookie),
// admin responses, credentials, or upload tickets.
export async function cachedPublicData<T>(db: D1Database, key: string, load: () => Promise<T>): Promise<T> {
  // One indexed row read per lookup. Triggers change the revision atomically
  // with content writes, including MCP, uploads and direct D1 maintenance.
  // Unlike cache.delete(), this invalidates entries in every Cloudflare colo.
  const revision = await db.prepare("SELECT revision FROM public_content_revision WHERE id = 1").first<string>("revision");
  if (!revision) throw new Error("Public content revision is missing");
  const cacheKey = new Request(`https://madogiwa.work/__public-data/v2/${encodeURIComponent(key)}?revision=${revision}`);
  try {
    const cache = await caches.open("madogiwa-public-v1");
    const hit = await cache.match(cacheKey);
    if (hit) {
      const data = await hit.json() as T;
      console.info({ event: "public_data_cache", key, outcome: "hit" });
      return data;
    }
  } catch {
    console.warn({ event: "public_cache_read_failed", key });
  }
  const data = await load();
  console.info({ event: "public_data_cache", key, outcome: "miss" });
  try {
    // Await the bounded JSON write; no request-scoped promises survive globally.
    const cache = await caches.open("madogiwa-public-v1");
    await cache.put(cacheKey, Response.json(data, { headers: { "cache-control": "public, max-age=300" } }));
  } catch {
    console.warn({ event: "public_cache_write_failed", key });
  }
  return data;
}
