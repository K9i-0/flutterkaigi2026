import React from 'react';
import {AbsoluteFill,Composition,OffthreadVideo,Sequence,registerRoot,staticFile,interpolate} from 'remotion';
import {Effects} from './Effects';
import m from './edit-manifest.json';
import w from './wrap-manifest.json';
import {StoryCM} from './StoryCM';
import {RoadWarning} from './RoadWarning';
const CM:React.FC=()=> <AbsoluteFill style={{backgroundColor:'#05080d'}}>
<Sequence durationInFrames={m.endcardStartFrame}><OffthreadVideo src={staticFile(m.inputVideo)} volume={f=>interpolate(f,[m.mainAudioFadeStartFrame,m.endcardStartFrame-1],[1,0],{extrapolateLeft:'clamp',extrapolateRight:'clamp'})} style={{width:'100%',height:'100%'}}/></Sequence>
<Sequence from={m.endcardStartFrame} durationInFrames={m.composition.durationInFrames-m.endcardStartFrame}><div style={{position:'absolute',width:1920,height:1080,transform:`scale(${m.composition.width/1920},${m.composition.height/1080})`,transformOrigin:'top left'}}><Effects mode="B" titleImage="titles/title_meme.png" notice/></div></Sequence>
</AbsoluteFill>;
registerRoot(()=> <><Composition component={CM} {...m.composition}/><Composition component={StoryCM} {...w.composition}/><Composition id="RoadWarning" component={RoadWarning} width={854} height={480} fps={30} durationInFrames={45}/></>);
