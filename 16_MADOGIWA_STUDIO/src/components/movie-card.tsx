import { Play, Star } from "lucide-react";
import { Link } from "react-router-dom";
import type { EpisodeSummary } from "@/lib/api";

export function MovieCard({ episode, index, featuredLayout = false }: { episode: EpisodeSummary; index: number; featuredLayout?: boolean }) {
  return <Link to={`/episodes/${episode.slug}`} className={featuredLayout ? "movie-card movie-card-featured" : "movie-card"}>
    <div className="movie-visual">
      {episode.primary_video_id ? <video src={`/media/${episode.primary_video_id}`} muted preload="metadata" playsInline /> : <img src="/site/hero-shibuya-wide.webp" alt="" />}
      <div className="movie-number">{String(index + 1).padStart(2, "0")}</div>
      {episode.has_featured_video ? <span className="featured-ribbon"><Star fill="currentColor" /> PICK UP</span> : null}
      <span className="play-circle"><Play fill="currentColor" /></span>
    </div>
    <div className="movie-meta">
      <span>{episode.studio_id}</span>
      <h3>{episode.title}</h3>
      <p>{episode.summary || "窓際族たちの新しい物語。"}</p>
      <small>{episode.generation_count} GENERATION{episode.generation_count === 1 ? "" : "S"}</small>
    </div>
  </Link>;
}
