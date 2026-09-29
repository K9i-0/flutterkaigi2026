import { createFileRoute, notFound } from "@tanstack/react-router";
import { ClipPage, clips } from "@/features/clips/clips";
import { absoluteUrl, socialMeta } from "@/lib/public-data";

export const Route = createFileRoute("/clips/$slug")({
  loader: ({ params }) => {
    const clip = clips.find((item) => item.id === params.slug);
    if (!clip) throw notFound();
    return clip;
  },
  head: ({ loaderData: clip }) => clip ? ({
    meta: socialMeta({ title: `${clip.title}｜窓際族物語 迷言・迷場面集`, description: `第${clip.episode}話・${clip.character}の${clip.kind}。動画を保存してSNSやチャットで共有できます。`, path: `/clips/${clip.id}`, image: clip.poster, type: "video.episode" }),
    links: [{ rel: "canonical", href: absoluteUrl(`/clips/${clip.id}`) }],
  }) : ({}),
  component: () => (
    <ClipPage key={Route.useParams().slug} clip={Route.useLoaderData()} />
  ),
});
