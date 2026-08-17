import { createFileRoute } from "@tanstack/react-router";
import { SITE_ORIGIN } from "@/lib/public-data";
import { characters } from "@/lib/site-content";

export const Route = createFileRoute("/sitemap.xml")({
  server: { handlers: { GET: async () => {
    const { loadPublicEpisodes, loadPublicGallery } = await import("@/server/public-data.server");
    const [episodes, gallery] = await Promise.all([loadPublicEpisodes(), loadPublicGallery()]);
    const paths = ["/", "/episodes", "/gallery", "/story", ...episodes.map((item) => `/episodes/${item.slug}`), ...gallery.map((item) => `/gallery/${item.slug}`), ...characters.map((item) => `/characters/${item.id}`)];
    const xml = `<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">${paths.map((path) => `<url><loc>${new URL(path, SITE_ORIGIN)}</loc></url>`).join("")}</urlset>`;
    return new Response(xml, { headers: { "content-type": "application/xml; charset=utf-8", "cache-control": "public, max-age=300" } });
  } } },
});
