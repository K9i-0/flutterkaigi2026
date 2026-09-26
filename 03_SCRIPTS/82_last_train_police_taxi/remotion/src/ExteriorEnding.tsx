import React from 'react';
import {AbsoluteFill, Audio, OffthreadVideo, Sequence, interpolate, staticFile} from 'remotion';
import e from './ending-edit.json';
export const ExteriorEnding: React.FC = () => <AbsoluteFill>
 <Sequence durationInFrames={e.cutFrame}>
  <OffthreadVideo src={staticFile(e.inputVideo)} muted />
 </Sequence>
 <Sequence from={e.cutFrame} durationInFrames={e.exteriorDurationFrames}>
  <OffthreadVideo src={staticFile(e.inputVideo)} muted
   startFrom={e.exteriorSourceStartFrame} endAt={e.exteriorSourceEndFrame}
   playbackRate={(e.exteriorSourceEndFrame-e.exteriorSourceStartFrame)/e.exteriorDurationFrames} />
 </Sequence>
 <Audio src={staticFile(e.inputVideo)}
  volume={frame => interpolate(frame,[0,e.audioFadeStartFrame,e.audioEndFrame],[1,1,0],{extrapolateRight:'clamp'})} />
</AbsoluteFill>;
