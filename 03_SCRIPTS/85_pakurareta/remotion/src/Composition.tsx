import {AbsoluteFill, Html5Audio, OffthreadVideo, staticFile} from 'remotion';
import type {EditManifest} from './types';
export const EditComposition: React.FC<{manifest: EditManifest}> = ({manifest}) => <AbsoluteFill>
  <OffthreadVideo src={staticFile(manifest.inputVideo)} muted style={{width:'100%',height:'100%'}} />
  {manifest.replacementAudio && <Html5Audio src={staticFile(manifest.replacementAudio)} />}
</AbsoluteFill>;
