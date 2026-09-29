import { ArrowRight } from "lucide-react";
import type { AvailableTheme } from "@/official/site-theme";
import "./clips-entry.css";
import catalog from "./catalog.json";

export function ClipsEntry({ theme }: { theme: AvailableTheme }) {
  return (
    <section className="j-section j-clips-entry" aria-label="迷言・迷場面集">
      <a href={`/clips?theme=${theme}`}>
        <div className="j-clips-entry-images" aria-hidden="true">
          <img src={catalog.find((clip) => clip.id === "taxi")?.poster} alt="" loading="lazy" />
          <img src={catalog.find((clip) => clip.id === "okayaman")?.poster} alt="" loading="lazy" />
          <img src={catalog.find((clip) => clip.id === "first-class")?.poster} alt="" loading="lazy" />
        </div>
        <div className="j-clips-entry-copy">
          <h2>迷言・迷場面集</h2>
          <p>SNS、チャットツールにおすすめ</p>
        </div>
        <span className="j-clips-entry-action">
          一覧を見る
          <ArrowRight size={18} />
        </span>
      </a>
    </section>
  );
}
