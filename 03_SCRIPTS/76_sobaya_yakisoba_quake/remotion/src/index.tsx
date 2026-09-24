import React from 'react';
import {AbsoluteFill,Audio,Composition,OffthreadVideo,Sequence,registerRoot,staticFile,useCurrentFrame} from 'remotion';
import revision02 from './edit-manifest.json';
import revision03 from './edit-manifest-revision03.json';
import revision04 from './edit-manifest-revision04.json';
type Manifest = typeof revision02;
const makeEdit = (manifest: Manifest): React.FC => () => <AbsoluteFill style={{backgroundColor:'black'}}>{manifest.segments.map(s=><Sequence key={s.file} from={s.from} durationInFrames={s.durationInFrames}><OffthreadVideo src={staticFile(s.file)} trimBefore={s.trimBefore} style={{width:'100%',height:'100%'}} /></Sequence>)}</AbsoluteFill>;
const Edit02 = makeEdit(revision02);
const Edit03 = makeEdit(revision03);
const Edit04: React.FC = () => {
 const frame=useCurrentFrame();
 const q=revision04.earthquake;
 const active=frame>=q.startFrame && frame<q.stopFrame;
 const t=frame-q.startFrame;
 const strength=active ? Math.min(1,t/7)*(frame<q.strongEndFrame?1:0.64) : 0;
 // Incommensurate components keep the motion irregular, while deterministic per frame.
 const x=strength*(8*Math.sin(t*2.17)+3*Math.sin(t*.83)+2*Math.sin(t*3.53));
 const y=strength*(3.6*Math.sin(t*1.71)+1.5*Math.sin(t*2.93));
 const rotation=strength*(0.48*Math.sin(t*1.29)+0.16*Math.sin(t*2.67));
 const scale=frame>=q.startFrame && frame<q.cropEndFrame?q.scale:1;
 const originalVolume=(f:number)=>{
  if(f<q.stopFrame || f>=q.finalSpeechFrame)return 1;
  // No dialogue here: reduce residual earthquake ambience after the sip.
  return 0.3;
 };
 return <AbsoluteFill style={{backgroundColor:'black',overflow:'hidden'}}>
  <AbsoluteFill style={{transform:`translate(${x}px,${y}px) rotate(${rotation}deg) scale(${scale})`}}>
   {revision04.segments.map(s=><Sequence key={s.file} from={s.from} durationInFrames={s.durationInFrames}>
    <OffthreadVideo src={staticFile(s.file)} trimBefore={s.trimBefore} volume={f=>originalVolume(f+s.from)} style={{width:'100%',height:'100%'}} />
   </Sequence>)}
  </AbsoluteFill>
  <Audio src={staticFile(q.soundFile)}/>
 </AbsoluteFill>;
};
const Root: React.FC = () => <><Composition {...revision02.composition} component={Edit02}/><Composition {...revision03.composition} component={Edit03}/><Composition {...revision04.composition} component={Edit04}/></>;
registerRoot(Root);
