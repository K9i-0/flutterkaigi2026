import {Composition, registerRoot} from 'remotion';
import {Turntable} from './turntable';
import manifest from './edit-manifest.json';
import {RigMotionPreview} from './rig-preview';
import rigManifest from './rig-manifest.json';

const Root = () => (
  <><Composition
    id={manifest.composition.id}
    component={Turntable}
    width={manifest.composition.width}
    height={manifest.composition.height}
    fps={manifest.composition.fps}
    durationInFrames={manifest.composition.durationInFrames}
  /><Composition
    id={rigManifest.composition.id}
    component={RigMotionPreview}
    width={rigManifest.composition.width}
    height={rigManifest.composition.height}
    fps={rigManifest.composition.fps}
    durationInFrames={rigManifest.composition.durationInFrames}
  /></>
);

registerRoot(Root);
