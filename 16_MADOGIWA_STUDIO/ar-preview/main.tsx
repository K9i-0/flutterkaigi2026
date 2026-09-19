import { createRoot } from "react-dom/client";
import { useState } from "react";
import { CharacterAR } from "../src/official/character-ar";
import { modelCharacters } from "../src/official/character-ar-config";
import "../src/official/character-3d.css";
import "./preview.css";
function Preview() {
  const [character, setCharacter] = useState("yametaro");
  return <main className="j-model-dialog ar-preview">
    <header><span className="j-model-eyebrow">窓際族物語 / IPHONE SAFARI</span><h1>今日の一枚に、<br />窓際の仲間を。</h1><p>改善版 v3：やめ太郎の肌の反射・光沢を修正。</p></header>
    <div className="ar-preview-characters" aria-label="撮影するキャラクター">
      {modelCharacters.map(({ id, name }) => <button key={id} aria-pressed={character === id} onClick={() => setCharacter(id)}><img src={`/site/characters/${id}.webp`} alt=""/><span>{name}</span></button>)}
    </div>
    <CharacterAR key={character} character={character} />
    <footer>改善版 v3 / 肌色と光沢の貼り付け座標を分離。<br />空間への配置・自撮り・写真保存はiPhone実機で確認してください。</footer>
  </main>;
}
createRoot(document.getElementById("root")!).render(<Preview/>);
