import React from 'react';
import {
  AbsoluteFill,
  Audio,
  Img,
  interpolate,
  Sequence,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';
import {Video} from '@remotion/media';

interface CaptionItem {
  id: string;
  image: string;
  voice?: string;
  se?: string;
  startFrame: number;
  endFrame: number;
  top: number;
  right?: number;
  left?: number;
  height: number;
  popScale?: number;
}

const CAPTION_CUES: CaptionItem[] = [
  // 1コマ目相当 (54f ~ 235f / 1.8s ~ 7.8s)
  {
    id: 'yametaro',
    image: 'captions/caption_01_yametaro.png',
    voice: 'audio/sobaya_01_yametaro.wav',
    se: 'audio/se_impact_deep.wav',
    startFrame: 54, // 1.8s
    endFrame: 235,
    top: 50,
    right: 70,
    height: 180,
  },
  {
    id: 'fukuchan',
    image: 'captions/caption_02_fukuchan.png',
    voice: 'audio/sobaya_02_fukuchan.wav',
    se: 'audio/se_impact_deep.wav',
    startFrame: 110, // 3.66s
    endFrame: 235,
    top: 50,
    right: 175,
    height: 300,
  },
  {
    id: 'tokun',
    image: 'captions/caption_03_tokun.png',
    voice: 'audio/sobaya_03_tokun.wav',
    se: 'audio/se_impact_deep.wav',
    startFrame: 165, // 5.5s
    endFrame: 235,
    top: 50,
    left: 80,
    height: 300,
  },

  // 2コマ目相当 (238f ~ 335f / 7.9s ~ 11.1s)
  {
    id: 'ina',
    image: 'captions/caption_04_ina.png',
    voice: 'audio/sobaya_04_ina.wav',
    se: 'audio/se_impact_sharp.wav',
    startFrame: 240, // 8.0s
    endFrame: 335,
    top: 60,
    right: 180,
    height: 100,
    popScale: 1.5,
  },
  {
    id: 'okayaman',
    image: 'captions/caption_05_okayaman.png',
    voice: 'audio/sobaya_05_okayaman.wav',
    se: 'audio/se_impact_deep.wav',
    startFrame: 265, // 8.83s
    endFrame: 335,
    top: 60,
    right: 70,
    height: 360,
  },

  // 3コマ目相当 (340f ~ 450f / 11.3s ~ 15.0s)
  {
    id: 'orega',
    image: 'captions/caption_06_orega.png',
    voice: 'audio/sobaya_06_orega.wav',
    se: 'audio/se_impact_deep.wav',
    startFrame: 345, // 11.5s
    endFrame: 450,
    top: 70,
    left: 175,
    height: 140,
  },
  {
    id: 'mamoraneba',
    image: 'captions/caption_07_mamoraneba.png',
    voice: 'audio/sobaya_07_mamoraneba.wav',
    se: 'audio/se_impact_deep.wav',
    startFrame: 375, // 12.5s
    endFrame: 450,
    top: 70,
    left: 80,
    height: 310,
    popScale: 1.4,
  },
  {
    id: 'naranu',
    image: 'captions/caption_08_naranu.png',
    voice: 'audio/sobaya_08_naranu.wav',
    se: 'audio/se_impact_deep.wav',
    startFrame: 405, // 13.5s
    endFrame: 450,
    top: 200,
    left: 20,
    height: 180,
    popScale: 1.3,
  },
];

export const BakiGuardianScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();

  // Subtle camera shake on heavy impact cues
  let shakeX = 0;
  let shakeY = 0;
  for (const cue of CAPTION_CUES) {
    if (cue.se && frame >= cue.startFrame && frame < cue.startFrame + 8) {
      const offset = frame - cue.startFrame;
      const decay = (8 - offset) / 8;
      shakeX += Math.sin(offset * 3) * 4 * decay;
      shakeY += Math.cos(offset * 3) * 3 * decay;
    }
  }

  return (
    <AbsoluteFill
      style={{
        backgroundColor: '#000',
        transform: `translate(${shakeX}px, ${shakeY}px)`,
        overflow: 'hidden',
      }}
    >
      {/* Background Video */}
      <AbsoluteFill>
        <Video
          src={staticFile('input.mp4')}
          volume={0.8}
          style={{
            width: '100%',
            height: '100%',
            objectFit: 'cover',
          }}
        />
      </AbsoluteFill>

      {/* Vignette / Edge Shadow for dramatic tension */}
      <AbsoluteFill
        style={{
          background:
            'radial-gradient(ellipse at center, rgba(0,0,0,0) 50%, rgba(0,0,0,0.6) 100%)',
          pointerEvents: 'none',
        }}
      />

      {/* Captions and Sound Effects */}
      {CAPTION_CUES.map((cue) => {
        const isVisible = frame >= cue.startFrame && frame <= cue.endFrame;

        const progress = spring({
          frame: frame - cue.startFrame,
          fps,
          config: {
            damping: 14,
            mass: 0.6,
            stiffness: 220,
          },
        });

        const popMultiplier = cue.popScale ?? 1.25;
        const scale = interpolate(progress, [0, 1], [popMultiplier, 1]);
        const opacity = interpolate(progress, [0, 0.4], [0, 1], {
          extrapolateRight: 'clamp',
        });

        // Fade out near endFrame if not the final scene
        let exitOpacity = 1;
        if (cue.endFrame < 450 && frame > cue.endFrame - 6) {
          exitOpacity = interpolate(frame, [cue.endFrame - 6, cue.endFrame], [1, 0], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
          });
        }

        return (
          <React.Fragment key={cue.id}>
            {isVisible && (
              <div
                style={{
                  position: 'absolute',
                  top: cue.top,
                  ...(cue.right !== undefined ? {right: cue.right} : {}),
                  ...(cue.left !== undefined ? {left: cue.left} : {}),
                  transform: `scale(${scale})`,
                  transformOrigin: 'top center',
                  opacity: opacity * exitOpacity,
                  filter:
                    'drop-shadow(0px 0px 8px rgba(0,0,0,0.95)) drop-shadow(0px 4px 16px rgba(0,0,0,0.85))',
                  zIndex: 10,
                }}
              >
                <Img
                  src={staticFile(cue.image)}
                  style={{
                    height: cue.height,
                    width: 'auto',
                    display: 'block',
                  }}
                />
              </div>
            )}

            {/* Audio: Dialogue with Sequence */}
            {cue.voice && (
              <Sequence
                from={cue.startFrame}
                durationInFrames={Math.max(1, cue.endFrame - cue.startFrame)}
              >
                <Audio src={staticFile(cue.voice)} volume={1.4} />
              </Sequence>
            )}

            {/* Audio: Impact SE with Sequence */}
            {cue.se && (
              <Sequence from={cue.startFrame} durationInFrames={45}>
                <Audio src={staticFile(cue.se)} volume={1.5} />
              </Sequence>
            )}
          </React.Fragment>
        );
      })}
    </AbsoluteFill>
  );
};
