import React from 'react';
import {AbsoluteFill, Img, OffthreadVideo, staticFile, useCurrentFrame} from 'remotion';
import edit from './first-frame.json';

export const FirstFrameFilm = () => {
  const frame = useCurrentFrame();
  return <AbsoluteFill>
    <OffthreadVideo src={staticFile(edit.inputVideo)} muted />
    {frame === edit.replacementFrame && <AbsoluteFill>
      <Img src={staticFile(edit.image)} style={{width: '100%', height: '100%'}} />
    </AbsoluteFill>}
  </AbsoluteFill>;
};
