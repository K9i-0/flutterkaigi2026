import './style.css';
import {Composition} from 'remotion';
import manifestJson from './edit-manifest.json';
import surveillanceManifestJson from './surveillance-manifest.json';
import {EditComposition} from './Composition';
import {
  SurveillanceComposition,
  type SurveillanceManifest,
} from './SurveillanceComposition';
import type {EditManifest} from './types';

const manifest = manifestJson as EditManifest;
const surveillanceManifest = surveillanceManifestJson as SurveillanceManifest;

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id={manifest.composition.id}
        component={EditComposition}
        width={manifest.composition.width}
        height={manifest.composition.height}
        fps={manifest.composition.fps}
        durationInFrames={manifest.composition.durationInFrames}
        defaultProps={{manifest}}
      />
      <Composition
        id={surveillanceManifest.composition.id}
        component={SurveillanceComposition}
        width={surveillanceManifest.composition.width}
        height={surveillanceManifest.composition.height}
        fps={surveillanceManifest.composition.fps}
        durationInFrames={surveillanceManifest.composition.durationInFrames}
        defaultProps={{manifest: surveillanceManifest}}
      />
    </>
  );
};
