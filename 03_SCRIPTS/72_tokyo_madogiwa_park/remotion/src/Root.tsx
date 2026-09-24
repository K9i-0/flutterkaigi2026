import {Composition} from 'remotion';
import revisionV2 from './edit-manifest-revision-v2.json';
import revision from './edit-manifest-revision.json';
import manifest from './edit-manifest.json';
import reordered from './edit-manifest-reordered.json';
import {EditComposition} from './Composition';
import {CommercialEnding} from './CommercialEnding';
import commercialTiming from './commercial-timing.json';
import {VoicePatchLab} from './VoicePatchLab';
export const RemotionRoot = () => <><Composition id={manifest.composition.id} component={EditComposition}
  width={manifest.composition.width} height={manifest.composition.height} fps={manifest.composition.fps}
  durationInFrames={manifest.composition.durationInFrames} />
  <Composition id="VoicePatchLab" component={VoicePatchLab} width={854} height={480} fps={30} durationInFrames={310} />
  <Composition id="MadogiwaReordered12543" component={EditComposition} defaultProps={{edit: reordered}} width={854} height={480} fps={30} durationInFrames={900} />
  <Composition id="MadogiwaCommercial" component={CommercialEnding} width={854} height={480} fps={30} durationInFrames={900 + commercialTiming.duration} />
  <Composition id="MadogiwaRevision" component={CommercialEnding} defaultProps={{edit: revision}} width={854} height={480} fps={30} durationInFrames={revision.composition.durationInFrames + commercialTiming.duration} />
  <Composition id="MadogiwaRevisionV2" component={CommercialEnding} defaultProps={{edit: revisionV2}} width={854} height={480} fps={30} durationInFrames={revisionV2.composition.durationInFrames + commercialTiming.duration} />
</>;
