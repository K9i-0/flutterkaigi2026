import { createFileRoute, notFound } from "@tanstack/react-router";
import { absoluteUrl } from "@/lib/public-data";
import { GalleryDetailPage } from "@/pages/gallery-detail-page";
import { getPublicGalleryItem } from "@/server/public-data.functions";

export const Route = createFileRoute("/gallery/$slug")({
  loader: async ({ params }) => {
    const detail = await getPublicGalleryItem({ data: params.slug });
    if (!detail) throw notFound();
    return detail;
  },
  head: ({ loaderData }) => loaderData ? {
    meta: [
      { title: `${loaderData.item.title}｜窓際族物語` },
      { name: "description", content: `${loaderData.item.kind}「${loaderData.item.title}」` },
      { property: "og:type", content: "article" }, { property: "og:title", content: loaderData.item.title },
      { property: "og:image", content: absoluteUrl(loaderData.item.image_url) },
      { property: "og:url", content: absoluteUrl(`/gallery/${loaderData.item.slug}`) },
      { name: "twitter:card", content: "summary_large_image" },
    ],
    links: [{ rel: "canonical", href: absoluteUrl(`/gallery/${loaderData.item.slug}`) }],
  } : {},
  component: GalleryDetailRoute,
});

function GalleryDetailRoute() {
  return <GalleryDetailPage {...Route.useLoaderData()} />;
}
