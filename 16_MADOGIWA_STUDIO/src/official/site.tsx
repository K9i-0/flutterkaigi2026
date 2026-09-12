import Journal from "./journal";
import type { HomeData } from "../lib/public-data";
import type { AvailableTheme } from "./site-theme";
export function OfficialSite({ data, initialTheme, initialHref }: { data: HomeData; initialTheme: AvailableTheme; initialHref: string }) {
  return <Journal episodes={data.episodes} galleryItems={data.galleryItems} initialTheme={initialTheme} initialHref={initialHref} />;
}
