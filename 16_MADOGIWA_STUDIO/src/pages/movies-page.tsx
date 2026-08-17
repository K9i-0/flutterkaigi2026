import { Check, Film, Star, Users } from "lucide-react";
import { useMemo } from "react";
import { MovieCard } from "@/components/movie-card";
import type { EpisodeSummary } from "@/lib/api";
import { characters } from "@/lib/site-content";

type Filters = { featuredOnly: boolean; selectedMembers: string[] };

export function EpisodesPage({ episodes, featuredOnly, selectedMembers, onFilters }: {
  episodes: EpisodeSummary[];
  featuredOnly: boolean;
  selectedMembers: string[];
  onFilters: (filters: Filters) => void;
}) {
  const availableMembers = useMemo(() => {
    const memberIds = new Set(episodes.flatMap((episode) => episode.members.map((member) => member.id)));
    return characters.filter((character) => memberIds.has(character.id));
  }, [episodes]);
  const filteredEpisodes = useMemo(() => episodes.filter((episode) => {
    const matchesFeatured = !featuredOnly || Boolean(episode.has_featured_video);
    const matchesMembers = selectedMembers.every((memberId) => episode.members.some((member) => member.id === memberId));
    return matchesFeatured && matchesMembers;
  }), [episodes, featuredOnly, selectedMembers]);

  function toggleMember(memberId: string) {
    onFilters({ featuredOnly, selectedMembers: selectedMembers.includes(memberId) ? selectedMembers.filter((id) => id !== memberId) : [...selectedMembers, memberId] });
  }

  return <div className="movies-archive">
    <header className="archive-heading"><div className="section-icon"><Film /></div><div><span>EPISODE ARCHIVE</span><h1>すべての映像物語。</h1><p>動画はエピソードの中で楽しむ。登場人物から、次の物語を見つけられます。</p></div></header>
    <section className="movie-filters" aria-label="エピソードの絞り込み">
      <div className="movie-filter-heading"><div><Users /><span>CHARACTERS</span></div><button type="button" className="featured-only-toggle" role="switch" aria-checked={featuredOnly} onClick={() => onFilters({ featuredOnly: !featuredOnly, selectedMembers })}><Star fill={featuredOnly ? "currentColor" : "none"} /><span>イチオシのみ</span><i aria-hidden="true"><b /></i></button></div>
      <div className="member-portrait-filters">{availableMembers.map((character) => {
        const selected = selectedMembers.includes(character.id);
        return <button key={character.id} type="button" aria-pressed={selected} onClick={() => toggleMember(character.id)}><span className="member-portrait"><img src={character.image} alt="" /><i><Check /></i></span><span>{character.name}</span></button>;
      })}</div>
      {selectedMembers.length ? <button type="button" className="member-filter-reset" onClick={() => onFilters({ featuredOnly, selectedMembers: [] })}>メンバー選択を解除</button> : null}
    </section>
    <div className="archive-count">{filteredEpisodes.length === episodes.length ? `${episodes.length} EPISODES` : `${filteredEpisodes.length} / ${episodes.length} EPISODES`}</div>
    {filteredEpisodes.length ? <div className="movie-archive-grid">{filteredEpisodes.map((episode, index) => <MovieCard key={episode.id} episode={episode} index={index} />)}</div> : <div className="empty-feature">条件に合う公開エピソードはありません。</div>}
  </div>;
}
