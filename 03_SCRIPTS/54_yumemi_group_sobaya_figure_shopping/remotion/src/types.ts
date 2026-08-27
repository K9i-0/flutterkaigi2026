export type FrameRange = {
  startFrame: number;
  endFrame: number;
};

export type Caption = FrameRange & {
  speaker: '福ちゃん' | 'そば屋';
  text: string;
  emphasis?: string;
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
  replacementAudio: string;
  brand: {
    name: string;
    cornerLabel: string;
  };
  product: {
    name: string;
    claims: string[];
    height: string;
    weight: string;
    regularPrice: string;
    todayPrice: string;
    stock: string;
    matchRate: string;
    disclaimer: string;
    presidentTitle: string;
  };
  cues: Record<string, FrameRange>;
  captions: Caption[];
};
