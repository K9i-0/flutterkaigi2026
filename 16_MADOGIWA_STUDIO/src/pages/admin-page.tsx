import { useEffect, useRef, useState } from "react";
import { useBlocker, useNavigate, useSearch } from "@tanstack/react-router";
import { ArrowDown, ArrowUp, GripVertical, Search, Star, X } from "lucide-react";
import { toast } from "sonner";
import { api, type EpisodeDetail, type EpisodeEditorInput, type EpisodeSummary, type Member } from "@/lib/api";
import { CreateEpisode, ProductionEditor } from "./admin-production";
import { EditorialAdmin } from "./editorial-admin";
import "./admin.css";

function message(error: unknown) { return error instanceof Error ? error.message : "処理に失敗しました"; }
function moved<T>(items: T[], from: number, to: number) {
  if (from < 0 || to < 0 || to >= items.length) return items;
  const next = [...items]; const [item] = next.splice(from, 1); next.splice(to, 0, item); return next;
}

export function AdminPage() {
  const search = useSearch({from: "/admin"});
  const navigate = useNavigate({from: "/admin"});
  const section = search.section ?? "episodes";
  const [episodes, setEpisodes] = useState<EpisodeSummary[]>([]);
  const [members, setMembers] = useState<Member[]>([]);
  const [email, setEmail] = useState("");
  const [loaded, setLoaded] = useState(false);
  const [error, setError] = useState("");
  const [detail, setDetail] = useState<EpisodeDetail | null>(null);
  const [detailError, setDetailError] = useState("");
  const [creating, setCreating] = useState(false);
  const [query, setQuery] = useState("");
  const [member, setMember] = useState("");
  const [status, setStatus] = useState("");
  const [featured, setFeatured] = useState(false);
  const [sort, setSort] = useState("display");
  const [order, setOrder] = useState<EpisodeSummary[] | null>(null);
  const [savingOrder, setSavingOrder] = useState(false);
  const [dirty, setDirty] = useState(false);
  const dragId = useRef<string | null>(null);
  const listRef = useRef<HTMLDivElement>(null);
  const dirtyAny = dirty || order !== null;
  useBlocker({shouldBlockFn: () => { if (!dirtyAny) return false; if (!window.confirm("未保存の変更があります。破棄して移動しますか？")) return true; setDirty(false); setOrder(null); return false; }, enableBeforeUnload: dirtyAny});
  async function reloadList() { setEpisodes((await api.listEpisodes()).episodes); }
  useEffect(() => {
    let active = true;
    Promise.all([api.getSession(), api.listEpisodes(), api.listMembers()]).then(([session, list, people]) => {
      if (!active) return;
      setEmail(session.admin?.email ?? ""); setEpisodes(list.episodes); setMembers(people.members); setLoaded(true);
    }).catch((reason: unknown) => { if (active) setError(message(reason)); });
    return () => { active = false; };
  }, []);
  useEffect(() => {
    let active = true;
    if (search.episode) api.getEpisode(search.episode).then((next) => {
      if (active) { setDetail(next); setDirty(false); }
    }).catch((reason: unknown) => { if (active) setDetailError(message(reason)); });
    return () => { active = false; };
  }, [search.episode]);
  async function select(slug?: string) {
    if (slug === search.episode) return;
    if (dirty && !window.confirm("未保存の変更を破棄しますか？")) return;
    setDirty(false); setCreating(false); setDetailError(""); setDetail(null);
    await navigate({search: {episode: slug}, ignoreBlocker: true});
  }
  async function refreshDetail() {
    const next = await api.getEpisode(search.episode!); setDetail(next); await reloadList(); return next;
  }
  const visible = (order ?? episodes).filter((episode) => order || (
    `${episode.title} ${episode.studio_id} ${episode.slug}`.toLowerCase().includes(query.toLowerCase()) &&
    (!member || episode.members.some((person) => person.id === member)) && (!status || episode.status === status) && (!featured || !!episode.has_featured_video)
  )).sort((a, b) => order || sort === "display" ? 0 : sort === "title" ? a.title.localeCompare(b.title, "ja") : sort === "updated" ? b.updated_at.localeCompare(a.updated_at) : b.created_at.localeCompare(a.created_at));
  async function saveOrder() {
    if (!order) return; setSavingOrder(true);
    try { setEpisodes((await api.reorderEpisodes(order.map((item) => item.id), episodes.map((item) => item.id))).episodes); setOrder(null); toast.success("掲載順を保存しました"); }
    catch (reason) { toast.error(message(reason)); } finally { setSavingOrder(false); }
  }
  if (error) return <div role="alert" className="desk-empty">{error}<button onClick={() => window.location.reload()}>再読み込み</button></div>;
  if (!loaded) return <div className="desk-empty" role="status">作品を読み込んでいます…</div>;
  if (!email) return <div className="desk-empty">管理画面にログインしてください。</div>;
  const editing = !!search.episode || creating;
  return <div className="desk">
    <header className="desk-heading"><div><h1>コンテンツ管理</h1><p>登録済みの作品を編集・整理</p></div><details className="desk-account"><summary>アカウント</summary><p>{email}</p><a href="/cdn-cgi/access/logout">ログアウト</a></details></header>
    <nav className="desk-tabs" aria-label="管理対象">{(["episodes", "gallery", "articles"] as const).map((item) => <button key={item} aria-current={section === item ? "page" : undefined} onClick={() => void navigate({search: item === "episodes" ? {} : {section: item}})}>{{episodes: "作品", gallery: "ギャラリー", articles: "記事"}[item]}</button>)}</nav>
    {section !== "episodes" ? <EditorialAdmin section={section} /> : <div className={`desk-workspace ${editing ? "is-editing" : ""}`}>
      <div className="desk-library" ref={listRef}>
        <div className="desk-tools">
          <label className="desk-search"><Search size={16}/><input aria-label="作品を検索" placeholder="タイトル・Studio IDで検索" value={query} disabled={!!order} onChange={(event) => setQuery(event.target.value)}/></label>
          <div className="desk-filters"><select aria-label="登場人物で絞り込み" value={member} disabled={!!order} onChange={(event) => setMember(event.target.value)}><option value="">全登場人物</option>{members.map((person) => <option value={person.id} key={person.id}>{person.name}</option>)}</select><select aria-label="公開状態で絞り込み" value={status} disabled={!!order} onChange={(event) => setStatus(event.target.value)}><option value="">公開・非公開</option><option value="published">公開</option><option value="archived">非公開</option></select><label><input type="checkbox" checked={featured} disabled={!!order} onChange={(event) => setFeatured(event.target.checked)}/> ★ イチオシ</label></div>
          <div className="desk-list-actions"><span>{visible.length}作品</span>{order ? <><button className="desk-primary" disabled={savingOrder} onClick={() => void saveOrder()}>{savingOrder ? "保存中…" : "順序を保存"}</button><button disabled={savingOrder} onClick={() => setOrder(null)}>キャンセル</button></> : <><select aria-label="一覧の並び順" value={sort} onChange={(event) => setSort(event.target.value)}><option value="display">掲載順</option><option value="created">登録日が新しい順</option><option value="updated">更新日が新しい順</option><option value="title">タイトル順</option></select><button disabled={dirty} onClick={() => {setOrder([...episodes]);}}>掲載順を編集</button></>}</div>
          {order && <p role="status">全作品を表示中。⋮⋮ をドラッグ、または上下ボタンで移動して保存します。</p>}
        </div>
        <div className="desk-rows">{visible.map((episode, index) => <div key={episode.id} className={`desk-row ${search.episode === episode.slug ? "selected" : ""}`} onDragOver={(event) => {if (order) event.preventDefault();}} onDrop={(event) => {event.preventDefault(); if (order && !savingOrder) setOrder(moved(order, order.findIndex((item) => item.id === dragId.current), index)); dragId.current = null;}}>
          {order && <div className="desk-reorder"><button draggable={!savingOrder} disabled={savingOrder} aria-label={`${episode.title}をドラッグして移動`} onDragStart={() => {dragId.current = episode.id;}} onDragEnd={() => {dragId.current = null;}}><GripVertical size={16}/></button><button aria-label={`${episode.title}を上へ`} disabled={index === 0 || savingOrder} onClick={() => setOrder(moved(order, index, index - 1))}><ArrowUp size={14}/></button><button aria-label={`${episode.title}を下へ`} disabled={index === visible.length - 1 || savingOrder} onClick={() => setOrder(moved(order, index, index + 1))}><ArrowDown size={14}/></button></div>}
          <button className="desk-select" onClick={() => void select(episode.slug)} aria-pressed={search.episode === episode.slug}>
            <div className="desk-thumb">{episode.primary_video_poster_url ? <img src={episode.primary_video_poster_url} alt="" loading="lazy"/> : <span>サムネなし</span>}</div>
            <div className="desk-row-copy"><strong>{episode.title}</strong><span>{episode.members.map((person) => person.name).join("・") || "登場人物未設定"}</span><small>{episode.video_count}動画 · {episode.generation_count}バージョン · {episode.status === "published" ? "公開" : "非公開"}{episode.has_featured_video ? " · ★ イチオシ" : ""}</small></div>
          </button>
        </div>)}{!visible.length && <div className="desk-empty">条件に一致する作品はありません。</div>}</div>
        <details className="desk-add"><summary>追加操作</summary><p>新規登録はMCPから行えます。手動登録も利用できます。</p><button onClick={() => {if (!dirty || window.confirm("未保存の変更を破棄しますか？")) {setDirty(false); setCreating(true);}}}>新規作品を登録</button></details>
      </div>
      <section className="desk-panel" aria-label="作品の編集">
        {editing && <button className="desk-back" onClick={() => {if (creating) {setCreating(false);} else void select();}}>← 一覧へ戻る</button>}
        {creating ? <CreateEpisode members={members} onCreated={async (slug) => {await reloadList(); setCreating(false); await select(slug);}}/> : search.episode ? detailError ? <div role="alert" className="desk-empty">{detailError}<button onClick={() => void refreshDetail().then(() => setDetailError("")).catch((reason) => toast.error(message(reason)))}>再読み込み</button></div> : detail?.episode.slug === search.episode ? <WorkEditor key={detail.episode.id} detail={detail} members={members} onDirty={setDirty} onSaved={async (next) => {setDetail(next); await reloadList();}} onRefresh={refreshDetail}/> : <div role="status" className="desk-empty">作品を読み込んでいます…</div> : <div className="desk-empty"><h2>作品を選んで編集</h2><p>タイトル・登場人物・イチオシ設定・動画の順序をまとめて変更できます。</p></div>}
      </section>
    </div>}
  </div>;
}

