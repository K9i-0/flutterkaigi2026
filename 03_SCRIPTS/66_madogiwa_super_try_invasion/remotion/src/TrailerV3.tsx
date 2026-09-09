import React from 'react';
import {AbsoluteFill,Sequence,OffthreadVideo,staticFile,useCurrentFrame,interpolate} from 'remotion';
import silent from './trailer-v3-manifest.json';
import voiced from './trailer-voice-v3-manifest.json';
const Card=({text,duration}:{text:string;duration:number})=>{const f=useCurrentFrame();const opacity=interpolate(f,[4,14,duration-10,duration-2],[0,1,1,0],{extrapolateLeft:'clamp',extrapolateRight:'clamp'});return <AbsoluteFill style={{background:'black',justifyContent:'center',alignItems:'center'}}><div style={{opacity,color:'#f1efe9',fontFamily:'Hiragino Mincho ProN, serif',fontWeight:600,fontSize:32,lineHeight:1.9,letterSpacing:2,textAlign:'center',whiteSpace:'pre-line',padding:'0 40px'}}>{text}</div></AbsoluteFill>};
const Film=({voice}:{voice:boolean})=>{const m=voice?voiced:silent;return <AbsoluteFill style={{background:'black'}}>{m.segments.map((s,i)=><Sequence key={i} from={s.from} durationInFrames={s.duration}>{s.kind==='video'?<OffthreadVideo src={staticFile(m.source)} startFrom={s.sourceStart!} muted/>:<Card text={s.text!} duration={s.duration}/>}</Sequence>)}</AbsoluteFill>};
export const TrailerV3=()=> <Film voice={false}/>;
export const TrailerVoiceV3=()=> <Film voice={true}/>;
