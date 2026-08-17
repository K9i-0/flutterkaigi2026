import { Link } from "@tanstack/react-router";
import type { GalleryItem } from "@/lib/api";

export function GalleryCard({ item, featured = false }: { item: GalleryItem; featured?: boolean }) {
  return <figure className={featured ? "gallery-item gallery-wide" : "gallery-item"}>
    <Link to="/gallery/$slug" params={{ slug: item.slug }} className="gallery-image-trigger" aria-label={`${item.title}を見る`}><img src={item.image_url} alt={item.title} loading="lazy" /></Link>
    <figcaption><span>{item.kind}</span><b>{item.title}</b></figcaption>
  </figure>;
}
