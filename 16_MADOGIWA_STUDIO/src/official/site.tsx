import Journal from "./journal";
import type { OfficialData } from "../lib/catalog";
import type { AvailableTheme } from "./site-theme";
export function OfficialSite({ data, initialTheme, initialHref }: { data: OfficialData; initialTheme: AvailableTheme; initialHref: string }) {
  return <Journal episodes={data.episodes} galleryItems={data.galleryItems} initialTheme={initialTheme} initialHref={initialHref} catalog={data.catalog} />;
}
