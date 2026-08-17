import { createFileRoute, notFound } from "@tanstack/react-router";
import { absoluteUrl } from "@/lib/public-data";
import { characters } from "@/lib/site-content";
import { CharacterPage } from "@/pages/character-page";
import { getCharacterData } from "@/server/public-data.functions";

export const Route = createFileRoute("/characters/$slug")({
  loader: async ({ params }) => {
    const character = characters.find((candidate) => candidate.id === params.slug);
    if (!character) throw notFound();
    return { character, ...(await getCharacterData({ data: character.id })) };
  },
  head: ({ loaderData }) => loaderData ? {
    meta: [
      { title: `${loaderData.character.name}｜窓際族物語` }, { name: "description", content: loaderData.character.copy },
      { property: "og:title", content: `${loaderData.character.name}｜窓際族物語` },
      { property: "og:description", content: loaderData.character.copy },
      { property: "og:image", content: absoluteUrl(loaderData.character.image) },
      { property: "og:url", content: absoluteUrl(`/characters/${loaderData.character.id}`) },
      { name: "twitter:card", content: "summary_large_image" },
    ],
    links: [{ rel: "canonical", href: absoluteUrl(`/characters/${loaderData.character.id}`) }],
  } : {},
  component: CharacterRoute,
});

function CharacterRoute() { return <CharacterPage {...Route.useLoaderData()} />; }
