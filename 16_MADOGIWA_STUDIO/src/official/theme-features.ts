import type { AvailableTheme } from "./site-theme";
import type { Episode } from "./journal-data";

export const themeFeatures: Record<AvailableTheme, { slug: string; character: string; note?: string }> = {
  sakaba: { slug: "tako-game-dormitory", character: "yametaro", note: "やめさん、寝床は選んだほうがいい。" },
  excel: { slug: "professional-window-side-sobaya", character: "sobaya" },
  underground: { slug: "madogiwa-super-try-underground", character: "yametaro" },
};

/** Only select playable public entries; unpublished recommendations never leak from a snapshot. */
export function chooseThemeFeature(episodes: Episode[], theme: AvailableTheme): Episode | undefined {
  const available = episodes.filter((episode) => episode.status === "published" && episode.primary_video_id);
  return available.find((episode) => episode.slug === themeFeatures[theme].slug)
    ?? available.find((episode) => episode.has_featured_video === 1)
    ?? available[0];
}
