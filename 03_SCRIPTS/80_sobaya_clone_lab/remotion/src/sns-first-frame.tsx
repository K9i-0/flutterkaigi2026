import React from 'react';
import {AbsoluteFill, Composition, Img, OffthreadVideo, registerRoot, staticFile, useCurrentFrame} from 'remotion';
import m from './sns-first-frame.json';

const SnsFilm: React.FC = () => {
  const frame = useCurrentFrame();
  return <AbsoluteFill style={{backgroundColor: 'black'}}>
    <OffthreadVideo muted src={staticFile(m.publicSource)} style={{width: '100%', height: '100%'}}/>
    {frame === 0 && <AbsoluteFill><Img src={staticFile(m.thumbnail)} style={{width: '100%', height: '100%'}}/></AbsoluteFill>}
  </AbsoluteFill>;
};

registerRoot(() => <Composition id="CloneLabSns" component={SnsFilm} width={m.width} height={m.height} fps={m.fps} durationInFrames={m.durationInFrames}/>);
