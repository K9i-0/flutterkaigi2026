export type FrameRange = {
  startFrame: number;
  endFrame: number;
};

export type LiveSegment = FrameRange & {
  viewerCount: string;
  logoVariant: 'black' | 'white';
};

export type ChatComment = FrameRange & {
  text: string;
  author?: 'okayaman';
  tone?: 'normal' | 'hot' | 'danger';
};

export type Caption = FrameRange & {
  speaker: 'やめ太郎' | 'そば屋' | '福ちゃん';
  text: string;
};

export type VideoInsert = FrameRange & {
  path: string;
  sourceStartFrame: number;
  playbackRate?: number;
  lensCover?: {
    startFrame: number;
    endFrame: number;
    scale: number;
    origin: string;
  };
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
  replacementVideo: {
    path: string;
    startFrame: number;
    sourceCutFrame: number;
  };
  videoInserts: VideoInsert[];
  platform: {
    name: string;
    logoBlack: string;
    logoWhite: string;
  };
  channel: {
    name: string;
    handle: string;
  };
  liveSegments: LiveSegment[];
  comments: ChatComment[];
  confidential: FrameRange & {
    text: string;
  };
  overlays: [];
  captions: Caption[];
};
