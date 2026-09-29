import { createFileRoute, notFound } from "@tanstack/react-router";
import { ClipPage, clips } from "@/features/clips/clips";

export const Route = createFileRoute("/clips/$slug")({
  loader: ({ params }) => {
    if (!import.meta.env.DEV) throw notFound();
    const clip = clips.find((item) => item.id === params.slug);
    if (!clip) throw notFound();
    return clip;
  },
  head: ({ loaderData }) => ({
    meta: [
      {
        title: `${loaderData?.title ?? "クリップ"}｜窓際族物語 迷言・迷場面集`,
      },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: () => (
    <ClipPage key={Route.useParams().slug} clip={Route.useLoaderData()} />
  ),
});
