import type { ReactNode } from "react";

export function OwnerNote({ children, portrait = false }: { children: ReactNode; portrait?: boolean }) {
  return <div className={`s-owner-note${portrait ? " with-portrait" : ""}`}>
    {portrait && <img src="/site/characters/sobaya.webp" alt="店主そば屋" />}
    <div><small>店主より</small><p>{children}</p></div>
  </div>;
}

export const ownerNotes: Record<string, { title: string; note: string }> = {
  "新着動画": { title: "本日の入荷", note: "できたて、並べておきました。" },
  "人物特集": { title: "店主と常連さん", note: "席はあります。気楽にどうぞ。" },
  "漫画・ゲーム": { title: "もう少し、寄り道", note: "一杯のお供に、一話どうです？" },
  "ギャラリー": { title: "店内の貼り紙", note: "気に入った一枚、見つけていって。" },
};

export const menuNotes: Record<string, string> = {
  "tako-game-dormitory": "やめさん、寝床は選んだほうがいい。",
  "madogiwa-super-try-keisha": "低姿勢にも、ほどがある。",
  "madogiwa-super-try-commute": "会社へ行くだけで、この騒ぎ。",
  "professional-window-side-sobaya": "ビールを注ぐのも、立派な仕事です。",
  "madogiwa-super-try-underground": "一日分の労働が、この一杯に。",
  "balcony-bar-construction-timelapse": "うちの開店準備、見ていきます？",
};
