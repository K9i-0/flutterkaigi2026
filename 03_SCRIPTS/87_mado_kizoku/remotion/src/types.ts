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

export type Overlay = StationBug | NewsLowerThird | Ticker;

export type Caption = FrameRange & {
  text: string;
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
