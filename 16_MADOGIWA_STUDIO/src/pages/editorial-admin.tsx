import { ArrowDown, ArrowUp, BookOpen, CloudUpload, Images, Plus, Save } from "lucide-react";
import { FormEvent, useEffect, useState } from "react";
import { toast } from "sonner";
import { StatusBadge } from "@/components/status-badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { api, type Article, type EditorialContentStatus, type GalleryItem } from "@/lib/api";
import { cn } from "@/lib/utils";

const CONTENT_STATUSES: EditorialContentStatus[] = ["draft", "published", "archived"];

export function EditorialAdmin({ section }: { section: "gallery" | "articles" }) {
  return section === "gallery" ? <GalleryAdmin /> : <ArticlesAdmin />;
}

function GalleryAdmin() {
  const [items, setItems] = useState<GalleryItem[]>([]);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [creating, setCreating] = useState(false);
  const [loading, setLoading] = useState(true);

  async function refresh(preferredId?: string): Promise<void> {
    const next = (await api.listAdminGalleryItems()).galleryItems;
    setItems(next);
    setSelectedId((current) => preferredId ?? (current && next.some((item) => item.id === current) ? current : next[0]?.id ?? null));
  }

  useEffect(() => {
    refresh().catch((reason: unknown) => toast.error(errorMessage(reason, "ギャラリーの読み込みに失敗しました"))).finally(() => setLoading(false));
  }, []);

  async function move(itemId: string, direction: -1 | 1): Promise<void> {
    const index = items.findIndex((item) => item.id === itemId);
    const target = index + direction;
    if (index < 0 || target < 0 || target >= items.length) return;
    const next = [...items];
    [next[index], next[target]] = [next[target], next[index]];
    try {
      const result = await api.reorderGalleryItems(next.map((item) => item.id));
      setItems(result.galleryItems);
      toast.success("ギャラリーの表示順を更新しました");
    } catch (reason) {
      toast.error(errorMessage(reason, "並び順の更新に失敗しました"));
    }
  }

  if (loading) return <div className="py-16 text-center text-sm text-stone-600">GALLERY LOADING...</div>;
  const selected = items.find((item) => item.id === selectedId) ?? null;

  return <div className="grid gap-6 lg:grid-cols-[300px_minmax(0,1fr)]">
    <ContentList title="Gallery" icon={<Images className="size-4" />} onCreate={() => setCreating(true)}>
      {items.map((item, index) => <ContentListItem
        key={item.id}
        title={item.title}
        meta={item.kind}
        status={item.status}
        selected={selectedId === item.id && !creating}
        first={index === 0}
        last={index === items.length - 1}
        onSelect={() => { setSelectedId(item.id); setCreating(false); }}
        onMove={(direction) => void move(item.id, direction)}
      />)}
    </ContentList>
    <div>{creating
      ? <CreateGalleryForm nextOrder={items.length} onCreated={async (item) => { setCreating(false); await refresh(item.id); }} />
      : selected
        ? <GalleryEditor key={`${selected.id}:${selected.updated_at}`} item={selected} onSaved={() => refresh(selected.id)} />
        : <EmptyEditor label="ギャラリー項目を追加してください" />}
    </div>
  </div>;
}

function CreateGalleryForm({ nextOrder, onCreated }: { nextOrder: number; onCreated: (item: GalleryItem) => Promise<void> }) {
  const [saving, setSaving] = useState(false);
  async function submit(event: FormEvent<HTMLFormElement>): Promise<void> {
    event.preventDefault();
    setSaving(true);
    const data = new FormData(event.currentTarget);
    try {
      const item = await api.createGalleryItem({
        slug: String(data.get("slug")),
        title: String(data.get("title")),
        kind: String(data.get("kind")),
        displayOrder: nextOrder,
        status: "draft",
      });
      toast.success("ギャラリー項目を作成しました。画像を登録してから公開できます");
      await onCreated(item);
    } catch (reason) {
      toast.error(errorMessage(reason, "作成に失敗しました"));
    } finally {
      setSaving(false);
    }
  }
  return <Card><CardHeader><h2 className="text-xl font-medium">新しいギャラリー項目</h2><p className="text-sm text-stone-500">最初はdraftで作成されます。</p></CardHeader><CardContent><form onSubmit={(event) => void submit(event)} className="space-y-5"><Field label="slug"><Input name="slug" required placeholder="new-key-visual" /></Field><Field label="タイトル"><Input name="title" required /></Field><Field label="種別"><Input name="kind" required placeholder="KEY VISUAL" /></Field><Button disabled={saving}><Plus className="size-4" />{saving ? "作成中…" : "作成"}</Button></form></CardContent></Card>;
}

