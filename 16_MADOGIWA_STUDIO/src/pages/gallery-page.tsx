import { Images, Tags } from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { GalleryCard } from "@/components/gallery-card";
import { api, type GalleryItem } from "@/lib/api";

const ALL_KINDS = "ALL";

export function GalleryPage() {
  const [items, setItems] = useState<GalleryItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedKind, setSelectedKind] = useState(ALL_KINDS);

  useEffect(() => {
    api.listGalleryItems()
      .then((result) => setItems(result.galleryItems))
      .catch(() => setItems([]))
      .finally(() => setLoading(false));
  }, []);

  const kinds = useMemo(() => Array.from(new Set(items.map((item) => item.kind))), [items]);
  const filteredItems = useMemo(
    () => selectedKind === ALL_KINDS ? items : items.filter((item) => item.kind === selectedKind),
    [items, selectedKind],
  );

  return <div className="gallery-archive">
    <header className="archive-heading">
      <div className="section-icon"><Images /></div>
      <div><span>GALLERY ARCHIVE</span><h1>物語から生まれた、すべての景色。</h1></div>
    </header>
    <section className="gallery-filters" aria-label="ギャラリーの絞り込み">
      <div className="gallery-filter-heading"><Tags /><span>CATEGORIES</span></div>
      <div className="gallery-kind-filters">
        {[ALL_KINDS, ...kinds].map((kind) => {
          const selected = selectedKind === kind;
          const count = kind === ALL_KINDS ? items.length : items.filter((item) => item.kind === kind).length;
          return <button key={kind} type="button" aria-pressed={selected} onClick={() => setSelectedKind(kind)}>
            <span>{kind}</span><b>{count}</b>
          </button>;
        })}
      </div>
    </section>
    <div className="archive-count">{filteredItems.length === items.length ? `${items.length} WORKS` : `${filteredItems.length} / ${items.length} WORKS`}</div>
    {loading
      ? <div className="loading-line">GALLERY LOADING...</div>
      : filteredItems.length
        ? <div className="gallery-archive-grid">{filteredItems.map((item) => <GalleryCard key={item.id} item={item} />)}</div>
        : <div className="empty-feature">条件に合う作品はありません。</div>}
  </div>;
}
