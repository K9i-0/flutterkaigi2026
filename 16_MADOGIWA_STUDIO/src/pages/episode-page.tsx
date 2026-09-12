import { useEffect, useState } from "react";
import { ArrowLeft, ImageIcon, Music2, Paperclip } from "lucide-react";
import { DeferredVideo } from "@/components/deferred-video";
import { DocumentPreview } from "@/components/document-preview";
import { ZoomableImage } from "@/components/image-lightbox";
import { episodePoster, type PublicEpisodeDetail, type PublicInputAsset } from "@/lib/public-data";
import "./production-note.css";

export function EpisodePage({ detail }: { detail: PublicEpisodeDetail }) {
  const { episode, videos, productions } = detail;
  const [selected, setSelected] = useState(videos[0]?.id ?? "");
  const [returnTo, setReturnTo] = useState("/?page=movies");
  useEffect(() => {
    const requested = location.hash.replace("#making-", "");
    if (videos.some((video) => video.id === requested)) setSelected(requested);
    try {
      const saved = JSON.parse(sessionStorage.getItem("madogiwa-production-return") ?? "null");
      if (saved?.slug === episode.slug && typeof saved.href === "string" && saved.href.startsWith("/") && !saved.href.startsWith("//")) setReturnTo(saved.href);
    } catch { /* Direct visits return to the video list. */ }
  }, [episode.slug, videos]);
  const video = videos.find((item) => item.id === selected) ?? videos[0];
  const production = productions.find((item) => item.generation_id === video?.generation_id);
  return <article className="production-note">
    <a className="production-back" href={returnTo}><ArrowLeft size={17} />動画に戻る</a>
    <header className="production-heading"><p>窓際族物語 / 制作ノート</p><h1>{episode.title}</h1></header>
    {videos.length > 1 && <label className="production-select">制作バージョン<select value={video?.id} onChange={(event) => { setSelected(event.target.value); history.replaceState(null, "", `#making-${event.target.value}`); }}>{videos.map((item) => <option key={item.id} value={item.id}>{item.label || "動画"} · v{productions.find((p) => p.generation_id === item.generation_id)?.version ?? "—"}</option>)}</select></label>}
    {video && <section className="production-video"><DeferredVideo key={video.id} src={`/media/${video.id}`} poster={video.poster_url ?? episodePoster(detail)} label={video.label || episode.title} /></section>}
    {production ? <div id={`making-${video?.id}`} className="production-content">
      <section className="production-model"><h2>使用モデル</h2><p>{production.model_name || "未登録"}<small>生成 v{production.version} · {production.label}</small></p></section>
      <section className="production-inputs"><h2>入力素材 <small>{production.inputs.length}件</small></h2><p className="production-help">参照番号をプロンプト内の指定と照らし合わせてご覧ください。</p>{production.inputs.length ? <div className="production-input-grid">{production.inputs.map((asset) => <InputAssetPreview key={asset.id} asset={asset} />)}</div> : <p>入力素材はまだ公開されていません。</p>}</section>
      <section className="production-prompt"><h2>プロンプト</h2>{production.prompt ? <><p className="production-help">{production.prompt.label} · revision {production.prompt.version}</p><PromptBody key={production.generation_id} body={production.prompt.body} /></> : <p>プロンプトはまだ公開されていません。</p>}</section>
    </div> : <p className="production-help">この動画の制作資料はまだ公開されていません。</p>}
    <a className="production-back production-back-bottom" href={returnTo}><ArrowLeft size={17} />動画に戻る</a>
  </article>;
}

function InputAssetPreview({ asset }: { asset: PublicInputAsset }) {
  const metadata = [asset.group_label, asset.reference_label, asset.filename].filter(Boolean).join(" · ");
  return <article className="episode-input-asset">
    {asset.kind === "image" ? <ZoomableImage src={asset.url} alt={asset.label} caption={asset.label} loading="lazy" buttonClassName="episode-input-preview episode-input-image-trigger" /> : null}
    {asset.kind === "audio" ? <div className="episode-input-audio"><Music2 /><audio src={asset.url} controls preload="none" /></div> : null}
    {asset.kind === "document" || asset.kind === "other" ? <DocumentPreview asset={asset} /> : null}
    <div className="episode-input-copy">
      <span>{asset.kind === "image" ? <ImageIcon /> : asset.kind === "audio" ? <Music2 /> : <Paperclip />}{asset.kind.toUpperCase()}</span>
      <h3>{asset.label}</h3>
      {metadata ? <small>{metadata}</small> : null}
      {asset.notes ? <p>{asset.notes}</p> : null}
    </div>
  </article>;
}

function PromptBody({ body }: { body: string }) {
  const [message, setMessage] = useState("");
  async function copy() {
    try { await navigator.clipboard.writeText(body); setMessage("コピーしました"); }
    catch { setMessage("コピーできませんでした。本文を選択してコピーしてください。"); }
  }
  return <><button className="episode-prompt-copy" onClick={() => void copy()}>プロンプトをコピー</button><span className="episode-copy-status" role="status">{message}</span><pre>{body}</pre></>;
}
