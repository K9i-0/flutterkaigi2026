import { ArrowLeft, ArrowRight, ArrowUpRight, BookOpen, Film, Gamepad2, Images, Sparkles } from "lucide-react";
import { useEffect, useMemo, useRef, useState } from "react";
import { Link } from "react-router-dom";
import { MovieCard } from "@/components/movie-card";
import { api, type EpisodeSummary } from "@/lib/api";
import { articles, characters, comicEpisodes, galleryItems } from "@/lib/site-content";

export function HomePage() {
  const [episodes, setEpisodes] = useState<EpisodeSummary[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api.listEpisodes(true).then((result) => setEpisodes(result.episodes)).catch(() => setEpisodes([])).finally(() => setLoading(false));
  }, []);

  const prioritizedEpisodes = useMemo(() => [...episodes].sort((left, right) => {
    if (left.has_featured_video !== right.has_featured_video) return right.has_featured_video - left.has_featured_video;
    const leftDate = left.has_featured_video ? left.featured_video_created_at : left.updated_at;
    const rightDate = right.has_featured_video ? right.featured_video_created_at : right.updated_at;
    return String(rightDate ?? "").localeCompare(String(leftDate ?? ""));
  }), [episodes]);
  return <>
    <section className="official-hero">
      <div className="hero-media">
        <img src="/site/hero-shibuya-wide.webp" alt="渋谷の中心に現れた巨大なそば屋" fetchPriority="high" />
      </div>
      <div className="hero-shade" />
      <div className="hero-copy">
        <div className="hero-kicker"><span /> MADOGIWAZOKU MONOGATARI</div>
        <h1>働かない。<br />でも、物語は<br /><em>動き出す。</em></h1>
        <p>窓際から宇宙まで。AI映像、漫画、ゲームへと広がり続ける<br className="hidden sm:block" />“働かない人たち”の壮大でささやかな物語。</p>
      </div>
      <a className="hero-scroll" href="#contents"><span /> SCROLL</a>
    </section>

    <div id="contents" className="official-content">
      <Section id="movie" eyebrow="FEATURED MOVIES" title="最新のイチオシ動画。" icon={<Film />} intro="窓際族物語から、いま見てほしい映像を新しい順に。">
        <div className="movie-section-link"><span>{prioritizedEpisodes.length} PICKS</span><Link to="/movies">動画一覧を見る <ArrowRight /></Link></div>
        {loading ? <div className="loading-line">MOVIES LOADING...</div> : prioritizedEpisodes.length ? <div className="movie-grid">{prioritizedEpisodes.slice(0, 4).map((episode, index) => <MovieCard key={episode.id} episode={episode} index={index} featuredLayout={index === 0} inlinePlayback />)}</div> : <div className="empty-feature">イチオシ動画を準備しています。</div>}
      </Section>

      <Section id="character" eyebrow="CHARACTER" title="窓際に集う、仲間たち。" icon={<Sparkles />} intro="働き方も、姿かたちも、ちょっと変わった登場人物。">
        <div className="character-strip">{characters.map((character, index) => <article className="character-card" key={character.name}><img src={character.image} alt={character.name} loading="lazy" /><div><span>0{index + 1}</span><small>{character.role}</small><h3>{character.name}</h3><p>{character.copy}</p></div></article>)}</div>
      </Section>

      <Section id="comic" eyebrow="ORIGINAL COMIC" title="すべては、14話の漫画から。" icon={<BookOpen />} intro="入社初日、そこに自分の席はなかった。窓際族物語の原点を一気に読む。">
        <ComicCarousel />
      </Section>

      <Section id="gallery" eyebrow="GALLERY" title="物語から生まれた、もうひとつの景色。" icon={<Images />} intro="原作の外側へ広がるキービジュアル、世界観アート、特別作品。">
        <div className="gallery-grid">{galleryItems.map((item, index) => <figure key={item.title} className={index === 0 ? "gallery-item gallery-wide" : "gallery-item"}><img src={item.image} alt={item.title} loading="lazy" /><figcaption><span>{item.kind}</span><b>{item.title}</b></figcaption></figure>)}</div>
      </Section>

      <Section id="game" eyebrow="GAME" title="遊べる窓際、営業中。" icon={<Gamepad2 />} intro="ドット絵、カード、レース。窓際族の世界へ、プレイヤーとして飛び込もう。">
        <a className="game-banner" href="https://sobaya-0141.github.io/Seedance_Madogiwa/" target="_blank" rel="noreferrer"><img src="/site/game/arcade.webp" alt="窓際族物語ゲームセンター" loading="lazy" /><div><span>NOW PLAYING</span><h3>MADOGIWA<br />GAME CENTER</h3><p>ブラウザですぐ遊べる、窓際族物語のゲームコレクション。</p><b>ゲームセンターへ <ArrowUpRight /></b></div></a>
      </Section>

      <Section id="article" eyebrow="ARTICLE" title="物語の、その裏側へ。" icon={<BookOpen />} intro="作品を支える映像、音声、Web技術の制作ノート。">
        <div className="article-grid">{articles.map((article, index) => <article key={article.title}><span>{article.label} · 0{index + 1}</span><h3>{article.title}</h3><p>{article.copy}</p><small>COMING SOON</small></article>)}</div>
      </Section>
    </div>
  </>;
}

