import { createFileRoute } from "@tanstack/react-router";
import { absoluteUrl, socialMeta } from "@/lib/public-data";

type GallerySearch = { kind?: string };
const title = "ギャラリー｜窓際族物語";
const description = "窓際族物語から生まれたキービジュアル、世界観アート、特別作品。";

export const Route = createFileRoute("/gallery/")({
  validateSearch: (search: Record<string, unknown>): GallerySearch => ({ kind: typeof search.kind === "string" && search.kind ? search.kind : undefined }),
  head: () => ({
    meta: socialMeta({ title, description, path: "/gallery" }),
    links: [{ rel: "canonical", href: absoluteUrl("/gallery") }],
  }),
  component: GalleryRoute,
});

function GalleryRoute() { return null; }
