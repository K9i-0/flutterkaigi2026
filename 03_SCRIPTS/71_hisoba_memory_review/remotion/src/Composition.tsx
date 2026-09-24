import {Video} from '@remotion/media';
import {AbsoluteFill, staticFile, useCurrentFrame} from 'remotion';
import type {EditManifest} from './types';

export const EditComposition: React.FC<{manifest: EditManifest}> = ({manifest}) => {
  const frame = useCurrentFrame();
  const caption = manifest.captions.find(c => frame >= c.startFrame && frame < c.endFrame);
  const opacity = caption ? Math.min(1, (frame - caption.startFrame + 1) / 4, (caption.endFrame - frame) / 4) : 0;
  return <AbsoluteFill style={{backgroundColor: '#000'}}>
    <Video src={staticFile(manifest.inputVideo)} volume={1} style={{width: '100%', height: '100%'}} objectFit="contain" />
    {caption ? <div style={{position: 'absolute', left: '5%', right: '5%', bottom: 38,
      textAlign: 'center', whiteSpace: 'pre-line', color: '#fff', opacity,
      fontFamily: '"Hiragino Sans", "Yu Gothic", sans-serif', fontWeight: 600,
      fontSynthesis: 'none', fontSize: 28, lineHeight: 1.35, letterSpacing: '0.01em',
      WebkitTextStroke: '1.6px rgba(0,0,0,0.95)', paintOrder: 'stroke fill',
      textShadow: '0 2px 5px #000', WebkitFontSmoothing: 'antialiased', textRendering: 'geometricPrecision',
    }}>{caption.text}</div> : null}
  </AbsoluteFill>;
};
