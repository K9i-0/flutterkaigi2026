import './style.css';
import {Composition} from 'remotion';
import manifestJson from './edit-manifest.json';
import {BakiGuardianScene} from './BakiGuardianScene';
import type {EditManifest} from './types';

const manifest = manifestJson as EditManifest;

export const RemotionRoot: React.FC = () => {
  return (
    <Composition
      id={manifest.composition.id}
      component={BakiGuardianScene}
      width={manifest.composition.width}
      height={manifest.composition.height}
      fps={manifest.composition.fps}
      durationInFrames={manifest.composition.durationInFrames}
    />
  );
};
