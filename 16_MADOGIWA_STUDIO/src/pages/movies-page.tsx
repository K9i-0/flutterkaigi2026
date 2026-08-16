import { ArrowLeft, Film } from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { MovieCard } from "@/components/movie-card";
import { api, type EpisodeSummary } from "@/lib/api";

export function MoviesPage() {
  const [episodes, setEpisodes] = useState<EpisodeSummary[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api.listEpisodes().then((result) => setEpisodes(result.episodes)).catch(() => setEpisodes([])).finally(() => setLoading(false));
  }, []);

  const videos = useMemo(() => episodes.filter((episode) => episode.primary_video_id), [episodes]);

  return <div className="movies-archive">
    <Link to="/#movie" className="archive-back"><ArrowLeft /> 公式サイトへ戻る</Link>
    <header className="archive-heading">
      <div className="section-icon"><Film /></div>
      <div><span>MOVIE ARCHIVE</span><h1>すべての映像物語。</h1><p>窓際族物語から生まれた動画を、新しい作品からまとめて楽しめます。</p></div>
    </header>
    <div className="archive-count">{videos.length} MOVIES</div>
    {loading ? <div className="loading-line">MOVIES LOADING...</div> : videos.length ? <div className="movie-archive-grid">{videos.map((episode, index) => <MovieCard key={episode.id} episode={episode} index={index} />)}</div> : <div className="empty-feature">映像を準備しています。</div>}
  </div>;
}
