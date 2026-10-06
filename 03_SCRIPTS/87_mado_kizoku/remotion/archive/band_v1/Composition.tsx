import React from 'react';
import {AbsoluteFill, Html5Audio, OffthreadVideo, staticFile, useCurrentFrame, Sequence} from 'remotion';
import manifest from './edit-manifest.json';
export const EditComposition: React.FC = () => {
  const frame = useCurrentFrame();
  const caption = manifest.captions.find(c => frame >= c.startFrame && frame < c.endFrame);
  return <AbsoluteFill style={{backgroundColor:'#141920'}}>
    {manifest.sourceSegments.map((seg, i) => <Sequence key={i} from={manifest.sourceSegments.slice(0,i).reduce((n,s)=>n+s.endFrame-s.startFrame,0)} durationInFrames={seg.endFrame-seg.startFrame}><OffthreadVideo src={staticFile('input.mp4')} startFrom={seg.startFrame} endAt={seg.endFrame} muted style={{width:'100%',height:'100%',objectFit:'fill'}} /></Sequence>)}
    <Html5Audio src={staticFile('repaired_audio.wav')} />
    <div style={{position:'absolute',left:0,right:0,bottom:0,height:142,background:'#141920',borderTop:'2px solid #b59a62',fontFamily:'"Hiragino Sans", "Yu Gothic", sans-serif',fontSynthesis:'none',color:'#fff',padding:'8px 64px 36px',boxSizing:'border-box'}}>
      {caption && <><div style={{fontSize:20,lineHeight:1.1,fontWeight:600,color:'#e2c88f',marginBottom:3}}>{caption.speaker}</div><div style={{fontSize:32,fontWeight:500,lineHeight:1.15,whiteSpace:'pre-line',letterSpacing:'0.015em'}}>{caption.text}</div></>}
    </div>
  </AbsoluteFill>;
};
