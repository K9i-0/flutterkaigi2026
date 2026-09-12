import { createFileRoute } from "@tanstack/react-router";
import { SITE_ORIGIN } from "@/lib/public-data";
import { characters } from "@/lib/site-content";

export const Route = createFileRoute("/sitemap.xml")({
  server: { handlers: { GET: async () => {
    const { env } = await import("cloudflare:workers");
    const { listPublicSitemapEntries } = await import("../../worker/public-repository");
    const entries = await listPublicSitemapEntries(env.DB);
    const paths = ["/", "/episodes", "/gallery", "/story", ...entries.map((item) => item.path), ...characters.map((item) => `/characters/${item.id}`)];
    const xml = `<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">${paths.map((path) => `<url><loc>${new URL(path, SITE_ORIGIN)}</loc></url>`).join("")}</urlset>`;
    return new Response(xml, { headers: { "content-type": "application/xml; charset=utf-8", "cache-control": "no-cache" } });
  } } },
});
