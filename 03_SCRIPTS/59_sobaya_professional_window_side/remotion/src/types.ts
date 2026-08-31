export type FrameRange = {
  startFrame: number;
  endFrame: number;
};

export type VideoSegment = FrameRange & {
  kind: 'video';
  sourceStartFrame: number;
};

export type QuestionCard = FrameRange & {
  text: string;
};

export type Caption = FrameRange & {
  text: string;
};

export type IrodoriAudioClip = FrameRange & {
  src: string;
  volume: number;
};

export type AmbientBed = {
  src: string;
  volume: number;
};

export type OpeningTitle = FrameRange & {
  eyebrow: string;
  title: string;
  subtitle: string;
};

export type LowerThird = FrameRange & {
  company: string;
  role: string;
  name: string;
};

export type Outro = FrameRange & {
  brand: string;
  title: string;
  subtitle: string;
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
  sourceDurationInFrames: number;
  inputVideoVolume: number;
  replacementAudio: string | null;
  ambientBed: AmbientBed;
  irodoriAudio: IrodoriAudioClip[];
  timeline: VideoSegment[];
  questionCards: QuestionCard[];
  openingTitle: OpeningTitle;
  lowerThird: LowerThird;
  outro: Outro;
  captions: Caption[];
  irodoriCaptions: Caption[];
};

export type AudioMode = 'wan' | 'irodori';
