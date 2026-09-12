import { useEffect, useState } from "react";
import Journal from "../src/official/journal";
import type { EpisodeSummary, GalleryItem } from "../src/lib/api";
import snapshot from "./episodes.json";
import { arts } from "./journal-data";
const galleryFallback: GalleryItem[] = arts.map((a, index) => ({ id: String(index), slug: String(index), title: a.title, kind: a.kind, image_url: a.src, legacy_image_path: a.src, image_r2_key: null, image_content_type: null, image_size_bytes: null, display_order: index, status: "published", created_by: null, updated_by: null, created_at: "", updated_at: "", archived_at: null }));
export default function Review() {
  const [episodes, setEpisodes] = useState<EpisodeSummary[]>(snapshot.map(e => ({ ...e, status: "published" })));
  const [galleryItems, setGalleryItems] = useState(galleryFallback);
  useEffect(() => {
    const controller = new AbortController();
    void fetch("/api/episodes", { signal: controller.signal }).then(r => { if (!r.ok) throw new Error("Snapshot fallback"); return r.json(); }).then((data: { episodes: EpisodeSummary[] }) => setEpisodes(data.episodes)).catch(() => {});
    void fetch("/api/gallery-items", { signal: controller.signal }).then(r => { if (!r.ok) throw new Error("Snapshot fallback"); return r.json(); }).then((data: { galleryItems: GalleryItem[] }) => setGalleryItems(data.galleryItems)).catch(() => {});
    return () => controller.abort();
  }, []);
  return <Journal episodes={episodes} galleryItems={galleryItems} />;
}