function GalleryEditor({ item, onSaved }: { item: GalleryItem; onSaved: () => Promise<void> }) {
  const [saving, setSaving] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [file, setFile] = useState<File | null>(null);

  async function save(event: FormEvent<HTMLFormElement>): Promise<void> {
    event.preventDefault();
    setSaving(true);
    const data = new FormData(event.currentTarget);
    try {
      await api.updateGalleryItem(item.id, {
        slug: String(data.get("slug")),
        title: String(data.get("title")),
        kind: String(data.get("kind")),
        status: String(data.get("status")) as EditorialContentStatus,
      });
      toast.success("ギャラリー項目を保存しました");
      await onSaved();
    } catch (reason) {
      toast.error(errorMessage(reason, "保存に失敗しました"));
    } finally {
      setSaving(false);
    }
  }

  async function uploadImage(): Promise<void> {
    if (!file) return;
    if (!["image/jpeg", "image/png", "image/webp"].includes(file.type)) {
      toast.error("JPEG、PNG、WebP画像を選択してください");
      return;
    }
    setUploading(true);
    try {
      const ticket = await api.createGalleryImageUpload(item.id, { filename: file.name, contentType: file.type });
      await api.uploadGalleryImage(ticket.uploadUrl, file);
      setFile(null);
      toast.success("ギャラリー画像を差し替えました");
      await onSaved();
    } catch (reason) {
      toast.error(errorMessage(reason, "画像のアップロードに失敗しました"));
    } finally {
      setUploading(false);
    }
  }

  return <div className="space-y-5"><Card><CardHeader><div className="flex items-start justify-between gap-4"><div><h2 className="text-xl font-medium">{item.title}</h2><p className="mt-1 text-xs text-stone-600">最終更新: {item.updated_by ?? "unknown"}</p></div><StatusBadge status={item.status} /></div></CardHeader><CardContent><form onSubmit={(event) => void save(event)} className="space-y-5"><Field label="slug"><Input name="slug" defaultValue={item.slug} required /></Field><Field label="タイトル"><Input name="title" defaultValue={item.title} required /></Field><Field label="種別"><Input name="kind" defaultValue={item.kind} required /></Field><Field label="ステータス"><StatusSelect defaultValue={item.status} /></Field><Button disabled={saving}><Save className="size-4" />{saving ? "保存中…" : "保存"}</Button></form></CardContent></Card><Card><CardHeader><h3 className="text-sm font-medium">掲載画像</h3><p className="text-xs text-stone-600">JPEG、PNG、WebP・10MB以下。アップロード完了時にR2画像へ切り替わります。</p></CardHeader><CardContent className="space-y-4">{item.image_url ? <img src={item.image_url} alt={item.title} className="max-h-80 w-full rounded-2xl bg-black/20 object-contain" /> : <div className="grid h-48 place-items-center rounded-2xl bg-black/20 text-sm text-stone-600">画像未登録</div>}<label className="flex cursor-pointer items-center gap-3 rounded-2xl border border-dashed border-white/12 px-4 py-5 text-sm text-stone-400"><CloudUpload className="size-5" /><input type="file" accept="image/jpeg,image/png,image/webp" className="sr-only" onChange={(event) => setFile(event.target.files?.[0] ?? null)} />{file?.name ?? "画像を選択"}</label><Button type="button" disabled={!file || uploading} onClick={() => void uploadImage()}><CloudUpload className="size-4" />{uploading ? "アップロード中…" : "画像を差し替える"}</Button></CardContent></Card></div>;
}

