import { useEffect, useRef, useState } from "react";
import {
  ArrowLeft,
  ArrowRight,
  ArrowUpRight,
  Play,
  X,
  Volume2,
  Check,
  Heart,
  Menu,
} from "lucide-react";
import * as Dialog from "@radix-ui/react-dialog";
import { characters, comicEpisodes } from "../src/lib/site-content";
import episodeSnapshot from "./episodes.json";
const rawEpisodes = episodeSnapshot.filter(
  (episode) => episode.primary_video_id && !episode.title.includes("検証"),
);
import "./style.css";

type Episode = (typeof rawEpisodes)[number];
type Character = (typeof characters)[number];
type Mode = "cinema" | "paper" | "club";
const modes: { id: Mode; label: string; name: string }[] = [
  { id: "cinema", label: "A", name: "シネマ" },
  { id: "paper", label: "B", name: "マガジン" },
  { id: "club", label: "C", name: "キャラクター" },
];
const curatedSlugs = [
  "madogiwa-super-try-commute",
  "professional-window-side-sobaya",
  "yametaro-unauthorized-office-livestream",
];
const localSlugs = [
  ...curatedSlugs,
  "tako-game-dormitory",
  "madogiwa-super-try-keisha",
  "sobaya-never-drops-beer",
];
const picks = curatedSlugs.map((slug) =>
  rawEpisodes.find((e) => e.slug === slug)!,
);
const shortTitles: Record<string, string> = {
  "madogiwa-super-try-commute": "出社インポッシブル",
  "professional-window-side-sobaya": "プロフェッショナル 窓際の流儀",
  "yametaro-unauthorized-office-livestream": "やめチャンネル、無断生配信。",
  "tako-game-dormitory": "タコゲーム — 目覚め",
  "madogiwa-super-try-keisha": "土下座レース篇",
};
const descriptions: Record<string, string> = {
  "madogiwa-super-try-commute": "命懸けでよじ登った先は、いつもの窓際席。",
  "professional-window-side-sobaya": "ビールを注ぐ。その仕事に、密着する。",
  "yametaro-unauthorized-office-livestream":
    "会社で配信してみたら、映してはいけないものだらけ。",
  "tako-game-dormitory": "目覚めたら、そこは巨大なタコ部屋だった。",
  "madogiwa-super-try-keisha": "低姿勢で、ぶっちぎれ。",
};
const title = (e: Episode) => shortTitles[e.slug] ?? e.title;
const poster = (e: Episode) =>
  e.primary_video_poster_url
    ? `/cache/${e.primary_video_id}.jpg`
    : "/site/hero-shibuya-wide.webp";
const duration = (e: Episode) =>
  e.slug === "professional-window-side-sobaya"
    ? "37秒"
    : e.slug === "madogiwa-super-try-keisha"
      ? "25秒"
      : e.slug === "sobaya-never-drops-beer"
        ? "15秒"
        : e.summary.match(/(?:約)?(\d+(?:\.\d+)?)秒/)?.[1] + "秒";
const themeColors: Record<string, string> = {
  sobaya: "#caac74",
  yametaro: "#b6a1d4",
  takosan: "#86b7ae",
  fukuchan: "#dc9e75",
  tokun: "#a3b979",
  yotan: "#d2ba6c",
  okayaman: "#b5b3bf",
  yumemin: "#8bbaca",
};
const characterLines: Record<string, string> = {
  fukuchan: "今日も、ぎゅんぎゅん。",
  tokun: "社長の隣には、いつもウクレレ。",
  yotan: "窓際に、ロックを。",
  okayaman: "窓際族を見守る、伝説の王。",
  yumemin: "夢の向こうから、ふわり。",
};
const extras: Record<string, { line: string; detail: string; tags: string[] }> =
  {
    sobaya: {
      line: "ビール片手に、今日もマイペース。",
      detail:
        "窓際の立ち飲み処を営む店主。見た目は怖いけれど、仲間には優しい。ベランダに席を移されても、冷たいビールが飲めれば「快適です！」。",
      tags: ["白い仮面", "立ち飲み処の店主", "怪力"],
    },
    yametaro: {
      line: "また、何かやらかしたらしい。",
      detail:
        "紫のシャツと丸眼鏡。窓際で巻き起こる騒動の中心には、だいたいこの男がいる。次はどこへ逃げるのか。",
      tags: ["紫のシャツ", "丸眼鏡", "逃走中"],
    },
    takosan: {
      line: "フードの下には、謎がいっぱい。",
      detail:
        "独特の触手とフードが目印の宇宙人。窓際の日常から壮大な騒動まで、不思議な存在感を放つ。",
      tags: ["宇宙人", "触手", "タコ部屋"],
    },
  };
