import type { Article, Episode, EpisodeSummary, GalleryItem, InputAsset, Member, PromptVersion, Video } from "@/lib/api";

export const SITE_ORIGIN = "https://madogiwa-studio.madogiwa-studio.workers.dev";
export const SITE_NAME = "窓際族物語";
export const DEFAULT_DESCRIPTION = "働かない。でも、物語は動き出す。漫画、映像、ゲームへと広がる『窓際族物語』公式サイト。";
export const DEFAULT_OG_IMAGE = "/site/hero-shibuya-wide.webp";

type SocialMetaOptions = {
  title: string;
  description: string;
  path: string;
  image?: string;
  type?: "website" | "article" | "video.episode";
  imageAlt?: string;
};

export function socialMeta({
  title,
  description,
  path,
  image = DEFAULT_OG_IMAGE,
  type = "website",
  imageAlt = title,
}: SocialMetaOptions) {
  const url = absoluteUrl(path);
  const imageUrl = absoluteUrl(image);

  return [
    { title },
    { name: "description", content: description },
    { property: "og:type", content: type },
    { property: "og:locale", content: "ja_JP" },
    { property: "og:site_name", content: SITE_NAME },
    { property: "og:title", content: title },
    { property: "og:description", content: description },
    { property: "og:url", content: url },
    { property: "og:image", content: imageUrl },
    { property: "og:image:alt", content: imageAlt },
    { name: "twitter:card", content: "summary_large_image" },
    { name: "twitter:title", content: title },
    { name: "twitter:description", content: description },
    { name: "twitter:image", content: imageUrl },
    { name: "twitter:image:alt", content: imageAlt },
  ];
}

export type PublicVideo = Pick<Video, "id" | "generation_id" | "label" | "created_at" | "is_featured"> & {
  poster_url: string | null;
};

export type PublicPrompt = Pick<PromptVersion, "label" | "body" | "version">;

export type PublicInputAsset = Pick<
  InputAsset,
  "id" | "filename" | "label" | "kind" | "reference_label" | "group_label" | "notes" | "content_type" | "display_order"
> & { url: string };

export type PublicProduction = {
  generation_id: string;
  version: number;
  label: string;
  model_name: string | null;
  prompt: PublicPrompt | null;
  inputs: PublicInputAsset[];
};

export type PublicEpisodeDetail = {
  episode: Episode;
  members: Member[];
  videos: PublicVideo[];
  productions: PublicProduction[];
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
