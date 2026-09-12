import { createFileRoute, notFound } from "@tanstack/react-router";
import { absoluteUrl, socialMeta } from "@/lib/public-data";
import { characters } from "@/lib/site-content";

export const Route = createFileRoute("/characters/$slug")({
  loader: ({ params }) => {
    const character = characters.find((candidate) => candidate.id === params.slug);
    if (!character) throw notFound();
    return { character };
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

function CharacterRoute() { return null; }
