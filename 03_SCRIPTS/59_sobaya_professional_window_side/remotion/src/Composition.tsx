import {Video} from '@remotion/media';
import {
  AbsoluteFill,
  Html5Audio,
  Sequence,
  interpolate,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';
import type {
  AudioMode,
  Caption,
  EditManifest,
  IrodoriAudioClip,
  LowerThird as LowerThirdType,
  OpeningTitle as OpeningTitleType,
  Outro as OutroType,
  QuestionCard as QuestionCardType,
  VideoSegment as VideoSegmentType,
} from './types';

const mincho =
  '"Hiragino Mincho ProN", "Yu Mincho", "Noto Serif JP", serif';
const gothic =
  '"Hiragino Sans", "Yu Gothic", "Noto Sans JP", system-ui, sans-serif';

const BroadcastBug: React.FC = () => (
  <div
    style={{
      position: 'absolute',
      right: 22,
      top: 17,
      display: 'flex',
      alignItems: 'center',
      height: 28,
      padding: '1px 9px 0',
      border: '1px solid rgba(255,255,255,0.78)',
      background: 'rgba(0,0,0,0.25)',
      color: '#fff',
      fontFamily: gothic,
      fontSize: 16,
      fontWeight: 600,
      letterSpacing: '0.14em',
      textShadow: '0 1px 4px rgba(0,0,0,0.85)',
      fontSynthesis: 'none',
    }}
  >
    YHK
  </div>
);

const VideoSegment: React.FC<{
  segment: VideoSegmentType;
  manifest: EditManifest;
  audioMode: AudioMode;
}> = ({segment, manifest, audioMode}) => {
  const duration = segment.endFrame - segment.startFrame;
  const originalAudioEnabled =
    manifest.replacementAudio === null &&
    (audioMode === 'wan' || segment.startFrame === 0);
  const sourceVolume = (frame: number) => {
    if (!originalAudioEnabled) {
      return 0;
    }
    if (audioMode === 'irodori' && segment.startFrame === 0) {
      return (
        manifest.inputVideoVolume *
        interpolate(frame, [0, 4, duration - 8, duration], [0, 1, 1, 0], {
          extrapolateLeft: 'clamp',
          extrapolateRight: 'clamp',
        })
      );
    }
    return manifest.inputVideoVolume;
  };
  return (
    <AbsoluteFill>
      <Video
        src={staticFile(manifest.inputVideo)}
        trimBefore={segment.sourceStartFrame}
        trimAfter={segment.sourceStartFrame + duration}
        muted={!originalAudioEnabled}
        volume={sourceVolume}
        objectFit="cover"
        style={{width: '100%', height: '100%'}}
      />
      <BroadcastBug />
    </AbsoluteFill>
  );
};

const IrodoriVoice: React.FC<{clip: IrodoriAudioClip}> = ({clip}) => {
  const frame = useCurrentFrame();
  const duration = clip.endFrame - clip.startFrame;
  const fadeFrames = Math.min(3, Math.floor(duration / 4));
  const envelope = interpolate(
    frame,
    [0, fadeFrames, Math.max(fadeFrames, duration - fadeFrames), duration],
    [0, 1, 1, 0],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
  );
  return (
    <Html5Audio src={staticFile(clip.src)} volume={clip.volume * envelope} />
  );
};

const QuestionCard: React.FC<{card: QuestionCardType}> = ({card}) => {
  const frame = useCurrentFrame();
  const duration = card.endFrame - card.startFrame;
  const opacity = interpolate(
    frame,
    [0, 5, Math.max(5, duration - 5), duration],
    [0, 1, 1, 0],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
  );
  return (
    <AbsoluteFill
      style={{
        backgroundColor: '#000',
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      <div
        style={{
          opacity,
          color: '#f5f5f3',
          fontFamily: mincho,
          fontSize: 27,
          fontWeight: 400,
          letterSpacing: '0.075em',
          fontSynthesis: 'none',
          WebkitFontSmoothing: 'antialiased',
          textRendering: 'geometricPrecision',
        }}
      >
        {card.text}
      </div>
    </AbsoluteFill>
  );
};

const OpeningTitle: React.FC<{title: OpeningTitleType}> = ({title}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const enter = spring({
    frame,
    fps,
    config: {damping: 24, stiffness: 80, mass: 1.1},
    durationInFrames: 34,
  });
  const duration = title.endFrame - title.startFrame;
  const opacity = interpolate(
    frame,
    [0, 8, Math.max(8, duration - 10), duration],
    [0, 1, 1, 0],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
  );
  return (
    <AbsoluteFill
      style={{
        opacity,
        justifyContent: 'flex-end',
        padding: '0 0 44px 42px',
        background:
          'linear-gradient(180deg, transparent 40%, rgba(0,0,0,0.08) 58%, rgba(0,0,0,0.76) 100%)',
      }}
    >
      <div
        style={{
          transform: `translateY(${interpolate(enter, [0, 1], [14, 0])}px)`,
          color: '#fff',
          textShadow: '0 2px 12px rgba(0,0,0,0.72)',
          fontSynthesis: 'none',
        }}
      >
        <div
          style={{
            marginBottom: 8,
            fontFamily: gothic,
            fontSize: 10,
            fontWeight: 500,
            letterSpacing: '0.24em',
            opacity: 0.92,
          }}
        >
          {title.eyebrow}
        </div>
        <div
          style={{
            fontFamily: mincho,
            fontSize: 34,
            lineHeight: 1,
            fontWeight: 400,
            letterSpacing: '0.055em',
          }}
        >
          {title.title}
        </div>
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 11,
            marginTop: 9,
            fontFamily: mincho,
            fontSize: 21,
            fontWeight: 400,
            letterSpacing: '0.22em',
          }}
        >
          <span style={{width: 28, height: 2, background: '#9c1c24'}} />
          {title.subtitle}
        </div>
      </div>
    </AbsoluteFill>
  );
};

const LowerThird: React.FC<{lowerThird: LowerThirdType}> = ({lowerThird}) => {
  const frame = useCurrentFrame();
  const opacity = interpolate(frame, [0, 7, 225, 240], [0, 1, 1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const x = interpolate(frame, [0, 9], [-12, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  return (
    <div
      style={{
        position: 'absolute',
        left: 18,
        bottom: 66,
        width: 332,
        minHeight: 98,
        padding: '11px 16px 10px 18px',
        background: 'rgba(0,0,0,0.97)',
        borderLeft: '3px solid #a62028',
        color: '#fff',
        fontFamily: gothic,
        fontSynthesis: 'none',
        boxShadow: '0 4px 15px rgba(0,0,0,0.35)',
      }}
    >
      <div
        style={{
          opacity,
          transform: `translateX(${x}px)`,
        }}
      >
        <div style={{fontSize: 13, lineHeight: 1.2, fontWeight: 500}}>
          {lowerThird.company}
        </div>
        <div
          style={{
            marginTop: 4,
            fontSize: 13,
            lineHeight: 1.2,
            fontWeight: 400,
            opacity: 0.88,
          }}
        >
          {lowerThird.role}
        </div>
        <div
          style={{
            marginTop: 6,
            fontFamily: mincho,
            fontSize: 24,
            lineHeight: 1,
            fontWeight: 400,
            letterSpacing: '0.12em',
          }}
        >
          {lowerThird.name}
        </div>
      </div>
    </div>
  );
};

const CaptionLayer: React.FC<{caption: Caption}> = ({caption}) => {
  const frame = useCurrentFrame();
  const duration = caption.endFrame - caption.startFrame;
  const opacity = interpolate(
    frame,
    [0, 4, Math.max(4, duration - 4), duration],
    [0, 1, 1, 0],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
  );
  return (
    <div
      style={{
        position: 'absolute',
        left: 0,
        right: 0,
        bottom: 0,
        minHeight: 64,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '6px 42px 7px',
        background:
          'linear-gradient(90deg, rgba(0,0,0,0.97), rgba(0,0,0,0.89) 50%, rgba(0,0,0,0.97))',
        color: '#fff',
        textAlign: 'center',
        whiteSpace: 'pre-line',
        fontFamily: gothic,
        fontSize: 22,
        fontWeight: 500,
        letterSpacing: '0.025em',
        lineHeight: 1.24,
        fontSynthesis: 'none',
        WebkitFontSmoothing: 'antialiased',
        textRendering: 'geometricPrecision',
      }}
    >
      <span style={{opacity}}>{caption.text}</span>
    </div>
  );
};

const Outro: React.FC<{outro: OutroType}> = ({outro}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const duration = outro.endFrame - outro.startFrame;
  const enter = spring({
    frame,
    fps,
    config: {damping: 22, stiffness: 70, mass: 1.2},
    durationInFrames: 40,
  });
  const fade = interpolate(frame, [0, 12, duration - 18, duration], [0, 1, 1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  return (
    <AbsoluteFill
      style={{
        background: 'radial-gradient(circle at 50% 45%, #151515 0%, #050505 52%, #000 100%)',
        alignItems: 'center',
        justifyContent: 'center',
        color: '#fff',
        opacity: fade,
        fontSynthesis: 'none',
      }}
    >
      <div
        style={{
          position: 'absolute',
          right: 28,
          top: 22,
          fontFamily: gothic,
          fontSize: 17,
          fontWeight: 600,
          letterSpacing: '0.16em',
        }}
      >
        {outro.brand}
      </div>
      <div
        style={{
          transform: `scale(${interpolate(enter, [0, 1], [0.975, 1])})`,
          textAlign: 'center',
          textShadow: '0 2px 16px rgba(0,0,0,0.85)',
        }}
      >
        <div
          style={{
            fontFamily: mincho,
            fontSize: 42,
            fontWeight: 400,
            letterSpacing: '0.06em',
          }}
        >
          {outro.title}
        </div>
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: 16,
            marginTop: 16,
            fontFamily: mincho,
            fontSize: 24,
            fontWeight: 400,
            letterSpacing: '0.24em',
          }}
        >
          <span style={{width: 43, height: 2, background: '#9c1c24'}} />
          {outro.subtitle}
          <span style={{width: 43, height: 2, background: '#9c1c24'}} />
        </div>
      </div>
    </AbsoluteFill>
  );
};

export const EditComposition: React.FC<{
  manifest: EditManifest;
  audioMode: AudioMode;
}> = ({manifest, audioMode}) => {
  const activeCaptions =
    audioMode === 'irodori' ? manifest.irodoriCaptions : manifest.captions;
  return (
    <AbsoluteFill style={{backgroundColor: '#000'}}>
      {manifest.timeline.map((segment, index) => (
        <Sequence
          key={`video-${segment.startFrame}-${index}`}
          from={segment.startFrame}
          durationInFrames={segment.endFrame - segment.startFrame}
        >
          <VideoSegment
            segment={segment}
            manifest={manifest}
            audioMode={audioMode}
          />
        </Sequence>
      ))}

      {manifest.questionCards.map((card, index) => (
        <Sequence
          key={`question-${card.startFrame}-${index}`}
          from={card.startFrame}
          durationInFrames={card.endFrame - card.startFrame}
        >
          <QuestionCard card={card} />
        </Sequence>
      ))}

      <Sequence
        from={manifest.openingTitle.startFrame}
        durationInFrames={
          manifest.openingTitle.endFrame - manifest.openingTitle.startFrame
        }
      >
        <OpeningTitle title={manifest.openingTitle} />
      </Sequence>

      <Sequence
        from={manifest.lowerThird.startFrame}
        durationInFrames={manifest.lowerThird.endFrame - manifest.lowerThird.startFrame}
      >
        <LowerThird lowerThird={manifest.lowerThird} />
      </Sequence>

      {activeCaptions.map((caption, index) => (
        <Sequence
          key={`caption-${caption.startFrame}-${index}`}
          from={caption.startFrame}
          durationInFrames={caption.endFrame - caption.startFrame}
        >
          <CaptionLayer caption={caption} />
        </Sequence>
      ))}

      <Sequence
        from={manifest.outro.startFrame}
        durationInFrames={manifest.outro.endFrame - manifest.outro.startFrame}
      >
        <Outro outro={manifest.outro} />
      </Sequence>

      {audioMode === 'irodori'
        ? manifest.timeline
            .filter((segment) => segment.startFrame > 0)
            .map((segment, index) => (
              <Sequence
                key={`ambient-${segment.startFrame}-${index}`}
                from={segment.startFrame}
                durationInFrames={segment.endFrame - segment.startFrame}
              >
                <Html5Audio
                  src={staticFile(manifest.ambientBed.src)}
                  volume={manifest.ambientBed.volume}
                  loop
                />
              </Sequence>
            ))
        : null}

      {audioMode === 'irodori'
        ? manifest.irodoriAudio.map((clip, index) => (
            <Sequence
              key={`irodori-${clip.startFrame}-${index}`}
              from={clip.startFrame}
              durationInFrames={clip.endFrame - clip.startFrame}
            >
              <IrodoriVoice clip={clip} />
            </Sequence>
          ))
        : null}

      {manifest.replacementAudio ? (
        <Html5Audio src={staticFile(manifest.replacementAudio)} />
      ) : null}
    </AbsoluteFill>
  );
};
