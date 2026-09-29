import {registerRoot,Composition} from 'remotion';
import {Film,NoJobsFilm,LargeFilm} from './Film';
import manifest from './edit-manifest.json';
import nojobs from './edit-manifest-nojobs.json';
import large from './edit-manifest-large.json';
registerRoot(()=> <><Composition id='MadogiwaKeynote' component={Film} width={1280} height={720} fps={24} durationInFrames={manifest.durationInFrames}/><Composition id='MadogiwaNoJobs' component={NoJobsFilm} width={1280} height={720} fps={24} durationInFrames={nojobs.durationInFrames}/><Composition id='MadogiwaKeynoteLarge' component={LargeFilm} width={1280} height={720} fps={24} durationInFrames={large.durationInFrames}/></>);
