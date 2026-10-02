import React from 'react';
import {AbsoluteFill, OffthreadVideo, Sequence, staticFile} from 'remotion';
import manifest from './edit-manifest.json';
export const EditComposition: React.FC = () => {
 let cursor = 0;
 return <AbsoluteFill style={{backgroundColor:'black'}}>{manifest.segments.map((s,i)=>{
 const from=cursor; const duration=s.end-s.start; cursor+=duration;
 return <Sequence key={i} from={from} durationInFrames={duration}><OffthreadVideo src={staticFile(s.src)} startFrom={s.start} endAt={s.end} style={{width:'100%',height:'100%'}} /></Sequence>;
 })}</AbsoluteFill>;
};
