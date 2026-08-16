import { Bot, CheckCircle2, CloudUpload, FileVideo2, ImageIcon, KeyRound, Layers3, LogOut, Music2, Paperclip, Plus, Save } from "lucide-react";
import { FormEvent, useEffect, useMemo, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { toast } from "sonner";
import { StatusBadge } from "@/components/status-badge";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { AdminAuthenticationRequiredError, api, type EpisodeDetail, type EpisodeStatus, type EpisodeSummary, type Generation, type InputAssetKind, type Member } from "@/lib/api";
import { cn } from "@/lib/utils";

const COMMON_MODELS = ["Seedance 2.0", "Seedance 2.5", "MiniMax H3"];

export function AdminPage() {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const selectedSlug = searchParams.get("episode");
  const [session, setSession] = useState<{ email: string; source: "access" } | null | undefined>(undefined);
  const [episodes, setEpisodes] = useState<EpisodeSummary[]>([]);
  const [members, setMembers] = useState<Member[]>([]);
  const [detail, setDetail] = useState<EpisodeDetail | null>(null);
  const [error, setError] = useState<string | null>(null);

  function handleLoadError(reason: unknown) {
    if (reason instanceof AdminAuthenticationRequiredError) {
      window.location.reload();
      return;
    }
    setError(reason instanceof Error ? reason.message : "読み込みに失敗しました");
  }

  async function refreshList() { setEpisodes((await api.listEpisodes()).episodes); }
  async function refreshDetail(): Promise<EpisodeDetail> {
    if (!selectedSlug) throw new Error("エピソードが選択されていません");
    const next = await api.getEpisode(selectedSlug);
    setDetail(next);
    await refreshList();
    return next;
  }

  useEffect(() => {
    Promise.all([api.getSession(), api.listEpisodes(), api.listMembers()]).then(([sessionResult, episodeResult, memberResult]) => {
      setSession(sessionResult.admin); setEpisodes(episodeResult.episodes); setMembers(memberResult.members);
    }).catch(handleLoadError);
  }, []);
  useEffect(() => {
    if (!selectedSlug) { setDetail(null); return; }
    api.getEpisode(selectedSlug).then(setDetail).catch(handleLoadError);
  }, [selectedSlug]);

  if (error) return <div className="rounded-2xl border border-red-400/20 bg-red-400/8 p-5 text-sm text-red-200">{error}</div>;
  if (session === undefined) return <div className="py-20 text-center text-sm text-stone-600">管理画面を確認しています…</div>;
  if (!session) return <LoginRequired />;

  return <div className="space-y-8"><datalist id="madogiwa-model-suggestions">{COMMON_MODELS.map((model) => <option key={model} value={model} />)}</datalist>
    <section className="flex flex-wrap items-end justify-between gap-5"><div><Badge className="border-emerald-400/20 bg-emerald-400/8 text-emerald-300"><CheckCircle2 className="mr-2 size-3" />Authenticated</Badge><h1 className="mt-5 text-3xl font-semibold tracking-[-0.035em] sm:text-5xl">Production desk</h1><p className="mt-3 text-sm text-stone-500">{session.email}</p></div><div className="flex items-center gap-2"><Badge>Cloudflare Access</Badge><Button variant="ghost" size="sm" asChild><a href="/cdn-cgi/access/logout"><LogOut className="size-3.5" />ログアウト</a></Button></div></section>
    <div className="grid gap-6 lg:grid-cols-[280px_minmax(0,1fr)]"><aside className="space-y-3"><Button className="w-full" onClick={() => void navigate("/admin")}><Plus className="size-4" />新規エピソード</Button><div className="space-y-1 rounded-2xl border border-white/7 bg-white/[0.02] p-2">{episodes.map((episode) => <button key={episode.id} onClick={() => void navigate(`/admin?episode=${episode.slug}`)} className={cn("flex w-full items-center justify-between gap-3 rounded-xl px-3 py-3 text-left transition", selectedSlug === episode.slug ? "bg-white/10" : "hover:bg-white/5")}><div className="min-w-0"><div className="truncate text-sm text-stone-200">{episode.title}</div><div className="mt-1 font-mono text-[10px] text-stone-600">{episode.studio_id} · {episode.generation_count} versions</div></div><StatusBadge status={episode.status} /></button>)}</div><McpHint /></aside><div>{detail ? <EpisodeEditor key={detail.episode.id} detail={detail} members={members} onSaved={refreshDetail} /> : <CreateEpisode members={members} onCreated={async (slug) => { await refreshList(); await navigate(`/admin?episode=${slug}`); }} />}</div></div>
  </div>;
}

function LoginRequired() { return <Card className="mx-auto max-w-xl"><CardHeader className="items-center pt-10 text-center"><span className="grid size-14 place-items-center rounded-2xl bg-amber-400/10 text-amber-300"><KeyRound className="size-6" /></span><h1 className="mt-4 text-2xl font-semibold">管理画面は認証が必要です</h1><p className="max-w-md text-sm leading-6 text-stone-500">Cloudflare Accessのログイン画面から、許可された方法でログインしてください。</p></CardHeader></Card>; }

function CreateEpisode({ members, onCreated }: { members: Member[]; onCreated: (slug: string) => Promise<void> }) {
  const [saving, setSaving] = useState(false);
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setSaving(true); const data = new FormData(event.currentTarget);
    try { const created = await api.createEpisode({ slug: String(data.get("slug")), title: String(data.get("title")), summary: String(data.get("summary")), memberIds: data.getAll("members").map(String) }); toast.success(`${created.studio_id}を作成しました`); await onCreated(created.slug); }
    catch (reason) { toast.error(reason instanceof Error ? reason.message : "作成に失敗しました"); } finally { setSaving(false); }
  }
  return <Card><CardHeader><h2 className="text-xl font-medium">新規エピソード</h2><p className="text-sm text-stone-500">Studio IDとv1は自動生成されます。採番や時系列の入力は不要です。</p></CardHeader><CardContent><form onSubmit={submit} className="grid gap-5 sm:grid-cols-2"><Field label="slug"><Input name="slug" required placeholder="new-episode" /></Field><Field label="タイトル"><Input name="title" required placeholder="エピソードタイトル" /></Field><Field label="概要" className="sm:col-span-2"><Textarea name="summary" placeholder="一覧と詳細ページへ表示する短い概要" /></Field><Field label="登場メンバー" className="sm:col-span-2"><MemberPicker members={members} selected={[]} /></Field><div className="sm:col-span-2"><Button disabled={saving}>{saving ? "作成中…" : "エピソードを作成"}</Button></div></form></CardContent></Card>;
}

