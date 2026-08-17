import { createFileRoute, notFound } from "@tanstack/react-router";
import { absoluteUrl, socialMeta } from "@/lib/public-data";
import { characters } from "@/lib/site-content";
import { CharacterPage } from "@/pages/character-page";
import { getCharacterData } from "@/server/public-data.functions";

export const Route = createFileRoute("/characters/$slug")({
  loader: async ({ params }) => {
    const character = characters.find((candidate) => candidate.id === params.slug);
    if (!character) throw notFound();
    return { character, ...(await getCharacterData({ data: character.id })) };
  },
  head: ({ loaderData }) => {
    if (!loaderData) return {};
    const title = `${loaderData.character.name}｜窓際族物語`;
    const path = `/characters/${loaderData.character.id}`;
    return {
      meta: socialMeta({ title, description: loaderData.character.copy, path, image: loaderData.character.image }),
      links: [{ rel: "canonical", href: absoluteUrl(path) }],
    };
  },
  component: CharacterRoute,
});

function CharacterRoute() { return <CharacterPage {...Route.useLoaderData()} />; }
