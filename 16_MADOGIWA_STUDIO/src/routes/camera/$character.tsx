import { createFileRoute, notFound } from "@tanstack/react-router";
import { arCharacters, isARCharacter } from "@/official/character-ar-config";
import { CharacterCameraPage } from "@/official/character-camera-page";
import { absoluteUrl, socialMeta } from "@/lib/public-data";

export const Route = createFileRoute("/camera/$character")({
  loader: ({ params }) => {
    if (!isARCharacter(params.character)) throw notFound();
    return { character: params.character };
  },
  head: ({ loaderData }) => {
    if (!loaderData) return {};
    const character = loaderData.character;
    const path = `/camera/${character}`;
    return {
      meta: socialMeta({ title: `${arCharacters[character].name}といっしょに撮る｜窓際族物語`, description: "窓際の仲間を等身大やぬいぐるみサイズで。iPhoneのARカメラで一緒の一枚を撮影できます。", path, image: `/site/characters/${character}.webp` }),
      links: [{ rel: "canonical", href: absoluteUrl(path) }],
    };
  },
  component: CameraRoute,
});
function CameraRoute() {
  const { character } = Route.useLoaderData();
  return <CharacterCameraPage key={character} character={character} />;
}
