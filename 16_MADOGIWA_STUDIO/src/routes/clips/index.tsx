import { createFileRoute, notFound } from "@tanstack/react-router";
import { ClipsPage } from "@/features/clips/clips";

export const Route = createFileRoute("/clips/")({
  beforeLoad: () => {
    if (!import.meta.env.DEV) throw notFound();
  },
  head: () => ({
    meta: [
      { title: "迷言・迷場面集｜窓際族物語" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: ClipsPage,
});
