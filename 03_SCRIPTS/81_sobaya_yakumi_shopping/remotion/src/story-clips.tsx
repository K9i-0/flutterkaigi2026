import React from 'react';
import {AbsoluteFill,Composition,OffthreadVideo,registerRoot,staticFile} from 'remotion';
import m from './story-clips.json';
type Props={publicSource:string;startFrame:number;endFrameExclusive:number};
const Clip:React.FC<Props>=({publicSource,startFrame,endFrameExclusive})=><AbsoluteFill style={{backgroundColor:'black'}}><OffthreadVideo src={staticFile(publicSource)} startFrom={startFrame} endAt={endFrameExclusive} style={{width:'100%',height:'100%'}}/></AbsoluteFill>;
registerRoot(()=> <>{m.clips.map(c=><Composition key={c.id} id={c.id} component={Clip} defaultProps={c} width={m.width} height={m.height} fps={m.fps} durationInFrames={c.endFrameExclusive-c.startFrame}/>)}</>);
