import "./style.css";
import rigConfigJson from "./sobaya.rig.json";
import {
  PoseCalibrator,
  PoseSmoother,
  cheersMotionAt,
  demoPoseAt,
  idleCheersMotion,
  neutralPose,
} from "./pose";
import { SobayaPuppet } from "./puppet";
import { WebcamFaceTracker } from "./tracker";
import type { BackgroundMode, RigConfig, TrackingPose } from "./types";

const rigConfig = rigConfigJson as RigConfig;
const appElement = document.querySelector<HTMLDivElement>("#app");
if (!appElement) throw new Error("Missing #app mount");

appElement.innerHTML = `
  <main class="app-shell">
    <section class="stage-panel" aria-label="そば屋VTuberプレビュー">
      <div id="puppet-stage" class="puppet-stage" data-background="studio">
        <div class="stage-vignette"></div>
        <div class="stage-status">
          <span id="status-dot" class="status-dot"></span>
          <span id="status-text">準備中</span>
        </div>
        <div class="stage-brand">SOBA-YA / WEB RIG</div>
      </div>
    </section>

    <aside class="control-panel">
      <header class="brand-block">
        <div class="brand-mark">蕎</div>
        <div>
          <p class="eyebrow">OPEN WEB PUPPET</p>
          <h1>そば屋 VTuber</h1>
          <p>MediaPipe × PixiJS</p>
        </div>
      </header>

      <section class="control-section primary-controls">
        <button id="camera-button" class="button button-primary">カメラを開始</button>
        <button id="demo-button" class="button">デモを開始</button>
        <button id="cheers-button" class="button cheers-button" disabled>🍻 乾杯！</button>
      </section>

      <section class="control-section">
        <div class="section-heading">
          <h2>トラッキング</h2>
          <button id="calibrate-button" class="text-button" disabled>ニュートラルを記録</button>
        </div>
        <div class="camera-preview-wrap">
          <video id="camera-preview" autoplay muted playsinline></video>
          <div id="camera-placeholder">カメラ停止中</div>
        </div>
        <dl class="diagnostics">
          <div><dt>状態</dt><dd id="diag-face">待機</dd></div>
          <div><dt>FPS</dt><dd id="diag-fps">—</dd></div>
          <div><dt>推論</dt><dd id="diag-time">—</dd></div>
          <div><dt>処理</dt><dd id="diag-backend">—</dd></div>
        </dl>
      </section>

      <section class="control-section">
        <div class="section-heading"><h2>表示</h2></div>
        <label class="field-label" for="background-select">背景</label>
        <select id="background-select">
          <option value="studio">スタジオ</option>
          <option value="transparent">透過</option>
          <option value="green">グリーンバック</option>
          <option value="magenta">マゼンタバック</option>
        </select>
        <label class="toggle-row">
          <input id="mirror-toggle" type="checkbox" checked />
          <span>カメラプレビューを左右反転</span>
        </label>
      </section>

      <footer>
        映像フレームはブラウザ内で処理されます。<br />
        <code>src/sobaya.rig.json</code>で可動域を調整できます。
      </footer>
    </aside>
  </main>
`;

const stage = document.querySelector<HTMLElement>("#puppet-stage")!;
const video = document.querySelector<HTMLVideoElement>("#camera-preview")!;
const cameraButton = document.querySelector<HTMLButtonElement>("#camera-button")!;
const demoButton = document.querySelector<HTMLButtonElement>("#demo-button")!;
const cheersButton = document.querySelector<HTMLButtonElement>("#cheers-button")!;
const calibrateButton = document.querySelector<HTMLButtonElement>("#calibrate-button")!;
const backgroundSelect = document.querySelector<HTMLSelectElement>("#background-select")!;
const mirrorToggle = document.querySelector<HTMLInputElement>("#mirror-toggle")!;
const cameraPlaceholder = document.querySelector<HTMLElement>("#camera-placeholder")!;
const statusDot = document.querySelector<HTMLElement>("#status-dot")!;
const statusText = document.querySelector<HTMLElement>("#status-text")!;
const diagFace = document.querySelector<HTMLElement>("#diag-face")!;
const diagFps = document.querySelector<HTMLElement>("#diag-fps")!;
const diagTime = document.querySelector<HTMLElement>("#diag-time")!;
const diagBackend = document.querySelector<HTMLElement>("#diag-backend")!;

const puppet = new SobayaPuppet(stage, rigConfig);
const tracker = new WebcamFaceTracker();
const smoother = new PoseSmoother(rigConfig.motion.smoothingHalfLifeMs);
const calibrator = new PoseCalibrator();

type Mode = "idle" | "camera" | "demo";
let mode: Mode = "idle";
let latestPose: TrackingPose = neutralPose();
let lastFrame = performance.now();
let demoStartedAt = lastFrame;
let diagnosticsUpdatedAt = 0;
let animationFrameId = 0;
let shuttingDown = false;
let cheersStartedAt: number | null = null;
let puppetReady = false;

const setStatus = (label: string, active = false, error = false): void => {
  statusText.textContent = label;
  statusDot.classList.toggle("is-active", active);
  statusDot.classList.toggle("is-error", error);
};

