import {registerRoot,Composition} from 'remotion';
import {Film} from './Film';
import manifest from './edit-manifest.json';
registerRoot(()=> <Composition id='MadogiwaKeynote' component={Film} width={1280} height={720} fps={24} durationInFrames={manifest.durationInFrames}/>);
