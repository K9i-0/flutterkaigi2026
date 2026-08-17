import { createFileRoute } from "@tanstack/react-router";
import { getHomeData } from "@/server/public-data.functions";
import { HomePage } from "@/pages/home-page";
import { DEFAULT_DESCRIPTION, absoluteUrl, socialMeta } from "@/lib/public-data";

export const Route = createFileRoute("/")({
  loader: () => getHomeData(),
  head: () => ({
    meta: socialMeta({
      title: "窓際族物語｜公式サイト",
      description: DEFAULT_DESCRIPTION,
      path: "/",
      imageAlt: "渋谷の中心に現れた巨大なそば屋と、窓際族物語の登場人物たち",
    }),
    links: [{ rel: "canonical", href: absoluteUrl("/") }],
  }),
  component: HomeRoute,
});

function HomeRoute() {
  return <HomePage {...Route.useLoaderData()} />;
}
