import {Composition, registerRoot} from 'remotion';
import {Turntable} from './turntable';
import manifest from './edit-manifest.json';
const Root = () => <Composition id="OkayamanTurntable" component={Turntable} {...manifest.composition}/>;
registerRoot(Root);
