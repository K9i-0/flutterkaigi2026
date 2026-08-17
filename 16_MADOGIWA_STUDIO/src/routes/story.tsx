import { createFileRoute } from "@tanstack/react-router";
import { StoryPage } from "@/pages/story-page";
import { absoluteUrl } from "@/lib/public-data";

export const Route = createFileRoute("/story")({
  head: () => ({
    meta: [{ title: "原作ストーリー｜窓際族物語" }, { name: "description", content: "入社初日からBONKまで。窓際族物語の原点となる全14話。" }, { property: "og:url", content: absoluteUrl("/story") }],
    links: [{ rel: "canonical", href: absoluteUrl("/story") }],
  }),
  component: StoryPage,
});
