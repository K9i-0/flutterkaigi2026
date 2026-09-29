import { useEffect, useRef, useState } from "react";
import { Link } from "@tanstack/react-router";
import {
  ArrowDownToLine,
  ArrowLeft,
  ArrowUpRight,
  Check,
  Copy,
  Film,
  Play,
  Search,
  Share2,
  X,
} from "lucide-react";
import catalog from "./catalog.json";
import "./clips.css";

export const clips = catalog;
type Clip = (typeof clips)[number];
const characters = [
  "すべて",
  "そば屋",
  "やめ太郎",
  "福ちゃん",
  "おかやまん",
  "よーたん",
];
const seconds = (clip: Clip) => `${clip.seconds.toFixed(1)}秒`;

function Player({ clip }: { clip: Clip }) {
  const [playing, setPlaying] = useState(false);
  return (
    <div className="clips-player">
      {playing ? (
        <video
          src={clip.video}
          poster={clip.poster}
          controls
          autoPlay
          playsInline
          preload="metadata"
          onPlay={(event) => {
            document.querySelectorAll("video").forEach((video) => {
              if (video !== event.currentTarget) video.pause();
            });
          }}
        />
      ) : (
        <button
          className="clips-play"
          onClick={() => setPlaying(true)}
          aria-label={`${clip.title}を再生`}
        >
          <img src={clip.poster} alt="" loading="lazy" />
          <span>
            <Play size={24} fill="currentColor" />
          </span>
          <small>音声つき · {seconds(clip)}</small>
        </button>
      )}
    </div>
  );
}

function Actions({ clip }: { clip: Clip }) {
  const [file, setFile] = useState<File | null>(null);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  const [copied, setCopied] = useState(false);
  const [fallbackUrl, setFallbackUrl] = useState("");
  const active = useRef(true);
  useEffect(() => {
    active.current = true;
    return () => {
      active.current = false;
    };
  }, []);
  async function share() {
    setMessage("");
    if (file) {
      try {
        await navigator.share({ files: [file] });
      } catch (error) {
        if (import.meta.env.DEV)
          console.warn("Clip file sharing failed", error);
        if (!(error instanceof DOMException && error.name === "AbortError"))
          setMessage("共有できませんでした。MP4を保存して添付できます。");
      }
      return;
    }
    if (!navigator.share || !navigator.canShare) {
      setMessage(
        "このブラウザでは動画の共有メニューを使えません。MP4を保存して添付してください。",
      );
      return;
    }
    setBusy(true);
    try {
      const response = await fetch(clip.video);
      if (!response.ok) throw new Error("Video unavailable");
      const prepared = new File([await response.blob()], clip.filename, {
        type: "video/mp4",
      });
      if (!active.current) return;
      if (!navigator.canShare({ files: [prepared] })) {
        setMessage(
          "この環境ではMP4を直接共有できません。MP4を保存して添付してください。",
        );
        return;
      }
      setFile(prepared);
      setMessage(
        "動画を準備しました。もう一度ボタンを押すと共有先を選べます。",
      );
    } catch {
      if (active.current)
        setMessage(
          "動画を読み込めませんでした。接続を確認して、もう一度お試しください。",
        );
    } finally {
      if (active.current) setBusy(false);
    }
  }
  async function copy() {
    const url = new URL(`/clips/${clip.id}`, window.location.origin).href;
    try {
      await navigator.clipboard.writeText(url);
      setCopied(true);
      setFallbackUrl("");
    } catch {
      setFallbackUrl(url);
      setMessage("下のURLを選択してコピーしてください。");
    }
  }
  return (
    <div className="clips-actions-wrap">
      <div className="clips-actions">
        <a
          className="clips-download"
          href={`${clip.video}?download=1`}
          download={clip.filename}
        >
          <ArrowDownToLine size={17} />
          MP4を保存
        </a>
        <button onClick={() => void share()} disabled={busy}>
          <Share2 size={17} />
          {busy ? "準備中…" : file ? "共有先を選ぶ" : "動画を共有"}
        </button>
        <button
          onClick={() => void copy()}
          aria-label={`${clip.title}のURLをコピー`}
        >
          {copied ? <Check size={17} /> : <Copy size={17} />}
          {copied ? "コピー済み" : "URLをコピー"}
        </button>
      </div>
      {message && (
        <p className="clips-status" role="status">
          {message}
        </p>
      )}
      {fallbackUrl && (
        <input
          className="clips-copy-fallback"
          aria-label="クリップのURL"
          readOnly
          value={fallbackUrl}
          onFocus={(event) => event.target.select()}
        />
      )}
    </div>
  );
}

