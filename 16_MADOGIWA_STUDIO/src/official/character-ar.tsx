import { useEffect, useRef, useState } from "react";
import { Camera, Check, Download, MoveUpRight, RotateCcw } from "lucide-react";
import { arCharacters, arHeight, isARCharacter, type ARCharacter, type ARPlacement } from "./character-ar-config";
import "./character-ar.css";

export function CharacterAR({ character }: { character: string }) {
  const [placement, setPlacement] = useState<ARPlacement>("life");
  const [pose, setPose] = useState<"Idle" | "Wave">("Idle");
  if (!isARCharacter(character)) return null;
  const id = character as ARCharacter;
  return <section className="j-ar" aria-label="窓際ARカメラ">
    <div className="j-ar-heading"><div><span className="j-model-eyebrow">いつもの景色に、窓際の仲間。</span><h3><Camera size={20} />窓際ARカメラ</h3></div></div>
    <p className="j-ar-intro">テーブルにちょこんと。隣に、等身大で。<br />好きなサイズで、一緒の一枚を。</p>
    <div className="j-ar-options" role="group" aria-label="ARの置き方">
      <button aria-pressed={placement === "plush"} onClick={() => setPlacement("plush")}><span>ぬいぐるみ</span><small>高さ20cm・机や料理のそばに</small></button>
      <button aria-pressed={placement === "life"} onClick={() => setPlacement("life")}><span>等身大</span><small>高さ約{Math.round(arHeight(id, "life") * 100)}cm・隣に並んで</small></button>
      <button aria-pressed={placement === "selfie"} onClick={() => setPlacement("selfie")}><span>顔の横で自撮り <em>実験版</em></span><small>高さ12cm・顔の動きについてくる</small></button>
    </div>
    <div className="j-ar-poses" role="group" aria-label="撮影ポーズ"><span>ポーズ</span><button aria-pressed={pose === "Idle"} onClick={() => setPose("Idle")}>いつもの姿</button><button aria-pressed={pose === "Wave"} onClick={() => setPose("Wave")}>ごあいさつ</button></div>
    {placement === "selfie" ? <p className="j-ar-hint">TrueDepthカメラ搭載iPhone向け。顔に合わせた固定位置・サイズです。顔の向きに合わせてキャラも動きます。</p> : <p className="j-ar-hint">置いたあとも指で移動・拡大縮小できます。AR画面の撮影ボタンで写真を撮れます。</p>}
    <ARLaunch key={`${id}:${placement}:${pose}`} character={id} placement={placement} pose={pose} />
    <p className="j-ar-privacy"><Check size={14} />写真・カメラ映像はサーバーに送信しません。</p>
    <p className="j-ar-support">iPhoneのSafari向け。Androidは動作未保証です。アプリ内ブラウザではSafariで開いてください。</p>
  </section>;
}

function ARLaunch({ character, placement, pose }: { character: ARCharacter; placement: ARPlacement; pose: "Idle" | "Wave" }) {
  const [supported, setSupported] = useState(false);
  const [status, setStatus] = useState<"idle" | "working" | "ready" | "error">("idle");
  const [error, setError] = useState("");
  const [url, setUrl] = useState("");
  const resource = useRef<{ controller?: AbortController; url?: string }>({});
  useEffect(() => {
    setSupported(document.createElement("a").relList.supports?.("ar") ?? false);
    const current = resource.current;
    return () => { current.controller?.abort(); if (current.url) URL.revokeObjectURL(current.url); };
  }, []);
  const prepare = async () => {
    if (status === "working") return;
    const controller = new AbortController();
    resource.current.controller?.abort();
    resource.current.controller = controller;
    setStatus("working");
    setError("");
    try {
      const { createARAsset } = await import("./character-ar-export");
      controller.signal.throwIfAborted();
      const blob = await createARAsset(character, placement, pose, controller.signal);
      controller.signal.throwIfAborted();
      const next = URL.createObjectURL(blob);
      if (resource.current.url) URL.revokeObjectURL(resource.current.url);
      resource.current.url = next;
      setUrl(next);
      setStatus("ready");
    } catch (error) {
      if (controller.signal.aborted) return;
      setError(error instanceof Error ? error.message : "準備できませんでした。もう一度お試しください。");
      setStatus("error");
    }
  };
  return <div className="j-ar-launch">
    {status !== "ready" ? <button className="j-ar-primary" disabled={status === "working"} onClick={() => void prepare()}>{status === "working" ? <><span className="j-model-spinner" />ARを準備しています…</> : status === "error" ? <><RotateCcw size={18} />もう一度準備する</> : <><Camera size={18} />{arCharacters[character].name}と撮る準備をする</>}</button> : <>
      {supported ? <div className="j-ar-ready"><a rel="ar" download={`${character}-${placement}.usdz`} href={`${url}#allowsContentScaling=${placement === "selfie" ? "0" : "1"}`} aria-label={`${arCharacters[character].name}を${placement === "selfie" ? "自撮りAR" : "AR"}で開く`}><img src={`/site/characters/${character}.webp`} alt={`${arCharacters[character].name}のARを開く`} /></a><div><strong>準備できました。</strong><p>左のキャラをタップして<br />iPhoneのARカメラへ。</p><MoveUpRight size={18} /></div></div> : <p className="j-ar-hint">このブラウザではAppleのARを起動できません。iPhoneのSafariでこのページを開くか、ARファイルを保存してiPhoneへ転送してください。</p>}
      <a className="j-ar-download" href={url} download={`${character}-${placement}-${pose.toLowerCase()}.usdz`}><Download size={16} />ARファイルを保存</a>
    </>}
    <div role="status" aria-live="polite">{status === "working" && <p className="j-ar-hint">この端末で作成中です。初回は少し時間がかかります。</p>}{status === "error" && <p className="j-ar-error">{error}</p>}</div>
  </div>;
}
