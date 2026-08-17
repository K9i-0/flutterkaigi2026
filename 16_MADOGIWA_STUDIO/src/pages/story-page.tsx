import { BookOpen } from "lucide-react";
import { ZoomableImage } from "@/components/image-lightbox";
import { ShareActions } from "@/components/share-actions";
import { comicEpisodes } from "@/lib/site-content";

export function StoryPage() {
  return <div className="story-page">
    <header className="story-header">
      <div className="section-icon"><BookOpen /></div>
      <div><span>ORIGINAL STORY</span><h1>原作ストーリー</h1><p>窓際の席から、物語は始まった。入社初日からBONKまでを辿る全14話。</p>
        <ShareActions title="原作ストーリー" text="窓際族物語の原点となる全14話。" path="/story" />
      </div>
    </header>
    <div className="story-grid">{comicEpisodes.map((episode) => <article key={episode.number}>
      <ZoomableImage src={episode.image} alt={`第${episode.number}話 ${episode.title}`} caption={episode.description} className="story-image" />
      <div><span>STORY {String(episode.number).padStart(2, "0")}</span><h2>{episode.title}</h2><p>{episode.description}</p></div>
    </article>)}</div>
  </div>;
}
