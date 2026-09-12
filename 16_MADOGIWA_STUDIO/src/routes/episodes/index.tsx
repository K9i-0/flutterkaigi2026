import { createFileRoute } from "@tanstack/react-router";
import { absoluteUrl, socialMeta } from "@/lib/public-data";

type EpisodeSearch = { featured?: boolean; members?: string };
const title = "エピソード｜窓際族物語";
const description = "窓際族物語の公開エピソードと映像作品一覧。";

export const Route = createFileRoute("/episodes/")({
  validateSearch: (search: Record<string, unknown>): EpisodeSearch => ({
    featured: search.featured === true || search.featured === "true" ? true : undefined,
    members: typeof search.members === "string" && search.members ? search.members : undefined,
  }),
  head: () => ({
    meta: socialMeta({ title, description, path: "/episodes" }),
    links: [{ rel: "canonical", href: absoluteUrl("/episodes") }],
  }),
  component: EpisodesRoute,
});

function EpisodesRoute() { return null; }
