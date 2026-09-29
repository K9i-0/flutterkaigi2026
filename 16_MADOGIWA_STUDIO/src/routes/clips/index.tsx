import { createFileRoute } from "@tanstack/react-router";
import { ClipsPage, clips } from "@/features/clips/clips";
import { absoluteUrl, socialMeta } from "@/lib/public-data";

export const Route = createFileRoute("/clips/")({
  validateSearch: (search: Record<string, unknown>): { page?: number } => {
    const page = Number(search.page);
    return { page: Number.isSafeInteger(page) && page > 1 ? page : undefined };
  },
  head: () => ({
    meta: socialMeta({ title: "迷言・迷場面集｜窓際族物語", description: "SNS、チャットツールにおすすめ。窓際族物語の迷言・迷場面を動画で保存・共有できます。", path: "/clips", image: clips[0].poster }),
    links: [{ rel: "canonical", href: absoluteUrl("/clips") }],
  }),
  component: () => <ClipsPage page={Route.useSearch().page ?? 1} />,
});
