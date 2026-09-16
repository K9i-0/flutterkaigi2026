import { createRoot } from "react-dom/client";
import { useState } from "react";
import { CharacterAR } from "../src/official/character-ar";
import { arCharacters } from "../src/official/character-ar-config";
import "../src/official/character-3d.css";
import "./preview.css";
function Preview() {
  const [character, setCharacter] = useState("sobaya");
  return <main className="j-model-dialog ar-preview">
    <header><span className="j-model-eyebrow">窓際族物語 / IPHONE SAFARI</span><h1>今日の一枚に、<br />窓際の仲間を。</h1><p>キャラクターを選んで、いつもの景色へ。</p></header>
    <div className="ar-preview-characters" aria-label="撮影するキャラクター">
      {Object.entries(arCharacters).map(([id, entry]) => <button key={id} aria-pressed={character === id} onClick={() => setCharacter(id)}><img src={`/site/characters/${id}.webp`} alt=""/><span>{entry.name}</span></button>)}
    </div>
    <CharacterAR key={character} character={character} />
    <footer>端末内でARデータを生成するローカル試作です。<br />空間への配置・自撮り・写真保存はiPhone実機で確認してください。</footer>
  </main>;
}
createRoot(document.getElementById("root")!).render(<Preview/>);
