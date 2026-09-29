import React from 'react';
import {AbsoluteFill,Composition,OffthreadVideo,registerRoot,staticFile} from 'remotion';
import m from './reply-clip.json';
const Clip:React.FC=()=> <AbsoluteFill style={{backgroundColor:'black'}}><OffthreadVideo src={staticFile(m.publicSource)} startFrom={m.startFrame} endAt={m.endFrameExclusive} style={{width:'100%',height:'100%'}}/></AbsoluteFill>;
registerRoot(()=> <Composition id={m.id} component={Clip} width={m.width} height={m.height} fps={m.fps} durationInFrames={m.endFrameExclusive-m.startFrame}/>);
