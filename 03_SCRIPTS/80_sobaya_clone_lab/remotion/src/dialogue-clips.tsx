import React from 'react';
import {AbsoluteFill, Composition, OffthreadVideo, registerRoot, staticFile} from 'remotion';
import m from './dialogue-clips.json';
type Clip = {startFrame:number;endFrameExclusive:number};
const Dialogue:React.FC<Clip>=({startFrame,endFrameExclusive})=><AbsoluteFill style={{backgroundColor:'black'}}><OffthreadVideo src={staticFile(m.publicSource)} startFrom={startFrame} endAt={endFrameExclusive} style={{width:'100%',height:'100%'}}/></AbsoluteFill>;
registerRoot(()=> <>{m.clips.map(clip=><Composition key={clip.id} id={clip.id} component={Dialogue} defaultProps={clip} width={m.width} height={m.height} fps={m.fps} durationInFrames={clip.endFrameExclusive-clip.startFrame}/>)}</>);
