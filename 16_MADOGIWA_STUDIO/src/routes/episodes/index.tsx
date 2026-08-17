import { createFileRoute } from "@tanstack/react-router";
import { getPublicEpisodes } from "@/server/public-data.functions";
import { EpisodesPage } from "@/pages/movies-page";
import { absoluteUrl, socialMeta } from "@/lib/public-data";

type EpisodeSearch = { featured?: boolean; members?: string };
const title = "エピソード｜窓際族物語";
const description = "窓際族物語の公開エピソードと映像作品一覧。";

export const Route = createFileRoute("/episodes/")({
  validateSearch: (search: Record<string, unknown>): EpisodeSearch => ({
    featured: search.featured === true || search.featured === "true" ? true : undefined,
    members: typeof search.members === "string" && search.members ? search.members : undefined,
  }),
  loader: () => getPublicEpisodes(),
  head: () => ({
    meta: socialMeta({ title, description, path: "/episodes" }),
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