function Shell({ children }: { children: React.ReactNode }) {
  return (
    <div className="clips-shell">
      <header className="clips-header">
        <a href="/" className="clips-brand">
          <img src="/site/sobaya-icon.jpg" alt="" />
          <span>
            窓際族物語<small>働かない。でも、物語は動き出す。</small>
          </span>
        </a>
        <nav>
          <a href="/episodes">
            本編一覧
            <ArrowUpRight size={14} />
          </a>
          <span className="clips-preview">ローカルプレビュー</span>
        </nav>
      </header>
      {children}
      <footer className="clips-footer">
        <b>窓際族物語</b>
        <span>迷言も、迷場面も、日常のひとコマに。</span>
        <small>© MADOGIWAZOKU MONOGATARI</small>
      </footer>
    </div>
  );
}

function Guide() {
  return (
    <details className="clips-guide">
      <summary>
        動画の使い方 <span>保存・共有・URLのちがい</span>
      </summary>
      <div>
        <p>
          <b>MP4を保存</b>
          音声つきの動画を保存し、Xの返信やSlackのメッセージに添付。iPhoneでは「ファイル」に保存される場合があります。「ファイル」の共有メニューに「ビデオを保存」があれば写真アプリへ移せます。
        </p>
        <p>
          <b>動画を共有</b>
          動画を準備したあと「共有先を選ぶ」で端末の共有メニューを開きます。選べるアプリは環境によって異なります。Xの特定の投稿に返信する場合は、返信画面から保存したMP4を添付してください。
        </p>
        <p>
          <b>URLをコピー</b>
          このクリップのページを紹介するリンクです。動画ファイルの添付とは異なります。今はローカル版のため、この端末で開く確認用URLです。
        </p>
      </div>
    </details>
  );
}

export function ClipsPage() {
  const [query, setQuery] = useState("");
  const [character, setCharacter] = useState("すべて");
  const [kind, setKind] = useState("すべて");
  const filtered = clips.filter(
    (clip) =>
      (character === "すべて" || clip.character === character) &&
      (kind === "すべて" || clip.kind === kind) &&
      `${clip.title} ${clip.character} ${clip.tag} ${clip.episode}話`.includes(
        query.trim(),
      ),
  );
  return (
    <Shell>
      <main className="clips-main">
        <section className="clips-hero">
          <div>
            <div className="clips-eyebrow">
              <span /> 窓際から、おすそわけ。
            </div>
            <h1>
              迷言<span>・</span>迷場面集
              <span className="clips-period">。</span>
            </h1>
            <p>
              あのひと言も、あの騒動も。
              <br />
              お気に入りの一幕を、会話のおともに。
            </p>
            <div className="clips-hero-meta">
              <span>
                <Film size={16} />
                {clips.length} CLIPS
              </span>
              <span>音声つきMP4</span>
              <span>2〜9秒の短編</span>
            </div>
          </div>
          <div className="clips-hero-note">
            <span>本日の窓際心得</span>
            <p>
              一流の窓際族は、
              <br />
              窓際を作り出す。
            </p>
            <Link to="/clips/$slug" params={{ slug: "first-class" }}>
              そば屋 ／ 第59話 <ArrowUpRight size={16} />
            </Link>
          </div>
        </section>
        <Guide />
        <section className="clips-selection" aria-label="クリップを探す">
          <div className="clips-filter-top">
            <div className="clips-kind">
              {["すべて", "迷場面", "迷言"].map((item) => (
                <button
                  key={item}
                  aria-pressed={kind === item}
                  onClick={() => setKind(item)}
                >
                  {item}
                </button>
              ))}
            </div>
            <label className="clips-search">
              <Search size={18} />
              <input
                type="search"
                placeholder="セリフ・人物・話数で探す"
                aria-label="クリップを検索"
                value={query}
                onChange={(event) => setQuery(event.target.value)}
              />
            </label>
          </div>
          <div className="clips-character-filter">
            {characters.map((item) => (
              <button
                key={item}
                aria-pressed={character === item}
                onClick={() => setCharacter(item)}
              >
                {item}
              </button>
            ))}
          </div>
        </section>
        <div className="clips-results">
          <h2>窓際の名場面を、ひとつ。</h2>
          <span aria-live="polite">{filtered.length} 本</span>
        </div>
        <div className="clips-grid">
          {filtered.map((clip) => (
            <article className="clips-card" key={clip.id}>
              <Player clip={clip} />
              <div className="clips-card-body">
                <div className="clips-card-meta">
                  <span>{clip.character}</span>
                  <span>
                    第{clip.episode}話 · {clip.kind}
                  </span>
                </div>
                <h3>
                  <Link to="/clips/$slug" params={{ slug: clip.id }}>
                    {clip.title}
                  </Link>
                </h3>
                <div className="clips-card-info">
                  <span>#{clip.tag}</span>
                  <span>
                    {seconds(clip)} · {(clip.bytes / 1024 / 1024).toFixed(1)} MB
                  </span>
                </div>
                <Actions clip={clip} />
                <Link
                  className="clips-source-link"
                  to="/clips/$slug"
                  params={{ slug: clip.id }}
                >
                  切り抜き元・クリップ詳細 <ArrowUpRight size={14} />
                </Link>
              </div>
            </article>
          ))}
        </div>
        {!filtered.length && (
          <div className="clips-empty">
            <Search size={30} />
            <h3>見つかりませんでした</h3>
            <p>セリフの一部や、人物名で探してみてください。</p>
            <button
              onClick={() => {
                setQuery("");
                setKind("すべて");
                setCharacter("すべて");
              }}
            >
              絞り込みをリセット
            </button>
          </div>
        )}
      </main>
    </Shell>
  );
}

