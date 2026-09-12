import { Play } from "lucide-react";
import { useState } from "react";

// A poster has no media source to preload. Mount the player only after a click
// to play, so offscreen versions never trigger Worker/R2 Range requests.
export function DeferredVideo({ src, poster, label }: { src: string; poster: string; label: string }) {
  const [started, setStarted] = useState(false);
  return started
    ? <video src={src} poster={poster} controls autoPlay preload="none" playsInline aria-label={label} />
    : <button type="button" className="deferred-video" aria-label={`${label}を再生`} onClick={() => setStarted(true)}>
      <img src={poster} alt="" loading="lazy" decoding="async" />
      <span className="play-circle"><Play fill="currentColor" /></span>
    </button>;
}
