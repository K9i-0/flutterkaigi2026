import { Play, Star } from "lucide-react";
import { useState } from "react";
import { useVideoPreferences } from "./use-video-preferences";
import { Link } from "@tanstack/react-router";
import type { EpisodeSummary } from "@/lib/api";

type MovieCardProps = {
  episode: EpisodeSummary;
  index: number;
  featuredLayout?: boolean;
  inlinePlayback?: boolean;
};

export function MovieCard({ episode, index, featuredLayout = false, inlinePlayback = false }: MovieCardProps) {
  const { ref, videoRef } = useVideoPreferences();
  const [started, setStarted] = useState(false);
  const className = featuredLayout ? "movie-card movie-card-featured" : "movie-card";

  async function startPlayback() {
    const video = videoRef.current;
    if (!video) return;
    if (!video.getAttribute("src")) video.src = `/media/${episode.primary_video_id}`;
    try {
      await video.play();
      setStarted(true);
    } catch {
      setStarted(false);
    }
  }

  const visual = <>
    {inlinePlayback && episode.primary_video_id ? <video
      ref={ref}
      poster={episode.primary_video_poster_url ?? undefined}
      controls={inlinePlayback && started}
      preload="none"
      playsInline
      onPlay={inlinePlayback ? () => setStarted(true) : undefined}
      onEnded={inlinePlayback ? () => setStarted(false) : undefined}
    /> : <img src={episode.primary_video_poster_url ?? "/site/hero-shibuya-wide.webp"} alt="" loading="lazy" decoding="async" />}
    <div className="movie-number">{String(index + 1).padStart(2, "0")}</div>
  </>;

  return <article className={className}>
    {inlinePlayback && episode.primary_video_id ? <div className="movie-visual movie-visual-inline">
      {visual}
      {!started ? <button type="button" className="movie-play-button" onClick={startPlayback} aria-label={`${episode.title}を再生`}>
        <span className="play-circle"><Play fill="currentColor" /></span>
      </button> : null}
    </div> : <Link to="/episodes/$slug" params={{ slug: episode.slug }} className="movie-visual movie-visual-link" aria-label={`${episode.title}の詳細を見る`}>
      {visual}
      <span className="play-circle"><Play fill="currentColor" /></span>
    </Link>}
    <Link to="/episodes/$slug" params={{ slug: episode.slug }} className="movie-meta">
      <div className="movie-meta-topline">
        <span>{episode.studio_id}</span>
        {episode.has_featured_video ? <span className="featured-ribbon"><Star fill="currentColor" /> PICK UP</span> : null}
      </div>
      <h3>{episode.title}</h3>
      <p>{episode.summary || "窓際族たちの新しい物語。"}</p>
      <small>{episode.members.map((member) => member.name).join(" · ") || "MADOGIWA STORY"}</small>
    </Link>
  </article>;
}
