import {Video} from '@remotion/media';
import {
  AbsoluteFill,
  Sequence,
  interpolate,
  staticFile,
  useCurrentFrame,
} from 'remotion';
import type {EditManifest, TimelineClip} from './types';

const fadeLevel = (frame: number, clip: TimelineClip) => {
  let level = 1;

  if (clip.fadeInFrames > 0) {
    level *= interpolate(frame, [0, clip.fadeInFrames - 1], [0, 1], {
      extrapolateLeft: 'clamp',
      extrapolateRight: 'clamp',
    });
  }

  if (clip.fadeOutFrames > 0) {
    level *= interpolate(
      frame,
      [clip.durationInFrames - clip.fadeOutFrames, clip.durationInFrames - 1],
      [1, 0],
      {
        extrapolateLeft: 'clamp',
        extrapolateRight: 'clamp',
      },
    );
  }

  return level;
};

const TimelineVideo: React.FC<{clip: TimelineClip}> = ({clip}) => {
  const frame = useCurrentFrame();
  const visualOpacity =
    clip.fadeInFrames > 0
      ? interpolate(frame, [0, clip.fadeInFrames - 1], [0, 1], {
          extrapolateLeft: 'clamp',
          extrapolateRight: 'clamp',
        })
      : 1;

  return (
    <AbsoluteFill style={{opacity: visualOpacity}}>
      <Video
        src={staticFile(clip.src)}
        trimBefore={clip.trimBeforeFrames}
        trimAfter={clip.trimBeforeFrames + clip.durationInFrames}
        volume={(mediaFrame) => fadeLevel(mediaFrame, clip) * clip.volume}
        objectFit="cover"
        style={{width: '100%', height: '100%'}}
      />
    </AbsoluteFill>
  );
};

export const EditComposition: React.FC<{manifest: EditManifest}> = ({manifest}) => {
  return (
    <AbsoluteFill style={{backgroundColor: '#eeeae3'}}>
      {manifest.clips.map((clip) => (
        <Sequence
          key={clip.id}
          from={clip.startFrame}
          durationInFrames={clip.durationInFrames}
          premountFor={15}
        >
          <TimelineVideo clip={clip} />
        </Sequence>
      ))}
    </AbsoluteFill>
  );
};
