import { ArrowUpRight, Film, Search, Sparkles, Users } from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { Badge } from "@/components/ui/badge";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { api, type EpisodeSummary, type Member } from "@/lib/api";
import { cn, formatDate } from "@/lib/utils";

export function HomePage() {
  const [episodes, setEpisodes] = useState<EpisodeSummary[]>([]);
  const [members, setMembers] = useState<Member[]>([]);
  const [selectedMembers, setSelectedMembers] = useState<string[]>([]);
  const [query, setQuery] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    Promise.all([api.listEpisodes(), api.listMembers()])
      .then(([episodeResult, memberResult]) => {
        setEpisodes(episodeResult.episodes);
        setMembers(memberResult.members);
      })
      .catch((reason: unknown) => setError(reason instanceof Error ? reason.message : "読み込みに失敗しました"))
      .finally(() => setLoading(false));
  }, []);

  const filtered = useMemo(() => {
    const needle = query.trim().toLowerCase();
    return episodes.filter((episode) => {
      const haystack = `${episode.studio_id} ${episode.title} ${episode.summary} ${episode.members.map((member) => member.name).join(" ")}`.toLowerCase();
      const matchesText = !needle || haystack.includes(needle);
      const matchesMembers = selectedMembers.every((id) => episode.members.some((member) => member.id === id));
      return matchesText && matchesMembers;
    });
  }, [episodes, query, selectedMembers]);

  function toggleMember(id: string) {
    setSelectedMembers((current) => current.includes(id) ? current.filter((item) => item !== id) : [...current, id]);
  }

  return <div className="space-y-10">
    <section className="grid gap-8 lg:grid-cols-[1fr_auto] lg:items-end">
      <div className="max-w-3xl space-y-5">
        <Badge className="border-amber-300/15 bg-amber-300/8 text-amber-200"><Sparkles className="mr-2 size-3" />Seedance production archive</Badge>
        <h1 className="text-balance text-4xl font-semibold leading-[1.08] tracking-[-0.04em] sm:text-6xl">すべての物語を、<br /><span className="text-stone-500">再生成できる形で。</span></h1>
        <p className="max-w-2xl text-sm leading-7 text-stone-400 sm:text-base">エピソードごとに、v1・v2の生成履歴、入力素材、採用プロンプト、生成動画をまとめて保管します。</p>
      </div>
      <div className="grid grid-cols-2 gap-3"><Metric label="Episodes" value={episodes.length} /><Metric label="Generations" value={episodes.reduce((sum, item) => sum + item.generation_count, 0)} /></div>
    </section>

    <section className="space-y-4">
      <div className="relative max-w-lg"><Search className="absolute left-4 top-1/2 size-4 -translate-y-1/2 text-stone-600" /><Input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Studio ID、タイトル、メンバーで検索" className="h-12 rounded-full pl-11" /></div>
      <div className="flex flex-wrap items-center gap-2"><span className="mr-1 flex items-center gap-1.5 text-xs text-stone-600"><Users className="size-3.5" />メンバー</span>{members.map((member) => <button key={member.id} onClick={() => toggleMember(member.id)} className={cn("rounded-full border px-3 py-1.5 text-xs transition", selectedMembers.includes(member.id) ? "border-amber-300/35 bg-amber-300/10 text-amber-200" : "border-white/8 bg-white/[0.025] text-stone-500 hover:border-white/15 hover:text-stone-300")}>{member.name}</button>)}{selectedMembers.length ? <button onClick={() => setSelectedMembers([])} className="px-2 text-xs text-stone-600 hover:text-stone-300">解除</button> : null}</div>
    </section>

    {error ? <div className="rounded-2xl border border-red-400/20 bg-red-400/8 p-4 text-sm text-red-200">{error}</div> : null}
    {loading ? <div className="py-20 text-center text-sm text-stone-600">Archiveを読み込んでいます…</div> : null}
    {!loading && !error ? <section className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">{filtered.map((episode) => <Link key={episode.id} to={`/episodes/${episode.slug}`} className="group block"><Card className="h-full overflow-hidden transition duration-300 hover:-translate-y-1 hover:border-amber-300/20 hover:bg-stone-900"><div className="relative aspect-video overflow-hidden border-b border-white/6 bg-[linear-gradient(135deg,#292524,#0c0a09)]">{episode.primary_video_id ? <video src={`/media/${episode.primary_video_id}`} muted preload="metadata" className="h-full w-full object-cover opacity-75 transition duration-500 group-hover:scale-[1.02] group-hover:opacity-100" /> : <div className="grid h-full place-items-center text-stone-700"><Film className="size-9" /></div>}<div className="absolute inset-x-0 bottom-0 h-24 bg-gradient-to-t from-stone-950/80 to-transparent" /><div className="absolute bottom-4 left-4 font-mono text-xs text-stone-300">{episode.studio_id}</div><div className="absolute bottom-4 right-4 rounded-full bg-black/50 px-2 py-1 font-mono text-[10px] text-stone-400">{episode.generation_count} version{episode.generation_count === 1 ? "" : "s"}</div></div><div className="space-y-4 p-5"><div className="flex items-start justify-between gap-4"><h2 className="text-lg font-medium tracking-tight text-stone-100">{episode.title}</h2><ArrowUpRight className="mt-1 size-4 shrink-0 text-stone-600 transition group-hover:translate-x-0.5 group-hover:-translate-y-0.5 group-hover:text-amber-300" /></div><p className="line-clamp-2 min-h-10 text-sm leading-6 text-stone-500">{episode.summary || "概要はまだ登録されていません。"}</p><div className="flex flex-wrap gap-1.5">{episode.members.map((member) => <span key={member.id} className="rounded-full bg-white/5 px-2 py-1 text-[10px] text-stone-500">{member.name}</span>)}</div><div className="flex items-center justify-between border-t border-white/6 pt-4 text-[11px] text-stone-600"><span>{episode.input_count} inputs · {episode.video_count} videos</span><span>{formatDate(episode.updated_at)}</span></div></div></Card></Link>)}</section> : null}
    {!loading && !error && filtered.length === 0 ? <div className="rounded-3xl border border-dashed border-white/10 py-24 text-center text-sm text-stone-600">一致するエピソードはありません。</div> : null}
  </div>;
}

function Metric({ label, value }: { label: string; value: number }) {
  return <div className="min-w-28 rounded-2xl border border-white/7 bg-white/[0.025] px-5 py-4"><div className="text-2xl font-semibold tabular-nums">{String(value).padStart(2, "0")}</div><div className="mt-1 text-[10px] uppercase tracking-[0.2em] text-stone-600">{label}</div></div>;
}