function Section({ id, eyebrow, title, intro, icon, children }: { id: string; eyebrow: string; title: string; intro: string; icon: React.ReactNode; children: React.ReactNode }) {
  return <section id={id} className="official-section"><header className="section-heading"><div className="section-icon">{icon}</div><div><span>{eyebrow}</span><h2>{title}</h2><p>{intro}</p></div></header>{children}</section>;
}

function ComicCarousel() {
  const [selectedComic, setSelectedComic] = useState(1);
  const carouselRef = useRef<HTMLDivElement>(null);
  const cardRefs = useRef<Array<HTMLElement | null>>([]);
  const scrollFrame = useRef<number | null>(null);
  const programmaticScroll = useRef(false);
  const scrollStopTimer = useRef<number | null>(null);
  const selectedEpisode = comicEpisodes[selectedComic - 1] ?? comicEpisodes[0];

  useEffect(() => () => {
    if (scrollFrame.current !== null) cancelAnimationFrame(scrollFrame.current);
    if (scrollStopTimer.current !== null) window.clearTimeout(scrollStopTimer.current);
  }, []);

  function selectComic(index: number, behavior: ScrollBehavior = "smooth") {
    const boundedIndex = Math.max(0, Math.min(comicEpisodes.length - 1, index));
    setSelectedComic(comicEpisodes[boundedIndex].number);
    const carousel = carouselRef.current;
    const card = cardRefs.current[boundedIndex];
    if (!carousel || !card) return;

    const centeredLeft = card.offsetLeft + card.offsetWidth / 2 - carousel.clientWidth / 2;
    if (scrollStopTimer.current !== null) window.clearTimeout(scrollStopTimer.current);
    programmaticScroll.current = behavior === "smooth";
    carousel.scrollTo({ left: Math.max(0, centeredLeft), behavior });

    if (behavior === "smooth") {
      scrollStopTimer.current = window.setTimeout(() => {
        programmaticScroll.current = false;
        updateCenteredComic();
      }, 600);
    } else {
      programmaticScroll.current = false;
    }
  }

  function updateCenteredComic() {
    const carousel = carouselRef.current;
    if (!carousel) return;
    const carouselBox = carousel.getBoundingClientRect();
    const center = carouselBox.left + carouselBox.width / 2;
    let closestIndex = 0;
    let closestDistance = Number.POSITIVE_INFINITY;
    cardRefs.current.forEach((card, index) => {
      if (!card) return;
      const box = card.getBoundingClientRect();
      const distance = Math.abs(box.left + box.width / 2 - center);
      if (distance < closestDistance) {
        closestIndex = index;
        closestDistance = distance;
      }
    });
    setSelectedComic(comicEpisodes[closestIndex].number);
  }

  function handleScroll() {
    if (programmaticScroll.current) {
      if (scrollStopTimer.current !== null) window.clearTimeout(scrollStopTimer.current);
      scrollStopTimer.current = window.setTimeout(() => {
        programmaticScroll.current = false;
        updateCenteredComic();
      }, 120);
      return;
    }
    if (scrollFrame.current !== null) cancelAnimationFrame(scrollFrame.current);
    scrollFrame.current = requestAnimationFrame(updateCenteredComic);
  }

  return <div className="comic-carousel-layout">
    <div className="comic-carousel-frame">
      <div className="comic-edge comic-edge-left" />
      <div
        ref={carouselRef}
        className="comic-carousel"
        onScroll={handleScroll}
        aria-label="原作漫画 全14話"
      >
        {comicEpisodes.map((episode, index) => {
          const selected = selectedComic === episode.number;
          return <article
            key={episode.number}
            ref={(element) => { cardRefs.current[index] = element; }}
            className={`comic-card${selected ? " comic-card-selected" : ""}`}
          >
            <button
              type="button"
              onClick={() => selectComic(index)}
              aria-pressed={selected}
              aria-label={`第${episode.number}話 ${episode.title}`}
            >
              <span className="comic-cover"><img src={episode.image} alt="" loading={index === 0 ? "eager" : "lazy"} /></span>
            </button>
          </article>;
        })}
      </div>
      <div className="comic-edge comic-edge-right" />
    </div>
    <div className="comic-detail" aria-live="polite">
      <div className="comic-detail-index"><span>ORIGINAL STORY</span><b>{String(selectedEpisode.number).padStart(2, "0")}<small> / {comicEpisodes.length}</small></b></div>
      <div className="comic-detail-copy"><span>第{String(selectedEpisode.number).padStart(2, "0")}話</span><h3>{selectedEpisode.title}</h3><p>{selectedEpisode.description}</p></div>
      <nav className="comic-controls" aria-label="漫画の話数を移動">
        <button type="button" onClick={() => selectComic(selectedComic - 2)} disabled={selectedComic === 1} aria-label="前の話"><ArrowLeft /></button>
        <div>{comicEpisodes.map((episode) => <button key={episode.number} type="button" className={episode.number === selectedComic ? "active" : ""} onClick={() => selectComic(episode.number - 1)} aria-label={`第${episode.number}話へ`} />)}</div>
        <button type="button" onClick={() => selectComic(selectedComic)} disabled={selectedComic === comicEpisodes.length} aria-label="次の話"><ArrowRight /></button>
      </nav>
    </div>
    <p className="comic-scroll-hint"><span /> 横にスクロールして続きを読む</p>
  </div>;
}
