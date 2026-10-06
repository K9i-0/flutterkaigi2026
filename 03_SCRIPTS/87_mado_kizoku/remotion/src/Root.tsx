import './style.css';
import {Composition} from 'remotion';
import manifest from './edit-manifest.json';
import part1 from './part1-manifest.json';
import {Part1, FullFilm} from './Part1';
import {EditComposition} from './Composition';
export const RemotionRoot: React.FC = () => <><Composition id={manifest.composition.id} component={EditComposition} width={1280} height={720} fps={30} durationInFrames={manifest.composition.durationInFrames} /><Composition id="MadoKizokuPart1" component={Part1} width={1280} height={720} fps={30} durationInFrames={part1.composition.durationInFrames}/><Composition id="MadoKizokuFull" component={FullFilm} width={1280} height={720} fps={30} durationInFrames={part1.composition.durationInFrames+45+663+12+60}/></>;
