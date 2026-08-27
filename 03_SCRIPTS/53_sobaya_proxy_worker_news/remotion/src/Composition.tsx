import {Video} from '@remotion/media';
import {
  AbsoluteFill,
  Html5Audio,
  Img,
  Sequence,
  interpolate,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';
import type {
  Caption,
  EditManifest,
  NewsLowerThird as NewsLowerThirdType,
  Overlay,
  StationBug as StationBugType,
  Ticker as TickerType,
} from './types';

const fontStack =
  '"Hiragino Sans", "Yu Gothic", "Noto Sans JP", system-ui, sans-serif';

const StationBug: React.FC<{overlay: StationBugType}> = ({overlay}) => {
  const frame = useCurrentFrame();
  const {height} = useVideoConfig();
  const scale = height / 480;
  const variant = overlay.variant ?? 'plain';
  const position = overlay.position ?? 'top-right';
  const opacity =
    variant === 'plain'
      ? interpolate(frame, [0, 6], [0, 1], {
          extrapolateLeft: 'clamp',
          extrapolateRight: 'clamp',
        })
      : 1;
  const branded = variant === 'brand' && overlay.text === 'ゆめテレ';
  return (
    <div
      style={{
        position: 'absolute',
        top: (variant === 'brand' ? 13 : 16) * scale,
        ...(position === 'top-left' ? {left: '5%'} : {right: '2%'}),
        opacity,
        display: 'flex',
        alignItems: 'center',
        gap: 7 * scale,
        minHeight:
          variant === 'plain' ? undefined : (variant === 'brand' ? 42 : 34) * scale,
        padding:
          variant === 'plain'
            ? 0
            : variant === 'brand'
              ? `${5 * scale}px ${12 * scale}px ${7 * scale}px`
              : `${4 * scale}px ${10 * scale}px ${5 * scale}px`,
        color: variant === 'brand' ? '#123b70' : 'white',
        background:
          variant === 'brand'
            ? '#fcfdff'
            : variant === 'clock'
              ? 'rgba(7,25,47,0.9)'
              : 'transparent',
        borderRadius: variant === 'plain' ? 0 : 5 * scale,
        boxShadow:
          variant === 'plain' ? 'none' : '0 2px 8px rgba(0,0,0,0.22)',
        fontFamily: fontStack,
        fontSize: Math.max(
          10,
          Math.round((variant === 'plain' ? 24 : 20) * scale),
        ),
        fontWeight: 700,
        fontVariantNumeric: 'tabular-nums',
        letterSpacing: variant === 'clock' ? '0.04em' : '0.01em',
        textShadow:
          variant === 'plain' ? '0 1px 5px rgba(0,0,0,0.8)' : 'none',
        WebkitFontSmoothing: 'antialiased',
        textRendering: 'geometricPrecision',
      }}
    >
      {overlay.image ? (
        <Img
          src={staticFile(overlay.image)}
          style={{
            width: Math.round(110 * scale),
            maxHeight: Math.round(54 * scale),
            objectFit: 'contain',
          }}
        />
      ) : branded ? (
        <>
          <span
            style={{
              position: 'relative',
              width: 19 * scale,
              height: 19 * scale,
              flex: `0 0 ${19 * scale}px`,
              borderRadius: '50%',
              background: '#123f78',
            }}
          >
            <span
              style={{
                position: 'absolute',
                left: 6 * scale,
                top: 2 * scale,
                width: 11 * scale,
                height: 13 * scale,
                borderRadius: '50%',
                background: '#fcfdff',
              }}
            />
            <span
              style={{
                position: 'absolute',
                right: 1 * scale,
                top: -1 * scale,
                width: 7 * scale,
                height: 7 * scale,
                borderRadius: '50%',
                background: '#ee594f',
              }}
            />
          </span>
          <span>
            <span style={{color: '#123f78'}}>ゆめ</span>
            <span style={{color: '#e94f4c'}}>テレ</span>
          </span>
        </>
      ) : (
        overlay.text
      )}
    </div>
  );
};

const NewsLowerThird: React.FC<{
  overlay: NewsLowerThirdType;
  hasTicker: boolean;
}> = ({overlay, hasTicker}) => {
  const frame = useCurrentFrame();
  const {fps, height} = useVideoConfig();
  const scale = height / 480;
  const progress = spring({frame, fps, config: {damping: 18, stiffness: 180}});
  const placement = overlay.placement ?? 'bottom';
  const compact = overlay.variant === 'compact' || placement !== 'bottom';
  const translateY = interpolate(progress, [0, 1], [compact ? -18 : 40, 0]);
  const accent = overlay.accentColor ?? '#c4142f';
  const widthPercent = Math.min(90, Math.max(28, overlay.widthPercent ?? 42));
  const position =
    placement === 'top-left'
      ? {top: 58 * scale, left: '5%', width: `${widthPercent}%`}
      : placement === 'bottom-left'
        ? {
            bottom: (hasTicker ? 62 : 24) * scale,
            left: '5%',
            width: `${widthPercent}%`,
          }
        : {
            bottom: (hasTicker ? 62 : 24) * scale,
            left: '5%',
            right: '5%',
          };
  return (
    <div
      style={{
        position: 'absolute',
        ...position,
        transform: `translateY(${translateY * scale}px)`,
        opacity: progress,
        fontFamily: fontStack,
        fontSynthesis: 'none',
        WebkitFontSmoothing: 'antialiased',
        textRendering: 'geometricPrecision',
        filter: 'drop-shadow(0 5px 14px rgba(0,0,0,0.35))',
      }}
    >
      <div
        style={{
          display: 'inline-block',
          background: accent,
          color: 'white',
          fontSize: Math.max(9, Math.round((compact ? 16 : 20) * scale)),
          fontWeight: 700,
          padding: `${(compact ? 5 : 7) * scale}px ${(compact ? 12 : 16) * scale}px ${(compact ? 4 : 6) * scale}px`,
          letterSpacing: Math.max(0.5, (compact ? 1.2 : 2) * scale),
          borderRadius: `${4 * scale}px ${4 * scale}px 0 0`,
        }}
      >
        {overlay.kicker}
      </div>
      <div
        style={{
          background: 'rgba(252,253,255,0.96)',
          borderLeft: `${Math.max(3, 7 * scale)}px solid ${accent}`,
          color: '#111827',
          padding: `${(compact ? 10 : 15) * scale}px ${(compact ? 14 : 22) * scale}px ${(compact ? 10 : 14) * scale}px`,
          borderRadius: `0 ${4 * scale}px ${4 * scale}px ${4 * scale}px`,
        }}
      >
        <div
          style={{
            fontSize: Math.max(12, Math.round((compact ? 22 : 30) * scale)),
            lineHeight: compact ? 1.26 : 1.22,
            fontWeight: 700,
            letterSpacing: '0.01em',
            whiteSpace: 'pre-line',
          }}
        >
          {overlay.headline}
        </div>
        {overlay.subheadline ? (
          <div
            style={{
              marginTop: (compact ? 5 : 7) * scale,
              fontSize: Math.max(9, Math.round((compact ? 15 : 19) * scale)),
              lineHeight: 1.25,
              color: '#3f4a5a',
              fontWeight: 500,
              letterSpacing: '0.01em',
            }}
          >
            {overlay.subheadline}
          </div>
        ) : null}
      </div>
    </div>
  );
};

const Ticker: React.FC<{overlay: TickerType}> = ({overlay}) => {
  const frame = useCurrentFrame();
  const {width, height} = useVideoConfig();
  const scale = height / 480;
  const duration = overlay.endFrame - overlay.startFrame;
  const estimatedTextWidth = Math.max(500 * scale, overlay.text.length * 25 * scale);
  const x = interpolate(frame, [0, duration], [width, -estimatedTextWidth], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const accent = overlay.accentColor ?? '#c4142f';
  return (
    <div
      style={{
        position: 'absolute',
        left: 0,
        right: 0,
        bottom: 0,
        height: 48 * scale,
        display: 'flex',
        overflow: 'hidden',
        background: 'rgba(8,18,34,0.96)',
        color: 'white',
        fontFamily: fontStack,
        fontSize: Math.max(9, Math.round(20 * scale)),
        WebkitFontSmoothing: 'antialiased',
        textRendering: 'geometricPrecision',
        alignItems: 'center',
      }}
    >
      <div
        style={{
          position: 'relative',
          zIndex: 2,
          alignSelf: 'stretch',
          display: 'flex',
          alignItems: 'center',
          padding: `0 ${17 * scale}px`,
          background: accent,
          fontWeight: 700,
          letterSpacing: 1,
        }}
      >
        {overlay.label}
      </div>
      <div
        style={{
          position: 'absolute',
          left: 0,
          transform: `translateX(${x}px)`,
          whiteSpace: 'nowrap',
          fontWeight: 500,
          letterSpacing: '0.01em',
        }}
      >
        {overlay.text}
      </div>
    </div>
  );
};

const CaptionLayer: React.FC<{
  caption: Caption;
  elevated: boolean;
}> = ({caption, elevated}) => {
  const {height} = useVideoConfig();
  const fontSize = Math.max(14, Math.round(height * 0.055));
  return (
    <div
      style={{
        position: 'absolute',
        left: '5%',
        right: '5%',
        bottom: elevated ? '34%' : '10%',
        color: 'white',
        textAlign: 'center',
        whiteSpace: 'pre-line',
        fontFamily: fontStack,
        fontSize,
        fontWeight: 600,
        letterSpacing: '0.02em',
        lineHeight: 1.32,
        WebkitTextStroke: `${Math.max(1, fontSize * 0.055)}px rgba(0,0,0,0.9)`,
        paintOrder: 'stroke fill',
        textShadow: '0 3px 10px rgba(0,0,0,0.9)',
      }}
    >
      {caption.text}
    </div>
  );
};

const renderOverlay = (overlay: Overlay, hasTicker: boolean) => {
  if (overlay.type === 'station-bug') {
    return <StationBug overlay={overlay} />;
  }
  if (overlay.type === 'news-lower-third') {
    return <NewsLowerThird overlay={overlay} hasTicker={hasTicker} />;
  }
  return <Ticker overlay={overlay} />;
};

export const EditComposition: React.FC<{manifest: EditManifest}> = ({manifest}) => {
  const frame = useCurrentFrame();
  const replacementAudio = manifest.replacementAudio;
  const activeCaption = manifest.captions.find(
    (caption) => frame >= caption.startFrame && frame < caption.endFrame,
  );
  const hasActiveLowerThird = manifest.overlays.some(
    (overlay) =>
      overlay.type === 'news-lower-third' &&
      frame >= overlay.startFrame &&
      frame < overlay.endFrame,
  );
  return (
    <AbsoluteFill style={{backgroundColor: '#000'}}>
      <Video
        src={staticFile(manifest.inputVideo)}
        muted={replacementAudio !== null}
        volume={replacementAudio === null ? manifest.inputVideoVolume : 0}
        objectFit="cover"
        style={{width: '100%', height: '100%'}}
      />
      {replacementAudio ? <Html5Audio src={staticFile(replacementAudio)} /> : null}
      {manifest.overlays.map((overlay, index) => {
        const hasTicker = manifest.overlays.some(
          (candidate) =>
            candidate.type === 'ticker' &&
            candidate.startFrame < overlay.endFrame &&
            candidate.endFrame > overlay.startFrame,
        );
        return (
          <Sequence
            key={`${overlay.type}-${overlay.startFrame}-${index}`}
            from={overlay.startFrame}
            durationInFrames={overlay.endFrame - overlay.startFrame}
          >
            {renderOverlay(overlay, hasTicker)}
          </Sequence>
        );
      })}
      {activeCaption ? (
        <CaptionLayer caption={activeCaption} elevated={hasActiveLowerThird} />
      ) : null}
    </AbsoluteFill>
  );
};