function EpisodeEditor({ detail, members, onSaved }: { detail: EpisodeDetail; members: Member[]; onSaved: () => Promise<EpisodeDetail> }) {
  const [tab, setTab] = useState<"details" | "generation" | "prompt" | "inputs" | "video">("details");
  const [generationId, setGenerationId] = useState(detail.generations[0]?.id ?? "");
  const [addingGeneration, setAddingGeneration] = useState(false);
  const generation = detail.generations.find((item) => item.id === generationId) ?? detail.generations[0];
  return <div className="space-y-5"><div className="flex flex-wrap items-center justify-between gap-4"><div><div className="font-mono text-xs text-stone-500">{detail.episode.studio_id}</div><h2 className="mt-1 text-2xl font-medium">{detail.episode.title}</h2></div><StatusBadge status={detail.episode.status} /></div><div className="space-y-3 rounded-2xl border border-white/7 bg-white/[0.02] p-3"><div className="flex flex-wrap items-center gap-2">{detail.generations.map((item) => <button key={item.id} onClick={() => setGenerationId(item.id)} className={cn("rounded-xl border px-3 py-2 text-left transition", item.id === generation?.id ? "border-amber-300/25 bg-amber-300/[0.08] text-amber-200" : "border-white/7 text-stone-500 hover:text-stone-300")}><div className="font-mono text-xs">v{item.version}</div><div className="mt-0.5 max-w-32 truncate text-[10px] opacity-70">{item.label || `生成 v${item.version}`}</div>{item.model_name ? <div className="mt-1 max-w-32 truncate text-[10px] text-violet-300/70">{item.model_name}</div> : null}</button>)}<Button type="button" variant="ghost" size="sm" onClick={() => setAddingGeneration((value) => !value)}><Plus className="size-3.5" />新しい生成</Button></div>{addingGeneration ? <CreateGenerationForm episodeId={detail.episode.id} nextVersion={detail.generations.length + 1} onCreated={async (created) => { await onSaved(); setGenerationId(created.id); setAddingGeneration(false); }} /> : null}</div><div className="flex gap-1 rounded-2xl border border-white/7 bg-white/[0.02] p-1">{(["details", "generation", "prompt", "inputs", "video"] as const).map((item) => <button key={item} onClick={() => setTab(item)} className={cn("flex-1 rounded-xl px-3 py-2 text-xs font-medium capitalize transition", tab === item ? "bg-white/10 text-white" : "text-stone-600 hover:text-stone-300")}>{item}</button>)}</div>{tab === "details" ? <DetailsForm detail={detail} members={members} onSaved={onSaved} /> : null}{generation && tab === "generation" ? <GenerationSettings key={generation.id} generation={generation} onSaved={onSaved} /> : null}{generation && tab === "prompt" ? <PromptForm generation={generation} onSaved={onSaved} /> : null}{generation && tab === "inputs" ? <InputAssetsForm generation={generation} onSaved={onSaved} /> : null}{generation && tab === "video" ? <VideoForm generation={generation} onSaved={onSaved} /> : null}</div>;
}

