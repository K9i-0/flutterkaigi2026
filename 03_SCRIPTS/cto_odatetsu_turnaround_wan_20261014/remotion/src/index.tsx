import {Composition, registerRoot} from 'remotion';
import {Turntable} from './turntable';
import manifest from './edit-manifest.json';

const Root = () => (
  <Composition
    id={manifest.composition.id}
    component={Turntable}
    width={manifest.composition.width}
    height={manifest.composition.height}
    fps={manifest.composition.fps}
    durationInFrames={manifest.composition.durationInFrames}
  />
);

registerRoot(Root);
