import { createFileRoute, notFound } from "@tanstack/react-router";
import { absoluteUrl, episodePoster, socialMeta } from "@/lib/public-data";
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
    const path = `/episodes/${loaderData.episode.slug}`;
    return {
      meta: socialMeta({ title, description, path, image: episodePoster(loaderData), type: "video.episode" }),
      links: [{ rel: "canonical", href: absoluteUrl(path) }],
    };
  },
  component: EpisodeRoute,
});

function EpisodeRoute() {
  return <EpisodePage detail={Route.useLoaderData()} />;
}