const updateDiagnostics = (): void => {
  if (mode === "demo") {
    diagFace.textContent = "デモ入力";
    diagFps.textContent = "60";
    diagTime.textContent = "—";
    diagBackend.textContent = "合成モーション";
    return;
  }
  const diagnostics = tracker.getDiagnostics();
  diagFace.textContent = diagnostics.hasFace ? "顔を検出" : mode === "camera" ? "探索中" : "待機";
  diagFps.textContent = diagnostics.fps > 0 ? diagnostics.fps.toFixed(1) : "—";
  diagTime.textContent = diagnostics.inferenceMs > 0 ? `${diagnostics.inferenceMs.toFixed(1)} ms` : "—";
  diagBackend.textContent = diagnostics.backend;
};

const stopCamera = (): void => {
  tracker.stop(video);
  cameraPlaceholder.hidden = false;
  cameraButton.textContent = "カメラを開始";
  calibrateButton.disabled = true;
};

cameraButton.addEventListener("click", async () => {
  if (mode === "camera") {
    stopCamera();
    mode = "idle";
    latestPose = smoother.reset();
    setStatus("待機中");
    return;
  }

  if (mode === "demo") {
    mode = "idle";
    demoButton.textContent = "デモを開始";
  }

  cameraButton.disabled = true;
  setStatus("カメラを準備中…");
  try {
    await tracker.start(video);
    mode = "camera";
    smoother.reset();
    cameraPlaceholder.hidden = true;
    cameraButton.textContent = "カメラを停止";
    calibrateButton.disabled = false;
    setStatus("顔を探索中", true);
  } catch (error) {
    console.error(error);
    setStatus("カメラを開始できません", false, true);
    diagFace.textContent = "権限または初期化エラー";
  } finally {
    cameraButton.disabled = false;
  }
});

demoButton.addEventListener("click", () => {
  if (mode === "camera") stopCamera();
  if (mode === "demo") {
    mode = "idle";
    demoButton.textContent = "デモを開始";
    latestPose = smoother.reset();
    setStatus("待機中");
    return;
  }
  mode = "demo";
  demoStartedAt = performance.now();
  smoother.reset();
  demoButton.textContent = "デモを停止";
  setStatus("デモ動作中", true);
});

const restoreModeStatus = (): void => {
  if (mode === "camera") setStatus("トラッキング中", true);
  else if (mode === "demo") setStatus("デモ動作中", true);
  else setStatus("待機中");
};

const startCheers = (): void => {
  if (!puppetReady || cheersStartedAt !== null) return;
  cheersStartedAt = performance.now();
  cheersButton.disabled = true;
  setStatus("乾杯！", true);
};

cheersButton.addEventListener("click", startCheers);
window.addEventListener("keydown", (event) => {
  const target = event.target as HTMLElement | null;
  if (target?.matches("input, select, button, textarea")) return;
  if (event.key.toLowerCase() === "c") startCheers();
});

calibrateButton.addEventListener("click", () => {
  calibrator.calibrate(latestPose);
  setStatus("ニュートラルを記録しました", true);
  window.setTimeout(() => mode === "camera" && setStatus("トラッキング中", true), 1100);
});

backgroundSelect.addEventListener("change", () => {
  puppet.setBackground(backgroundSelect.value as BackgroundMode);
});

mirrorToggle.addEventListener("change", () => {
  video.classList.toggle("is-mirrored", mirrorToggle.checked);
});
video.classList.add("is-mirrored");

const animate = (timestamp: number): void => {
  if (shuttingDown) return;
  const deltaMs = Math.min(80, timestamp - lastFrame);
  lastFrame = timestamp;

  let target = neutralPose();
  if (mode === "camera") {
    target = calibrator.apply(tracker.sample(video, timestamp));
    if (target.presence > 0.5) setStatus("トラッキング中", true);
  } else if (mode === "demo") {
    target = demoPoseAt((timestamp - demoStartedAt) / 1000);
  }

  latestPose = smoother.update(target, deltaMs);
  const cheers = cheersStartedAt === null
    ? idleCheersMotion()
    : cheersMotionAt(timestamp - cheersStartedAt);
  puppet.applyPose(latestPose, deltaMs, cheers);
  if (cheersStartedAt !== null && !cheers.active) {
    cheersStartedAt = null;
    cheersButton.disabled = false;
    restoreModeStatus();
  }

  if (timestamp - diagnosticsUpdatedAt > 250) {
    diagnosticsUpdatedAt = timestamp;
    updateDiagnostics();
  }
  animationFrameId = requestAnimationFrame(animate);
};

const start = async (): Promise<void> => {
  try {
    await puppet.initialize();
    puppet.setBackground("studio");
    puppetReady = true;
    cheersButton.disabled = false;
    setStatus("待機中");
    animationFrameId = requestAnimationFrame(animate);
  } catch (error) {
    console.error(error);
    setStatus("モデルの読み込みに失敗", false, true);
  }
};

window.addEventListener("beforeunload", () => {
  shuttingDown = true;
  cancelAnimationFrame(animationFrameId);
  tracker.destroy(video);
  puppet.destroy();
});

void start();
