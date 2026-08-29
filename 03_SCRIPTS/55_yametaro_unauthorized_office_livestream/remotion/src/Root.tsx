import './style.css';
import {Composition} from 'remotion';
import manifestJson from './edit-manifest.json';
import {EditComposition, MonitorScreenSource} from './Composition';
import type {EditManifest} from './types';

const manifest = manifestJson as EditManifest;
const greenMonitorManifest: EditManifest = {
  ...manifest,
  videoInserts: [
    manifest.videoInserts[0],
    manifest.greenMonitorTest.insert,
    manifest.greenMonitorTest.returnInsert,
  ],
};

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
        defaultProps={{manifest, monitorBackend: 'remotion' as const}}
      />
      <Composition
        id="YameChannelLiveOpenCV"
        component={EditComposition}
        width={manifest.composition.width}
        height={manifest.composition.height}
        fps={manifest.composition.fps}
        durationInFrames={manifest.composition.durationInFrames}
        defaultProps={{manifest, monitorBackend: 'opencv' as const}}
      />
      <Composition
        id="YameChannelLiveGreenMonitor"
        component={EditComposition}
        width={manifest.composition.width}
        height={manifest.composition.height}
        fps={manifest.composition.fps}
        durationInFrames={manifest.composition.durationInFrames}
        defaultProps={{manifest: greenMonitorManifest, monitorBackend: 'green' as const}}
      />
      <Composition
        id="MonitorScreenSource"
        component={MonitorScreenSource}
        width={1000}
        height={600}
        fps={manifest.composition.fps}
        durationInFrames={1}
        defaultProps={{text: manifest.monitorScreen.text}}
      />
    </>
  );
};
