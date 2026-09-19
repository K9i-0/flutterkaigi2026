import React from 'react';
import {AbsoluteFill,OffthreadVideo,Sequence,staticFile,interpolate} from 'remotion';
import {Effects} from './Effects';
import {RoadWarning} from './RoadWarning';
import m from './wrap-manifest.json';
export const StoryCM:React.FC=()=> <AbsoluteFill style={{backgroundColor:'#05080d'}}>
<Sequence durationInFrames={m.introFrames}><OffthreadVideo src={staticFile(m.insertVideo)} style={{width:'100%',height:'100%'}}/></Sequence>
<Sequence from={m.signStartFrame} durationInFrames={m.signDurationFrames}><RoadWarning/></Sequence>
<Sequence from={m.introFrames} durationInFrames={m.mainFrames}><OffthreadVideo src={staticFile(m.mainVideo)} volume={f=>interpolate(f,[441,449],[1,0],{extrapolateLeft:'clamp',extrapolateRight:'clamp'})} style={{width:'100%',height:'100%'}}/></Sequence>
<Sequence from={m.introFrames+m.mainFrames} durationInFrames={m.outroFrames}><OffthreadVideo src={staticFile(m.insertVideo)} startFrom={m.introFrames} style={{width:'100%',height:'100%'}}/></Sequence>
<Sequence from={m.endcardStartFrame} durationInFrames={150}><div style={{position:'absolute',width:1920,height:1080,transform:'scale(0.4447916667,0.4444444444)',transformOrigin:'top left'}}><Effects mode="B" titleImage="titles/title_meme.png" notice/></div></Sequence>
</AbsoluteFill>;
