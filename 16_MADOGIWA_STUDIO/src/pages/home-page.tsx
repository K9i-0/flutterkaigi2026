import { ArrowRight, ArrowUpRight, BookOpen, Film, Gamepad2, Images, Play, Sparkles } from "lucide-react";
import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { api, type EpisodeSummary } from "@/lib/api";
import { articles, characters, comicEpisodes, galleryItems } from "@/lib/site-content";

export function HomePage() {
  const [episodes, setEpisodes] = useState<EpisodeSummary[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api.listEpisodes().then((result) => setEpisodes(result.episodes)).catch(() => setEpisodes([])).finally(() => setLoading(false));
  }, []);

  const featured = episodes.find((episode) => episode.primary_video_id) ?? episodes[0];

  return <>
    <section className="official-hero">
      <div className="hero-media">
        <img src="/site/hero-shibuya-wide.webp" alt="渋谷の中心に現れた巨大なそば屋" fetchPriority="high" />
      </div>
      <div className="hero-shade" />
      <div className="hero-copy">
        <div className="hero-kicker"><span /> MADOGIWA MONOGATARI</div>
        <h1>働かない。<br />でも、物語は<br /><em>動き出す。</em></h1>
        <p>窓際から宇宙まで。AI映像、漫画、ゲームへと広がり続ける<br className="hidden sm:block" />“働かない人たち”の壮大でささやかな物語。</p>
        <div className="hero-actions">
          {featured ? <Link className="gold-button" to={`/episodes/${featured.slug}`}><Play fill="currentColor" /> 最新話を見る</Link> : <a className="gold-button" href="#movie"><Play fill="currentColor" /> 映像を見る</a>}
          <a className="ghost-button" href="#comic">原作漫画へ <ArrowRight /></a>
        </div>
      </div>
      <a className="hero-scroll" href="#contents"><span /> SCROLL</a>
    </section>

    <div id="contents" className="official-content">
      <Section id="movie" eyebrow="LATEST MOVIES" title="窓際から始まる、映像物語。" icon={<Film />} intro="新しいエピソードと、生成を重ねて進化していく物語。">
        {loading ? <div className="loading-line">MOVIES LOADING...</div> : episodes.length ? <div className="movie-grid">{episodes.slice(0, 4).map((episode, index) => <Link key={episode.id} to={`/episodes/${episode.slug}`} className={index === 0 ? "movie-card movie-card-featured" : "movie-card"}><div className="movie-visual">{episode.primary_video_id ? <video src={`/media/${episode.primary_video_id}`} muted preload="metadata" /> : <img src="/site/hero-shibuya-wide.webp" alt="" />}<div className="movie-number">{String(index + 1).padStart(2, "0")}</div><span className="play-circle"><Play fill="currentColor" /></span></div><div className="movie-meta"><span>{episode.studio_id}</span><h3>{episode.title}</h3><p>{episode.summary || "窓際族たちの新しい物語。"}</p><small>{episode.generation_count} GENERATION{episode.generation_count === 1 ? "" : "S"}</small></div></Link>)}</div> : <div className="empty-feature">次の映像を準備しています。</div>}
      </Section>

      <Section id="character" eyebrow="CHARACTER" title="窓際に集う、仲間たち。" icon={<Sparkles />} intro="働き方も、姿かたちも、ちょっと変わった登場人物。">
        <div className="character-strip">{characters.map((character, index) => <article className="character-card" key={character.name}><img src={character.image} alt={character.name} loading="lazy" /><div><span>0{index + 1}</span><small>{character.role}</small><h3>{character.name}</h3><p>{character.copy}</p></div></article>)}</div>
      </Section>

      <Section id="comic" eyebrow="ORIGINAL COMIC" title="すべては、14話の漫画から。" icon={<BookOpen />} intro="入社初日、そこに自分の席はなかった。窓際族物語の原点を一気に読む。">
        <div className="comic-grid">{comicEpisodes.map((episode) => <article key={episode.number} className="comic-card"><img src={episode.image} alt={`第${episode.number}話 ${episode.title}`} loading="lazy" /><div><span>第{String(episode.number).padStart(2, "0")}話</span><h3>{episode.title}</h3></div></article>)}</div>
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
