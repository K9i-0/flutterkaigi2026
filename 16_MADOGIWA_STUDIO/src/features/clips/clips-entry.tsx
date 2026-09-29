import { ArrowRight } from "lucide-react";
import type { AvailableTheme } from "@/official/site-theme";
import "./clips-entry.css";

export function ClipsEntry({ theme }: { theme: AvailableTheme }) {
  return (
    <section className="j-section j-clips-entry" aria-label="迷言・迷場面集">
      <a href={`/clips?theme=${theme}`}>
        <div className="j-clips-entry-images" aria-hidden="true">
          <img src="/__local-clips/taxi.jpg" alt="" loading="lazy" />
          <img src="/__local-clips/okayaman.jpg" alt="" loading="lazy" />
          <img src="/__local-clips/first-class.jpg" alt="" loading="lazy" />
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