export function ClipPage({ clip }: { clip: Clip }) {
  const [sourceOpen, setSourceOpen] = useState(false);
  return (
    <Shell>
      <main className="clips-main clips-detail">
        <Link className="clips-back" to="/clips">
          <ArrowLeft size={16} />
          迷言・迷場面集へ
        </Link>
        <div className="clips-detail-grid">
          <section>
            <Player clip={clip} />
            <div className="clips-detail-caption">
              <span>
                第{clip.episode}話 ／ {clip.character}
              </span>
              <span>{seconds(clip)} · 音声つきMP4</span>
            </div>
          </section>
          <section className="clips-detail-info">
            <div className="clips-eyebrow">
              {clip.kind} ／ #{clip.tag}
            </div>
            <h1>{clip.title}</h1>
            <p>この一幕を、会話のおともに。</p>
            <Actions clip={clip} />
            <div className="clips-source-box">
              <span>この場面のつづきは…</span>
              <h2>切り抜き元を見る</h2>
              <p>
                第{clip.episode}話 · {Math.floor(clip.startSeconds)}秒付近から
              </p>
              <button onClick={() => setSourceOpen(!sourceOpen)}>
                {sourceOpen ? <X size={16} /> : <Play size={16} />}
                {sourceOpen ? "元動画を閉じる" : "元動画をこの場面から再生"}
              </button>
              {clip.episodeSlug && (
                <a
                  href={`https://madogiwa.work/episodes/${clip.episodeSlug}`}
                  target="_blank"
                  rel="noreferrer"
                >
                  公式サイトで第{clip.episode}話を見る
                  <ArrowUpRight size={14} />
                </a>
              )}
            </div>
          </section>
        </div>
        {sourceOpen && (
          <section className="clips-original">
            <h2>切り抜き元動画 ／ 第{clip.episode}話</h2>
            <video
              src={`${clip.source}#t=${clip.startSeconds}`}
              controls
              autoPlay
              playsInline
              onPlay={() => {
                document
                  .querySelectorAll(".clips-player video")
                  .forEach((video) => (video as HTMLVideoElement).pause());
              }}
            />
            <p>
              制作時のローカル動画です。公式サイトの掲載版と編集が異なる場合があります。
            </p>
          </section>
        )}
        <Guide />
        <aside className="clips-detail-next">
          <b>ほかの一幕も、のぞいていく？</b>
          <Link to="/clips">
            迷言・迷場面集へ
            <ArrowUpRight size={18} />
          </Link>
        </aside>
      </main>
    </Shell>
  );
}
