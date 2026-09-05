import {Video} from '@remotion/media';
import {
  AbsoluteFill,
  Html5Audio,
  Img,
  interpolate,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';
import type {EditManifest, ViewerComment} from './types';

const fontStack =
  '"Hiragino Sans", "Yu Gothic", "Noto Sans JP", system-ui, sans-serif';

const ViewerPill: React.FC<{count: string}> = ({count}) => (
  <div
    style={{
      display: 'flex',
      alignItems: 'center',
      gap: 7,
      height: 32,
      padding: '0 11px',
      color: '#fff',
      background: 'rgba(15, 11, 27, 0.76)',
      border: '1px solid rgba(255,255,255,0.22)',
      borderRadius: 10,
      boxShadow: '0 3px 14px rgba(0,0,0,0.32)',
      fontFamily: fontStack,
      fontSize: 16,
      fontWeight: 700,
      fontVariantNumeric: 'tabular-nums',
    }}
  >
    <span aria-hidden style={{fontSize: 15}}>●</span>
    {count}
  </div>
);

const StreamChrome: React.FC<{manifest: EditManifest}> = ({manifest}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const intro = spring({frame, fps, config: {damping: 18, stiffness: 150}});
  const topY = interpolate(intro, [0, 1], [-18, 0]);
  return (
    <>
      <div
        style={{
          position: 'absolute',
          top: 13,
          left: 15,
          right: 15,
          height: 54,
          display: 'flex',
          alignItems: 'center',
          gap: 10,
          transform: `translateY(${topY}px)`,
          opacity: intro,
          zIndex: 10,
        }}
      >
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 7,
            height: 32,
            padding: '0 11px',
            color: '#fff',
            background: 'linear-gradient(135deg, #ff357a, #d51d5f)',
            border: '1px solid rgba(255,255,255,0.52)',
            borderRadius: 10,
            boxShadow: '0 3px 14px rgba(0,0,0,0.34)',
            fontFamily: fontStack,
            fontSize: 16,
            fontWeight: 800,
            letterSpacing: '0.04em',
          }}
        >
          <span
            style={{
              width: 9,
              height: 9,
              borderRadius: '50%',
              background: '#fff',
              boxShadow: '0 0 8px rgba(255,255,255,0.95)',
            }}
          />
          {manifest.stream.liveLabel}
        </div>
        <ViewerPill count={manifest.stream.viewerCount} />
        <div
          style={{
            flex: 1,
            minWidth: 0,
            height: 52,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: 12,
            padding: '0 19px',
            color: '#231333',
            background: 'rgba(253, 250, 255, 0.94)',
            border: '3px solid rgba(179, 121, 224, 0.76)',
            borderRadius: 25,
            boxShadow: '0 5px 18px rgba(26,9,49,0.34)',
            fontFamily: fontStack,
            fontSize: 24,
            fontWeight: 750,
            letterSpacing: '0.012em',
            whiteSpace: 'nowrap',
          }}
        >
          <span style={{overflow: 'hidden', textOverflow: 'ellipsis'}}>
            {manifest.stream.title}
          </span>
          <span
            style={{
              flex: '0 0 auto',
              padding: '4px 12px 5px',
              borderRadius: 15,
              color: '#fff',
              background: 'linear-gradient(135deg, #a457d0, #7536a4)',
              fontSize: 16,
              fontWeight: 750,
            }}
          >
            {manifest.stream.tag}
          </span>
        </div>
      </div>
      <div
        style={{
          position: 'absolute',
          left: 18,
          bottom: 16,
          minWidth: 238,
          padding: '9px 13px 10px',
          color: '#fff',
          background: 'linear-gradient(135deg, rgba(42,22,65,0.88), rgba(17,11,31,0.84))',
          border: '1px solid rgba(231,207,255,0.34)',
          borderRadius: 12,
          boxShadow: '0 5px 18px rgba(0,0,0,0.35)',
          fontFamily: fontStack,
          zIndex: 10,
        }}
      >
        <div style={{fontSize: 17, fontWeight: 750}}>{manifest.stream.channelName}</div>
        <div style={{marginTop: 1, color: '#d8c7e8', fontSize: 12, fontWeight: 500}}>
          {manifest.stream.handle}
        </div>
      </div>
    </>
  );
};

