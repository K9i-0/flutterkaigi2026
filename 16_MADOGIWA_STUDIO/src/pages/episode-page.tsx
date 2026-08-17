import { ArrowLeft, CalendarDays, Film, Star, Users } from "lucide-react";
import { Link } from "@tanstack/react-router";
import { MovieCard } from "@/components/movie-card";
import { ShareActions } from "@/components/share-actions";
import { absoluteUrl, episodePoster, type PublicEpisodeDetail } from "@/lib/public-data";
import { formatDate } from "@/lib/utils";

export function EpisodePage({ detail }: { detail: PublicEpisodeDetail }) {
  const { episode, members, videos, related } = detail;
  const primaryVideo = videos[0] ?? null;
  const pagePath = `/episodes/${episode.slug}`;
  const jsonLd = {
    "@context": "https://schema.org",
    "@type": "VideoObject",
    name: episode.title,
    description: episode.summary || "窓際族たちの新しい物語。",
    thumbnailUrl: [absoluteUrl(episodePoster(detail))],
    uploadDate: episode.published_at ?? episode.updated_at,
    contentUrl: primaryVideo ? absoluteUrl(`/media/${primaryVideo.id}`) : undefined,
    url: absoluteUrl(pagePath),
  };

  return <div className="episode-detail-page">
    <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd).replace(/</g, "\\u003c") }} />
    <Link to="/episodes" className="archive-back"><ArrowLeft /> EPISODES</Link>

    <header className="episode-detail-header">
      <div className="episode-detail-copy">
        <span>{episode.studio_id}</span>
        <h1>{episode.title}</h1>
        <p>{episode.summary || "窓際族たちの新しい物語。"}</p>
        <div className="episode-detail-facts">
          <span><CalendarDays />{formatDate(episode.published_at ?? episode.updated_at)}</span>
          <span><Film />{videos.length} VIDEO{videos.length === 1 ? "" : "S"}</span>
          <span><Users />{members.length} CAST</span>
        </div>
        <ShareActions title={episode.title} text={episode.summary || "窓際族たちの新しい物語。"} path={pagePath} />
      </div>
      <div className="episode-detail-poster">
        <img src={episodePoster(detail)} alt={`${episode.title}のキービジュアル`} />
      </div>
    </header>

    <section className="episode-video-section" aria-labelledby="episode-video-heading">
      <div className="episode-section-label"><Film /><span id="episode-video-heading">WATCH</span></div>
      {primaryVideo ? <div className="episode-main-video">
        <video src={`/media/${primaryVideo.id}`} poster={primaryVideo.poster_url ?? undefined} controls preload="metadata" playsInline />
        <div><span>{primaryVideo.is_featured ? <><Star fill="currentColor" /> PICK UP</> : "FEATURED VIDEO"}</span><h2>{primaryVideo.label}</h2></div>
      </div> : <div className="empty-feature">VIDEO COMING SOON</div>}
      {videos.length > 1 ? <div className="episode-more-videos">
        {videos.slice(1).map((video) => <article key={video.id}>
          <video src={`/media/${video.id}`} poster={video.poster_url ?? undefined} controls preload="metadata" playsInline />
          <h3>{video.label}</h3>
        </article>)}
      </div> : null}
    </section>

    {members.length ? <section className="episode-cast-section" aria-labelledby="episode-cast-heading">
      <div className="episode-section-label"><Users /><span id="episode-cast-heading">CAST</span></div>
      <div className="episode-cast-grid">{members.map((member) => <Link key={member.id} to="/characters/$slug" params={{ slug: member.id }}>
        <span>{member.name}</span><small>CHARACTER PROFILE →</small>
      </Link>)}</div>
    </section> : null}

    {related.length ? <section className="episode-related-section" aria-labelledby="episode-related-heading">
      <div className="episode-section-label"><Film /><span id="episode-related-heading">RELATED EPISODES</span></div>
      <div className="movie-archive-grid">{related.map((item, index) => <MovieCard key={item.id} episode={item} index={index} />)}</div>
    </section> : null}
  </div>;
}
