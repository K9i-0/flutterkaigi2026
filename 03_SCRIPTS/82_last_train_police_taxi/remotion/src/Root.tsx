import {Composition} from 'remotion';
import data from './edit-manifest.json';
import {EditComposition} from './Composition';
export const RemotionRoot: React.FC = () => <Composition
 id={data.composition.id} component={EditComposition}
 width={data.composition.width} height={data.composition.height}
 fps={data.composition.fps} durationInFrames={data.composition.durationInFrames} />;
