import { createFileRoute, notFound } from "@tanstack/react-router";
import { absoluteUrl, episodePoster } from "@/lib/public-data";
import { EpisodePage } from "@/pages/episode-page";
import { getPublicEpisode } from "@/server/public-data.functions";

export const Route = createFileRoute("/episodes/$slug")({
  loader: async ({ params }) => {
    const detail = await getPublicEpisode({ data: params.slug });
    if (!detail) throw notFound();
    return detail;
  },
  head: ({ loaderData }) => {
    if (!loaderData) return {};
    const title = `${loaderData.episode.title}｜窓際族物語`;
    const description = loaderData.episode.summary || "窓際族たちの新しい物語。";
    const url = absoluteUrl(`/episodes/${loaderData.episode.slug}`);
    const image = absoluteUrl(episodePoster(loaderData));
    return {
      meta: [
        { title }, { name: "description", content: description },
        { property: "og:type", content: "video.episode" }, { property: "og:title", content: title },
        { property: "og:description", content: description }, { property: "og:url", content: url },
        { property: "og:image", content: image }, { name: "twitter:card", content: "summary_large_image" },
        { name: "twitter:title", content: title }, { name: "twitter:description", content: description },
        { name: "twitter:image", content: image },
      ],
      links: [{ rel: "canonical", href: url }],
    };
  },
  component: EpisodeRoute,
});

function EpisodeRoute() {
  return <EpisodePage detail={Route.useLoaderData()} />;
}
