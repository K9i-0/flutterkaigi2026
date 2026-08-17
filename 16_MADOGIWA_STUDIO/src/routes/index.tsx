import { createFileRoute } from "@tanstack/react-router";
import { getHomeData } from "@/server/public-data.functions";
import { HomePage } from "@/pages/home-page";
import { DEFAULT_DESCRIPTION, DEFAULT_OG_IMAGE, absoluteUrl } from "@/lib/public-data";

export const Route = createFileRoute("/")({
  loader: () => getHomeData(),
  head: () => ({
    meta: [
      { title: "窓際族物語｜公式サイト" },
      { name: "description", content: DEFAULT_DESCRIPTION },
      { property: "og:url", content: absoluteUrl("/") },
      { property: "og:image", content: absoluteUrl(DEFAULT_OG_IMAGE) },
    ],
    links: [{ rel: "canonical", href: absoluteUrl("/") }],
  }),
  component: HomeRoute,
});

function HomeRoute() {
  return <HomePage {...Route.useLoaderData()} />;
}
