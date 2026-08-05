export type LayerId =
  | "body"
  | "head"
  | "eyeLidL"
  | "eyeLidR"
  | "mouth"
  | "mug";

export interface RigLayerConfig {
  id: LayerId;
  asset: string;
  parent: "root" | "head" | "mouth";
  pivot: [number, number];
  zIndex: number;
}

export interface RigConfig {
  id: string;
  displayName: string;
  canvas: { width: number; height: number };
  viewport: { fit: number; verticalOffset: number };
  layers: RigLayerConfig[];
  motion: {
    headYawPixels: number;
    headPitchPixels: number;
    headRollDegrees: number;
    bodySwayPixels: number;
    bodyRollDegrees: number;
    mouthOpenScale: number;
    mugBouncePixels: number;
    breathingScale: number;
    smoothingHalfLifeMs: number;
    cheersLiftPixels: number;
    cheersCenterPixels: number;
    cheersScale: number;
    cheersTiltDegrees: number;
  };
}

export interface TrackingPose {
  yaw: number;
  pitch: number;
  roll: number;
  faceX: number;
  faceY: number;
  eyeOpenL: number;
  eyeOpenR: number;
  mouthOpen: number;
  smile: number;
  presence: number;
}

export interface CheersMotion {
  active: boolean;
  lift: number;
  clink: number;
}

export type BackgroundMode = "studio" | "transparent" | "green" | "magenta";

export interface TrackingDiagnostics {
  fps: number;
  inferenceMs: number;
  backend: string;
  hasFace: boolean;
}
