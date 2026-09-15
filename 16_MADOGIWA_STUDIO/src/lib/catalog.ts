import type { EpisodeSummary, GalleryItem } from './api';

export type PublicCard = Omit<EpisodeSummary, 'generation_count' | 'video_count' | 'input_count' | 'prompt_label' | 'featured_video_created_at'>;
export type CatalogOptions = { member?: string; all?: boolean; cursor?: string; backwards?: boolean };
export type CatalogPage = { episodes: PublicCard[]; previous?: string; next?: string };
export type OfficialData = { episodes: PublicCard[]; galleryItems: GalleryItem[]; catalog?: CatalogPage };
export const CATALOG_SIZE = 18;
export function catalogCursor(row: PublicCard): string {
  return JSON.stringify([row.display_order, row.created_at, row.id]);
}
export function parseCatalogCursor(cursor?: string): [number, string, string] | null {
  if (!cursor) return null;
  if (cursor.length > 300) throw new Error('Invalid catalog cursor');
  const value: unknown = JSON.parse(cursor);
  if (!Array.isArray(value) || value.length !== 3 || !Number.isSafeInteger(value[0]) || typeof value[1] !== 'string' || typeof value[2] !== 'string') throw new Error('Invalid catalog cursor');
  return [value[0] as number, value[1], value[2]];
}
