import './style.css';
import {Composition} from 'remotion';
import manifest from './edit-manifest.json';
import {EditComposition} from './Composition';
export const RemotionRoot = () => <Composition {...manifest.composition} component={EditComposition}/>;