function ArticlesAdmin() {
  const [items, setItems] = useState<Article[]>([]);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [creating, setCreating] = useState(false);
  const [loading, setLoading] = useState(true);

  async function refresh(preferredId?: string): Promise<void> {
    const next = (await api.listAdminArticles()).articles;
    setItems(next);
    setSelectedId((current) => preferredId ?? (current && next.some((item) => item.id === current) ? current : next[0]?.id ?? null));
  }

  useEffect(() => {
    refresh().catch((reason: unknown) => toast.error(errorMessage(reason, "記事の読み込みに失敗しました"))).finally(() => setLoading(false));
  }, []);

  async function move(itemId: string, direction: -1 | 1): Promise<void> {
    const index = items.findIndex((item) => item.id === itemId);
    const target = index + direction;
    if (index < 0 || target < 0 || target >= items.length) return;
    const next = [...items];
    [next[index], next[target]] = [next[target], next[index]];
    try {
      const result = await api.reorderArticles(next.map((item) => item.id));
      setItems(result.articles);
      toast.success("記事の表示順を更新しました");
    } catch (reason) {
      toast.error(errorMessage(reason, "並び順の更新に失敗しました"));
    }
  }

  if (loading) return <div className="py-16 text-center text-sm text-stone-600">ARTICLES LOADING...</div>;
  const selected = items.find((item) => item.id === selectedId) ?? null;
  return <div className="grid gap-6 lg:grid-cols-[300px_minmax(0,1fr)]">
    <ContentList title="Articles" icon={<BookOpen className="size-4" />} onCreate={() => setCreating(true)}>
      {items.map((item, index) => <ContentListItem key={item.id} title={item.title} meta={`${item.source} · ${item.label}`} status={item.status} selected={selectedId === item.id && !creating} first={index === 0} last={index === items.length - 1} onSelect={() => { setSelectedId(item.id); setCreating(false); }} onMove={(direction) => void move(item.id, direction)} />)}
    </ContentList>
    <div>{creating
      ? <CreateArticleForm nextOrder={items.length} onCreated={async (item) => { setCreating(false); await refresh(item.id); }} />
      : selected
        ? <ArticleEditor key={`${selected.id}:${selected.updated_at}`} item={selected} onSaved={() => refresh(selected.id)} />
        : <EmptyEditor label="記事を追加してください" />}
    </div>
  </div>;
}

function CreateArticleForm({ nextOrder, onCreated }: { nextOrder: number; onCreated: (item: Article) => Promise<void> }) {
  const [saving, setSaving] = useState(false);
  async function submit(event: FormEvent<HTMLFormElement>): Promise<void> {
    event.preventDefault();
    setSaving(true);
    const data = new FormData(event.currentTarget);
    try {
      const item = await api.createArticle(articleInput(data, nextOrder));
      toast.success("記事を作成しました");
      await onCreated(item);
    } catch (reason) {
      toast.error(errorMessage(reason, "作成に失敗しました"));
    } finally {
      setSaving(false);
    }
  }
  return <Card><CardHeader><h2 className="text-xl font-medium">新しい記事</h2></CardHeader><CardContent><ArticleFields onSubmit={(event) => void submit(event)} saving={saving} /></CardContent></Card>;
}

function ArticleEditor({ item, onSaved }: { item: Article; onSaved: () => Promise<void> }) {
  const [saving, setSaving] = useState(false);
  async function submit(event: FormEvent<HTMLFormElement>): Promise<void> {
    event.preventDefault();
    setSaving(true);
    const data = new FormData(event.currentTarget);
    try {
      await api.updateArticle(item.id, articleInput(data, item.display_order));
      toast.success("記事を保存しました");
      await onSaved();
    } catch (reason) {
      toast.error(errorMessage(reason, "保存に失敗しました"));
    } finally {
      setSaving(false);
    }
  }
  return <Card><CardHeader><div className="flex items-start justify-between gap-4"><div><h2 className="text-xl font-medium">{item.title}</h2><p className="mt-1 text-xs text-stone-600">最終更新: {item.updated_by ?? "unknown"}</p></div><StatusBadge status={item.status} /></div></CardHeader><CardContent><ArticleFields item={item} onSubmit={(event) => void submit(event)} saving={saving} /></CardContent></Card>;
}

