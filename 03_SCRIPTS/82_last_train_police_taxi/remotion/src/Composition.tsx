import React from 'react';
import {AbsoluteFill, Audio, OffthreadVideo, Sequence, interpolate, staticFile} from 'remotion';
import data from './edit-manifest.json';

export const EditComposition: React.FC = () => {
 const s = data.siren;
 return <AbsoluteFill>
  <OffthreadVideo src={staticFile(data.inputVideo)} volume={1} />
  <Sequence from={s.startFrame} durationInFrames={s.endFrame-s.startFrame}>
   <Audio src={staticFile(s.file)} loop loopVolumeCurveBehavior="extend"
    volume={(frame) => interpolate(frame, s.volumeFrames, s.volumes,
     {extrapolateLeft:'clamp',extrapolateRight:'clamp'})} />
  </Sequence>
 </AbsoluteFill>;
};