export default function App() {
  const params = new URLSearchParams(location.search);
  const [mode, setMode] = useState<Mode>(
    modes.find((m) => m.id === params.get("view"))?.id ?? "cinema",
  );
  const [character, setCharacter] = useState<Character | null>(
    characters.find((c) => c.id === params.get("character")) ?? null,
  );
  const [active, setActive] = useState(0);
  const [playing, setPlaying] = useState<Episode | null>(null);
  const [image, setImage] = useState<{ src: string; title: string } | null>(
    null,
  );
  const [menu, setMenu] = useState(false);
  const [filter, setFilter] = useState("all");
  const [expanded, setExpanded] = useState(false);
  const [saved, setSaved] = useState<string[]>(() => {
    try {
      return JSON.parse(
        localStorage.getItem("madogiwa-favorites") ?? "[]",
      ) as string[];
    } catch {
      return [];
    }
  });
  const [notice, setNotice] = useState("");
  useEffect(() => {
    document.documentElement.dataset.mode = mode;
    document.title = `${character ? character.name + "｜" : ""}窓際族物語 — ${modes.find((m) => m.id === mode)?.name}`;
    const url = new URL(location.href);
    url.searchParams.set("view", mode);
    if (character) url.searchParams.set("character", character.id);
    else url.searchParams.delete("character");
    history.replaceState(null, "", url);
  }, [mode, character]);
  useEffect(() => {
    if (!notice) return;
    const timer = setTimeout(() => setNotice(""), 2500);
    return () => clearTimeout(timer);
  }, [notice]);
  function openCharacter(c: Character) {
    setCharacter(c);
    window.scrollTo({ top: 0, behavior: "instant" });
    setMenu(false);
  }
  function home() {
    setCharacter(null);
    window.scrollTo({ top: 0, behavior: "instant" });
  }
  function favorite(c: Character) {
    const next = saved.includes(c.id)
      ? saved.filter((id) => id !== c.id)
      : [...saved, c.id];
    setSaved(next);
    localStorage.setItem("madogiwa-favorites", JSON.stringify(next));
  }
  function jump(id: string) {
    setCharacter(null);
    setMenu(false);
    requestAnimationFrame(() =>
      document.getElementById(id)?.scrollIntoView({ behavior: "smooth" }),
    );
  }
  const featured = picks[active];
  const catalog = rawEpisodes.filter(
    (e) => filter === "all" || e.members.some((m) => m.slug === filter),
  );
  const sectionTitle = (
    label: string,
    id: string,
    action?: () => void,
    text = "すべて見る",
  ) => (
    <div className="section-title">
      <h2 id={id}>{label}</h2>
      {action && (
        <button onClick={action}>
          {text}
          <ArrowRight size={16} />
        </button>
      )}
    </div>
  );
  const movie = (e: Episode, index = 0) => (
    <button className="movie" key={e.id} onClick={() => setPlaying(e)}>
      <div className="movie-image">
        <img src={poster(e)} alt="" loading="lazy" />
        <span className="small-play">
          <Play size={18} fill="currentColor" />
        </span>
        <span className="duration">
          {duration(e) === "undefined秒" ? "短編" : duration(e)}
        </span>
      </div>
      <div className="movie-caption">
        <span className="movie-index">
          {String(index + 1).padStart(2, "0")}
        </span>
        <div>
          <h3>{title(e)}</h3>
          <p>
            {descriptions[e.slug] ?? e.members.map((m) => m.name).join("・")}
          </p>
        </div>
      </div>
    </button>
  );
  const castStrip = () => (
    <section className="section cast-section">
      {sectionTitle("登場人物", "characters")}
      <div className="cast-strip">
        {characters.map((c) => (
          <button
            className="cast-card"
            key={c.id}
            onClick={() => openCharacter(c)}
            style={{ "--cast-color": themeColors[c.id] } as React.CSSProperties}
          >
            <div>
              <img src={c.image} alt="" loading="lazy" />
              <ArrowUpRight size={19} />
            </div>
            <h3>{c.name}</h3>
            <p>{c.role}</p>
          </button>
        ))}
      </div>
    </section>
  );
  return (
    <>
      <div className="preview-bar">
        <span>デザイン比較</span>
        <div>
          {modes.map((m) => (
            <button
              key={m.id}
              aria-pressed={mode === m.id}
              onClick={() => setMode(m.id)}
            >
              <b>{m.label}</b> {m.name}
            </button>
          ))}
        </div>
      </div>
      <header className="site-header">
        <button className="brand" onClick={home}>
          <img src="/site/sobaya-icon.jpg" alt="" />
          <span>
            窓際族物語<small>公式サイト</small>
          </span>
        </button>
        <nav aria-label="メインメニュー">
          <button onClick={() => jump("movies")}>動画</button>
          <button onClick={() => jump("characters")}>登場人物</button>
          <button onClick={() => jump("world")}>はじめての方へ</button>
          <button onClick={() => jump("extras")}>漫画・ゲーム</button>
        </nav>
        <button
          className="mobile-menu"
          aria-label="メニュー"
          aria-expanded={menu}
          onClick={() => setMenu(!menu)}
        >
          {menu ? <X /> : <Menu />}
        </button>
      </header>
      {menu && (
        <nav className="menu-panel">
          {[
            ["movies", "動画"],
            ["characters", "登場人物"],
            ["world", "はじめての方へ"],
            ["extras", "漫画・ゲーム"],
          ].map(([id, label]) => (
            <button key={id} onClick={() => jump(id)}>
              {label}
              <ArrowRight size={18} />
            </button>
          ))}
        </nav>
      )}
      {character ? (
        <main
          className="character-page"
          style={
            { "--cast-color": themeColors[character.id] } as React.CSSProperties
          }
        >
          <div className="character-nav">
            <button onClick={home}>
              <ArrowLeft size={16} /> トップへ
            </button>
            <span>登場人物</span>
          </div>
          <section className="character-feature">
            <div className="character-portrait">
              <img src={character.image} alt={character.name} />
              <span className="portrait-label">
                {character.id.toUpperCase()}
              </span>
            </div>
            <div className="character-profile">
              <p className="eyebrow">{character.role}</p>
              <h1>{character.name}</h1>
              <p className="character-line">
                {extras[character.id]?.line ??
                  characterLines[character.id] ??
                  character.copy}
              </p>
              <p className="character-bio">
                {extras[character.id]?.detail ?? character.copy}
              </p>
              <div className="tags">
                {(extras[character.id]?.tags ?? [character.role]).map((tag) => (
                  <span key={tag}>{tag}</span>
                ))}
              </div>
              <div className="profile-actions">
                <button
                  className="primary-button"
                  onClick={() => {
                    const e = rawEpisodes.find((e) =>
                      e.members.some((m) => m.slug === character.id),
                    );
                    if (e) setPlaying(e);
                  }}
                >
                  <Play size={17} fill="currentColor" />
                  登場する動画を見る
                </button>
                <button
                  className="round-button"
                  aria-label="推しに登録"
                  aria-pressed={saved.includes(character.id)}
                  onClick={() => favorite(character)}
                >
                  {saved.includes(character.id) ? (
                    <Heart fill="currentColor" />
                  ) : (
                    <Heart />
                  )}
                </button>
              </div>
              <p className="favorite-note">
                {saved.includes(character.id)
                  ? "推しに登録しました。このブラウザに保存されます。"
                  : "気になるキャラを、推しに登録。"}
              </p>
              {character.id === "sobaya" && <VoiceButton />}
            </div>
          </section>
          <section className="section">
            <div className="section-title">
              <h2>{character.name}の出演作</h2>
              <button
                onClick={() => {
                  setFilter(character.id);
                  setExpanded(true);
                  jump("movies");
                }}
              >
                全
                {
                  rawEpisodes.filter((e) =>
                    e.members.some((m) => m.slug === character.id),
                  ).length
                }
                作品を見る <ArrowRight size={16} />
              </button>
            </div>
            <div className="movie-grid">
              {[
                ...picks,
                ...rawEpisodes.filter((e) => !curatedSlugs.includes(e.slug)),
              ]
                .filter((e) => e.members.some((m) => m.slug === character.id))
                .slice(0, 6)
                .map(movie)}
            </div>
          </section>
          <section className="section">
            <div className="section-title">
              <h2>仲間をもっと知る</h2>
            </div>
            <div className="relation-grid">
              {characters
                .filter((c) => c.id !== character.id)
                .slice(0, 3)
                .map((c) => (
                  <button onClick={() => openCharacter(c)} key={c.id}>
                    <img src={c.image} alt="" />
                    <div>
                      <small>{c.role}</small>
                      <h3>{c.name}</h3>
                      <p>{c.copy}</p>
                    </div>
                    <ArrowRight />
                  </button>
                ))}
            </div>
          </section>
        </main>
      ) : (
        <main>
          {mode === "cinema" && (
            <section className="cinema-hero">
              <button
                className="hero-art"
                onClick={() => setPlaying(featured)}
                aria-label={`${title(featured)}を再生`}
              >
                <img
                  src={poster(featured)}
                  alt={title(featured)}
                  fetchPriority="high"
                />
                <span className="hero-play">
                  <Play fill="currentColor" size={30} />
                </span>
              </button>
              <div className="cinema-caption">
                <div>
                  <span className="eyebrow">
                    はじめての一本 · {duration(featured)}
                  </span>
                  <h1>{title(featured)}</h1>
                  <p>{descriptions[featured.slug]}</p>
                </div>
                <button
                  className="primary-button"
                  onClick={() => setPlaying(featured)}
                >
                  <Play size={17} fill="currentColor" /> 再生する
                </button>
              </div>
              <div className="hero-switcher">
                {picks.map((e, i) => (
                  <button
                    key={e.id}
                    aria-pressed={active === i}
                    onClick={() => setActive(i)}
                  >
                    <img src={poster(e)} alt="" />
                    <span>
                      <small>0{i + 1}</small>
                      {title(e)}
                    </span>
                  </button>
                ))}
              </div>
            </section>
          )}
          {mode === "paper" && (
            <section className="paper-hero">
              <div className="issue-line">
                <span>窓際通信</span>
                <span>動画 / 漫画 / ときどき大騒動</span>
              </div>
              <div className="paper-lead">
                <button
                  className="paper-main-image"
                  onClick={() => setPlaying(picks[0])}
                >
                  <img src={poster(picks[0])} alt="出社インポッシブル" />
                  <span>
                    <Play fill="currentColor" />
                    30秒で見る
                  </span>
                </button>
                <div className="paper-side">
                  <span className="eyebrow">今週の一本</span>
                  <h1>出社インポッシブル</h1>
                  <p>
                    命懸けでよじ登った先は、
                    <br />
                    いつもの窓際席。
                  </p>
                  <button
                    className="text-link"
                    onClick={() => setPlaying(picks[0])}
                  >
                    動画を見る <ArrowUpRight size={19} />
                  </button>
                  <div className="editor-pick">
                    <img src="/site/characters/sobaya.webp" alt="そば屋" />
                    <div>
                      <small>この人が主役</small>
                      <button onClick={() => openCharacter(characters[0])}>
                        そば屋 <ArrowRight size={16} />
                      </button>
                    </div>
                  </div>
                </div>
              </div>
              <div className="paper-bottom">
                <span>初めての方へ</span>
                <p>会社の片隅に、酒場を開いた人たちがいます。</p>
                <button onClick={() => jump("world")} aria-label="世界観を読む">
                  <ArrowRight />
                </button>
              </div>
            </section>
          )}
          {mode === "club" && (
            <section className="club-hero" id="characters">
              <div className="club-head">
                <h1>登場人物</h1>
                <p>気になる顔から、物語へ。</p>
              </div>
              <div className="club-cast">
                {characters.slice(0, 4).map((c, i) => (
                  <button
                    key={c.id}
                    onClick={() => openCharacter(c)}
                    style={
                      {
                        "--cast-color": themeColors[c.id],
                      } as React.CSSProperties
                    }
                  >
                    <img src={c.image} alt="" />
                    <span className="club-number">0{i + 1}</span>
                    <div>
                      <small>{c.role}</small>
                      <h2>{c.name}</h2>
                      <span className="club-detail">
                        この人を知る <ArrowUpRight size={18} />
                      </span>
                    </div>
                  </button>
                ))}
              </div>
              <div className="club-more">
                {characters.slice(4).map((c) => (
                  <button key={c.id} onClick={() => openCharacter(c)}>
                    <img src={c.image} alt="" />
                    {c.name}
                    <ArrowUpRight size={15} />
                  </button>
                ))}
              </div>
            </section>
          )}
          <section className="section">
            {sectionTitle(
              mode === "club" ? "この3本からどうぞ" : "おすすめ動画",
              "movies",
              () => {
                setExpanded(!expanded);
              },
              expanded ? "閉じる" : "作品一覧",
            )}
            <div className="movie-grid">
              {(mode === "cinema"
                ? [rawEpisodes[0], rawEpisodes[1], picks[2]]
                : mode === "paper"
                  ? [picks[1], picks[2], rawEpisodes[0]]
                  : picks
              ).map(movie)}
            </div>
            {expanded && (
              <div className="catalog">
                <div className="filters" aria-label="出演者で絞り込む">
                  {[{ id: "all", name: "すべて" }, ...characters].map((c) => (
                    <button
                      key={c.id}
                      aria-pressed={filter === c.id}
                      onClick={() => setFilter(c.id)}
                    >
                      {c.name}
                    </button>
                  ))}
                </div>
                <p className="result-count">{catalog.length}作品</p>
                <div className="movie-grid">{catalog.map(movie)}</div>
              </div>
            )}
          </section>
          {mode !== "club" && castStrip()}
          <section className="section world-section" id="world">
            <div className="world-image">
              <img
                src="/site/comic/episode-04.webp"
                alt="ベランダに開店した立ち飲み処"
                loading="lazy"
              />
            </div>
            <div className="world-copy">
              <span className="eyebrow">はじめての方へ</span>
              <h2>
                会社の窓際で、
                <br />
                何してる？
              </h2>
              <p>
                舞台は、巨大IT企業の片隅。
                <br />
                そば屋たちは追いやられた窓際で、
                <br />
                立ち飲み処を開いてしまいます。
              </p>
              <p>
                会社の日常から、宇宙規模の大騒動まで。
                <br />
                気になった短編から、お楽しみください。
              </p>
              <button
                className="text-link"
                onClick={() =>
                  setImage({
                    src: comicEpisodes[0].image,
                    title: "原作漫画 第1話 入社",
                  })
                }
              >
                原作の第1話を読む <ArrowRight size={18} />
              </button>
            </div>
          </section>
          <section className="section" id="extras">
            {sectionTitle("漫画と、遊べる窓際", "enjoy")}
            <div className="extras-grid">
              <button
                onClick={() =>
                  setImage({
                    src: comicEpisodes[0].image,
                    title: "原作漫画 第1話 入社",
                  })
                }
              >
                <div className="comic-preview">
                  {comicEpisodes.slice(0, 3).map((e) => (
                    <img key={e.number} src={e.image} alt="" loading="lazy" />
                  ))}
                </div>
                <div>
                  <h3>原作漫画 全14話</h3>
                  <span>
                    そば屋の入社から読む <ArrowUpRight size={18} />
                  </span>
                </div>
              </button>
              <a
                href="https://sobaya-0141.github.io/Seedance_Madogiwa/"
                target="_blank"
                rel="noreferrer"
              >
                <img
                  src="/site/game/arcade.webp"
                  alt="窓際族物語ゲームセンター"
                  loading="lazy"
                />
                <div>
                  <h3>窓際ゲームセンター</h3>
                  <span>
                    ブラウザで遊ぶ <ArrowUpRight size={18} />
                  </span>
                </div>
              </a>
            </div>
          </section>
          <section className="section gallery-section">
            {sectionTitle("ギャラリー", "gallery")}
            <div className="art-grid">
              {[
                {
                  src: "/site/gallery/regulation-team.webp",
                  title: "規制チーム、出動。",
                },
                {
                  src: "/site/gallery/takosan-homeworld.webp",
                  title: "タコさんの故郷",
                },
                { src: "/site/gallery/soba-shark.webp", title: "Soba Shark" },
              ].map((item) => (
                <button key={item.src} onClick={() => setImage(item)}>
                  <img src={item.src} alt={item.title} loading="lazy" />
                  <span>
                    {item.title}
                    <ArrowUpRight size={16} />
                  </span>
                </button>
              ))}
            </div>
          </section>
        </main>
      )}
      <footer>
        <button className="brand" onClick={home}>
          窓際族物語
        </button>
        <p>動画も、漫画も、ゲームも。窓際は今日も営業中。</p>
        <div>
          <button onClick={() => jump("movies")}>動画</button>
          <button onClick={() => jump("characters")}>登場人物</button>
          <a href="https://madogiwa.work" target="_blank" rel="noreferrer">
            現在の公式サイト <ArrowUpRight size={14} />
          </a>
        </div>
        <small>© 窓際族物語</small>
      </footer>
      <Dialog.Root
        open={!!playing}
        onOpenChange={(open) => {
          if (!open) setPlaying(null);
        }}
      >
        <Dialog.Portal>
          <Dialog.Overlay className="modal-overlay" />
          <Dialog.Content className="video-modal" aria-describedby={undefined}>
            <Dialog.Close className="modal-close" aria-label="閉じる">
              <X />
            </Dialog.Close>
            {playing && (
              <>
                <Dialog.Title>{title(playing)}</Dialog.Title>
                <video
                  key={playing.id}
                  src={
                    localSlugs.includes(playing.slug)
                      ? `/cache/${playing.primary_video_id}.mp4`
                      : `https://madogiwa.work/media/${playing.primary_video_id}`
                  }
                  poster={poster(playing)}
                  controls
                  autoPlay
                  playsInline
                  onError={() =>
                    setNotice(
                      "動画を読み込めませんでした。公式ページでも視聴できます。",
                    )
                  }
                />
                <div className="video-under">
                  <p>
                    {descriptions[playing.slug] ??
                      playing.members.map((m) => m.name).join("・")}
                  </p>
                  <a
                    href={`https://madogiwa.work/episodes/${playing.slug}`}
                    target="_blank"
                    rel="noreferrer"
                  >
                    公式ページ <ArrowUpRight size={15} />
                  </a>
                </div>
                <div className="video-cast">
                  {playing.members.map((m) => (
                    <button
                      key={m.id}
                      onClick={() => {
                        const c = characters.find((c) => c.id === m.slug);
                        if (c) {
                          setPlaying(null);
                          openCharacter(c);
                        }
                      }}
                    >
                      {m.name}
                      <ArrowRight size={14} />
                    </button>
                  ))}
                </div>
                <div className="next-video">
                  <span>次に見る</span>
                  {picks
                    .filter((e) => e.id !== playing.id)
                    .slice(0, 2)
                    .map((e) => (
                      <button key={e.id} onClick={() => setPlaying(e)}>
                        <img src={poster(e)} alt="" />
                        {title(e)}
                        <Play size={16} />
                      </button>
                    ))}
                </div>
              </>
            )}
          </Dialog.Content>
        </Dialog.Portal>
      </Dialog.Root>
      <Dialog.Root
        open={!!image}
        onOpenChange={(open) => {
          if (!open) setImage(null);
        }}
      >
        <Dialog.Portal>
          <Dialog.Overlay className="modal-overlay" />
          <Dialog.Content className="image-modal" aria-describedby={undefined}>
            <Dialog.Close className="modal-close" aria-label="閉じる">
              <X />
            </Dialog.Close>
            <Dialog.Title>{image?.title}</Dialog.Title>
            <img src={image?.src} alt={image?.title} />
            {image?.src.includes("/comic/") && (
              <div className="comic-navigation">
                {comicEpisodes.map((e) => (
                  <button
                    key={e.number}
                    aria-pressed={image.src === e.image}
                    onClick={() =>
                      setImage({
                        src: e.image,
                        title: `原作漫画 第${e.number}話 ${e.title}`,
                      })
                    }
                  >
                    {e.number}
                  </button>
                ))}
              </div>
            )}
          </Dialog.Content>
        </Dialog.Portal>
      </Dialog.Root>
      {notice && (
        <div className="toast" role="status">
          <Check size={18} />
          {notice}
        </div>
      )}
    </>
  );
}
function VoiceButton() {
  const audio = useRef<HTMLAudioElement>(null);
  const [playing, setPlaying] = useState(false);
  return (
    <div className="voice">
      <audio
        ref={audio}
        src="/voice/sobaya.wav"
        onEnded={() => setPlaying(false)}
      />
      <button
        onClick={() => {
          if (playing) {
            audio.current?.pause();
            setPlaying(false);
          } else {
            void audio.current
              ?.play()
              .then(() => setPlaying(true))
              .catch(() => setPlaying(false));
          }
        }}
      >
        <Volume2 size={18} />
        {playing ? "再生を止める" : "そば屋の声を聴く"}
        <span className={playing ? "wave playing" : "wave"}>
          <i />
          <i />
          <i />
          <i />
          <i />
        </span>
      </button>
    </div>
  );
}