function CreateGenerationForm({ episodeId, nextVersion, onCreated }: { episodeId: string; nextVersion: number; onCreated: (generation: Generation) => Promise<void> }) {
  const [saving, setSaving] = useState(false);
  async function submit(event: FormEvent<HTMLFormElement>) { event.preventDefault(); setSaving(true); const data = new FormData(event.currentTarget); try { const modelName = String(data.get("modelName") || "").trim(); const created = await api.createGeneration(episodeId, { label: String(data.get("label")), modelName: modelName || null, notes: String(data.get("notes")) }); toast.success(`v${created.version}を追加しました`); await onCreated(created); } catch (reason) { toast.error(reason instanceof Error ? reason.message : "追加に失敗しました"); } finally { setSaving(false); } }
  return <form onSubmit={submit} className="grid gap-3 rounded-xl border border-white/7 bg-black/15 p-4 sm:grid-cols-2 xl:grid-cols-[1fr_1fr_1.5fr_auto]"><Input name="label" placeholder={`v${nextVersion}のラベル`} /><Input name="modelName" list="madogiwa-model-suggestions" placeholder="使用モデル（任意）" /><Input name="notes" placeholder="変更点や生成目的" /><Button size="sm" disabled={saving}><Layers3 className="size-3.5" />{saving ? "追加中" : `v${nextVersion}を追加`}</Button></form>;
}

