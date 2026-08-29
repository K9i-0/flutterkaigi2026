import {Audio, Video} from '@remotion/media';
import {
  AbsoluteFill,
  Sequence,
  interpolate,
  random,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';

export type SurveillanceManifest = {
  composition: {
    id: string;
    width: number;
    height: number;
    fps: number;
    durationInFrames: number;
  };
  inputVideo: string;
  inputVideoVolume: number;
  replacementAudio: null;
  overlays: [];
  captions: [];
  cameraId: string;
  location: string;
  timestamp: string;
  anomalyStartFrame: number;
  anomalyEndFrame: number;
  identityStartFrame: number;
  identityEndFrame: number;
  glitchFrames: number[];
};

const mono =
  '"SFMono-Regular", Menlo, Monaco, Consolas, "Hiragino Sans", monospace';

const formatTimestamp = (base: string, frame: number, fps: number) => {
  const normalized = base.replace(' ', 'T') + 'Z';
  const date = new Date(Date.parse(normalized) + Math.floor((frame / fps) * 1000));
  return date.toISOString().replace('T', ' ').slice(0, 19);
};

const trackingRect = (frame: number) => {
  if (frame <= 220) {
    return {
      left: interpolate(frame, [0, 220], [302, 346]),
      top: interpolate(frame, [0, 220], [24, 278]),
      width: interpolate(frame, [0, 220], [228, 140]),
      height: interpolate(frame, [0, 220], [430, 166]),
    };
  }

  return {
    left: interpolate(frame, [220, 445], [346, 335]),
    top: interpolate(frame, [220, 445], [278, 22]),
    width: interpolate(frame, [220, 445], [140, 162]),
    height: interpolate(frame, [220, 445], [166, 426]),
  };
};

const Corner: React.FC<{
  horizontal: 'left' | 'right';
  vertical: 'top' | 'bottom';
}> = ({horizontal, vertical}) => (
  <div
    style={{
      position: 'absolute',
      [horizontal]: 18,
      [vertical]: 18,
      width: 42,
      height: 42,
      borderLeft: horizontal === 'left' ? '2px solid rgba(207,255,222,0.8)' : 0,
      borderRight: horizontal === 'right' ? '2px solid rgba(207,255,222,0.8)' : 0,
      borderTop: vertical === 'top' ? '2px solid rgba(207,255,222,0.8)' : 0,
      borderBottom:
        vertical === 'bottom' ? '2px solid rgba(207,255,222,0.8)' : 0,
    }}
  />
);

const TrackingBox: React.FC<{
  frame: number;
  anomaly: boolean;
  identity: boolean;
}> = ({frame, anomaly, identity}) => {
  const rect = trackingRect(frame);
  const color = anomaly || identity ? '#ff3b34' : 'rgba(184,255,207,0.72)';
  const pulse = anomaly ? 0.72 + Math.sin(frame * 0.65) * 0.2 : 0.72;

  return (
    <div
      style={{
        position: 'absolute',
        left: rect.left,
        top: rect.top,
        width: rect.width,
        height: rect.height,
        border: `1px solid ${color}`,
        boxShadow: anomaly ? `0 0 10px rgba(255,35,28,${pulse * 0.4})` : 'none',
        opacity: pulse,
      }}
    >
      <div
        style={{
          position: 'absolute',
          left: -1,
          top: -22,
          color,
          fontFamily: mono,
          fontSize: 12,
          fontWeight: 700,
          letterSpacing: '0.04em',
          whiteSpace: 'nowrap',
          textShadow: '0 1px 3px #000',
        }}
      >
        {identity ? 'BIO MATCH: FUKUCHAN' : anomaly ? 'IDENTITY SHIFT' : 'MOTION TRACK'}
      </div>
      {(['tl', 'tr', 'bl', 'br'] as const).map((corner) => (
        <span
          key={corner}
          style={{
            position: 'absolute',
            width: 12,
            height: 12,
            left: corner.endsWith('l') ? -2 : undefined,
            right: corner.endsWith('r') ? -2 : undefined,
            top: corner.startsWith('t') ? -2 : undefined,
            bottom: corner.startsWith('b') ? -2 : undefined,
            borderLeft: corner.endsWith('l') ? `3px solid ${color}` : 0,
            borderRight: corner.endsWith('r') ? `3px solid ${color}` : 0,
            borderTop: corner.startsWith('t') ? `3px solid ${color}` : 0,
            borderBottom: corner.startsWith('b') ? `3px solid ${color}` : 0,
          }}
        />
      ))}
    </div>
  );
};

export const SurveillanceComposition: React.FC<{
  manifest: SurveillanceManifest;
}> = ({manifest}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const anomaly =
    frame >= manifest.anomalyStartFrame && frame < manifest.anomalyEndFrame;
  const identity =
    frame >= manifest.identityStartFrame && frame < manifest.identityEndFrame;
  const glitch = manifest.glitchFrames.includes(frame);
  const jitterX = glitch ? (random(`x-${frame}`) - 0.5) * 12 : 0;
  const jitterY = glitch ? (random(`y-${frame}`) - 0.5) * 5 : 0;
  const identityOpacity = interpolate(
    frame,
    [manifest.identityStartFrame, manifest.identityStartFrame + 7],
    [0, 1],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
  );

  return (
    <AbsoluteFill style={{backgroundColor: '#07110b', overflow: 'hidden'}}>
      <AbsoluteFill
        style={{
          transform: `translate(${jitterX}px, ${jitterY}px) scale(${glitch ? 1.025 : 1.008})`,
          filter:
            'saturate(0.42) contrast(1.24) brightness(0.78) sepia(0.1) hue-rotate(72deg)',
        }}
      >
        <Video
          src={staticFile(manifest.inputVideo)}
          volume={manifest.inputVideoVolume}
          objectFit="cover"
          style={{width: '100%', height: '100%'}}
        />
      </AbsoluteFill>

      <Audio src={staticFile('cctv_noise.wav')} volume={0.38} />
      <Sequence from={197} durationInFrames={8}>
        <Audio src={staticFile('alert_beep.wav')} volume={0.34} />
      </Sequence>
      <Sequence from={218} durationInFrames={8}>
        <Audio src={staticFile('alert_beep.wav')} volume={0.42} />
      </Sequence>

      <AbsoluteFill
        style={{
          background:
            'repeating-linear-gradient(0deg, rgba(0,0,0,0.18) 0px, rgba(0,0,0,0.18) 1px, transparent 2px, transparent 4px)',
          mixBlendMode: 'multiply',
          opacity: 0.62,
        }}
      />
      <AbsoluteFill
        style={{
          backgroundImage:
            'repeating-radial-gradient(circle at 23% 41%, rgba(214,255,226,0.16) 0 0.65px, transparent 0.8px 3px)',
          backgroundPosition: `${(frame * 17) % 89}px ${(frame * 11) % 73}px`,
          opacity: glitch ? 0.45 : 0.13,
          mixBlendMode: 'screen',
        }}
      />
      {glitch ? (
        <AbsoluteFill
          style={{
            background:
              'repeating-linear-gradient(0deg, transparent 0 38px, rgba(205,255,220,0.3) 39px 42px, transparent 43px 91px)',
            transform: `translateX(${jitterX * -1.8}px)`,
            mixBlendMode: 'screen',
          }}
        />
      ) : null}
      <AbsoluteFill
        style={{
          background:
            'radial-gradient(ellipse at center, transparent 48%, rgba(0,12,5,0.48) 82%, rgba(0,0,0,0.82) 100%)',
        }}
      />

      <Corner horizontal="left" vertical="top" />
      <Corner horizontal="right" vertical="top" />
      <Corner horizontal="left" vertical="bottom" />
      <Corner horizontal="right" vertical="bottom" />

      <div
        style={{
          position: 'absolute',
          left: 34,
          top: 30,
          display: 'flex',
          alignItems: 'center',
          gap: 8,
          color: '#f5fff7',
          fontFamily: mono,
          fontWeight: 700,
          fontSize: 16,
          letterSpacing: '0.08em',
          textShadow: '0 2px 5px #000',
        }}
      >
        <span
          style={{
            width: 10,
            height: 10,
            borderRadius: '50%',
            background: '#ff352e',
            boxShadow: '0 0 8px #ff352e',
            opacity: frame % 30 < 22 ? 1 : 0.34,
          }}
        />
        REC
      </div>

      <div
        style={{
          position: 'absolute',
          right: 34,
          top: 29,
          textAlign: 'right',
          color: '#d9ffe4',
          fontFamily: mono,
          fontSize: 14,
          fontWeight: 700,
          letterSpacing: '0.06em',
          lineHeight: 1.4,
          textShadow: '0 2px 5px #000',
        }}
      >
        <div>{manifest.cameraId}</div>
        <div style={{fontSize: 10, opacity: 0.8}}>{manifest.location}</div>
      </div>

      <TrackingBox frame={frame} anomaly={anomaly} identity={identity} />

      {anomaly ? (
        <div
          style={{
            position: 'absolute',
            left: 34,
            bottom: 62,
            padding: '7px 11px 6px',
            borderLeft: '4px solid #ff342d',
            background: 'rgba(12,4,4,0.76)',
            color: '#ff5b54',
            fontFamily: mono,
            fontSize: 17,
            fontWeight: 700,
            letterSpacing: '0.05em',
            textShadow: '0 1px 3px #000',
          }}
        >
          形態異常を検出
          <span style={{display: 'block', fontSize: 10, color: '#ffd0cd'}}>
            UNAUTHORIZED IDENTITY SHIFT
          </span>
        </div>
      ) : null}

      {identity ? (
        <div
          style={{
            position: 'absolute',
            right: 34,
            bottom: 62,
            opacity: identityOpacity,
            padding: '8px 12px 7px',
            border: '1px solid #ff4a43',
            background: 'rgba(12,4,4,0.8)',
            color: '#fff4f2',
            fontFamily: mono,
            fontSize: 15,
            fontWeight: 700,
            lineHeight: 1.35,
            textAlign: 'right',
            letterSpacing: '0.04em',
            textShadow: '0 1px 3px #000',
          }}
        >
          生体照合：福ちゃん
          <span style={{display: 'block', fontSize: 10, color: '#ff6d66'}}>
            MATCH CONFIRMED
          </span>
        </div>
      ) : null}

      <div
        style={{
          position: 'absolute',
          left: 34,
          bottom: 28,
          color: '#d9ffe4',
          fontFamily: mono,
          fontSize: 13,
          fontWeight: 600,
          letterSpacing: '0.05em',
          textShadow: '0 2px 5px #000',
        }}
      >
        {formatTimestamp(manifest.timestamp, frame, fps)} JST
      </div>
      <div
        style={{
          position: 'absolute',
          right: 34,
          bottom: 28,
          color: '#b9e9c6',
          fontFamily: mono,
          fontSize: 11,
          letterSpacing: '0.06em',
          textShadow: '0 2px 5px #000',
        }}
      >
        ARCHIVE // MOTION REC
      </div>
    </AbsoluteFill>
  );
};
