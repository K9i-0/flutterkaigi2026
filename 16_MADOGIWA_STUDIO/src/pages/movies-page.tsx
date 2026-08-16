import { Check, Film, Star, Users } from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { MovieCard } from "@/components/movie-card";
import { api, type EpisodeSummary } from "@/lib/api";
import { characters } from "@/lib/site-content";

export function MoviesPage() {
  const [episodes, setEpisodes] = useState<EpisodeSummary[]>([]);
  const [loading, setLoading] = useState(true);
  const [featuredOnly, setFeaturedOnly] = useState(false);
  const [selectedMembers, setSelectedMembers] = useState<string[]>([]);

  useEffect(() => {
    api.listEpisodes().then((result) => setEpisodes(result.episodes)).catch(() => setEpisodes([])).finally(() => setLoading(false));
  }, []);

  const videos = useMemo(() => episodes.filter((episode) => episode.primary_video_id), [episodes]);
  const availableMembers = useMemo(() => {
    const memberIds = new Set(videos.flatMap((episode) => episode.members.map((member) => member.id)));
    return characters.filter((character) => memberIds.has(character.id));
  }, [videos]);
  const filteredVideos = useMemo(() => videos.filter((episode) => {
    const matchesFeatured = !featuredOnly || Boolean(episode.has_featured_video);
    const matchesMembers = selectedMembers.every((memberId) => episode.members.some((member) => member.id === memberId));
    return matchesFeatured && matchesMembers;
  }), [featuredOnly, selectedMembers, videos]);

  function toggleMember(memberId: string) {
    setSelectedMembers((current) => current.includes(memberId)
      ? current.filter((id) => id !== memberId)
      : [...current, memberId]);
  }

  return <div className="movies-archive">
    <header className="archive-heading">
      <div className="section-icon"><Film /></div>
      <div><span>MOVIE ARCHIVE</span><h1>すべての映像物語。</h1></div>
    </header>
    <section className="movie-filters" aria-label="動画の絞り込み">
      <div className="movie-filter-heading">
        <div><Users /><span>CHARACTERS</span></div>
        <button type="button" className="featured-only-toggle" role="switch" aria-checked={featuredOnly} onClick={() => setFeaturedOnly((current) => !current)}>
          <Star fill={featuredOnly ? "currentColor" : "none"} />
          <span>イチオシのみ</span>
          <i aria-hidden="true"><b /></i>
        </button>
      </div>
      <div className="member-portrait-filters">
        {availableMembers.map((character) => {
          const selected = selectedMembers.includes(character.id);
          return <button key={character.id} type="button" aria-pressed={selected} onClick={() => toggleMember(character.id)}>
            <span className="member-portrait"><img src={character.image} alt="" /><i><Check /></i></span>
            <span>{character.name}</span>
          </button>;
        })}
      </div>
      {selectedMembers.length ? <button type="button" className="member-filter-reset" onClick={() => setSelectedMembers([])}>メンバー選択を解除</button> : null}
    </section>
    <div className="archive-count">{filteredVideos.length === videos.length ? `${videos.length} MOVIES` : `${filteredVideos.length} / ${videos.length} MOVIES`}</div>
    {loading ? <div className="loading-line">MOVIES LOADING...</div> : filteredVideos.length ? <div className="movie-archive-grid">{filteredVideos.map((episode, index) => <MovieCard key={episode.id} episode={episode} index={index} />)}</div> : <div className="empty-feature">条件に合う動画はありません。</div>}
  </div>;
}
