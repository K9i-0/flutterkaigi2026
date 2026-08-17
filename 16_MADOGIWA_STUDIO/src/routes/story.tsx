import { createFileRoute } from "@tanstack/react-router";
import { StoryPage } from "@/pages/story-page";
import { absoluteUrl, socialMeta } from "@/lib/public-data";

const title = "原作ストーリー｜窓際族物語";
const description = "入社初日からBONKまで。窓際族物語の原点となる全14話。";

export const Route = createFileRoute("/story")({
  head: () => ({
    meta: socialMeta({ title, description, path: "/story" }),
    links: [{ rel: "canonical", href: absoluteUrl("/story") }],
  }),
  component: StoryPage,
});