function GenerationSettings({ generation, onSaved }: { generation: Generation; onSaved: () => Promise<EpisodeDetail> }) {
  const [saving, setSaving] = useState(false);
  async function submit(event: FormEvent<HTMLFormElement>) { event.preventDefault(); setSaving(true); const data = new FormData(event.currentTarget); try { const modelName = String(data.get("modelName") || "").trim(); await api.updateGeneration(generation.id, { label: String(data.get("label")), modelName: modelName || null, notes: String(data.get("notes")) }); toast.success(`v${generation.version}の生成情報を保存しました`); await onSaved(); } catch (reason) { toast.error(reason instanceof Error ? reason.message : "保存に失敗しました"); } finally { setSaving(false); } }
  return <Card><CardHeader><h3 className="text-sm font-medium">生成 v{generation.version}の設定</h3><p className="text-xs text-stone-600">使用モデルは候補から選択するか、任意のモデル名を入力できます。</p></CardHeader><CardContent><form onSubmit={submit} className="space-y-5"><Field label="ラベル"><Input name="label" defaultValue={generation.label} placeholder={`生成 v${generation.version}`} /></Field><Field label="使用モデル（任意）"><Input name="modelName" list="madogiwa-model-suggestions" defaultValue={generation.model_name ?? ""} placeholder="Seedance 2.0 / Seedance 2.5 / MiniMax H3 / その他" /></Field><Field label="変更点・メモ"><Textarea name="notes" defaultValue={generation.notes} /></Field><Button disabled={saving}><Save className="size-4" />{saving ? "保存中…" : "生成情報を保存"}</Button></form></CardContent></Card>;
}

function DetailsForm({ detail, members, onSaved }: { detail: EpisodeDetail; members: Member[]; onSaved: () => Promise<EpisodeDetail> }) {
  const [saving, setSaving] = useState(false);
  async function submit(event: FormEvent<HTMLFormElement>) { event.preventDefault(); setSaving(true); const data = new FormData(event.currentTarget); try { await api.updateEpisode(detail.episode.slug, { title: String(data.get("title")), summary: String(data.get("summary")), status: String(data.get("status")) as EpisodeStatus }); await api.updateEpisodeMembers(detail.episode.id, data.getAll("members").map(String)); toast.success("基本情報とメンバーを保存しました"); await onSaved(); } catch (reason) { toast.error(reason instanceof Error ? reason.message : "保存に失敗しました"); } finally { setSaving(false); } }
  return <Card><CardContent className="pt-6"><form onSubmit={submit} className="space-y-5"><Field label="Studio ID"><Input value={detail.episode.studio_id} readOnly className="font-mono text-stone-500" /></Field><Field label="タイトル"><Input name="title" defaultValue={detail.episode.title} required /></Field><Field label="概要"><Textarea name="summary" defaultValue={detail.episode.summary} /></Field><Field label="ステータス"><select name="status" defaultValue={detail.episode.status} className="h-11 w-full rounded-xl border border-white/10 bg-stone-950 px-3 text-sm outline-none focus:border-amber-400/60">{["draft", "generated", "published", "archived"].map((status) => <option key={status}>{status}</option>)}</select></Field><Field label="登場メンバー"><MemberPicker members={members} selected={detail.members.map((member) => member.id)} /></Field><Button disabled={saving}><Save className="size-4" />{saving ? "保存中…" : "保存"}</Button></form></CardContent></Card>;
}

function MemberPicker({ members, selected }: { members: Member[]; selected: string[] }) { return <div className="grid gap-2 sm:grid-cols-2 lg:grid-cols-4">{members.map((member) => <label key={member.id} className="flex cursor-pointer items-center gap-2 rounded-xl border border-white/8 bg-white/[0.02] px-3 py-2 text-xs text-stone-400 transition has-[:checked]:border-amber-300/25 has-[:checked]:bg-amber-300/[0.06] has-[:checked]:text-amber-200"><input type="checkbox" name="members" value={member.id} defaultChecked={selected.includes(member.id)} className="accent-amber-400" />{member.name}</label>)}</div>; }

