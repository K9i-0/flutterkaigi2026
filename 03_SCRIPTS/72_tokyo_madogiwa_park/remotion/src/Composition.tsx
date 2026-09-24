import {AbsoluteFill, OffthreadVideo, Html5Audio, Sequence, staticFile} from 'remotion';
import manifest from './edit-manifest.json';
type AudioInsert = {src: string; from: number; duration: number; volume: number};
type EditManifest = Omit<typeof manifest, "audioInserts"> & {audioInserts: AudioInsert[]};
export const EditComposition = ({edit = manifest}: {edit?: EditManifest}) => <AbsoluteFill style={{backgroundColor: 'black'}}>
  {edit.segments.map((segment) => <Sequence key={segment.from} from={segment.from} durationInFrames={segment.duration}>
    <OffthreadVideo src={staticFile(segment.src)} trimBefore={segment.trimBefore} muted={segment.muted} style={{width: '100%', height: '100%'}} />
  </Sequence>)}
  {edit.audioInserts.map((clip) => <Sequence key={clip.from} from={clip.from} durationInFrames={clip.duration}>
    <Html5Audio src={staticFile(clip.src)} volume={clip.volume} />
  </Sequence>)}
</AbsoluteFill>;
