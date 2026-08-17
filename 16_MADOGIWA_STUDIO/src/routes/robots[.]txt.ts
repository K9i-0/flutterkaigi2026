import { createFileRoute } from "@tanstack/react-router";
import { SITE_ORIGIN } from "@/lib/public-data";

export const Route = createFileRoute("/robots.txt")({ server: { handlers: { GET: async () => new Response(`User-agent: *\nAllow: /\nDisallow: /admin\nDisallow: /admin-api\nDisallow: /inputs\nDisallow: /mcp\nSitemap: ${SITE_ORIGIN}/sitemap.xml\n`, { headers: { "content-type": "text/plain; charset=utf-8", "cache-control": "public, max-age=3600" } }) } } });
