import { ZoomableImage } from "@/components/image-lightbox";
import type { GalleryItem } from "@/lib/api";

export function GalleryCard({ item, featured = false }: { item: GalleryItem; featured?: boolean }) {
  return <figure className={featured ? "gallery-item gallery-wide" : "gallery-item"}>
    <ZoomableImage
      src={item.image_url}
      alt={item.title}
      caption={item.kind}
      loading="lazy"
      buttonClassName="gallery-image-trigger"
    />
    <figcaption><span>{item.kind}</span><b>{item.title}</b></figcaption>
  </figure>;
}