function ArticleFields({ item, saving, onSubmit }: { item?: Article; saving: boolean; onSubmit: (event: FormEvent<HTMLFormElement>) => void }) {
  return <form onSubmit={onSubmit} className="grid gap-5 sm:grid-cols-2"><Field label="slug"><Input name="slug" defaultValue={item?.slug} required /></Field><Field label="ラベル"><Input name="label" defaultValue={item?.label} required placeholder="MAKING" /></Field><Field label="掲載元"><Input name="source" defaultValue={item?.source} required placeholder="NOTE / ZENN" /></Field><Field label="リンク文言"><Input name="action" defaultValue={item?.action} required placeholder="記事を読む" /></Field><Field label="タイトル" className="sm:col-span-2"><Input name="title" defaultValue={item?.title} required /></Field><Field label="説明" className="sm:col-span-2"><Textarea name="copy" defaultValue={item?.copy} /></Field><Field label="URL" className="sm:col-span-2"><Input name="url" type="url" defaultValue={item?.url} required /></Field><Field label="ステータス" className="sm:col-span-2"><StatusSelect defaultValue={item?.status ?? "draft"} /></Field><div className="sm:col-span-2"><Button disabled={saving}><Save className="size-4" />{saving ? "保存中…" : item ? "保存" : "作成"}</Button></div></form>;
}

function articleInput(data: FormData, displayOrder: number) {
  return {
    slug: String(data.get("slug")),
    label: String(data.get("label")),
    source: String(data.get("source")),
    title: String(data.get("title")),
    copy: String(data.get("copy")),
    url: String(data.get("url")),
    action: String(data.get("action")),
    displayOrder,
    status: String(data.get("status")) as EditorialContentStatus,
  };
}

function ContentList({ title, icon, onCreate, children }: { title: string; icon: React.ReactNode; onCreate: () => void; children: React.ReactNode }) {
  const createLabel = title === "Gallery" ? "新規ギャラリー" : "新規記事";
  return <aside className="space-y-3"><Button className="w-full" onClick={onCreate}><Plus className="size-4" />{createLabel}</Button><div className="rounded-2xl border border-white/7 bg-white/[0.02] p-2"><div className="flex items-center gap-2 px-3 py-2 text-xs font-medium text-stone-500">{icon}{title}</div><div className="space-y-1">{children}</div></div></aside>;
}

function ContentListItem({ title, meta, status, selected, first, last, onSelect, onMove }: { title: string; meta: string; status: string; selected: boolean; first: boolean; last: boolean; onSelect: () => void; onMove: (direction: -1 | 1) => void }) {
  return <div className={cn("rounded-xl transition", selected ? "bg-white/10" : "hover:bg-white/5")}><button type="button" onClick={onSelect} className="flex w-full items-center justify-between gap-3 px-3 pt-3 text-left"><div className="min-w-0"><div className="truncate text-sm text-stone-200">{title}</div><div className="mt-1 truncate text-[10px] text-stone-600">{meta}</div></div><StatusBadge status={status} /></button><div className="flex justify-end gap-1 px-2 pb-2"><Button type="button" variant="ghost" size="sm" disabled={first} aria-label={`${title}を上へ`} onClick={() => onMove(-1)}><ArrowUp className="size-3" /></Button><Button type="button" variant="ghost" size="sm" disabled={last} aria-label={`${title}を下へ`} onClick={() => onMove(1)}><ArrowDown className="size-3" /></Button></div></div>;
}

function StatusSelect({ defaultValue }: { defaultValue: EditorialContentStatus }) {
  return <select name="status" defaultValue={defaultValue} className="h-11 w-full rounded-xl border border-white/10 bg-stone-950 px-3 text-sm outline-none focus:border-amber-400/60">{CONTENT_STATUSES.map((status) => <option key={status}>{status}</option>)}</select>;
}

function Field({ label, className, children }: { label: string; className?: string; children: React.ReactNode }) {
  return <div className={cn("space-y-2", className)}><Label>{label}</Label>{children}</div>;
}

function EmptyEditor({ label }: { label: string }) {
  return <Card><CardContent className="grid min-h-64 place-items-center pt-6 text-sm text-stone-600">{label}</CardContent></Card>;
}

function errorMessage(reason: unknown, fallback: string): string {
  return reason instanceof Error ? reason.message : fallback;
}
