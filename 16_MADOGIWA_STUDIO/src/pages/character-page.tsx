import { ArrowLeft, Clapperboard } from "lucide-react";
import { Link } from "@tanstack/react-router";
import { MovieCard } from "@/components/movie-card";
import { ShareActions } from "@/components/share-actions";
import type { EpisodeSummary } from "@/lib/api";
import { characters } from "@/lib/site-content";

type Character = (typeof characters)[number];

export function CharacterPage({ character, episodes }: { character: Character; episodes: EpisodeSummary[] }) {
  return <div className="character-detail-page">
    <Link to="/" hash="characters" className="archive-back"><ArrowLeft /> CHARACTERS</Link>
    <header className="character-detail-header">
      <div className="character-detail-image"><img src={character.image} alt={character.name} /></div>
      <div className="character-detail-copy">
        <span>{character.role}</span><h1>{character.name}</h1><p>{character.copy}</p>
        <ShareActions title={character.name} path={`/characters/${character.id}`} />
      </div>
    </header>
    {episodes.length ? <section className="character-episodes">
      <div className="episode-section-label"><Clapperboard /><span>APPEARS IN</span></div>
      <div className="movie-archive-grid">{episodes.map((episode, index) => <MovieCard key={episode.id} episode={episode} index={index} />)}</div>
    </section> : <div className="empty-feature">EPISODES COMING SOON</div>}
  </div>;
}