function initialDraft(detail: EpisodeDetail): EpisodeEditorInput {
  return {title: detail.episode.title, summary: detail.episode.summary, status: detail.episode.status,
    memberIds: detail.members.map((member) => member.id), representativeVideoId: detail.episode.representative_video_id,
    expectedUpdatedAt: detail.episode.updated_at,
    videos: detail.generations.flatMap((generation) => generation.videos).sort((a, b) => a.display_order - b.display_order || b.created_at.localeCompare(a.created_at) || a.id.localeCompare(b.id)).map((video) => ({id: video.id, label: video.label, featured: !!video.is_featured, status: video.status, expectedUpdatedAt: video.updated_at})),
  };
}
function WorkEditor({detail, members, onDirty, onSaved, onRefresh}: {detail: EpisodeDetail; members: Member[]; onDirty: (value: boolean) => void; onSaved: (next: EpisodeDetail) => Promise<void>; onRefresh: () => Promise<EpisodeDetail>}) {
  const [draft, setDraft] = useState(() => initialDraft(detail));
  const [baseline, setBaseline] = useState(() => initialDraft(detail));
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [preview, setPreview] = useState<string | null>(null);
  const [production, setProduction] = useState(false);
  const drag = useRef<number>(-1);
  const heading = useRef<HTMLHeadingElement>(null);
  useEffect(() => {heading.current?.focus();}, []);
  const dirty = JSON.stringify(draft) !== JSON.stringify(baseline);
  function change(next: EpisodeEditorInput) {setDraft(next); onDirty(JSON.stringify(next) !== JSON.stringify(baseline));}
  async function save() {
    setSaving(true); setError("");
    try {const next = await api.saveEpisodeEditor(detail.episode.id, draft); const saved = initialDraft(next); setDraft(saved); setBaseline(saved); onDirty(false); await onSaved(next); toast.success("作品の変更を保存しました");}
    catch (reason) {setError(message(reason));} finally {setSaving(false);}
  }
  async function refresh() {
    if (dirty && !window.confirm("未保存の変更を破棄して再読み込みしますか？")) return;
    try {const next = await onRefresh(); const saved = initialDraft(next); setDraft(saved); setBaseline(saved); onDirty(false); setError("");} catch (reason) {setError(message(reason));}
  }
  function updateVideo(index: number, patch: Partial<EpisodeEditorInput["videos"][number]>) {change({...draft, videos: draft.videos.map((video, i) => i === index ? {...video, ...patch} : video)});}
  return <div className="desk-editor">
    <div className="desk-editor-heading"><div><small>{detail.episode.studio_id}</small><h2 tabIndex={-1} ref={heading}>{detail.episode.title}</h2></div><a href={`https://madogiwa.work/episodes/${detail.episode.slug}`} target="_blank" rel="noopener noreferrer">公開ページ ↗</a></div>
    <div className="desk-savebar"><span role="status">{dirty ? "未保存の変更あり" : "保存済み"}</span><button disabled={saving} onClick={() => void refresh()}>再読み込み</button><button disabled={!dirty || saving} onClick={() => {setDraft(baseline); onDirty(false); setError("");}}>キャンセル</button><button className="desk-primary" disabled={!dirty || saving} onClick={() => void save()}>{saving ? "保存中…" : "変更を保存"}</button></div>
    {error && <p role="alert" className="desk-error">{error}</p>}
    <fieldset disabled={saving} className="desk-fields">
      <label>タイトル<input maxLength={120} required value={draft.title} onChange={(event) => change({...draft, title: event.target.value})}/></label>
      <label>概要<textarea maxLength={1000} rows={3} value={draft.summary} onChange={(event) => change({...draft, summary: event.target.value})}/></label>
      <label>公開状態<select value={draft.status} onChange={(event) => change({...draft, status: event.target.value as EpisodeEditorInput["status"]})}><option value="published">公開</option><option value="archived">非公開（アーカイブ）</option></select></label>
      <div><h3>登場人物</h3><div className="desk-members">{members.map((member) => <label key={member.id}><input type="checkbox" checked={draft.memberIds.includes(member.id)} onChange={(event) => change({...draft, memberIds: event.target.checked ? [...draft.memberIds, member.id] : draft.memberIds.filter((id) => id !== member.id)})}/>{member.name}</label>)}</div></div>
      <section className="desk-videos"><h3>動画 <small>{draft.videos.length}本</small></h3><p>全バージョンの動画です。上下ボタン・ドラッグで掲載順を変更できます。</p><label>代表動画<select value={draft.representativeVideoId ?? ""} onChange={(event) => change({...draft, representativeVideoId: event.target.value || null})}><option value="">自動（掲載順で先頭の再生可能な動画）</option>{draft.videos.filter((video) => video.status === "ready" || video.status === "published").map((video) => <option key={video.id} value={video.id}>{video.label}</option>)}</select></label><p>代表動画は一覧のサムネと再生に使用。★はイチオシの指定です。</p>
        {draft.videos.map((video, index) => {
          const generation = detail.generations.find((item) => item.videos.some((v) => v.id === video.id))!;
          const source = generation.videos.find((item) => item.id === video.id)!;
          return <div className="desk-video-row" key={video.id} onDragOver={(event) => event.preventDefault()} onDrop={(event) => {event.preventDefault(); if (!saving) change({...draft, videos: moved(draft.videos, drag.current, index)}); drag.current = -1;}}>
            <div className="desk-reorder"><button type="button" draggable={!saving} aria-label={`${video.label}をドラッグして移動`} onDragStart={() => {drag.current = index;}} onDragEnd={() => {drag.current = -1;}}><GripVertical size={16}/></button><button type="button" aria-label={`${video.label}を上へ`} disabled={index === 0} onClick={() => change({...draft, videos: moved(draft.videos, index, index - 1)})}><ArrowUp size={14}/></button><button type="button" aria-label={`${video.label}を下へ`} disabled={index === draft.videos.length - 1} onClick={() => change({...draft, videos: moved(draft.videos, index, index + 1)})}><ArrowDown size={14}/></button></div>
            <button type="button" className="desk-video-thumb" disabled={video.status === "upload_pending"} aria-label={`${video.label}をプレビュー`} onClick={() => setPreview(preview === video.id ? null : video.id)}>{source.poster_r2_key ? <img src={`/admin-api/videos/${video.id}/poster`} alt="" loading="lazy"/> : <span>サムネなし</span>}<span>▶ 確認</span></button>
            <div className="desk-video-copy"><small>v{generation.version} · {generation.label || "生成動画"}</small><label>動画の表示名<input value={video.label} maxLength={120} onChange={(event) => updateVideo(index, {label: event.target.value})}/></label><div className="desk-video-options"><button type="button" aria-pressed={video.featured} className={video.featured ? "is-featured" : ""} onClick={() => updateVideo(index, {featured: !video.featured})}><Star size={15} fill={video.featured ? "currentColor" : "none"}/>イチオシ</button><select aria-label={`${video.label}の状態`} value={video.status} disabled={video.status === "upload_pending"} onChange={(event) => {const status = event.target.value as typeof video.status; change({...draft, representativeVideoId: status === "archived" && draft.representativeVideoId === video.id ? null : draft.representativeVideoId, videos: draft.videos.map((v, i) => i === index ? {...v, status} : v)});}}>{video.status === "upload_pending" && <option value="upload_pending">アップロード中</option>}<option value="ready">再生可能</option><option value="published">公開採用</option><option value="archived">非公開</option></select></div></div>
            {preview === video.id && <div className="desk-preview"><button type="button" aria-label="プレビューを閉じる" onClick={() => setPreview(null)}><X size={16}/></button><video key={video.id} controls preload="metadata" poster={source.poster_r2_key ? `/admin-api/videos/${video.id}/poster` : undefined} src={`/admin-api/videos/${video.id}/preview`}/></div>}
          </div>;
        })}{!draft.videos.length && <p>動画は未登録です。MCPまたは追加操作から登録できます。</p>}
      </section>
    </fieldset>
    <div className="desk-production"><button disabled={dirty || saving} aria-expanded={production} onClick={() => setProduction(!production)}>{production ? "−" : "＋"} 制作情報・追加操作</button>{dirty && <small>変更を保存すると開けます</small>}{production && !dirty && <ProductionEditor detail={detail} onSaved={async () => {const next = await onRefresh(); const saved = initialDraft(next); setDraft(saved); setBaseline(saved); return next;}}/>}</div>
  </div>;
}
