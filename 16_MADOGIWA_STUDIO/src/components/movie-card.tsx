import { Play, Star } from "lucide-react";
import { useRef, useState } from "react";
import { Link } from "react-router-dom";
import type { EpisodeSummary } from "@/lib/api";

type MovieCardProps = {
  episode: EpisodeSummary;
  index: number;
  featuredLayout?: boolean;
  inlinePlayback?: boolean;
};

export function MovieCard({ episode, index, featuredLayout = false, inlinePlayback = false }: MovieCardProps) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const [started, setStarted] = useState(false);
  const detailPath = `/episodes/${episode.slug}`;
  const className = featuredLayout ? "movie-card movie-card-featured" : "movie-card";

  async function startPlayback() {
    const video = videoRef.current;
    if (!video) return;
    video.muted = false;
    try {
      await video.play();
      setStarted(true);
    } catch {
      setStarted(false);
    }
  }

  const visual = <>
    {episode.primary_video_id ? <video
      ref={inlinePlayback ? videoRef : undefined}
      src={`/media/${episode.primary_video_id}`}
      poster={episode.primary_video_poster_url ?? undefined}
      muted={!inlinePlayback}
      controls={inlinePlayback && started}
      preload="metadata"
      playsInline
      onPlay={inlinePlayback ? () => setStarted(true) : undefined}
      onEnded={inlinePlayback ? () => setStarted(false) : undefined}
    /> : <img src="/site/hero-shibuya-wide.webp" alt="" />}
    <div className="movie-number">{String(index + 1).padStart(2, "0")}</div>
  </>;

  return <article className={className}>
    {inlinePlayback && episode.primary_video_id ? <div className="movie-visual movie-visual-inline">
      {visual}
      {!started ? <button type="button" className="movie-play-button" onClick={startPlayback} aria-label={`${episode.title}を再生`}>
        <span className="play-circle"><Play fill="currentColor" /></span>
      </button> : null}
    </div> : <Link to={detailPath} className="movie-visual movie-visual-link" aria-label={`${episode.title}の詳細を見る`}>
      {visual}
      <span className="play-circle"><Play fill="currentColor" /></span>
    </Link>}
    <Link to={detailPath} className="movie-meta">
      <div className="movie-meta-topline">
        <span>{episode.studio_id}</span>
        {episode.has_featured_video ? <span className="featured-ribbon"><Star fill="currentColor" /> PICK UP</span> : null}
      </div>
      <h3>{episode.title}</h3>
      <p>{episode.summary || "窓際族たちの新しい物語。"}</p>
      <small>{episode.generation_count} GENERATION{episode.generation_count === 1 ? "" : "S"}</small>
    </Link>
  </article>;
}
