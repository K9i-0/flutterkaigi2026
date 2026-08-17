import { createFileRoute } from "@tanstack/react-router";
import { getPublicEpisodes } from "@/server/public-data.functions";
import { EpisodesPage } from "@/pages/movies-page";
import { absoluteUrl } from "@/lib/public-data";

type EpisodeSearch = { featured?: boolean; members?: string };

export const Route = createFileRoute("/episodes/")({
  validateSearch: (search: Record<string, unknown>): EpisodeSearch => ({
    featured: search.featured === true || search.featured === "true" ? true : undefined,
    members: typeof search.members === "string" && search.members ? search.members : undefined,
  }),
  loader: () => getPublicEpisodes(),
  head: () => ({
    meta: [{ title: "エピソード｜窓際族物語" }, { name: "description", content: "窓際族物語の公開エピソードと映像作品一覧。" }, { property: "og:url", content: absoluteUrl("/episodes") }],
    links: [{ rel: "canonical", href: absoluteUrl("/episodes") }],
  }),
  component: EpisodesRoute,
});

function EpisodesRoute() {
  const search = Route.useSearch();
  const navigate = Route.useNavigate();
  return <EpisodesPage
    episodes={Route.useLoaderData()}
    featuredOnly={Boolean(search.featured)}
    selectedMembers={(search.members ?? "").split(",").filter(Boolean)}
    onFilters={(next) => void navigate({
      search: {
        featured: next.featuredOnly ? true : undefined,
        members: next.selectedMembers.length ? next.selectedMembers.join(",") : undefined,
      },
      replace: true,
    })}
  />;
}
