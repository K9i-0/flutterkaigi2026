import {
  FaceLandmarker,
  FilesetResolver,
  type FaceLandmarkerResult,
  type NormalizedLandmark,
} from "@mediapipe/tasks-vision";
import { clamp } from "./math";
import { neutralPose } from "./pose";
import { blinkScoreToEyeOpen } from "./tracking-math";
import type { TrackingDiagnostics, TrackingPose } from "./types";

const WASM_PATH = `${import.meta.env.BASE_URL}mediapipe/wasm`;
const MODEL_PATH = `${import.meta.env.BASE_URL}models/face_landmarker.task`;

const pointDistance = (a: NormalizedLandmark, b: NormalizedLandmark): number =>
  Math.hypot(a.x - b.x, a.y - b.y);

const blendshapeMap = (result: FaceLandmarkerResult): Map<string, number> => {
  const categories = result.faceBlendshapes[0]?.categories ?? [];
  return new Map(categories.map((entry) => [entry.categoryName, entry.score]));
};

export const poseFromFaceResult = (result: FaceLandmarkerResult): TrackingPose => {
  const landmarks = result.faceLandmarks[0];
  if (!landmarks) return neutralPose();

  const leftEye = landmarks[33];
  const rightEye = landmarks[263];
  const nose = landmarks[1];
  const chin = landmarks[152];
  if (!leftEye || !rightEye || !nose || !chin) return neutralPose();

  const eyeDistance = Math.max(0.0001, pointDistance(leftEye, rightEye));
  const eyeMidX = (leftEye.x + rightEye.x) / 2;
  const eyeMidY = (leftEye.y + rightEye.y) / 2;
  const faceHeight = Math.max(0.0001, chin.y - eyeMidY);
  const shapes = blendshapeMap(result);
  const getShape = (name: string): number => shapes.get(name) ?? 0;

  return {
    yaw: clamp(((nose.x - eyeMidX) / eyeDistance) * 3.2),
    pitch: clamp((((nose.y - eyeMidY) / faceHeight) - 0.42) * 3.4),
    roll: clamp((Math.atan2(rightEye.y - leftEye.y, rightEye.x - leftEye.x) / Math.PI) * 5),
    faceX: clamp((0.5 - eyeMidX) * 3),
    faceY: clamp((0.42 - eyeMidY) * 3),
    eyeOpenL: blinkScoreToEyeOpen(getShape("eyeBlinkLeft")),
    eyeOpenR: blinkScoreToEyeOpen(getShape("eyeBlinkRight")),
    mouthOpen: clamp(getShape("jawOpen") * 1.35, 0, 1),
    smile: clamp((getShape("mouthSmileLeft") + getShape("mouthSmileRight")) / 2, 0, 1),
    presence: 1,
  };
};

export class WebcamFaceTracker {
  private landmarker: FaceLandmarker | null = null;
  private stream: MediaStream | null = null;
  private lastVideoTime = -1;
  private lastResult = neutralPose();
  private sampleCount = 0;
  private sampleWindowStarted = performance.now();
  private diagnostics: TrackingDiagnostics = {
    fps: 0,
    inferenceMs: 0,
    backend: "未初期化",
    hasFace: false,
  };

  async initialize(): Promise<void> {
    const vision = await FilesetResolver.forVisionTasks(WASM_PATH);
    try {
      this.landmarker = await FaceLandmarker.createFromOptions(vision, {
        baseOptions: { modelAssetPath: MODEL_PATH, delegate: "GPU" },
        runningMode: "VIDEO",
        numFaces: 1,
        outputFaceBlendshapes: true,
        outputFacialTransformationMatrixes: true,
      });
      this.diagnostics.backend = "MediaPipe GPU";
    } catch {
      this.landmarker = await FaceLandmarker.createFromOptions(vision, {
        baseOptions: { modelAssetPath: MODEL_PATH, delegate: "CPU" },
        runningMode: "VIDEO",
        numFaces: 1,
        outputFaceBlendshapes: true,
        outputFacialTransformationMatrixes: true,
      });
      this.diagnostics.backend = "MediaPipe CPU";
    }
  }

  async start(video: HTMLVideoElement): Promise<void> {
    if (!this.landmarker) await this.initialize();
    this.stream = await navigator.mediaDevices.getUserMedia({
      video: {
        width: { ideal: 1280 },
        height: { ideal: 720 },
        frameRate: { ideal: 30, max: 60 },
        facingMode: "user",
      },
      audio: false,
    });
    video.srcObject = this.stream;
    await video.play();
  }

  sample(video: HTMLVideoElement, timestampMs: number): TrackingPose {
    if (!this.landmarker || video.readyState < HTMLMediaElement.HAVE_CURRENT_DATA) {
      return this.lastResult;
    }
    if (video.currentTime === this.lastVideoTime) return this.lastResult;
    this.lastVideoTime = video.currentTime;

    const started = performance.now();
    const result = this.landmarker.detectForVideo(video, timestampMs);
    this.diagnostics.inferenceMs = performance.now() - started;
    this.diagnostics.hasFace = result.faceLandmarks.length > 0;
    this.lastResult = poseFromFaceResult(result);

    this.sampleCount += 1;
    const elapsed = timestampMs - this.sampleWindowStarted;
    if (elapsed >= 1000) {
      this.diagnostics.fps = (this.sampleCount * 1000) / elapsed;
      this.sampleCount = 0;
      this.sampleWindowStarted = timestampMs;
    }
    return this.lastResult;
  }

  stop(video?: HTMLVideoElement): void {
    this.stream?.getTracks().forEach((track) => track.stop());
    this.stream = null;
    if (video) video.srcObject = null;
    this.diagnostics.hasFace = false;
  }

  getDiagnostics(): TrackingDiagnostics {
    return { ...this.diagnostics };
  }

  destroy(video?: HTMLVideoElement): void {
    this.stop(video);
    this.landmarker?.close();
    this.landmarker = null;
  }
}
