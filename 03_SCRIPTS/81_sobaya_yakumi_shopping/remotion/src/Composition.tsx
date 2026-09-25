import {Video} from '@remotion/media';
import {AbsoluteFill, Sequence, staticFile} from 'remotion';
import manifest from './edit-manifest.json';
export const EditComposition: React.FC = () => <AbsoluteFill style={{backgroundColor: '#000'}}>
  {manifest.clips.map(clip => <Sequence key={clip.file} from={clip.from} durationInFrames={clip.duration}>
    <Video src={staticFile(clip.file)} trimBefore={clip.trimBefore} volume={1} style={{width: '100%', height: '100%'}} objectFit="contain" />
  </Sequence>)}
</AbsoluteFill>;
