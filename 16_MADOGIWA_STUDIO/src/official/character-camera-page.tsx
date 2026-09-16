import { ArrowLeft } from "lucide-react";
import { CharacterAR } from "./character-ar";
import { arCharacters, cameraUrl, type ARCharacter } from "./character-ar-config";
import "./character-3d.css";
import "./character-camera-page.css";

export function CharacterCameraPage({ character }: { character: ARCharacter }) {
  return <div className="j-camera-shell"><main className="j-model-dialog j-camera">
    <a className="j-camera-back" href={`/characters/${character}`}><ArrowLeft size={16} />キャラクター紹介へ</a>
    <header><span className="j-model-eyebrow">窓際族物語 / AR CAMERA</span><h1>今日の一枚に、<br />窓際の仲間を。</h1><p>キャラクターを選んで、いつもの景色へ。</p></header>
    <nav className="j-camera-characters" aria-label="撮影するキャラクター">
      {Object.entries(arCharacters).map(([id, entry]) => <a key={id} href={cameraUrl(id)} aria-current={character === id ? "page" : undefined}><img src={`/site/characters/${id}.webp`} alt=""/><span>{entry.name}</span></a>)}
    </nav>
    <CharacterAR character={character} />
    <footer><a href="/">窓際族物語 トップへ</a><span>© 窓際族物語</span></footer>
  </main></div>;
}
