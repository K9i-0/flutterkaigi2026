import { clamp, lerp, smoothingFactor } from "./math.js";
import type { CheersMotion, TrackingPose } from "./types.js";

export const neutralPose = (): TrackingPose => ({
  yaw: 0,
  pitch: 0,
  roll: 0,
  faceX: 0,
  faceY: 0,
  eyeOpenL: 1,
  eyeOpenR: 1,
  mouthOpen: 0,
  smile: 0,
  presence: 0,
});

export const sanitizePose = (pose: TrackingPose): TrackingPose => ({
  yaw: clamp(pose.yaw),
  pitch: clamp(pose.pitch),
  roll: clamp(pose.roll),
  faceX: clamp(pose.faceX),
  faceY: clamp(pose.faceY),
  eyeOpenL: clamp(pose.eyeOpenL, 0, 1),
  eyeOpenR: clamp(pose.eyeOpenR, 0, 1),
  mouthOpen: clamp(pose.mouthOpen, 0, 1),
  smile: clamp(pose.smile, 0, 1),
  presence: clamp(pose.presence, 0, 1),
});

export class PoseSmoother {
  private current = neutralPose();

  constructor(private readonly halfLifeMs: number) {}

  reset(pose = neutralPose()): TrackingPose {
    this.current = sanitizePose(pose);
    return this.current;
  }

  update(target: TrackingPose, deltaMs: number): TrackingPose {
    const safeTarget = sanitizePose(target);
    const amount = smoothingFactor(deltaMs, this.halfLifeMs);
    const result = {} as TrackingPose;
    for (const key of Object.keys(this.current) as Array<keyof TrackingPose>) {
      result[key] = lerp(this.current[key], safeTarget[key], amount);
    }
    this.current = sanitizePose(result);
    return this.current;
  }
}

export class PoseCalibrator {
  private offset = neutralPose();

  calibrate(pose: TrackingPose): void {
    this.offset = {
      ...neutralPose(),
      yaw: pose.yaw,
      pitch: pose.pitch,
      roll: pose.roll,
      faceX: pose.faceX,
      faceY: pose.faceY,
    };
  }

  apply(pose: TrackingPose): TrackingPose {
    return sanitizePose({
      ...pose,
      yaw: pose.yaw - this.offset.yaw,
      pitch: pose.pitch - this.offset.pitch,
      roll: pose.roll - this.offset.roll,
      faceX: pose.faceX - this.offset.faceX,
      faceY: pose.faceY - this.offset.faceY,
    });
  }
}

export const demoPoseAt = (seconds: number): TrackingPose => {
  const blinkPhase = seconds % 4.2;
  const eyeOpen = blinkPhase > 3.98 ? Math.abs(blinkPhase - 4.09) / 0.11 : 1;
  return sanitizePose({
    yaw: Math.sin(seconds * 0.72) * 0.72,
    pitch: Math.sin(seconds * 0.47 + 0.8) * 0.45,
    roll: Math.sin(seconds * 0.58) * 0.55,
    faceX: Math.sin(seconds * 0.33) * 0.35,
    faceY: Math.sin(seconds * 0.41 + 1.3) * 0.2,
    eyeOpenL: eyeOpen,
    eyeOpenR: eyeOpen,
    mouthOpen: Math.max(0, Math.sin(seconds * 5.2)) * 0.75,
    smile: 0.12,
    presence: 1,
  });
};

const smoothStep = (value: number): number => {
  const safe = clamp(value, 0, 1);
  return safe * safe * (3 - 2 * safe);
};

export const idleCheersMotion = (): CheersMotion => ({
  active: false,
  lift: 0,
  clink: 0,
});

export const cheersMotionAt = (elapsedMs: number): CheersMotion => {
  const durationMs = 2000;
  if (elapsedMs < 0 || elapsedMs >= durationMs) return idleCheersMotion();

  const time = elapsedMs / durationMs;
  const rise = smoothStep(time / 0.24);
  const fall = 1 - smoothStep((time - 0.68) / 0.32);
  const lift = Math.min(rise, fall);
  const clinkWindow = clamp(1 - Math.abs(time - 0.43) / 0.14, 0, 1);
  const clink = Math.sin((time - 0.34) * Math.PI * 12) * clinkWindow;
  return { active: true, lift, clink };
};
