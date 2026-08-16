import { ArrowLeft, Check, Clipboard, Clock3, Download, FileText, Film, History, ImageIcon, Music2, PencilLine, Users } from "lucide-react";
import { useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { toast } from "sonner";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader } from "@/components/ui/card";
import { ZoomableImage } from "@/components/image-lightbox";
import { api, type Generation, type InputAsset } from "@/lib/api";
import { cn, formatBytes, formatDate } from "@/lib/utils";

export function EpisodePage() {
  const { slug = "" } = useParams();
  const [detail, setDetail] = useState<Awaited<ReturnType<typeof api.getEpisode>> | null>(null);
  const [selectedGenerationId, setSelectedGenerationId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api.getEpisode(slug).then((result) => {
      setDetail(result);
      setSelectedGenerationId(result.generations[0]?.id ?? null);
    }).catch((reason: unknown) => setError(reason instanceof Error ? reason.message : "読み込みに失敗しました"));
  }, [slug]);

  if (error) return <div className="py-20 text-center text-red-300">{error}</div>;
  if (!detail) return <div className="py-20 text-center text-sm text-stone-600">エピソードを読み込んでいます…</div>;
  const { episode, members, generations } = detail;
  const generation = generations.find((item) => item.id === selectedGenerationId) ?? generations[0] ?? null;

  return <div className="space-y-8">
    <div className="flex flex-wrap items-center justify-between gap-4"><Button variant="ghost" asChild><Link to="/"><ArrowLeft className="size-4" />Archive</Link></Button><Button variant="secondary" asChild><Link reloadDocument to={`/admin?episode=${episode.slug}`}><PencilLine className="size-4" />編集</Link></Button></div>
    <section className="grid gap-8 lg:grid-cols-[minmax(0,1.55fr)_minmax(320px,0.75fr)]"><div className="space-y-5"><div className="font-mono text-xs text-stone-500">{episode.studio_id}</div><h1 className="text-balance text-3xl font-semibold tracking-[-0.04em] sm:text-5xl">{episode.title}</h1><p className="max-w-3xl text-sm leading-7 text-stone-400 sm:text-base">{episode.summary || "概要はまだ登録されていません。"}</p><div className="flex flex-wrap items-center gap-2"><Users className="size-3.5 text-stone-600" />{members.length ? members.map((member) => <span key={member.id} className="rounded-full border border-white/8 bg-white/[0.025] px-3 py-1 text-xs text-stone-400">{member.name}</span>) : <span className="text-xs text-stone-600">登場メンバー未登録</span>}</div></div><div className="grid grid-cols-2 gap-3 self-end"><Meta label="Updated" value={formatDate(episode.updated_at)} /><Meta label="Versions" value={`${generations.length} generations`} /></div></section>

    <section className="space-y-3"><div className="text-[10px] uppercase tracking-[0.18em] text-stone-600">Generation history</div><div className="flex flex-wrap gap-2">{generations.map((item) => <button key={item.id} onClick={() => setSelectedGenerationId(item.id)} className={cn("rounded-2xl border px-4 py-3 text-left transition", item.id === generation?.id ? "border-amber-300/25 bg-amber-300/[0.08]" : "border-white/8 bg-white/[0.02] hover:border-white/15")}><div className={cn("font-mono text-sm font-semibold", item.id === generation?.id ? "text-amber-200" : "text-stone-400")}>v{item.version}</div><div className="mt-1 max-w-40 truncate text-[10px] text-stone-600">{item.label || `生成 v${item.version}`}</div>{item.model_name ? <div className="mt-1 max-w-40 truncate text-[10px] text-violet-300/70">{item.model_name}</div> : null}</button>)}</div></section>

    {generation ? <GenerationContent generation={generation} /> : <div className="rounded-3xl border border-dashed border-white/10 py-20 text-center text-sm text-stone-600">生成バージョンがありません。</div>}
  </div>;
}

function GenerationContent({ generation }: { generation: Generation }) {
  const visibleVideos = generation.videos.filter((video) => !["archived", "upload_pending"].includes(video.status));
  return <div className="space-y-8"><div className="rounded-2xl border border-white/7 bg-white/[0.02] px-5 py-4"><div className="flex flex-wrap items-center justify-between gap-3"><div><div className="flex flex-wrap items-center gap-2"><span className="text-sm font-medium">v{generation.version} · {generation.label || `生成 v${generation.version}`}</span>{generation.model_name ? <Badge className="border-violet-400/15 bg-violet-400/[0.06] text-violet-300">{generation.model_name}</Badge> : null}</div>{generation.notes ? <p className="mt-2 text-xs leading-5 text-stone-500">{generation.notes}</p> : null}</div><span className="text-[10px] text-stone-600">{formatDate(generation.updated_at)}</span></div></div>
    <section className="space-y-5"><div className="flex items-center gap-2 text-sm font-medium"><Film className="size-4 text-amber-300" />Generated videos</div>{visibleVideos.length ? <div className="grid gap-5 xl:grid-cols-2">{visibleVideos.map((video) => <Card key={video.id} className="overflow-hidden"><video src={`/media/${video.id}`} poster={video.poster_r2_key ? `/posters/${video.id}` : undefined} controls preload="metadata" playsInline className="aspect-video w-full bg-black object-contain" /><CardContent className="pt-5"><div><div className="text-sm font-medium">{video.label}</div><div className="mt-1 text-xs text-stone-600">{video.filename} · {formatBytes(video.size_bytes)}</div></div></CardContent></Card>)}</div> : <Empty message="このバージョンには動画がありません。" />}</section>
    <InputAssetsSection assets={generation.inputAssets} />
    <Card><CardHeader className="flex-row items-center justify-between gap-4 border-b border-white/6"><div><div className="flex items-center gap-2 text-sm font-medium"><Clipboard className="size-4 text-amber-300" />Input prompt</div><div className="mt-2 text-xs text-stone-600">この生成バージョンで使用したプロンプトです。</div></div>{generation.prompt ? <Badge>revision {generation.prompt.version}</Badge> : null}</CardHeader><CardContent className="pt-6">{generation.prompt ? <PromptBlock body={generation.prompt.body} /> : <div className="py-10 text-center text-sm text-stone-600">プロンプトはまだ登録されていません。</div>}</CardContent></Card>
    {generation.promptHistory.length > 1 ? <details className="group rounded-2xl border border-white/7 bg-white/[0.02]"><summary className="flex cursor-pointer list-none items-center gap-2 px-5 py-4 text-sm text-stone-400"><History className="size-4" />過去のプロンプト {generation.promptHistory.length - 1}件</summary><div className="space-y-3 border-t border-white/6 p-5">{generation.promptHistory.slice(1).map((item) => <div key={item.id} className="flex items-center justify-between text-xs text-stone-500"><span>revision {item.version} · {item.label}</span><span>{formatDate(item.created_at)}</span></div>)}</div></details> : null}
  </div>;
}