function PromptForm({ generation, onSaved }: { generation: Generation; onSaved: () => Promise<EpisodeDetail> }) {
  const [saving, setSaving] = useState(false);
  async function submit(event: FormEvent<HTMLFormElement>) { event.preventDefault(); setSaving(true); const data = new FormData(event.currentTarget); try { await api.upsertPrompt(generation.id, { label: String(data.get("label")), body: String(data.get("body")) }); toast.success(`v${generation.version}のプロンプトを保存しました`); await onSaved(); } catch (reason) { toast.error(reason instanceof Error ? reason.message : "保存に失敗しました"); } finally { setSaving(false); } }
  return <Card><CardHeader><h3 className="text-sm font-medium">生成 v{generation.version}のプロンプト</h3></CardHeader><CardContent><form onSubmit={submit} className="space-y-5"><Field label="ラベル"><Input name="label" defaultValue={generation.prompt?.label ?? "Seedance prompt"} required /></Field><Field label="プロンプト"><Textarea name="body" defaultValue={generation.prompt?.body ?? ""} className="min-h-96 font-mono text-xs" required /></Field><div className="flex justify-end"><Button disabled={saving}><Save className="size-4" />{saving ? "保存中…" : "新しいrevisionとして保存"}</Button></div></form></CardContent></Card>;
}

function VideoForm({ generation, onSaved }: { generation: Generation; onSaved: () => Promise<EpisodeDetail> }) {
  const [file, setFile] = useState<File | null>(null); const [uploading, setUploading] = useState(false); const defaultLabel = useMemo(() => `Generated video ${generation.videos.length + 1}`, [generation.videos.length]);
  async function submit(event: FormEvent<HTMLFormElement>) { event.preventDefault(); if (!file) return; setUploading(true); const data = new FormData(event.currentTarget); try { const ticket = await api.createUpload(generation.id, { filename: file.name, label: String(data.get("label")), contentType: file.type || "video/mp4" }); await api.uploadFile(ticket.uploadUrl, file); toast.success(`v${generation.version}へ動画を登録しました`); setFile(null); await onSaved(); } catch (reason) { toast.error(reason instanceof Error ? reason.message : "アップロードに失敗しました"); } finally { setUploading(false); } }
  return <div className="space-y-4"><Card><CardHeader><h3 className="text-sm font-medium">生成 v{generation.version}の動画</h3></CardHeader><CardContent><form onSubmit={submit} className="space-y-5"><Field label="表示名"><Input name="label" defaultValue={defaultLabel} required /></Field><UploadPicker file={file} label="動画を選択" accept="video/*" onFile={setFile} /><Button disabled={!file || uploading}><CloudUpload className="size-4" />{uploading ? "R2へアップロード中…" : "動画を登録"}</Button></form></CardContent></Card>{generation.videos.length ? <Card><CardContent className="space-y-2 pt-6">{generation.videos.map((video) => <div key={video.id} className="flex items-center justify-between gap-4 rounded-xl bg-white/[0.025] px-4 py-3"><div className="flex min-w-0 items-center gap-3"><FileVideo2 className="size-4 shrink-0 text-stone-600" /><span className="truncate text-sm text-stone-300">{video.label}</span></div><StatusBadge status={video.status} /></div>)}</CardContent></Card> : null}</div>;
}

