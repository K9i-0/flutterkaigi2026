import { useCallback, useRef } from "react";

const storageKey = "madogiwa-video-preferences";
type Preferences = { volume: number; muted: boolean };
let memory: Preferences | undefined;

function readPreferences(): Preferences | undefined {
  try {
    const value: unknown = JSON.parse(localStorage.getItem(storageKey) ?? "null");
    if (value && typeof value === "object" && "volume" in value && "muted" in value
      && typeof value.volume === "number" && Number.isFinite(value.volume)
      && value.volume >= 0 && value.volume <= 1 && typeof value.muted === "boolean") {
      memory = { volume: value.volume, muted: value.muted };
    }
  } catch { /* Keep the session preference when browser storage is unavailable. */ }
  return memory;
}

// The callback ref restores sound settings during mount, before autoplay.
export function useVideoPreferences() {
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const ref = useCallback((video: HTMLVideoElement | null) => {
    videoRef.current = video;
    if (!video) return;
    const restore = () => {
      const saved = readPreferences();
      if (!saved) return;
      // Some mobile browsers let only the system volume control change volume.
      try { video.volume = saved.volume; } catch { /* Use system volume. */ }
      video.muted = saved.muted;
    };
    restore();
    const save = () => {
      const next = { volume: video.volume, muted: video.muted };
      // Restoration also emits volumechange; avoid redundant storage writes.
      if (memory?.volume === next.volume && memory.muted === next.muted) return;
      memory = next;
      try { localStorage.setItem(storageKey, JSON.stringify(next)); } catch { /* Session memory remains usable. */ }
    };
    video.addEventListener("volumechange", save);
    video.addEventListener("play", restore);
    return () => {
      video.removeEventListener("volumechange", save);
      video.removeEventListener("play", restore);
      videoRef.current = null;
    };
  }, []);
  return { ref, videoRef };
}
