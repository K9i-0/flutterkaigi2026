import { useEffect, useRef, useState } from "react";
import * as Dialog from "@radix-ui/react-dialog";
import {
  ArrowLeft,
  ArrowRight,
  ArrowUpRight,
  Play,
  X,
  Menu,
  Search,
  Heart,
  Volume2,
  Pause,
  ChevronLeft,
  ChevronRight,
  Check,
  Share2,
  BookOpen,
  Star,
  Beer,
} from "lucide-react";
import {
  cast,
  starterSlugs,
  episodeTitle,
  episodeCopy,
  poster,
  runtime,
  videoSource,
  categories,
  category,
  comicEpisodes,
  type Episode,
  type Cast,
} from "./journal-data";
import type { GalleryItem } from "../lib/api";
import "./journal.css";
import "./sakaba.css";
import { chooseThemeFeature, themeFeatures } from "./theme-features";
import { OwnerNote, ownerNotes, menuNotes } from "./shop-details";
import { ThemeSwitcher, DesktopChrome, ExcelFormula, WorkSheet, PointLedger } from "./episode-themes";
import { Noren, SobayaLantern } from "./sakaba-entrance";
import { useSiteTheme, siteThemes, type AvailableTheme } from "./site-theme";
import "./shop-details.css";
type Page = "home" | "movies" | "characters" | "world" | "story" | "gallery";
type Route = {
  page: Page;
  character?: string;
  member?: string;
  collection?: string;
  chapter?: number;
  scope?: "all";
};
const pageNames: Record<Page, string> = {
  home: "トップ",
  movies: "動画",
  characters: "登場人物",
  world: "はじめての方へ",
  story: "原作漫画",
  gallery: "ギャラリー",
};
function readRoute(href = typeof location === "undefined" ? "/" : location.href): Route {
  const url = new URL(href, "https://madogiwa.work");
  const p = url.searchParams;
  const path = url.pathname.replace(/\/$/, "");
  const pathPage = path === "/episodes" || path === "/movies" ? "movies" : path.startsWith("/characters") ? "characters" : path === "/story" ? "story" : path === "/gallery" ? "gallery" : null;
  const page = p.get("page") ?? pathPage;
  return {
    page:
      page && Object.hasOwn(pageNames, page)
        ? (page as Page)
        : p.has("character")
          ? "characters"
          : "home",
    character: p.get("character") ?? (path.startsWith("/characters/") ? path.split("/")[2] : undefined),
    member: p.get("member") ?? undefined,
    scope: p.get("scope") === "all" ? "all" : undefined,
    collection: p.get("collection") ?? undefined,
    chapter: Math.min(
      14,
      Math.max(1, Math.floor(Number(p.get("chapter"))) || 1),
    ),
  };
}
function href(route: Route) {
  const q = new URLSearchParams();
  if (route.page !== "home") q.set("page", route.page);
  if (route.character) q.set("character", route.character);
  if (route.scope) q.set("scope", route.scope);
  if (route.member) q.set("member", route.member);
  if (route.collection) q.set("collection", route.collection);
  if (route.page === "story") q.set("chapter", String(route.chapter ?? 1));
  return `/?${q}`;
}
function IconPlay() {
  return <Play size={15} fill="currentColor" />;
}
export default function Journal({ episodes: publicEpisodes, galleryItems, initialTheme, initialHref }: { episodes: Episode[]; galleryItems: GalleryItem[]; initialTheme?: AvailableTheme; initialHref?: string }) {
  const arts = galleryItems.map((item) => ({ src: item.image_url, title: item.title, kind: item.kind }));
  const episodes = publicEpisodes.filter((e) => e.primary_video_id && !e.title.includes("検証"));
  const starters = starterSlugs.map((slug) => episodes.find((e) => e.slug === slug)).filter((e): e is Episode => !!e);
  if (!starters.length && episodes.length) starters.push(episodes[0]);
  const { theme, changeTheme } = useSiteTheme(initialTheme);
  const hero = chooseThemeFeature(episodes, theme) ?? episodes[0];
  const feature = themeFeatures[theme];
  const lead = cast.find((person) => person.id === (hero?.slug === feature.slug ? feature.character : hero?.members[0]?.slug)) ?? cast[0];
  const [lanternLit, setLanternLit] = useState(true);
  const [working, setWorking] = useState(false);
  const chooseTheme = (next: AvailableTheme) => { setWorking(false); changeTheme(next); };
  const [route, setRoute] = useState<Route>(() => readRoute(initialHref));
  const [menu, setMenu] = useState(false);
  const [playing, setPlaying] = useState<Episode | null>(null);
  const [zoom, setZoom] = useState<{ src: string; title: string } | null>(null);
  const [toast, setToast] = useState("");
  const [query, setQuery] = useState("");
  const [saved, setSaved] = useState<string[]>([]);
  useEffect(() => {
    try {
      const ids: unknown = JSON.parse(localStorage.getItem("madogiwa-favorites") ?? "[]");
      if (Array.isArray(ids)) setSaved(ids.filter((id): id is string => typeof id === "string" && cast.some((c) => c.id === id)));
    } catch { /* Storage may be unavailable. */ }
  }, []);
  const [onlySaved, setOnlySaved] = useState(false);
  const current = cast.find((c) => c.id === route.character);
  const reduced = () =>
    window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  useEffect(() => {
    document.documentElement.dataset.mode = "paper";
    document.documentElement.classList.add("journal-document");
    return () => document.documentElement.classList.remove("journal-document");
  }, []);
  useEffect(() => {
    const restore = () => {
      setRoute(readRoute());
      setMenu(false);
      setPlaying(null);
      setZoom(null);
    };
    window.addEventListener("popstate", restore);
    return () => window.removeEventListener("popstate", restore);
  }, []);
  useEffect(() => {
    document.title = `${current?.name ?? pageNames[route.page]}｜窓際族物語`;
  }, [route.page, current]);
  useEffect(() => {
    const frame = requestAnimationFrame(() => {
      const heading = document.querySelector<HTMLElement>(".j-main h1");
      heading?.setAttribute("tabindex", "-1");
      heading?.focus({ preventScroll: true });
    });
    return () => cancelAnimationFrame(frame);
  }, [route.page, route.character, route.chapter]);
  useEffect(() => {
    if (playing)
      document.querySelectorAll("audio").forEach((audio) => audio.pause());
  }, [playing]);
  useEffect(() => {
    if (!toast) return;
    const timer = setTimeout(() => setToast(""), 2800);
    return () => clearTimeout(timer);
  }, [toast]);
  function go(next: Route) {
    setWorking(false);
    history.pushState(null, "", href(next));
    setRoute(next);
    setMenu(false);
    setPlaying(null);
    setQuery("");
    window.scrollTo({ top: 0, behavior: "instant" });
  }
  function link(next: Route, label: React.ReactNode, className = "") {
    return (
      <a
        href={href(next)}
        className={className}
        onClick={(e) => {
          if (!e.metaKey && !e.ctrlKey && !e.shiftKey && !e.altKey) {
            e.preventDefault();
            go(next);
          }
        }}
      >
        {label}
      </a>
    );
  }
  function fave(c: Cast) {
    const next = saved.includes(c.id)
      ? saved.filter((id) => id !== c.id)
      : [...saved, c.id];
    setSaved(next);
    try {
      localStorage.setItem("madogiwa-favorites", JSON.stringify(next));
      setToast(
        next.includes(c.id)
          ? `${c.name}を推しに登録しました`
          : "推し登録を解除しました",
      );
    } catch {
      setToast("この画面で登録しました。ブラウザへの保存はできませんでした。");
    }
  }
  async function share(c: Cast) {
    try {
      await navigator.clipboard.writeText(
        `${location.origin}${href({ page: "characters", character: c.id })}`,
      );
      setToast("このキャラクターページのURLをコピーしました");
    } catch {
      setToast("アドレスバーのURLをコピーして共有できます。");
    }
  }
  function heading(name: string, action?: Route, more = "すべて見る") {
    const note = theme === "sakaba" ? ownerNotes[name] : undefined;
    return (
      <div className="j-section-heading">
        <div className={note ? "s-heading-with-note" : undefined}><h2>{note?.title ?? name}</h2>{note && <OwnerNote>{note.note}</OwnerNote>}</div>
        {action &&
          link(
            action,
            <>
              {more}
              <ArrowRight size={16} />
            </>,
            "j-more",
          )}
      </div>
    );
  }
  function movie(e: Episode, feature = false) {
    return (
      <article
        className={`j-movie${feature ? " j-movie-large" : ""}`}
        key={e.id}
      >
        <button
          className="j-movie-visual"
          onClick={() => setPlaying(e)}
          aria-label={`${episodeTitle(e)}を再生`}
        >
          <img src={poster(e)} alt="" loading="lazy" />
          <span className="j-play-mini">
            <IconPlay />
          </span>
          <span className="j-runtime">{runtime(e)}</span>
        </button>
        <div className="j-movie-meta">
          <span>{category(e)}{e.has_featured_video === 1 && <span className="j-pickup-badge"><Star size={11} fill="currentColor" />ピックアップ</span>}</span>
          <button onClick={() => setPlaying(e)}>
            <h3>{episodeTitle(e)}</h3>
          </button>
          {theme === "sakaba" && menuNotes[e.slug] ? <p className="s-menu-aside"><small>店主のひとこと</small>{menuNotes[e.slug]}</p> : <p>{episodeCopy(e)}</p>}
        </div>
      </article>
    );
  }
  function person(c: Cast, compact = false) {
    return link(
      { page: "characters", character: c.id },
      <>
        <div
          className="j-cast-photo"
          style={{ "--person-color": c.color } as React.CSSProperties}
        >
          <img src={c.image} alt={c.name} loading="lazy" />
          <span className="j-arrow">
            <ArrowUpRight size={18} />
          </span>
          {saved.includes(c.id) && (
            <span className="j-saved-mark">
              <Heart size={13} fill="currentColor" />
              推し
            </span>
          )}
        </div>
        <div className="j-cast-meta">
          <small>{c.role}</small>
          <h3>{c.name}</h3>
          {!compact && <p>{c.line}</p>}
        </div>
      </>,
      `j-cast-card ${compact ? "compact" : ""}`,
    );
  }
  const roster = (compact = false) => (
    <div className={`j-roster ${compact ? "compact" : ""}`}>
      {cast.map((c) => (
        <div key={c.id}>{person(c, compact)}</div>
      ))}
    </div>
  );
  const breadcrumbs = (label: string) => (
    <div className="j-breadcrumb">
      {link({ page: "home" }, "トップ")}
      <span>/</span>
      {current ? (
        <>
          {link({ page: "characters" }, "登場人物")}
          <span>/</span>
        </>
      ) : null}
      <span>{label}</span>
    </div>
  );
  const worldStrip = (
    <section className="j-world-strip">
      <div>
        <img
          src="/site/comic/episode-04.webp"
          alt="ベランダに開店した立ち飲み処"
          loading="lazy"
        />
      </div>
      <div>
        {theme === "sakaba" && <span className="s-small-label">当店のご案内</span>}
        <h2>初めての方へ</h2>
        {theme === "sakaba" && <OwnerNote>初めて？ とりあえず座って。</OwnerNote>}
        <p>会社の窓際に、酒場ができました。<br />そば屋と仲間たちを、漫画と動画でご紹介。</p>
        {link(
          { page: "world" },
          <>
            窓際族物語を知る
            <ArrowRight size={17} />
          </>,
          "j-underlined",
        )}
      </div>
    </section>
  );
  const story = comicEpisodes[(route.chapter ?? 1) - 1];
  const filtered = episodes.filter(
    (e) =>
      (route.scope === "all" || e.has_featured_video === 1) &&
      (!route.member || e.members.some((m) => m.slug === route.member)) &&
      (!route.collection || category(e) === route.collection) &&
      `${episodeTitle(e)} ${e.summary} ${e.members.map((m) => m.name).join(" ")}`
        .toLowerCase()
        .includes(query.toLowerCase()),
  );
  const mainHeader = (
    <header className="j-header" data-lantern-lit={lanternLit}>
      {theme === "sakaba" && <Noren />}
      <div className="j-header-main">
        {theme === "sakaba" && <SobayaLantern lit={lanternLit} onToggle={() => setLanternLit((value) => !value)} />}
        {link(
          { page: "home" },
          <>
            {theme !== "sakaba" && <img src="/site/sobaya-icon.jpg" alt="" />}
            <span>
              窓際族物語<small>公式サイト</small>
              {theme === "sakaba" && <i className="j-sakaba-seal" aria-hidden="true">窓際</i>}
            </span>
          </>,
          "j-brand",
        )}
        <nav aria-label="メインメニュー">
          {(["movies", "characters", "world", "story"] as Page[]).map(
            (page) => (
              <span key={page}>
                {link(
                  { page },
                  pageNames[page],
                  route.page === page ? "active" : "",
                )}
              </span>
            ),
          )}
        </nav>
        <ThemeSwitcher theme={theme} onChange={chooseTheme} onOpen={() => setMenu(false)} />
        <button
          className="j-menu-button"
          aria-label="メニュー"
          aria-expanded={menu}
          onClick={() => setMenu(!menu)}
        >
          {menu ? <X size={22} /> : <Menu size={22} />}
        </button>
      </div>
      {menu && (
        <nav className="j-mobile-nav" aria-label="スマホメニュー">
          {(
            [
              "home",
              "movies",
              "characters",
              "world",
              "story",
              "gallery",
            ] as Page[]
          ).map((page) => (
            <span key={page}>
              {link(
                { page },
                <>
                  {pageNames[page]}
                  <ArrowRight size={17} />
                </>,
              )}
            </span>
          ))}
        </nav>
      )}
    </header>
  );
  return (
    <div className="journal" style={{ "--shop-light": lanternLit ? 1 : 0 } as React.CSSProperties}>
      <DesktopChrome theme={theme} working={working} onToggleWork={() => setWorking((value) => !value)} />
      {mainHeader}
      {theme === "excel" && <ExcelFormula title={working ? "仕事中" : pageNames[route.page]} />}
      {theme === "underground" && <PointLedger />}
      {theme === "excel" && working && <WorkSheet onClose={() => setWorking(false)} />}
      <main className="j-main" hidden={theme === "excel" && working}>
        {route.page === "home" && !hero && <section className="j-cover"><h1>窓際族物語</h1><p>公開中の動画はまだありません。</p></section>}
        {route.page === "home" && hero && (
          <>
            <section className="j-cover">
              <div className="j-cover-rule">
                <span>{({ sakaba: "本日のお品書き", excel: "窓際業務報告", underground: "休憩時間の上映案内" })[theme]}</span>
                <span>{theme === "sakaba" ? "立ち飲み処 窓際酒場" : theme === "underground" ? "地下売店・娯楽係" : "動画・漫画・ときどき大騒動"}</span>
              </div>
              <div className="j-cover-grid">
                <button
                  className="j-cover-photo"
                  onClick={() => setPlaying(hero)}
                  aria-label={`${episodeTitle(hero)}を再生`}
                >
                  <img
                    src={poster(hero)}
                    alt={episodeTitle(hero)}
                    fetchPriority="high"
                  />
                  <span className="j-photo-play">
                    <IconPlay />
                    {runtime(hero) === "短編" ? "動画を見る" : `${runtime(hero)}で見る`}
                  </span>
                </button>
                <div className="j-cover-copy">
                  {theme === "sakaba" && <span className="s-house-stamp" aria-hidden="true">店主<br />おすすめ</span>}
                  <span className="j-outline-label">{theme === "sakaba" ? "本日のおすすめ" : "おすすめの一本"}</span>
                  <h1>{episodeTitle(hero)}</h1>
                  <p>{episodeCopy(hero)}</p>
                  <button
                    className="j-underlined"
                    onClick={() => setPlaying(hero)}
                  >
                    動画を見る
                    <ArrowUpRight size={18} />
                  </button>
                  {theme === "sakaba" && <OwnerNote portrait>{hero.slug === feature.slug ? feature.note : "まず一本。ビールは持った？"}</OwnerNote>}
                  {link(
                    { page: "characters", character: lead.id },
                    <>
                      <img src={lead.image} alt="" />
                      <span>
                        <small>この人が主役</small>
                        <b>
                          {lead.name}
                          <ArrowRight size={15} />
                        </b>
                      </span>
                    </>,
                    "j-lead-person",
                  )}
                </div>
              </div>
            </section>
            <section className="j-section j-introduction">{worldStrip}</section>
            <section className="j-section j-latest">
              {heading("新着動画", { page: "movies" }, "作品一覧")}
              <div className="j-movie-grid">
                {episodes
                  .filter((e) => !e.slug.endsWith("-trailer"))
                  .slice(0, 3)
                  .map((e) => movie(e))}
              </div>
            </section>
            <section className="j-section j-feature-person">
              {heading("人物特集", { page: "characters" }, "8人の登場人物")}
              <div className="j-person-editorial">
                {link(
                  { page: "characters", character: "sobaya" },
                  <>
                    <img src="/site/characters/sobaya.webp" alt="そば屋" />
                    <span>そば屋</span>
                  </>,
                  "j-person-editorial-image",
                )}
                <div className="j-person-editorial-copy">
                  <h2 className="j-cheers">「乾杯！」{theme === "sakaba" && <Beer size={27} aria-hidden="true" />}</h2>
                  <p>ビール片手に仲間を迎える、<br />窓際の立ち飲み処の店主。</p>
                  {link(
                    { page: "characters", character: "sobaya" },
                    <>
                      そば屋のページへ
                      <ArrowRight size={17} />
                    </>,
                    "j-underlined",
                  )}
                </div>
              </div>
              <div className="j-friends-row">
                {cast.slice(1).map((c) => (
                  <div key={c.id}>
                    {link(
                      { page: "characters", character: c.id },
                      <>
                        <img src={c.image} alt="" data-character={c.id} loading="lazy" />
                        <span>{c.name}</span>
                        <ArrowUpRight size={14} />
                      </>,
                    )}
                  </div>
                ))}
              </div>
            </section>
            <section className="j-section s-after-hours">
              {heading("漫画・ゲーム")}
              <div className="j-experiences">
                {link(
                  { page: "story" },
                  <>
                    <div className="j-comic-collage">
                      {comicEpisodes.slice(0, 3).map((e) => (
                        <img
                          key={e.number}
                          src={e.image}
                          alt=""
                          loading="lazy"
                        />
                      ))}
                    </div>
                    <div className="j-experience-label">
                      <div>
                        <small>原作漫画 / 全14話</small>
                        <h3>はじまりは、そば屋の入社。</h3>
                      </div>
                      <ArrowUpRight />
                    </div>
                  </>,
                )}
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
                  <div className="j-experience-label">
                    <div>
                      <small>ブラウザですぐに遊べる</small>
                      <h3>窓際ゲームセンター</h3>
                    </div>
                    <ArrowUpRight />
                  </div>
                </a>
              </div>
            </section>
            <section className="j-section s-wall-gallery">
              {heading("ギャラリー", { page: "gallery" })}
              <div className="j-art-grid">
                {arts.slice(0, 3).map((a) => (
                  <button key={a.src} onClick={() => setZoom(a)}>
                    <img src={a.src} alt={a.title} loading="lazy" />
                    <span>
                      <small>{a.kind}</small>
                      <b>{a.title}</b>
                      <ArrowUpRight size={17} />
                    </span>
                  </button>
                ))}
              </div>
            </section>
          </>
        )}
        {route.page === "movies" && (
          <>
            {breadcrumbs("動画")}
            <div className="j-page-heading">
              <div>
                <span className="j-kicker">窓際の上映室</span>
                <h1>動画</h1>
              </div>
              <p>
                日常から大騒動まで。
                <br />
                気になった一本からどうぞ。
              </p>
            </div>
            <div className="j-scope-tabs" aria-label="動画の表示範囲">
              {([undefined, "all"] as const).map((scope) => (
                <button key={scope ?? "pickup"} aria-pressed={route.scope === scope}
                  onClick={() => {
                    const next = { ...route, scope };
                    history.replaceState(null, "", href(next));
                    setRoute(next);
                  }}>
                  {!scope && <Star size={14} fill="currentColor" />}
                  {scope ? "すべての動画" : "ピックアップ"}
                  <span>{episodes.filter((e) => scope || e.has_featured_video === 1).length}</span>
                </button>
              ))}
            </div>
            <div className="j-search">
              <Search size={19} />
              <input
                aria-label="動画を検索"
                placeholder="作品名・登場人物で探す"
                value={query}
                onChange={(e) => setQuery(e.target.value)}
              />
              {query && (
                <button aria-label="検索をクリア" onClick={() => setQuery("")}>
                  <X size={17} />
                </button>
              )}
            </div>
            <div className="j-category-tabs" aria-label="ジャンルで絞り込む">
              {categories.map((c) => (
                <button
                  key={c}
                  aria-pressed={c === (route.collection ?? "すべて")}
                  onClick={() => {
                    const next = {
                      ...route,
                      collection: c === "すべて" ? undefined : c,
                    };
                    history.replaceState(null, "", href(next));
                    setRoute(next);
                  }}
                >
                  {c === "すべて" ? "全ジャンル" : c}
                </button>
              ))}
            </div>
            <div className="j-filter-row">
              <label>
                登場人物
                <select
                  value={route.member ?? ""}
                  onChange={(e) => {
                    const next = {
                      ...route,
                      member: e.target.value || undefined,
                    };
                    history.replaceState(null, "", href(next));
                    setRoute(next);
                  }}
                >
                  <option value="">すべての登場人物</option>
                  {cast.map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.name}
                    </option>
                  ))}
                </select>
              </label>
              <span aria-live="polite">{filtered.length}作品</span>
            </div>
            <div className="j-movie-grid j-catalog">
              {filtered.map((e) => movie(e))}
            </div>
            {!filtered.length && (
              <div className="j-empty">
                <Search />
                <h2>見つかりませんでした</h2>
                <p>別の言葉や登場人物で探してみてください。</p>
                <button
                  className="j-button"
                  onClick={() => {
                    setQuery("");
                    go({ page: "movies" });
                  }}
                >
                  条件をリセット
                </button>
              </div>
            )}
          </>
        )}
        {route.page === "characters" && !current && (
          <>
            {breadcrumbs("登場人物")}
            <div className="j-page-heading">
              <div>
                <span className="j-kicker">窓際の顔ぶれ</span>
                <h1>登場人物</h1>
              </div>
              <p>
                気になる顔を見つけたら、
                <br />
                その人の物語をのぞいてみよう。
              </p>
            </div>
            <div className="j-cast-filter">
              <button
                aria-pressed={!onlySaved}
                onClick={() => setOnlySaved(false)}
              >
                みんな
              </button>
              <button
                aria-pressed={onlySaved}
                onClick={() => setOnlySaved(true)}
              >
                <Heart size={15} />
                あなたの推し <span>{saved.length}</span>
              </button>
            </div>
            {onlySaved ? (
              saved.length ? (
                <div className="j-roster">
                  {cast
                    .filter((c) => saved.includes(c.id))
                    .map((c) => (
                      <div key={c.id}>{person(c)}</div>
                    ))}
                </div>
              ) : (
                <div className="j-empty">
                  <Heart />
                  <h2>推しは、これから。</h2>
                  <p>人物ページのハートを押すと、ここに並びます。</p>
                  <button
                    className="j-button"
                    onClick={() => setOnlySaved(false)}
                  >
                    登場人物を見る
                  </button>
                </div>
              )
            ) : (
              roster()
            )}
            <div className="j-character-bottom">
              {link(
                { page: "movies" },
                <>
                  映像で出会う、窓際族。
                  <span>
                    動画を見る
                    <ArrowRight size={17} />
                  </span>
                </>,
              )}
            </div>
          </>
        )}
        {route.page === "characters" && current && (
          <>
            {breadcrumbs(current.name)}
            <section
              className="j-profile"
              style={{ "--person-color": current.color } as React.CSSProperties}
            >
              <div className="j-profile-photo">
                <img src={current.image} alt={current.name} />
                <span className="j-profile-name-en">
                  {current.id.toUpperCase()}
                </span>
              </div>
              <div className="j-profile-copy">
                <span className="j-kicker">{current.role}</span>
                <h1>{current.name}</h1>
                <p className="j-profile-line">{current.line}</p>
                <p>{current.bio}</p>
                <div className="j-profile-buttons">
                  <button
                    className={`j-button ${saved.includes(current.id) ? "saved" : ""}`}
                    aria-pressed={saved.includes(current.id)}
                    onClick={() => fave(current)}
                  >
                    <Heart
                      size={17}
                      fill={
                        saved.includes(current.id) ? "currentColor" : "none"
                      }
                    />
                    {saved.includes(current.id)
                      ? "推しに登録済み"
                      : "推しに登録"}
                  </button>
                  <button
                    className="j-icon-button"
                    aria-label="キャラクターページのURLをコピー"
                    onClick={() => {
                      void share(current);
                    }}
                  >
                    <Share2 size={18} />
                  </button>
                </div>
                <span className="j-storage-note">
                  推しは、このブラウザに保存されます。
                </span>
                {current.id === "sobaya" && (
                  <Voice
                    onError={() =>
                      setToast(
                        "音声を読み込めませんでした。もう一度お試しください。",
                      )
                    }
                  />
                )}
                <nav
                  className="j-profile-pagination"
                  aria-label="前後のキャラクター"
                >
                  {link(
                    {
                      page: "characters",
                      character: cast[(cast.indexOf(current) + 7) % 8].id,
                    },
                    <>
                      <ChevronLeft size={16} />
                      前の人物
                    </>,
                  )}
                  {link(
                    {
                      page: "characters",
                      character: cast[(cast.indexOf(current) + 1) % 8].id,
                    },
                    <>
                      次の人物
                      <ChevronRight size={16} />
                    </>,
                  )}
                </nav>
              </div>
            </section>
            <section className="j-person-story">
              <div>
                <span className="j-kicker">その人らしさ</span>
                <h2>{current.quote}</h2>
                <p>{current.detail}</p>
              </div>
              <dl>
                {current.facts.map(([key, value]) => (
                  <div key={key}>
                    <dt>{key}</dt>
                    <dd>{value}</dd>
                  </div>
                ))}
              </dl>
            </section>
            <section className="j-section">
              {heading(`${current.name}が登場する動画`, {
                page: "movies",
                member: current.id,
              })}
              <div className="j-movie-grid">
                {[
                  ...starters,
                  ...episodes.filter((e) => !starterSlugs.includes(e.slug)),
                ]
                  .filter((e) => e.members.some((m) => m.slug === current.id))
                  .slice(0, 3)
                  .map((e) => movie(e))}
              </div>
            </section>
            <section className="j-section">
              {heading("この人と、あの人。")}
              <div className="j-relationships">
                {current.related.map((id, i) => {
                  const friend = cast.find((c) => c.id === id)!;
                  return (
                    <article key={id}>
                      {link(
                        { page: "characters", character: id },
                        <>
                          <img src={friend.image} alt="" />
                          <div>
                            <small>{current.relation[i]}</small>
                            <h3>{friend.name}</h3>
                          </div>
                          <ArrowUpRight size={18} />
                        </>,
                      )}
                      <button
                        onClick={() => {
                          const e = episodes.find(
                            (e) =>
                              e.members.some((m) => m.slug === id) &&
                              e.members.some((m) => m.slug === current.id),
                          );
                          if (e) setPlaying(e);
                        }}
                      >
                        ふたりが登場する動画
                        <Play size={13} />
                      </button>
                    </article>
                  );
                })}
              </div>
            </section>
          </>
        )}
        {route.page === "world" && (
          <>
            {breadcrumbs("はじめての方へ")}
            <div className="j-page-heading">
              <div>
                <span className="j-kicker">窓際族物語とは</span>
                <h1>会社の窓際で、何してる？</h1>
              </div>
            </div>
            <section className="j-world-opening">
              <img
                src="/site/comic/episode-04.webp"
                alt="ベランダの立ち飲み処"
              />
              <div>
                <h2>
                  席を追われても、
                  <br />
                  楽しみは手放さない。
                </h2>
                <p>
                  巨大IT企業「アクシデンチュア株式会社」。
                  <br />
                  真面目に働く社員たちの傍らで、
                  <br />
                  窓際の一角だけは、なぜか自由空間。
                </p>
                <p>
                  そば屋が開いた酒場には、同僚も社長も集まります。
                  <br />
                  窓際からベランダへ、ベランダから地上へ。
                  <br />
                  追いやられた先で、また何かが始まります。
                </p>
              </div>
            </section>
            <div className="j-world-chapters">
              {[
                {
                  image: 2,
                  title: "席は、段ボール。",
                  copy: "入社したそば屋を待っていたのは、手書きの「アーロンチェア」。本人は、もちろん快適です。",
                },
                {
                  image: 4,
                  title: "会社で、立ち飲み。",
                  copy: "暖簾と赤提灯を掲げたら、窓際酒場の開店。福ちゃんも、ウクレレを持った社長もやってきます。",
                },
                {
                  image: 11,
                  title: "捕まると、普通に働く。",
                  copy: "窓際族が連れて行かれるタコ部屋。待っているのは、電話対応やパソコン作業です。",
                },
              ].map((item, i) => (
                <article key={item.title}>
                  <img
                    src={comicEpisodes[item.image - 1].image}
                    alt={item.title}
                    loading="lazy"
                  />
                  <small>0{i + 1}</small>
                  <h2>{item.title}</h2>
                  <p>{item.copy}</p>
                </article>
              ))}
            </div>
            <section className="j-world-invite">
              <BookOpen size={24} />
              <div>
                <h2>始まりを読むなら、原作14話。</h2>
                <p>そば屋の入社から、窓際の仲間との出会いまで。</p>
              </div>
              {link(
                { page: "story" },
                <>
                  第1話を読む
                  <ArrowRight size={17} />
                </>,
                "j-button",
              )}
            </section>
            <section className="j-section">
              {heading("まずは、この一本から。", { page: "movies" })}
              <div className="j-movie-grid">
                {starters.map((e) => movie(e))}
              </div>
            </section>
            <section className="j-section">
              {heading("窓際に集まる仲間たち", { page: "characters" })}
              {roster(true)}
            </section>
          </>
        )}
        {route.page === "story" && (
          <>
            {breadcrumbs("原作漫画")}
            <div className="j-page-heading">
              <div>
                <span className="j-kicker">全14話</span>
                <h1>原作漫画</h1>
              </div>
              <p>
                そば屋の入社から始まる、
                <br />
                窓際族物語の原点。
              </p>
            </div>
            <section className="j-reader">
              <div className="j-reader-image">
                <button
                  onClick={() =>
                    setZoom({
                      src: story.image,
                      title: `第${story.number}話 ${story.title}`,
                    })
                  }
                  aria-label={`第${story.number}話の画像を拡大`}
                >
                  <img
                    src={story.image}
                    alt={`第${story.number}話 ${story.title}`}
                  />
                  <span>
                    画像を拡大
                    <ArrowUpRight size={14} />
                  </span>
                </button>
              </div>
              <div className="j-reader-copy">
                <span className="j-kicker">
                  第{String(story.number).padStart(2, "0")}話 / 14
                </span>
                <h2>{story.title}</h2>
                <p>{story.description}</p>
                <div className="j-reader-controls">
                  <button
                    aria-label="前の話"
                    disabled={story.number === 1}
                    onClick={() =>
                      go({ page: "story", chapter: story.number - 1 })
                    }
                  >
                    <ArrowLeft size={19} />
                  </button>
                  <span>{story.number} / 14</span>
                  <button
                    aria-label="次の話"
                    disabled={story.number === 14}
                    onClick={() =>
                      go({ page: "story", chapter: story.number + 1 })
                    }
                  >
                    <ArrowRight size={19} />
                  </button>
                </div>
                {story.number === 14 &&
                  link(
                    { page: "movies" },
                    <>
                      続いて、動画の窓際へ
                      <ArrowRight size={17} />
                    </>,
                    "j-underlined",
                  )}
              </div>
            </section>
            <nav className="j-chapter-list" aria-label="話数を選ぶ">
              {comicEpisodes.map((e) => (
                <a
                  key={e.number}
                  href={href({ page: "story", chapter: e.number })}
                  aria-current={story.number === e.number ? "page" : undefined}
                  onClick={(event) => {
                    event.preventDefault();
                    go({ page: "story", chapter: e.number });
                  }}
                >
                  <img src={e.image} alt="" loading="lazy" />
                  <span>
                    <small>第{e.number}話</small>
                    {e.title}
                  </span>
                </a>
              ))}
            </nav>
          </>
        )}
        {route.page === "gallery" && (
          <>
            {breadcrumbs("ギャラリー")}
            <div className="j-page-heading">
              <div>
                <span className="j-kicker">もうひとつの窓際</span>
                <h1>ギャラリー</h1>
              </div>
              <p>
                映画のような一枚も、
                <br />
                不思議な故郷の景色も。
              </p>
            </div>
            <div className="j-gallery-wall">
              {arts.map((a) => (
                <button key={a.src} onClick={() => setZoom(a)}>
                  <img src={a.src} alt={a.title} />
                  <span>
                    <small>{a.kind}</small>
                    <h2>{a.title}</h2>
                    <ArrowUpRight />
                  </span>
                </button>
              ))}
            </div>
          </>
        )}
        {route.page === "home" && (
          <section id="goods" className="j-section j-goods" aria-labelledby="goods-title">
            <header>
              <span className="j-kicker">グッズ</span>
              <h2 id="goods-title">{theme === "sakaba" ? "酒場の土産棚" : theme === "underground" ? "地下売店" : "窓際購買部"}</h2>
              <p>窓際族を、日常の片隅に。</p>
            </header>
            <div className="j-goods-item">
              <a className="j-goods-image" href="https://suzuri.jp/sobaya15/20889070/t-shirt/xl/white" target="_blank" rel="noreferrer" aria-label="窓際族TシャツをSUZURIで見る（新しいタブ）">
                <img src="/site/goods/madogiwa-tshirt.webp" alt="窓際族の仲間たちが集合したイラストと、白い窓際族Tシャツ" width="1200" height="630" loading="lazy" />
              </a>
              <div className="j-goods-copy">
                <h3>窓際族Tシャツ</h3>
                <p>いつもの仲間たちが、一枚に。<br />窓際族が好きなあなたへ。</p>
                <a className="j-goods-link" href="https://suzuri.jp/sobaya15/20889070/t-shirt/xl/white" target="_blank" rel="noreferrer">SUZURIで見る <ArrowUpRight size={16} /></a>
                <small>ご購入・色・サイズの選択はSUZURIへ。</small>
              </div>
            </div>
          </section>
        )}
      </main>
      <div className="j-footer-shell">
      <footer className="j-footer">
        <div className="j-footer-top">
          {link({ page: "home" }, "窓際族物語", "j-footer-brand")}
          <button
            onClick={() =>
              window.scrollTo({
                top: 0,
                behavior: reduced() ? "instant" : "smooth",
              })
            }
          >
            ページの先頭へ
            <ArrowUpRight size={17} />
          </button>
        </div>
        <div className="j-footer-links">
          {(
            ["movies", "characters", "world", "story", "gallery"] as Page[]
          ).map((page) => (
            <span key={page}>{link({ page }, pageNames[page])}</span>
          ))}
          <a
            href="https://sobaya-0141.github.io/Seedance_Madogiwa/"
            target="_blank"
            rel="noreferrer"
          >
            ゲーム
            <ArrowUpRight size={13} />
          </a>
        </div>
        <label className="j-theme-picker">
          表示スタイル
          <select value={theme} onChange={(event) => chooseTheme(event.target.value as AvailableTheme)}>
            {Object.entries(siteThemes).filter(([, value]) => value.ready).map(([id, value]) => <option key={id} value={id}>{value.label}</option>)}
          </select>
        </label>
        <div className="j-footer-bottom">
          <small>© 窓際族物語</small>
          <span>窓際は、今日も営業中。</span>
        </div>
      </footer>
      </div>
      {theme === "excel" && <nav className="e-sheet-tabs" aria-label="ワークシート">
        {(["home", "movies", "characters", "world", "story"] as Page[]).map((page) => <span key={page}>{link({ page }, pageNames[page], page === route.page ? "active" : "")}</span>)}
      </nav>}
      <Dialog.Root
        open={!!playing}
        onOpenChange={(open) => {
          if (!open) setPlaying(null);
        }}
      >
        <Dialog.Portal>
          <Dialog.Overlay className="j-dialog-overlay" />
          <Dialog.Content
            className="j-video-dialog"
            aria-describedby={undefined}
          >
            <Dialog.Close className="j-dialog-close" aria-label="閉じる">
              <X size={21} />
            </Dialog.Close>
            {playing && (
              <>
                <div className="j-video-title">
                  <span>
                    {category(playing)} · {runtime(playing)}
                  </span>
                  <Dialog.Title>{episodeTitle(playing)}</Dialog.Title>
                </div>
                <Video key={playing.id} episode={playing} />
                <p className="j-video-description">{episodeCopy(playing)}</p>
                <div className="j-video-cast">
                  <span>出演</span>
                  {playing.members.map((m) => {
                    const c = cast.find((c) => c.id === m.slug);
                    return c ? (
                      <span key={c.id}>
                        {link(
                          { page: "characters", character: c.id },
                          <>
                            <img src={c.image} alt="" />
                            {c.name}
                            <ArrowUpRight size={12} />
                          </>,
                        )}
                      </span>
                    ) : null;
                  })}
                </div>
                <div className="j-next">
                  <span>次に見るなら</span>
                  {starters
                    .filter((e) => e.id !== playing.id)
                    .slice(0, 2)
                    .map((e) => (
                      <button key={e.id} onClick={() => setPlaying(e)}>
                        <img src={poster(e)} alt="" />
                        <div>
                          <small>{runtime(e)}</small>
                          <b>{episodeTitle(e)}</b>
                        </div>
                        <IconPlay />
                      </button>
                    ))}
                </div>
              </>
            )}
          </Dialog.Content>
        </Dialog.Portal>
      </Dialog.Root>
      <Dialog.Root
        open={!!zoom}
        onOpenChange={(open) => {
          if (!open) setZoom(null);
        }}
      >
        <Dialog.Portal>
          <Dialog.Overlay className="j-dialog-overlay" />
          <Dialog.Content
            className="j-image-dialog"
            aria-describedby={undefined}
          >
            <Dialog.Close className="j-dialog-close" aria-label="閉じる">
              <X size={21} />
            </Dialog.Close>
            <Dialog.Title>{zoom?.title}</Dialog.Title>
            <img src={zoom?.src} alt={zoom?.title} />
          </Dialog.Content>
        </Dialog.Portal>
      </Dialog.Root>
      {toast && (
        <div className="j-toast" role="status">
          <Check size={17} />
          {toast}
        </div>
      )}
    </div>
  );
}
function Video({ episode }: { episode: Episode }) {
  const [failed, setFailed] = useState(false);
  const [ended, setEnded] = useState(false);
  const ref = useRef<HTMLVideoElement>(null);
  return (
    <div className="j-player">
      <video
        ref={ref}
        src={videoSource(episode)}
        poster={poster(episode)}
        controls
        autoPlay
        playsInline
        preload="metadata"
        onError={() => setFailed(true)}
        onEnded={() => setEnded(true)}
        onPlay={() => setEnded(false)}
      />
      {failed && (
        <div className="j-player-state">
          <p>動画を読み込めませんでした。</p>
          <a
            href={`https://madogiwa.work/episodes/${episode.slug}`}
            target="_blank"
            rel="noreferrer"
          >
            公式ページで見る
            <ArrowUpRight size={17} />
          </a>
        </div>
      )}
      {ended && !failed && (
        <div className="j-player-state">
          <button
            onClick={() => {
              if (ref.current) {
                ref.current.currentTime = 0;
                void ref.current.play().catch(() => setFailed(true));
              }
            }}
          >
            <IconPlay />
            もう一度見る
          </button>
          <p>続きは、下のおすすめから。</p>
        </div>
      )}
    </div>
  );
}
function Voice({ onError }: { onError: () => void }) {
  const ref = useRef<HTMLAudioElement>(null);
  const [playing, setPlaying] = useState(false);
  useEffect(
    () => () => {
      ref.current?.pause();
    },
    [],
  );
  return (
    <div className="j-voice">
      <audio
        ref={ref}
        src="/voice/sobaya.wav"
        preload="none"
        onPause={() => setPlaying(false)}
        onEnded={() => setPlaying(false)}
        onError={onError}
      />
      <button
        onClick={() => {
          if (playing) {
            ref.current?.pause();
            setPlaying(false);
          } else {
            void ref.current
              ?.play()
              .then(() => setPlaying(true))
              .catch(onError);
          }
        }}
      >
        {playing ? <Pause size={17} /> : <Volume2 size={17} />}
        <span>{playing ? "声を再生中" : "そば屋の声を聴く"}</span>
        <span className={`j-wave ${playing ? "is-playing" : ""}`}>
          <i />
          <i />
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
