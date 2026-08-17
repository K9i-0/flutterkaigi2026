import { ArrowLeft, ImageIcon } from "lucide-react";
import { Link } from "@tanstack/react-router";
import { GalleryCard } from "@/components/gallery-card";
import { ZoomableImage } from "@/components/image-lightbox";
import { ShareActions } from "@/components/share-actions";
import type { GalleryItem } from "@/lib/api";

export function GalleryDetailPage({ item, related }: { item: GalleryItem; related: GalleryItem[] }) {
  return <div className="gallery-detail-page">
    <Link to="/gallery" className="archive-back"><ArrowLeft /> GALLERY</Link>
    <header className="gallery-detail-header">
      <div><span>{item.kind}</span><h1>{item.title}</h1><ShareActions title={item.title} path={`/gallery/${item.slug}`} /></div>
    </header>
    <ZoomableImage src={item.image_url} alt={item.title} caption={item.title} className="gallery-detail-image" buttonClassName="gallery-detail-image-trigger" />
    {related.length ? <section className="gallery-related-section">
      <div className="episode-section-label"><ImageIcon /><span>MORE GALLERY</span></div>
      <div className="gallery-archive-grid">{related.map((candidate) => <GalleryCard key={candidate.id} item={candidate} />)}</div>
    </section> : null}
  </div>;
}
