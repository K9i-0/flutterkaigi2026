import { createFileRoute } from "@tanstack/react-router";
import { GalleryPage } from "@/pages/gallery-page";
import { getPublicGallery } from "@/server/public-data.functions";
import { absoluteUrl } from "@/lib/public-data";

type GallerySearch = { kind?: string };

export const Route = createFileRoute("/gallery/")({
  validateSearch: (search: Record<string, unknown>): GallerySearch => ({ kind: typeof search.kind === "string" && search.kind ? search.kind : undefined }),
  loader: () => getPublicGallery(),
  head: () => ({
    meta: [{ title: "ギャラリー｜窓際族物語" }, { name: "description", content: "窓際族物語から生まれたキービジュアル、世界観アート、特別作品。" }, { property: "og:url", content: absoluteUrl("/gallery") }],
    links: [{ rel: "canonical", href: absoluteUrl("/gallery") }],
  }),
  component: GalleryRoute,
});

function GalleryRoute() {
  const search = Route.useSearch();
  const navigate = Route.useNavigate();
  return <GalleryPage items={Route.useLoaderData()} selectedKind={search.kind ?? "ALL"} onKind={(kind) => void navigate({ search: { kind: kind === "ALL" ? undefined : kind }, replace: true })} />;
}
