import { lazy, Suspense, useEffect, useState, type ReactNode } from "react";
import { getHomeData } from "../server/public-data.functions";
import type { HomeData } from "../lib/public-data";
const Journal = lazy(() => import("./journal"));
export function OfficialSite({ fallback }: { fallback: ReactNode }) {
  const [data, setData] = useState<HomeData | null>(null);
  useEffect(() => {
    let active = true;
    void getHomeData().then((result) => { if (active) setData(result); }).catch(() => { /* Server-rendered page remains usable if loading fails. */ });
    return () => { active = false; };
  }, []);
  return data?.episodes.some((episode) => episode.primary_video_id) ? <Suspense fallback={fallback}><Journal episodes={data.episodes} galleryItems={data.galleryItems} /></Suspense> : fallback;
}
