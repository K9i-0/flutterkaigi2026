import { env } from "cloudflare:workers";
import type { EpisodeSummary } from "@/lib/api";
import type { CharacterData, HomeData, PublicEpisodeDetail, PublicVideo } from "@/lib/public-data";
import { listArticles, listGalleryItems } from "../../worker/content-repository";
import { getEpisodeBySlug, listEpisodes } from "../../worker/repository";

function publishedEpisodes(episodes: EpisodeSummary[]): EpisodeSummary[] {
  return episodes.filter((episode) => episode.status === "published");
}

export async function loadHomeData(): Promise<HomeData> {
  const [episodes, galleryItems, articles] = await Promise.all([
    listEpisodes(env.DB),
    listGalleryItems(env.DB, { publishedOnly: true }),
    listArticles(env.DB, { publishedOnly: true }),
  ]);
  return { episodes: publishedEpisodes(episodes), galleryItems, articles };
}

export async function loadPublicEpisodes(): Promise<EpisodeSummary[]> {
  return publishedEpisodes(await listEpisodes(env.DB));
}

export async function loadPublicEpisode(slug: string): Promise<PublicEpisodeDetail | null> {
  const [detail, allEpisodes] = await Promise.all([getEpisodeBySlug(env.DB, slug), listEpisodes(env.DB)]);
  if (!detail || detail.episode.status !== "published") return null;

  const videos: PublicVideo[] = detail.generations
    .flatMap((generation) => generation.videos)
    .filter((video) => video.status !== "archived" && video.status !== "upload_pending")
    .sort((left, right) => right.is_featured - left.is_featured || right.created_at.localeCompare(left.created_at))
    .map((video) => ({
      id: video.id,
      label: video.label,
      created_at: video.created_at,
      is_featured: video.is_featured,
      poster_url: video.poster_r2_key ? `/posters/${video.id}` : null,
    }));

  const memberIds = new Set(detail.members.map((member) => member.id));
  const related = publishedEpisodes(allEpisodes)
    .filter((episode) => episode.id !== detail.episode.id)
    .sort((left, right) => {
      const leftScore = left.members.filter((member) => memberIds.has(member.id)).length;
      const rightScore = right.members.filter((member) => memberIds.has(member.id)).length;
      return rightScore - leftScore || right.updated_at.localeCompare(left.updated_at);
    })
    .slice(0, 3);

  return { episode: detail.episode, members: detail.members, videos, related };
}

export async function loadPublicGallery() {
  return listGalleryItems(env.DB, { publishedOnly: true });
}

export async function loadPublicGalleryItem(slug: string) {
  const items = await loadPublicGallery();
  const item = items.find((candidate) => candidate.slug === slug) ?? null;
  return item ? { item, related: items.filter((candidate) => candidate.id !== item.id).slice(0, 3) } : null;
}

export async function loadCharacterData(characterId: string): Promise<CharacterData> {
  const episodes = publishedEpisodes(await listEpisodes(env.DB));
  return { episodes: episodes.filter((episode) => episode.members.some((member) => member.id === characterId)) };
}