function InputAssetsSection({ assets }: { assets: InputAsset[] }) {
  const groups = Array.from(assets.filter((asset) => asset.status === "ready").reduce((map, asset) => { const key = asset.group_label || "共通入力"; map.set(key, [...(map.get(key) ?? []), asset]); return map; }, new Map<string, InputAsset[]>()));
  return <section className="space-y-5"><div><div className="flex items-center gap-2 text-sm font-medium"><ImageIcon className="size-4 text-sky-300" />Input assets</div><p className="mt-2 text-xs text-stone-600">この生成バージョンへ渡した画像、参照音声、補足資料です。</p></div>{groups.length ? <div className="space-y-6">{groups.map(([group, items]) => <div key={group} className="space-y-3"><div className="flex items-center gap-3"><Badge>{group}</Badge><span className="text-[10px] text-stone-600">{items.length} files</span></div><div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">{items.map((asset) => <InputAssetCard key={asset.id} asset={asset} />)}</div></div>)}</div> : <Empty message="このバージョンには入力アセットがありません。" />}</section>;
}

function InputAssetCard({ asset }: { asset: InputAsset }) {
  const url = `/inputs/${asset.id}`;
  const icon = asset.kind === "image" ? <ImageIcon className="size-4 text-sky-300" /> : asset.kind === "audio" ? <Music2 className="size-4 text-violet-300" /> : <FileText className="size-4 text-stone-400" />;
  return <Card className="overflow-hidden">{asset.kind === "image" ? <ZoomableImage src={url} alt={asset.label} caption={asset.notes || asset.reference_label || undefined} loading="lazy" buttonClassName="episode-input-image-trigger" className="aspect-video w-full bg-black/30 object-contain" /> : null}{asset.kind === "audio" ? <div className="border-b border-white/6 bg-gradient-to-br from-violet-400/[0.08] to-transparent p-5"><audio src={url} controls preload="metadata" className="h-10 w-full" /></div> : null}<CardContent className="pt-5"><div className="flex items-start justify-between gap-3"><div className="flex min-w-0 items-start gap-3">{icon}<div className="min-w-0"><div className="truncate text-sm font-medium">{asset.label}</div><div className="mt-1 text-[10px] text-stone-600">{asset.reference_label || asset.kind} · {formatBytes(asset.size_bytes)}</div></div></div>{asset.kind === "document" || asset.kind === "other" ? <Button variant="ghost" size="icon" asChild><a href={url}><Download className="size-4" /></a></Button> : null}</div>{asset.notes ? <p className="mt-3 text-xs leading-5 text-stone-500">{asset.notes}</p> : null}<div className="mt-3 truncate font-mono text-[10px] text-stone-700">{asset.filename}</div></CardContent></Card>;
}

function PromptBlock({ body }: { body: string }) {
  const [copied, setCopied] = useState(false);
  async function copy() { await navigator.clipboard.writeText(body); setCopied(true); toast.success("プロンプトをコピーしました"); window.setTimeout(() => setCopied(false), 1500); }
  return <div className="relative"><pre className="max-h-[36rem] overflow-auto whitespace-pre-wrap rounded-2xl bg-black/25 p-5 pr-14 font-mono text-xs leading-6 text-stone-300">{body}</pre><Button variant="secondary" size="icon" onClick={copy} className="absolute right-3 top-3">{copied ? <Check className="size-4" /> : <Clipboard className="size-4" />}</Button></div>;
}

function Meta({ label, value }: { label: string; value: string }) { return <div className="rounded-2xl border border-white/7 bg-white/[0.025] p-4"><div className="flex items-center gap-1.5 text-[10px] uppercase tracking-[0.16em] text-stone-600"><Clock3 className="size-3" />{label}</div><div className="mt-2 text-sm text-stone-300">{value}</div></div>; }
function Empty({ message }: { message: string }) { return <div className="grid min-h-36 place-items-center rounded-3xl border border-dashed border-white/10 text-sm text-stone-600">{message}</div>; }
