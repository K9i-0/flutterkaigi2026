export type FrameRange = {
  startFrame: number;
  endFrame: number;
};

export type TimelineClip = {
  id: string;
  src: string;
  startFrame: number;
  durationInFrames: number;
  trimBeforeFrames: number;
  fadeInFrames: number;
  fadeOutFrames: number;
  volume: number;
};

export type EditManifest = {
  composition: {
    id: string;
    width: number;
    height: number;
    fps: number;
    durationInFrames: number;
  };
  inputVideo: string;
  inputVideoVolume: number;
  replacementAudio: string | null;
  overlays: [];
  captions: [];
  clips: TimelineClip[];
};
