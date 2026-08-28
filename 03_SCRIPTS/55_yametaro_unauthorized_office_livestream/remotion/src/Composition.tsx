import {Video} from '@remotion/media';
import {
  AbsoluteFill,
  Html5Audio,
  Img,
  interpolate,
  Sequence,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';
import type {
  Caption,
  ChatComment,
  EditManifest,
  FrameRange,
  LiveSegment,
  VideoInsert,
} from './types';

const fontStack =
  '"Hiragino Sans", "Yu Gothic", "Noto Sans JP", system-ui, sans-serif';
const red = '#ff2547';

const isActive = (frame: number, range: FrameRange) =>
  frame >= range.startFrame && frame < range.endFrame;

const liveSegmentAt = (frame: number, segments: LiveSegment[]) =>
  segments.find((segment) => isActive(frame, segment));

const LivestreamChrome: React.FC<{
  manifest: EditManifest;
  segment: LiveSegment;
}> = ({manifest, segment}) => {
  const frame = useCurrentFrame();
  const local = frame - segment.startFrame;
  const darkWordmark = segment.logoVariant === 'black';
  const foreground = darkWordmark ? '#000000' : '#FFFFFF';
  const foregroundShadow = darkWordmark
    ? '0 1px 5px rgba(255,255,255,0.92)'
    : '0 2px 8px rgba(0,0,0,0.9)';
  const platformLogo = darkWordmark
    ? manifest.platform.logoBlack
    : manifest.platform.logoWhite;
  const opacity = interpolate(local, [0, 5], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  return (
    <>
      <div
        style={{
          position: 'absolute',
          inset: 8,
          border: '1px solid rgba(255,255,255,0.24)',
          borderRadius: 17,
          boxShadow: 'inset 0 0 0 1px rgba(0,0,0,0.22)',
          opacity,
          pointerEvents: 'none',
        }}
      />
      <div
        style={{
          position: 'absolute',
          left: 18,
          right: 18,
          top: 14,
          height: 42,
          display: 'flex',
          alignItems: 'center',
          gap: 9,
          opacity,
          fontFamily: fontStack,
          fontSynthesis: 'none',
          color: foreground,
          textShadow: foregroundShadow,
          zIndex: 20,
        }}
      >
        <Img
          src={staticFile(platformLogo)}
          title={manifest.platform.name}
          style={{
            flex: '0 0 auto',
            width: 145,
            height: 38,
            objectFit: 'contain',
            filter: darkWordmark
              ? 'drop-shadow(0 1px 3px rgba(255,255,255,0.82))'
              : 'drop-shadow(0 2px 5px rgba(0,0,0,0.72))',
          }}
        />
        <div
          style={{
            flex: '0 0 auto',
            width: 1,
            height: 29,
            background: darkWordmark
              ? 'rgba(0,0,0,0.35)'
              : 'rgba(255,255,255,0.44)',
            boxShadow: foregroundShadow,
          }}
        />
        <div
          style={{
            width: 34,
            height: 34,
            borderRadius: '50%',
            background: 'linear-gradient(145deg, #9d79ff, #5530c7)',
            border: '2px solid rgba(255,255,255,0.92)',
            display: 'grid',
            placeItems: 'center',
            fontSize: 18,
            fontWeight: 700,
            boxShadow: '0 2px 8px rgba(0,0,0,0.35)',
          }}
        >
          や
        </div>
        <div style={{minWidth: 0}}>
          <div style={{fontSize: 18, lineHeight: 1.05, fontWeight: 700}}>
            {manifest.channel.name}
          </div>
          <div
            style={{
              marginTop: 2,
              fontSize: 10,
              lineHeight: 1,
              opacity: 0.82,
              fontWeight: 500,
            }}
          >
            {manifest.channel.handle}
          </div>
        </div>
        <div
          style={{
            marginLeft: 'auto',
            display: 'flex',
            alignItems: 'center',
            gap: 7,
          }}
        >
          <div
            style={{
              padding: '6px 10px 7px',
              borderRadius: 5,
              background: red,
              boxShadow: '0 2px 8px rgba(0,0,0,0.34)',
              fontSize: 14,
              lineHeight: 1,
              fontWeight: 700,
              letterSpacing: '0.07em',
            }}
          >
            LIVE
          </div>
          <div
            style={{
              minWidth: 69,
              padding: '6px 9px 7px',
              borderRadius: 5,
              background: 'rgba(8,10,17,0.68)',
              backdropFilter: 'blur(4px)',
              color: 'white',
              textShadow: '0 1px 4px rgba(0,0,0,0.8)',
              fontSize: 14,
              lineHeight: 1,
              fontWeight: 600,
              fontVariantNumeric: 'tabular-nums',
            }}
          >
            ◉ {segment.viewerCount}
          </div>
        </div>
      </div>
    </>
  );
};

const commentColor = (comment: ChatComment) => {
  if (comment.tone === 'danger') return '#ff6179';
  if (comment.tone === 'hot') return '#ffd166';
  return '#ffffff';
};

const anonymousAvatars = [
  {glyph: '猫', background: 'linear-gradient(145deg, #4fc3f7, #1565c0)'},
  {glyph: 'ゲ', background: 'linear-gradient(145deg, #ce93d8, #6a1b9a)'},
  {glyph: '麺', background: 'linear-gradient(145deg, #ffcc80, #ef6c00)'},
  {glyph: '草', background: 'linear-gradient(145deg, #81c784, #2e7d32)'},
  {glyph: '匿', background: 'linear-gradient(145deg, #90a4ae, #37474f)'},
  {glyph: '祭', background: 'linear-gradient(145deg, #ff8a80, #c62828)'},
] as const;

const AnonymousAvatar: React.FC<{index: number}> = ({index}) => {
  const avatar = anonymousAvatars[index % anonymousAvatars.length];
  return (
    <div
      style={{
        flex: '0 0 auto',
        width: 27,
        height: 27,
        display: 'grid',
        placeItems: 'center',
        borderRadius: '50%',
        background: avatar.background,
        border: '1.5px solid rgba(255,255,255,0.86)',
        boxShadow: '0 1px 5px rgba(0,0,0,0.5)',
        color: 'white',
        fontSize: 13,
        lineHeight: 1,
        fontWeight: 700,
      }}
    >
      {avatar.glyph}
    </div>
  );
};

const OkayamanAvatar: React.FC = () => (
  <div
    style={{
      flex: '0 0 auto',
      width: 29,
      height: 29,
      padding: 2,
      borderRadius: '50%',
      background: 'linear-gradient(145deg, #ffe66d, #ff8f00)',
      boxShadow: '0 1px 7px rgba(255,193,7,0.62)',
    }}
  >
    <Img
      src={staticFile('okayaman-avatar.jpg')}
      style={{
        width: '100%',
        height: '100%',
        display: 'block',
        borderRadius: '50%',
        objectFit: 'cover',
      }}
    />
  </div>
);

const CommentBubble: React.FC<{
  comment: ChatComment;
  index: number;
}> = ({comment, index}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const local = frame - comment.startFrame;
  const enter = spring({
    frame: local,
    fps,
    config: {damping: 17, stiffness: 220, mass: 0.55},
  });
  const exit = interpolate(
    frame,
    [comment.endFrame - 6, comment.endFrame],
    [1, 0],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
  );
  const opacity = Math.min(enter, exit);
  const x = interpolate(enter, [0, 1], [28, 0]);
  return (
    <div
      style={{
        opacity,
        transform: `translateX(${x}px)`,
        alignSelf: 'flex-end',
        maxWidth: 286,
        display: 'flex',
        alignItems: 'center',
        gap: 8,
        padding: '6px 10px 7px',
        borderRadius: 13,
        background:
          comment.tone === 'danger'
            ? 'rgba(82,5,19,0.78)'
            : 'rgba(4,7,12,0.66)',
        border:
          comment.tone === 'danger'
            ? '1px solid rgba(255,61,91,0.42)'
            : '1px solid rgba(255,255,255,0.13)',
        boxShadow: '0 2px 9px rgba(0,0,0,0.3)',
        color: commentColor(comment),
        fontFamily: fontStack,
        fontSynthesis: 'none',
        fontSize: 16,
        lineHeight: 1.23,
        fontWeight: comment.tone === 'normal' || !comment.tone ? 600 : 700,
        letterSpacing: '0.005em',
        textShadow: '0 1px 4px rgba(0,0,0,0.75)',
      }}
    >
      {comment.author === 'okayaman' ? (
        <OkayamanAvatar />
      ) : (
        <AnonymousAvatar index={index} />
      )}
      <span>{comment.text}</span>
    </div>
  );
};

const Comments: React.FC<{comments: ChatComment[]}> = ({comments}) => (
  <div
    style={{
      position: 'absolute',
      right: 18,
      top: 64,
      bottom: 88,
      width: 300,
      display: 'flex',
      flexDirection: 'column',
      justifyContent: 'flex-end',
      alignItems: 'flex-end',
      gap: 6,
      overflow: 'hidden',
      zIndex: 18,
    }}
  >
    {comments.slice(-6).map((comment, index) => (
      <CommentBubble
        key={`${comment.startFrame}-${comment.text}`}
        comment={comment}
        index={index}
      />
    ))}
  </div>
);

const CaptionLayer: React.FC<{caption: Caption; isLive: boolean}> = ({
  caption,
  isLive,
}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const local = frame - caption.startFrame;
  const enter = spring({
    frame: local,
    fps,
    config: {damping: 19, stiffness: 190, mass: 0.55},
  });
  return (
    <div
      style={{
        position: 'absolute',
        left: isLive ? 18 : 56,
        right: isLive ? 315 : 56,
        bottom: 18,
        display: 'flex',
        justifyContent: 'center',
        alignItems: 'flex-end',
        transform: `translateY(${interpolate(enter, [0, 1], [13, 0])}px)`,
        opacity: enter,
        zIndex: 24,
        fontFamily: fontStack,
        fontSynthesis: 'none',
        WebkitFontSmoothing: 'antialiased',
        textRendering: 'geometricPrecision',
      }}
    >
      <div
        style={{
          display: 'inline-block',
          width: 'fit-content',
          maxWidth: '100%',
          padding: '6px 11px 7px',
          borderRadius: 4,
          background: 'rgba(0,0,0,0.76)',
          color: 'white',
          whiteSpace: 'pre-line',
          textAlign: 'center',
          fontSize: 22,
          lineHeight: 1.27,
          fontWeight: 600,
          letterSpacing: '0.01em',
          textShadow: '0 1px 3px rgba(0,0,0,0.88)',
          boxShadow: '0 2px 8px rgba(0,0,0,0.3)',
        }}
      >
        {caption.text}
      </div>
    </div>
  );
};

const ConfidentialCard: React.FC<{manifest: EditManifest}> = ({manifest}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const local = frame - manifest.confidential.startFrame;
  const enter = spring({
    frame: local,
    fps,
    config: {damping: 16, stiffness: 220, mass: 0.48},
  });
  const exit = interpolate(
    frame,
    [manifest.confidential.endFrame - 5, manifest.confidential.endFrame],
    [1, 0],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
  );
  const pulse = 1 + Math.sin(local * 0.24) * 0.012;
  return (
    <div
      style={{
        position: 'absolute',
        left: '28%',
        right: '28%',
        top: '25%',
        height: '39%',
        display: 'grid',
        placeItems: 'center',
        opacity: Math.min(enter, exit),
        transform: `scale(${interpolate(enter, [0, 1], [0.82, pulse])})`,
        border: '6px solid #d91838',
        borderRadius: 5,
        background:
          'repeating-linear-gradient(-45deg, rgba(255,255,255,0.98) 0 15px, rgba(249,242,244,0.98) 15px 30px)',
        boxShadow: '0 8px 28px rgba(0,0,0,0.48)',
        color: '#c8102e',
        fontFamily: fontStack,
        fontSynthesis: 'none',
        fontSize: 53,
        lineHeight: 1,
        fontWeight: 700,
        letterSpacing: '0.11em',
        textShadow: '0 2px 0 white',
        zIndex: 15,
      }}
    >
      {manifest.confidential.text}
    </div>
  );
};

const InsertedVideo: React.FC<{insert: VideoInsert; globalFrame: number}> = ({
  insert,
  globalFrame,
}) => {
  const scale = insert.lensCover
    ? interpolate(
        globalFrame,
        [insert.lensCover.startFrame, insert.lensCover.endFrame],
        [1, insert.lensCover.scale],
        {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
      )
    : 1;

  return (
    <Video
      src={staticFile(insert.path)}
      trimBefore={insert.sourceStartFrame}
      playbackRate={insert.playbackRate ?? 1}
      muted
      volume={0}
      objectFit="cover"
      style={{
        width: '100%',
        height: '100%',
        transform: `scale(${scale})`,
        transformOrigin: insert.lensCover?.origin ?? '50% 50%',
      }}
    />
  );
};

export const EditComposition: React.FC<{manifest: EditManifest}> = ({manifest}) => {
  const frame = useCurrentFrame();
  const replacementAudio = manifest.replacementAudio;
  const liveSegment = liveSegmentAt(frame, manifest.liveSegments);
  const activeCaption = manifest.captions.find((caption) => isActive(frame, caption));
  const activeComments = manifest.comments.filter((comment) => isActive(frame, comment));
  const confidential = isActive(frame, manifest.confidential);
  const replacement = manifest.replacementVideo;
  const lensCoverScale = interpolate(frame, [909, 921], [1, 2.4], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  return (
    <AbsoluteFill style={{backgroundColor: '#000'}}>
      <Sequence from={0} durationInFrames={replacement.startFrame}>
        <Video
          src={staticFile(manifest.inputVideo)}
          muted={replacementAudio !== null}
          volume={replacementAudio === null ? manifest.inputVideoVolume : 0}
          playbackRate={replacement.sourceCutFrame / replacement.startFrame}
          objectFit="cover"
          style={{width: '100%', height: '100%'}}
        />
      </Sequence>
      <Sequence
        from={replacement.startFrame}
        durationInFrames={manifest.composition.durationInFrames - replacement.startFrame}
      >
        <Video
          src={staticFile(replacement.path)}
          muted
          volume={0}
          objectFit="cover"
          style={{
            width: '100%',
            height: '100%',
            transform: `scale(${lensCoverScale})`,
            transformOrigin: '50% 55%',
          }}
        />
      </Sequence>
      {manifest.videoInserts.map((insert, index) => (
        <Sequence
          key={`${insert.path}-${insert.startFrame}-${index}`}
          from={insert.startFrame}
          durationInFrames={insert.endFrame - insert.startFrame}
        >
          <InsertedVideo insert={insert} globalFrame={frame} />
        </Sequence>
      ))}
      {replacementAudio ? <Html5Audio src={staticFile(replacementAudio)} /> : null}
      {confidential ? <ConfidentialCard manifest={manifest} /> : null}
      {liveSegment ? (
        <>
          <LivestreamChrome manifest={manifest} segment={liveSegment} />
          <Comments comments={activeComments} />
        </>
      ) : null}
      {activeCaption ? (
        <CaptionLayer caption={activeCaption} isLive={liveSegment !== undefined} />
      ) : null}
    </AbsoluteFill>
  );
};
