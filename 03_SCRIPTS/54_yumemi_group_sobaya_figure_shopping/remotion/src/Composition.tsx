import {Video} from '@remotion/media';
import {
  AbsoluteFill,
  Html5Audio,
  interpolate,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';
import type {Caption, EditManifest, FrameRange} from './types';

const fontStack =
  '"Hiragino Sans", "Yu Gothic", "Noto Sans JP", system-ui, sans-serif';
const wine = '#7b1735';
const coral = '#e95345';
const gold = '#d8a83e';
const ink = '#341d22';

const rangeOpacity = (frame: number, range: FrameRange, easeFrames = 6) => {
  const enter = interpolate(
    frame,
    [range.startFrame, range.startFrame + easeFrames],
    [0, 1],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
  );
  const exit = interpolate(
    frame,
    [range.endFrame - easeFrames, range.endFrame],
    [1, 0],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
  );
  return Math.min(enter, exit);
};

const isActive = (frame: number, range: FrameRange) =>
  frame >= range.startFrame && frame < range.endFrame;

const BroadcastBrand: React.FC<{manifest: EditManifest}> = ({manifest}) => {
  return (
    <>
      <div
        style={{
          position: 'absolute',
          left: 14,
          top: 12,
          display: 'flex',
          alignItems: 'center',
          gap: 8,
          height: 42,
          padding: '4px 13px 5px 8px',
          borderRadius: 22,
          background: 'rgba(255,255,255,0.96)',
          border: `2px solid ${gold}`,
          boxShadow: '0 3px 13px rgba(63,25,19,0.26)',
          fontFamily: fontStack,
          fontSynthesis: 'none',
          zIndex: 20,
        }}
      >
        <span
          style={{
            width: 28,
            height: 28,
            borderRadius: '50%',
            display: 'grid',
            placeItems: 'center',
            color: 'white',
            background: `linear-gradient(145deg, ${coral}, ${wine})`,
            fontSize: 15,
            fontWeight: 700,
          }}
        >
          ゆ
        </span>
        <span
          style={{
            color: wine,
            fontSize: 20,
            fontWeight: 700,
            letterSpacing: '0.015em',
            whiteSpace: 'nowrap',
          }}
        >
          {manifest.brand.name}
        </span>
      </div>
      <div
        style={{
          position: 'absolute',
          right: 15,
          top: 13,
          padding: '7px 14px 8px',
          borderRadius: 5,
          background: coral,
          color: 'white',
          fontFamily: fontStack,
          fontSize: 17,
          lineHeight: 1,
          fontWeight: 700,
          letterSpacing: '0.08em',
          boxShadow: '0 3px 12px rgba(83,21,22,0.34)',
          zIndex: 20,
        }}
      >
        {manifest.brand.cornerLabel}
      </div>
    </>
  );
};

const IntroCard: React.FC<{manifest: EditManifest; range: FrameRange}> = ({
  manifest,
  range,
}) => {
  const frame = useCurrentFrame();
  const opacity = rangeOpacity(frame, range, 5);
  const y = interpolate(opacity, [0, 1], [18, 0]);
  return (
    <div
      style={{
        position: 'absolute',
        left: 34,
        right: 34,
        bottom: 26,
        transform: `translateY(${y}px)`,
        opacity,
        padding: '14px 24px 15px',
        borderRadius: 7,
        borderTop: `5px solid ${gold}`,
        background: 'linear-gradient(90deg, rgba(75,12,36,0.96), rgba(130,28,53,0.94))',
        boxShadow: '0 6px 22px rgba(0,0,0,0.36)',
        color: 'white',
        textAlign: 'center',
        fontFamily: fontStack,
        fontSynthesis: 'none',
      }}
    >
      <div style={{fontSize: 14, fontWeight: 600, letterSpacing: '0.2em'}}>
        窓際族公認・本日の目玉商品
      </div>
      <div
        style={{
          marginTop: 4,
          fontSize: 31,
          lineHeight: 1.2,
          fontWeight: 700,
          letterSpacing: '0.02em',
        }}
      >
        {manifest.product.name}
      </div>
    </div>
  );
};

const FeatureBadges: React.FC<{manifest: EditManifest; range: FrameRange}> = ({
  manifest,
  range,
}) => {
  const frame = useCurrentFrame();
  const opacity = rangeOpacity(frame, range);
  return (
    <div
      style={{
        position: 'absolute',
        left: 20,
        top: 78,
        display: 'flex',
        flexDirection: 'column',
        gap: 8,
        opacity,
        fontFamily: fontStack,
        fontSynthesis: 'none',
      }}
    >
      {manifest.product.claims.map((claim, index) => (
        <div
          key={claim}
          style={{
            transform: `translateX(${interpolate(opacity, [0, 1], [-24 - index * 6, 0])}px)`,
            padding: '7px 14px 8px',
            borderRadius: 4,
            background: index === 0 ? wine : 'rgba(255,252,243,0.95)',
            color: index === 0 ? 'white' : ink,
            border: index === 0 ? 'none' : `2px solid ${gold}`,
            boxShadow: '0 3px 10px rgba(0,0,0,0.26)',
            fontSize: 18,
            lineHeight: 1,
            fontWeight: 700,
            letterSpacing: '0.02em',
          }}
        >
          {claim}
        </div>
      ))}
      <div style={{display: 'flex', gap: 6}}>
        {[manifest.product.height, manifest.product.weight].map((item) => (
          <div
            key={item}
            style={{
              padding: '6px 10px',
              borderRadius: 4,
              background: 'rgba(42,25,27,0.88)',
              color: 'white',
              fontSize: 15,
              fontWeight: 600,
            }}
          >
            {item}
          </div>
        ))}
      </div>
    </div>
  );
};

const PresidentTag: React.FC<{text: string; range: FrameRange}> = ({text, range}) => {
  const frame = useCurrentFrame();
  const opacity = rangeOpacity(frame, range);
  return (
    <div
      style={{
        position: 'absolute',
        right: 22,
        bottom: 93,
        opacity,
        padding: '8px 14px 9px',
        borderRadius: 4,
        borderLeft: `6px solid ${gold}`,
        background: 'rgba(255,255,255,0.94)',
        color: ink,
        boxShadow: '0 4px 13px rgba(0,0,0,0.28)',
        fontFamily: fontStack,
        fontSynthesis: 'none',
        fontSize: 17,
        fontWeight: 600,
      }}
    >
      {text}
    </div>
  );
};

const PriceReveal: React.FC<{manifest: EditManifest; range: FrameRange}> = ({
  manifest,
  range,
}) => {
  const frame = useCurrentFrame();
  const opacity = rangeOpacity(frame, range, 5);
  const local = frame - range.startFrame;
  const scale = interpolate(local, [0, 8, 14], [0.72, 1.08, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  return (
    <div
      style={{
        position: 'absolute',
        left: 158,
        right: 158,
        top: 89,
        opacity,
        transform: `scale(${scale})`,
        padding: '19px 26px 22px',
        borderRadius: 12,
        border: `4px solid ${gold}`,
        background: 'rgba(255,252,242,0.97)',
        boxShadow: '0 10px 32px rgba(45,10,24,0.42)',
        color: ink,
        textAlign: 'center',
        fontFamily: fontStack,
        fontSynthesis: 'none',
        zIndex: 12,
      }}
    >
      <div style={{fontSize: 17, fontWeight: 600, letterSpacing: '0.08em'}}>
        メーカー通常価格
        <span
          style={{
            marginLeft: 10,
            color: '#6c6262',
            textDecoration: 'line-through',
            textDecorationThickness: 2,
          }}
        >
          {manifest.product.regularPrice}
        </span>
      </div>
      <div
        style={{
          marginTop: 7,
          color: coral,
          fontSize: 20,
          fontWeight: 700,
        }}
      >
        本日限り
      </div>
      <div
        style={{
          marginTop: -2,
          color: wine,
          fontSize: 53,
          lineHeight: 1.12,
          fontWeight: 700,
          letterSpacing: '0.01em',
          fontVariantNumeric: 'tabular-nums',
        }}
      >
        {manifest.product.todayPrice}
      </div>
    </div>
  );
};

const SmallPriceBug: React.FC<{price: string; visible: boolean}> = ({
  price,
  visible,
}) => (
  <div
    style={{
      position: 'absolute',
      right: 15,
      top: 54,
      opacity: visible ? 1 : 0,
      padding: '7px 12px 8px',
      borderRadius: 5,
      border: `2px solid ${gold}`,
      background: 'rgba(255,253,246,0.96)',
      color: wine,
      fontFamily: fontStack,
      fontSynthesis: 'none',
      fontSize: 22,
      fontWeight: 700,
      fontVariantNumeric: 'tabular-nums',
      boxShadow: '0 3px 10px rgba(0,0,0,0.24)',
      zIndex: 19,
    }}
  >
    <span style={{fontSize: 12, color: coral, marginRight: 7}}>本日価格</span>
    {price}
  </div>
);

const ComparisonTag: React.FC<{text: string; range: FrameRange}> = ({
  text,
  range,
}) => {
  const frame = useCurrentFrame();
  const opacity = rangeOpacity(frame, range);
  return (
    <div
      style={{
        position: 'absolute',
        left: 20,
        top: 67,
        opacity,
        padding: '7px 18px 8px',
        borderRadius: 5,
        background: 'rgba(123,23,53,0.92)',
        borderBottom: `3px solid ${gold}`,
        color: 'white',
        fontFamily: fontStack,
        fontSynthesis: 'none',
        fontSize: 24,
        lineHeight: 1,
        fontWeight: 700,
        letterSpacing: '0.02em',
        whiteSpace: 'nowrap',
        boxShadow: '0 3px 10px rgba(0,0,0,0.26)',
        pointerEvents: 'none',
      }}
    >
      {text}
    </div>
  );
};

const CaptionLayer: React.FC<{caption: Caption}> = ({caption}) => {
  const emphasis = caption.emphasis;
  const baseText = emphasis ? caption.text.replace(emphasis, '') : caption.text;
  return (
    <div
      style={{
        position: 'absolute',
        left: 18,
        right: 18,
        bottom: 12,
        minHeight: 61,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '8px 18px 9px',
        borderRadius: 7,
        borderTop: `3px solid ${gold}`,
        background: 'linear-gradient(90deg, rgba(38,18,24,0.94), rgba(83,19,43,0.94))',
        color: 'white',
        textAlign: 'center',
        fontFamily: fontStack,
        fontSynthesis: 'none',
        fontSize: caption.speaker === 'そば屋' ? 31 : 25,
        lineHeight: 1.22,
        fontWeight: 600,
        letterSpacing: '0.01em',
        textShadow: '0 2px 5px rgba(0,0,0,0.6)',
        WebkitFontSmoothing: 'antialiased',
        textRendering: 'geometricPrecision',
        zIndex: 30,
      }}
    >
      <span style={{whiteSpace: 'nowrap'}}>
        {baseText}
        {emphasis ? (
          <span
            style={{
              display: 'inline-block',
              marginLeft: 3,
              padding: '1px 7px 2px',
              borderRadius: 6,
              background: coral,
              color: '#fff7b8',
              fontSize: 31,
              fontWeight: 700,
              transform: 'rotate(-3deg) translateY(-2px)',
              boxShadow: '0 2px 0 #7a122d',
            }}
          >
            {emphasis}
          </span>
        ) : null}
      </span>
    </div>
  );
};

export const EditComposition: React.FC<{manifest: EditManifest}> = ({manifest}) => {
  const frame = useCurrentFrame();
  const {durationInFrames} = useVideoConfig();
  const activeCaption = manifest.captions.find(
    (caption) => frame >= caption.startFrame && frame < caption.endFrame,
  );
  const c = manifest.cues;
  const showPriceBug = frame >= c.priceReveal.endFrame && frame < durationInFrames;
  return (
    <AbsoluteFill style={{backgroundColor: '#000', overflow: 'hidden'}}>
      <Video
        src={staticFile(manifest.inputVideo)}
        muted
        volume={0}
        objectFit="cover"
        style={{width: '100%', height: '100%'}}
      />
      <Html5Audio src={staticFile(manifest.replacementAudio)} />

      <IntroCard manifest={manifest} range={c.intro} />
      {isActive(frame, c.features) ? (
        <FeatureBadges manifest={manifest} range={c.features} />
      ) : null}
      {isActive(frame, c.president) ? (
        <PresidentTag text={manifest.product.presidentTitle} range={c.president} />
      ) : null}
      {isActive(frame, c.priceReveal) ? (
        <PriceReveal manifest={manifest} range={c.priceReveal} />
      ) : null}
      {isActive(frame, c.comparison) ? (
        <ComparisonTag text={manifest.product.matchRate} range={c.comparison} />
      ) : null}
      {isActive(frame, c.disclaimer) ? (
        <div
          style={{
            position: 'absolute',
            left: '50%',
            bottom: 20,
            transform: 'translateX(-50%)',
            opacity: rangeOpacity(frame, c.disclaimer),
            padding: '6px 13px 7px',
            borderRadius: 4,
            background: 'rgba(20,20,20,0.76)',
            color: 'white',
            fontFamily: fontStack,
            fontSize: 14,
            fontWeight: 500,
            whiteSpace: 'nowrap',
          }}
        >
          {manifest.product.disclaimer}
        </div>
      ) : null}
      {isActive(frame, c.final) ? (
        <div
          style={{
            position: 'absolute',
            left: '50%',
            top: '50%',
            transform: `translate(-50%, -50%) scale(${interpolate(
              frame,
              [c.final.startFrame, c.final.startFrame + 7],
              [0.72, 1],
              {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
            )})`,
            padding: '12px 30px 14px',
            borderRadius: 8,
            border: `4px solid ${gold}`,
            background: 'rgba(123,23,53,0.96)',
            color: 'white',
            boxShadow: '0 8px 28px rgba(0,0,0,0.45)',
            fontFamily: fontStack,
            fontSynthesis: 'none',
            fontSize: 46,
            lineHeight: 1,
            fontWeight: 700,
            letterSpacing: '0.04em',
          }}
        >
          {manifest.product.stock}
        </div>
      ) : null}

      <BroadcastBrand manifest={manifest} />
      <SmallPriceBug price={manifest.product.todayPrice} visible={showPriceBug} />
      {activeCaption ? <CaptionLayer caption={activeCaption} /> : null}
    </AbsoluteFill>
  );
};
