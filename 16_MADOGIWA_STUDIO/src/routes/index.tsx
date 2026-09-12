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
      imageAlt: "高層ビル外側のベランダ席でビールを飲むそば屋、窓の中の福ちゃん、宙に浮くたこさんとやめ太郎の指名手配ポスター",
    }),
    links: [{ rel: "canonical", href: absoluteUrl("/") }],
  }),
  component: HomeRoute,
});

function HomeRoute() {
  return <HomePage {...Route.useLoaderData()} />;
}
