import {Video} from '@remotion/media';
import {AbsoluteFill, Sequence, staticFile, useCurrentFrame} from 'remotion';
import manifest from './edit-manifest.json';
export const EditComposition: React.FC = () => {
  const frame = useCurrentFrame();
  const reframe = manifest.reframes.find(r => frame >= r.startFrame && frame < r.endFrame);
  return <AbsoluteFill style={{backgroundColor: '#000', overflow: 'hidden'}}>
  {manifest.clips.map(clip => <Sequence key={clip.file} from={clip.from} durationInFrames={clip.duration}>
    <Video src={staticFile(clip.file)} trimBefore={clip.trimBefore} volume={1} style={{width: '100%', height: '100%', transform: `scale(${reframe?.scale ?? 1})`, transformOrigin: reframe?.origin ?? 'center'}} objectFit="contain" />
  </Sequence>)}
</AbsoluteFill>;
};