const CommentBubble: React.FC<{comment: ViewerComment}> = ({comment}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const localFrame = frame - comment.startFrame;
  const enter = spring({
    frame: localFrame,
    fps,
    config: {damping: 16, stiffness: 210, mass: 0.6},
  });
  const exit = interpolate(
    frame,
    [comment.endFrame - 7, comment.endFrame],
    [1, 0],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
  );
  return (
    <div
      style={{
        width: comment.featured ? 298 : 282,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'stretch',
        gap: comment.kind === 'superchat' ? 8 : 0,
        padding: comment.featured ? '11px 13px 12px' : '8px 11px 9px',
        opacity: Math.min(enter, exit),
        transform: `translateX(${interpolate(enter, [0, 1], [34, 0])}px)`,
        color: '#fff',
        background:
          comment.featured
            ? 'linear-gradient(135deg, rgba(108,54,139,0.97), rgba(51,25,73,0.95))'
            : comment.tone === 'hot'
              ? 'linear-gradient(135deg, rgba(83,35,116,0.93), rgba(43,22,66,0.9))'
              : 'linear-gradient(135deg, rgba(26,20,42,0.88), rgba(13,12,25,0.83))',
        border:
          comment.featured
            ? '2px solid rgba(247,211,123,0.9)'
            : comment.tone === 'hot'
              ? '1px solid rgba(224,169,255,0.56)'
              : '1px solid rgba(255,255,255,0.18)',
        borderRadius: comment.featured ? 17 : 14,
        boxShadow: comment.featured
          ? '0 7px 22px rgba(0,0,0,0.42), 0 0 17px rgba(226,181,98,0.34)'
          : '0 5px 15px rgba(0,0,0,0.34)',
        fontFamily: fontStack,
      }}
    >
      {comment.kind === 'superchat' ? (
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            margin: '-11px -13px 0',
            padding: '7px 12px 8px',
            borderRadius: '15px 15px 5px 5px',
            color: '#351d0b',
            background: 'linear-gradient(90deg, #ffd76a, #ffb547)',
            fontSize: 13,
            lineHeight: 1,
            fontWeight: 800,
            letterSpacing: '0.015em',
          }}
        >
          <span>スーパーチャット</span>
          <span style={{fontSize: 16, fontVariantNumeric: 'tabular-nums'}}>
            {comment.amount}
          </span>
        </div>
      ) : null}
      <div style={{display: 'flex', alignItems: 'center', gap: comment.featured ? 11 : 9}}>
        <div
          style={{
            flex: '0 0 auto',
            width: comment.featured ? 47 : 36,
            height: comment.featured ? 47 : 36,
            padding: 2,
            borderRadius: '50%',
            background: 'linear-gradient(145deg, #f1ccff, #8a4fb3)',
            boxShadow: comment.featured
              ? '0 2px 11px rgba(247,211,123,0.72)'
              : '0 2px 8px rgba(171,94,219,0.5)',
          }}
        >
          <Img
            src={staticFile(comment.avatar)}
            style={{
              width: '100%',
              height: '100%',
              display: 'block',
              borderRadius: '50%',
              objectFit: 'cover',
              objectPosition: comment.avatarPosition ?? '50% 28%',
              background: '#fff',
            }}
          />
        </div>
        <div style={{minWidth: 0}}>
          <div
            style={{
              marginBottom: 2,
              color: '#dcb8f0',
              fontSize: comment.featured ? 14 : 11,
              lineHeight: 1.1,
              fontWeight: 700,
            }}
          >
            {comment.displayName}
          </div>
          <div
            style={{
              fontSize: comment.featured ? 21 : 15,
              lineHeight: 1.22,
              fontWeight: 650,
              letterSpacing: '0.005em',
              whiteSpace: 'normal',
              textShadow: '0 1px 4px rgba(0,0,0,0.75)',
            }}
          >
            {comment.text}
          </div>
        </div>
      </div>
    </div>
  );
};

const Comments: React.FC<{comments: ViewerComment[]}> = ({comments}) => {
  const pinned = comments.find((comment) => comment.featured);
  const rolling = comments.filter((comment) => !comment.featured).slice(-3);
  return (
    <div
      style={{
        position: 'absolute',
        top: 80,
        right: 17,
        bottom: 17,
        width: 306,
        display: 'flex',
        flexDirection: 'column',
        justifyContent: 'flex-end',
        alignItems: 'flex-end',
        gap: 7,
        overflow: 'hidden',
        zIndex: 12,
      }}
    >
      {rolling.map((comment) => (
        <CommentBubble key={`${comment.author}-${comment.startFrame}`} comment={comment} />
      ))}
      {pinned ? (
        <CommentBubble key={`${pinned.author}-${pinned.startFrame}`} comment={pinned} />
      ) : null}
    </div>
  );
};

export const EditComposition: React.FC<{manifest: EditManifest}> = ({manifest}) => {
  const frame = useCurrentFrame();
  const replacementAudio = manifest.replacementAudio;
  const activeComments = manifest.comments.filter(
    (comment) => frame >= comment.startFrame && frame < comment.endFrame,
  );
  return (
    <AbsoluteFill style={{backgroundColor: '#090611'}}>
      <Video
        src={staticFile(manifest.inputVideo)}
        muted={replacementAudio !== null}
        volume={replacementAudio === null ? manifest.inputVideoVolume : 0}
        objectFit="cover"
        style={{width: '100%', height: '100%'}}
      />
      {replacementAudio ? <Html5Audio src={staticFile(replacementAudio)} /> : null}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background:
            'linear-gradient(90deg, transparent 48%, rgba(17,8,30,0.05) 62%, rgba(17,8,30,0.19) 100%)',
        }}
      />
      <StreamChrome manifest={manifest} />
      <Comments comments={activeComments} />
    </AbsoluteFill>
  );
};