function inferKind(file: File): InputAssetKind { if (file.type.startsWith("image/")) return "image"; if (file.type.startsWith("audio/")) return "audio"; if (file.type.startsWith("text/") || file.type === "application/pdf") return "document"; return "other"; }
function InputAssetsForm({ generation, onSaved }: { generation: Generation; onSaved: () => Promise<EpisodeDetail> }) {
  const [file, setFile] = useState<File | null>(null); const [kind, setKind] = useState<InputAssetKind>("image"); const [uploading, setUploading] = useState(false);
  async function submit(event: FormEvent<HTMLFormElement>) { event.preventDefault(); if (!file) return; setUploading(true); const data = new FormData(event.currentTarget); try { const ticket = await api.createInputUpload(generation.id, { filename: file.name, label: String(data.get("label")), kind, referenceLabel: String(data.get("referenceLabel") || "") || null, groupLabel: String(data.get("groupLabel") || "") || null, notes: String(data.get("notes") || ""), contentType: file.type || "application/octet-stream", displayOrder: Number(data.get("displayOrder") || 0) }); await api.uploadInputFile(ticket.uploadUrl, file); toast.success(`v${generation.version}へ入力アセットを登録しました`); setFile(null); await onSaved(); } catch (reason) { toast.error(reason instanceof Error ? reason.message : "アップロードに失敗しました"); } finally { setUploading(false); } }
  return <div className="space-y-4"><Card><CardHeader><h3 className="text-sm font-medium">生成 v{generation.version}の入力アセット</h3><p className="text-xs text-stone-600">この生成だけで使用する画像、参照音声、資料を登録します。</p></CardHeader><CardContent><form onSubmit={submit} className="grid gap-5 sm:grid-cols-2"><Field label="表示名"><Input name="label" required /></Field><Field label="種別"><select value={kind} onChange={(event) => setKind(event.target.value as InputAssetKind)} className="h-11 w-full rounded-xl border border-white/10 bg-stone-950 px-3 text-sm">{["image", "audio", "document", "other"].map((item) => <option key={item}>{item}</option>)}</select></Field><Field label="参照名"><Input name="referenceLabel" placeholder="@Image 1 / @Audio 1" /></Field><Field label="グループ"><Input name="groupLabel" placeholder="Clip A" /></Field><Field label="並び順"><Input name="displayOrder" type="number" min="0" defaultValue="0" /></Field><Field label="用途メモ"><Input name="notes" /></Field><div className="sm:col-span-2"><UploadPicker file={file} label="入力ファイルを選択" onFile={(next) => { setFile(next); if (next) setKind(inferKind(next)); }} /></div><div className="sm:col-span-2"><Button disabled={!file || uploading}><CloudUpload className="size-4" />{uploading ? "R2へアップロード中…" : "入力アセットを登録"}</Button></div></form></CardContent></Card>{generation.inputAssets.length ? <Card><CardContent className="space-y-2 pt-6">{generation.inputAssets.map((asset) => <div key={asset.id} className="flex items-center justify-between gap-4 rounded-xl bg-white/[0.025] px-4 py-3"><div className="flex min-w-0 items-center gap-3">{asset.kind === "image" ? <ImageIcon className="size-4 text-sky-400" /> : asset.kind === "audio" ? <Music2 className="size-4 text-violet-400" /> : <Paperclip className="size-4 text-stone-500" />}<div className="min-w-0"><div className="truncate text-sm text-stone-300">{asset.label}</div><div className="mt-1 text-[10px] text-stone-600">{[asset.group_label, asset.reference_label, asset.filename].filter(Boolean).join(" · ")}</div></div></div><StatusBadge status={asset.status} /></div>)}</CardContent></Card> : null}</div>;
}

function UploadPicker({ file, label, accept, onFile }: { file: File | null; label: string; accept?: string; onFile: (file: File | null) => void }) { return <label className="grid cursor-pointer place-items-center rounded-3xl border border-dashed border-white/12 bg-black/10 px-6 py-10 text-center transition hover:border-amber-300/30"><input type="file" accept={accept} className="sr-only" onChange={(event) => onFile(event.target.files?.[0] ?? null)} /><span className="grid size-12 place-items-center rounded-2xl bg-white/5 text-stone-400"><CloudUpload className="size-5" /></span><span className="mt-4 text-sm text-stone-300">{file ? file.name : label}</span></label>; }
function McpHint() { return <div className="rounded-2xl border border-violet-400/10 bg-violet-400/[0.04] p-4"><div className="flex items-center gap-2 text-xs font-medium text-violet-300"><Bot className="size-4" />Codex / MCP</div><p className="mt-2 text-[11px] leading-5 text-stone-600">エピソード、生成バージョン、入力、動画をRemote MCPから登録できます。</p></div>; }
function Field({ label, className, children }: { label: string; className?: string; children: React.ReactNode }) { return <div className={cn("space-y-2", className)}><Label>{label}</Label>{children}</div>; }
