import type { Article, Episode, EpisodeSummary, GalleryItem, Member, Video } from "@/lib/api";

export const SITE_ORIGIN = "https://madogiwa-studio.madogiwa-studio.workers.dev";
export const SITE_NAME = "窓際族物語";
export const DEFAULT_DESCRIPTION = "働かない。でも、物語は動き出す。漫画、映像、ゲームへと広がる『窓際族物語』公式サイト。";
export const DEFAULT_OG_IMAGE = "/site/hero-shibuya-wide.webp";

export type PublicVideo = Pick<Video, "id" | "label" | "created_at" | "is_featured"> & {
  poster_url: string | null;
};

export type PublicEpisodeDetail = {
  episode: Episode;
  members: Member[];
  videos: PublicVideo[];
  related: EpisodeSummary[];
};

export type HomeData = {
  episodes: EpisodeSummary[];
  galleryItems: GalleryItem[];
  articles: Article[];
};

export type CharacterData = {
  episodes: EpisodeSummary[];
};

export function absoluteUrl(path: string): string {
  return new URL(path, SITE_ORIGIN).toString();
}

export function episodePoster(detail: PublicEpisodeDetail): string {
  return detail.videos[0]?.poster_url ?? DEFAULT_OG_IMAGE;
}
