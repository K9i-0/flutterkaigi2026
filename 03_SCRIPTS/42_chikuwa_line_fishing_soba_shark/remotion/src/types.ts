export type FrameRange = {
  startFrame: number;
  endFrame: number;
};

export type StationBug = FrameRange & {
  type: 'station-bug';
  text?: string;
  image?: string;
  position?: 'top-left' | 'top-right';
  variant?: 'plain' | 'brand' | 'clock';
};

export type NewsLowerThird = FrameRange & {
  type: 'news-lower-third';
  kicker: string;
  headline: string;
  subheadline?: string;
  accentColor?: string;
  placement?: 'top-left' | 'bottom-left' | 'bottom';
  variant?: 'compact' | 'full';
  widthPercent?: number;
};

export type Ticker = FrameRange & {
  type: 'ticker';
  label: string;
  text: string;
  accentColor?: string;
};

export type VarietyPopup = FrameRange & {
  type: 'variety-popup';
  image: string;
  top?: number | string;
  bottom?: number | string;
  left?: number | string;
  width?: number | string;
  rotateDeg?: number;
};

export type Overlay = StationBug | NewsLowerThird | Ticker | VarietyPopup;

export type Caption = FrameRange & {
  text: string;
  speaker?: string;
  color?: string;
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
  overlays: Overlay[];
  captions: Caption[];
};
