import { ArrowLeft, CalendarDays, FileText, Film, ImageIcon, Music2, Paperclip, Sparkles, Star, Users } from "lucide-react";
import { Link } from "@tanstack/react-router";
import { MovieCard } from "@/components/movie-card";
import { ShareActions } from "@/components/share-actions";
import {
  absoluteUrl,
  episodePoster,
  type PublicEpisodeDetail,
  type PublicInputAsset,
  type PublicProduction,
  type PublicVideo,
} from "@/lib/public-data";
import { formatDate } from "@/lib/utils";

export function EpisodePage({ detail }: { detail: PublicEpisodeDetail }) {
  const { episode, members, videos, productions, related } = detail;
  const primaryVideo = videos[0] ?? null;
  const primaryProduction = productions.find((production) => production.generation_id === primaryVideo?.generation_id) ?? null;
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
      <div className="episode-detail-media">
        {primaryVideo
          ? <video src={`/media/${primaryVideo.id}`} poster={primaryVideo.poster_url ?? undefined} controls preload="metadata" playsInline />
          : <img src={episodePoster(detail)} alt={`${episode.title}のキービジュアル`} />}
      </div>
      <div className="episode-detail-copy">
        <div>
          <span>{episode.studio_id}</span>
          {primaryVideo ? <small>{primaryVideo.is_featured ? <><Star fill="currentColor" /> PICK UP</> : "EPISODE VIDEO"}</small> : null}
        </div>
        <h1>{episode.title}</h1>
        {primaryVideo ? <p className="episode-primary-video-label">{primaryVideo.label}</p> : null}
        <p>{episode.summary || "窓際族たちの新しい物語。"}</p>
        <div className="episode-detail-facts">
          <span><CalendarDays />{formatDate(episode.published_at ?? episode.updated_at)}</span>
          <span><Film />{videos.length} VIDEO{videos.length === 1 ? "" : "S"}</span>
          <span><Users />{members.length} CAST</span>
          {primaryProduction ? <span><Sparkles />v{primaryProduction.version}{primaryProduction.model_name ? ` · ${primaryProduction.model_name}` : ""}</span> : null}
        </div>
        <ShareActions title={episode.title} path={pagePath} />
      </div>
    </header>

    {videos.length > 1 ? <section className="episode-video-section" aria-labelledby="episode-video-heading">
      <div className="episode-section-label"><Film /><span id="episode-video-heading">MORE VIDEOS</span></div>
      <div className="episode-more-videos">
        {videos.slice(1).map((video) => {
          const production = productions.find((item) => item.generation_id === video.generation_id) ?? null;
          return <article key={video.id}>
            <video src={`/media/${video.id}`} poster={video.poster_url ?? undefined} controls preload="metadata" playsInline />
            <div><h3>{video.label}</h3>{production ? <small>v{production.version}{production.model_name ? ` · ${production.model_name}` : ""}</small> : null}</div>
          </article>;
        })}
      </div>
    </section> : null}

    {productions.length ? <ProductionSection productions={productions} videos={videos} /> : null}

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

function ProductionSection({ productions, videos }: { productions: PublicProduction[]; videos: PublicVideo[] }) {
  return <section className="episode-production-section" aria-labelledby="episode-production-heading">
    <div className="episode-section-label"><Sparkles /><span id="episode-production-heading">PROMPT &amp; INPUTS</span></div>
    <div className="episode-production-list">{productions.map((production) => {
      const labels = videos.filter((video) => video.generation_id === production.generation_id).map((video) => video.label);
      return <article className="episode-production" key={production.generation_id}>
        <header>
          <div><span>GENERATION v{production.version}</span><h2>{production.label}</h2></div>
          <div>{production.model_name ? <span>{production.model_name}</span> : null}{labels.map((label) => <small key={label}>{label}</small>)}</div>
        </header>
        <div className="episode-production-grid">
          <div className="episode-prompt-card">
            <div><FileText /><span>PROMPT</span>{production.prompt ? <small>revision {production.prompt.version}</small> : null}</div>
            {production.prompt
              ? <><h3>{production.prompt.label}</h3><pre>{production.prompt.body}</pre></>
              : <p>この動画のプロンプトはまだ登録されていません。</p>}
          </div>
          <div className="episode-inputs-card">
            <div><Paperclip /><span>INPUTS</span><small>{production.inputs.length}</small></div>
            {production.inputs.length
              ? <div className="episode-input-grid">{production.inputs.map((asset) => <InputAssetPreview key={asset.id} asset={asset} />)}</div>
              : <p>この生成にはインプット素材が登録されていません。</p>}
          </div>
        </div>
      </article>;
    })}</div>
  </section>;
}

function InputAssetPreview({ asset }: { asset: PublicInputAsset }) {
  const metadata = [asset.group_label, asset.reference_label, asset.filename].filter(Boolean).join(" · ");
  return <article className="episode-input-asset">
    {asset.kind === "image" ? <a href={asset.url} target="_blank" rel="noreferrer" className="episode-input-preview">
      <img src={asset.url} alt={asset.label} loading="lazy" />
    </a> : null}
    {asset.kind === "audio" ? <div className="episode-input-audio"><Music2 /><audio src={asset.url} controls preload="none" /></div> : null}
    {asset.kind === "document" || asset.kind === "other" ? <a href={asset.url} target="_blank" rel="noreferrer" className="episode-input-file">
      {asset.kind === "document" ? <FileText /> : <Paperclip />}<span>ファイルを開く</span>
    </a> : null}
    <div className="episode-input-copy">
      <span>{asset.kind === "image" ? <ImageIcon /> : asset.kind === "audio" ? <Music2 /> : <Paperclip />}{asset.kind.toUpperCase()}</span>
      <h3>{asset.label}</h3>
      {metadata ? <small>{metadata}</small> : null}
      {asset.notes ? <p>{asset.notes}</p> : null}
    </div>
  </article>;
}
