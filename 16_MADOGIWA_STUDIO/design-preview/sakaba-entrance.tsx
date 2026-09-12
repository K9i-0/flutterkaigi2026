import { useEffect, useRef, useState } from "react";
import type { LanternScene } from "./lantern-scene";
import "./sakaba-entrance.css";
import { LANTERN_LINES } from "./lantern-label";

export function Noren() {
  return (
    <div className="s-noren" aria-hidden="true">
      <div className="s-noren-rod" />
      <div className="s-noren-cloths">
        {[0, 1, 2, 3, 4].map((index) => <div className="s-noren-panel" key={index}><i /></div>)}
      </div>
      <div className="s-noren-light" />
    </div>
  );
}

export function SobayaLantern({ lit, onToggle }: { lit: boolean; onToggle: () => void }) {
  const host = useRef<HTMLSpanElement>(null);
  const scene = useRef<LanternScene | null>(null);
  const currentLit = useRef(lit);
  const [ready, setReady] = useState(false);
  useEffect(() => {
    currentLit.current = lit;
    scene.current?.setLit(lit);
  }, [lit]);
  useEffect(() => {
    const target = host.current;
    if (!target || new URLSearchParams(location.search).get("lantern") === "static") return;
    let cancelled = false;
    void import("./lantern-scene")
      .then(({ createLanternScene }) => cancelled ? null : createLanternScene(target, currentLit.current, () => setReady(false)))
      .then((instance) => {
        if (cancelled) { instance?.dispose(); return; }
        scene.current = instance;
        instance?.setLit(currentLit.current);
        setReady(!!instance);
      }).catch(() => { if (!cancelled) setReady(false); });
    return () => {
      cancelled = true;
      scene.current?.dispose();
      scene.current = null;
    };
  }, []);
  return (
    <button className="s-lantern" type="button" onClick={onToggle}
      aria-label={lit ? "赤提灯を消す" : "赤提灯を灯す"}
      aria-pressed={lit} title={lit ? "提灯を消す" : "提灯を灯す"}
      data-lit={lit} data-renderer={ready ? "webgl" : "static"}>
      <span className="s-lantern-halo" aria-hidden="true" />
      <span className="s-lantern-fallback" aria-hidden="true">
        <span className="s-lantern-wire" />
        <span className="s-lantern-cap s-lantern-cap-top" />
        <span className="s-lantern-paper"><span className="s-lantern-lettering">{LANTERN_LINES.map((line) => <span key={line}>{line}</span>)}</span></span>
        <span className="s-lantern-cap s-lantern-cap-bottom" />
      </span>
      <span className="s-lantern-canvas" ref={host} aria-hidden="true" />
    </button>
  );
}
