export type FrameRange = {
  startFrame: number;
  endFrame: number;
};

export type MemberId =
  | 'okayaman'
  | 'sobaya'
  | 'fukuchan'
  | 'takosan'
  | 'yotan';

export type ViewerId =
  | MemberId
  | 'viewer_shoken'
  | 'viewer_madobe_cat'
  | 'viewer_teiji_dash';

export type ViewerComment = FrameRange & {
  author: ViewerId;
  displayName: string;
  avatar: string;
  avatarPosition?: string;
  text: string;
  tone?: 'normal' | 'hot';
  featured?: boolean;
  kind?: 'comment' | 'superchat';
  amount?: string;
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
  stream: {
    title: string;
    tag: string;
    liveLabel: string;
    viewerCount: string;
    channelName: string;
    handle: string;
  };
  comments: ViewerComment[];
};
