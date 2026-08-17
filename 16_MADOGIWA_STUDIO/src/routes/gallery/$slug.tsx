import { createFileRoute, notFound } from "@tanstack/react-router";
import { absoluteUrl, socialMeta } from "@/lib/public-data";
import { GalleryDetailPage } from "@/pages/gallery-detail-page";
import { getPublicGalleryItem } from "@/server/public-data.functions";

export const Route = createFileRoute("/gallery/$slug")({
  loader: async ({ params }) => {
    const detail = await getPublicGalleryItem({ data: params.slug });
    if (!detail) throw notFound();
    return detail;
  },
  head: ({ loaderData }) => {
    if (!loaderData) return {};
    const title = `${loaderData.item.title}｜窓際族物語`;
    const path = `/gallery/${loaderData.item.slug}`;
    return {
      meta: socialMeta({
        title,
        description: `${loaderData.item.kind}「${loaderData.item.title}」`,
        path,
        image: loaderData.item.image_url,
        type: "article",
      }),
      links: [{ rel: "canonical", href: absoluteUrl(path) }],
    };
  },
  component: GalleryDetailRoute,
});

function GalleryDetailRoute() {
  return <GalleryDetailPage {...Route.useLoaderData()} />;
}
