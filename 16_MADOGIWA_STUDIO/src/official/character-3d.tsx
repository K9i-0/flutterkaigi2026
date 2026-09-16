import { useEffect, useRef, useState } from "react";
import * as Dialog from "@radix-ui/react-dialog";
import { Box, Camera, Pause, Play, RotateCcw, X } from "lucide-react";
import type { CharacterScene } from "./character-3d-scene";
import "./character-3d.css";
import { cameraUrl, isARCharacter, modelUrl } from "./character-ar-config";

const characters = [
  { id: "sobaya", name: "そば屋" },
  { id: "fukuchan", name: "福ちゃん" },
  { id: "takosan", name: "たこさん" },
  { id: "yametaro", name: "やめ太郎" },
];
const motions = [
  { id: "Idle", label: "待機" },
  { id: "Greeting", label: "ごあいさつ" },
  { id: "Wave", label: "手を振る" },
  { id: "Talk", label: "おしゃべり" },
  { id: "DanceStep", label: "ダンス" },
  { id: "DanceDisco", label: "ディスコ" },
];

export function Character3D({ character }: { character: string }) {
  const [open, setOpen] = useState(false);
  if (!characters.some((entry) => entry.id === character)) return null;
  return <Dialog.Root open={open} onOpenChange={setOpen}>
    <Dialog.Trigger asChild>
      <button className="j-model-trigger"><Box size={18} /><span>3Dで見る</span><span className="j-model-trigger-note">回して、動かして。</span></button>
    </Dialog.Trigger>
    <Dialog.Portal>
      <Dialog.Overlay className="j-model-overlay" />
      <Dialog.Content className="j-model-dialog">
        <div className="j-model-heading">
          <div><span className="j-model-eyebrow">窓際の住人を、ぐるり。</span><Dialog.Title>3Dキャラクター</Dialog.Title></div>
          <Dialog.Close className="j-model-icon" aria-label="3Dビューを閉じる"><X size={22} /></Dialog.Close>
        </div>
        <Dialog.Description className="j-model-description">ドラッグで回転。ピンチやホイールで、もっと近くに。</Dialog.Description>
        <ModelPicker initial={character} />
      </Dialog.Content>
    </Dialog.Portal>
  </Dialog.Root>;
}

function ModelPicker({ initial }: { initial: string }) {
  const [selected, setSelected] = useState(initial);
  return <>
    <div className="j-model-tabs" aria-label="3Dキャラクターを選ぶ">
      {characters.map((entry) => <button key={entry.id} aria-pressed={selected === entry.id} onClick={() => setSelected(entry.id)}>{entry.name}</button>)}
    </div>
    <ModelView key={selected} character={selected} />
    <a className="j-model-camera-link" href={cameraUrl(selected)}><Camera size={18} />いっしょに撮る<span>ARカメラへ</span></a>
  </>;
}

function ModelView({ character }: { character: string }) {
  const host = useRef<HTMLDivElement>(null);
  const scene = useRef<CharacterScene | null>(null);
  const [status, setStatus] = useState<"loading" | "ready" | "error">("loading");
  const [available, setAvailable] = useState<string[]>([]);
  const [motion, setMotion] = useState("Idle");
  const [paused, setPaused] = useState(() => window.matchMedia("(prefers-reduced-motion: reduce)").matches);
  const [attempt, setAttempt] = useState(0);
  useEffect(() => {
    let cancelled = false;
    let instance: CharacterScene | undefined;
    void import("./character-3d-scene").then(({ createCharacterScene }) => {
      if (cancelled || !host.current) return;
      instance = createCharacterScene(host.current, modelUrl(character), (clips) => {
        if (cancelled) return;
        setAvailable(clips);
        setStatus("ready");
      }, () => {
        if (cancelled) return;
        setStatus("error");
        instance?.dispose();
        scene.current = null;
      });
      scene.current = instance;
    }).catch(() => { if (!cancelled) setStatus("error"); });
    return () => { cancelled = true; instance?.dispose(); scene.current = null; };
  }, [character, attempt]);
  return <>
    <div className="j-model-stage">
      <div className="j-model-canvas" ref={host} />
      <span className="j-model-stage-label">{characters.find((entry) => entry.id === character)?.name}</span>
      {status !== "ready" && <div className="j-model-status" role="status">
        {status === "loading" ? <><span className="j-model-spinner" />もうすぐ、会えます。<small>3Dモデルを読み込み中</small></> : <><span>3Dを表示できませんでした。</span><small>通信環境やブラウザの3D対応をご確認ください。</small><button onClick={() => { setStatus("loading"); setMotion("Idle"); setPaused(window.matchMedia("(prefers-reduced-motion: reduce)").matches); setAttempt((value) => value + 1); }}>もう一度読み込む</button></>}
      </div>}
      <button className="j-model-reset" disabled={status !== "ready"} onClick={() => scene.current?.reset()}><RotateCcw size={15} />正面に戻す</button>
    </div>
    <div className="j-model-controls">
      <span className="j-model-controls-label">動いてもらう</span>
      <div className="j-model-motions">
        {motions.filter((entry) => available.includes(entry.id)).map((entry) => <button key={entry.id} disabled={status !== "ready"} aria-pressed={motion === entry.id} onClick={() => { setMotion(entry.id); scene.current?.motion(entry.id); }}>{entry.label}</button>)}
        <button className="j-model-pause" disabled={status !== "ready"} aria-label={paused ? "動作を再生" : "動作を一時停止"} onClick={() => { scene.current?.pause(!paused); setPaused(!paused); }}>{paused ? <Play size={16} /> : <Pause size={16} />}{paused ? "再生" : "一時停止"}</button>
      </div>
    </div>
  </>;
}

export function CharacterCameraLink({ character }: { character: string }) {
  if (!isARCharacter(character)) return null;
  return <a className="j-model-trigger j-camera-trigger" href={cameraUrl(character)}><Camera size={18} /><span>いっしょに撮る</span><span className="j-model-trigger-note">等身大でも、ぬいぐるみでも。</span></a>;
}
