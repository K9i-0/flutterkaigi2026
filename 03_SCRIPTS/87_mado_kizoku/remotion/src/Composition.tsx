import React from 'react';
import {AbsoluteFill, Html5Audio, OffthreadVideo, staticFile, useCurrentFrame, Sequence} from 'remotion';
import manifest from './edit-manifest.json';
export const EditComposition: React.FC = () => {
  const frame = useCurrentFrame();
  const caption = manifest.captions.find(c => frame >= c.startFrame && frame < c.endFrame);
  let offset = 0;
  let sourceFrame = 0;
  for(const seg of manifest.sourceSegments){
    if(frame >= offset && frame < offset+seg.endFrame-seg.startFrame) sourceFrame=seg.startFrame+frame-offset;
    offset+=seg.endFrame-seg.startFrame;
  }
  const blur = sourceFrame >= 338 && sourceFrame < 485 ? {left:505,top:630,width:285,height:75} : sourceFrame >= 666 ? {left:310,top:625,width:650,height:75} : null;
  return <AbsoluteFill style={{backgroundColor:'#000'}}>
    {manifest.sourceSegments.map((seg, i) => <Sequence key={i} from={manifest.sourceSegments.slice(0,i).reduce((n,s)=>n+s.endFrame-s.startFrame,0)} durationInFrames={seg.endFrame-seg.startFrame}><OffthreadVideo src={staticFile('input.mp4')} startFrom={seg.startFrame} endAt={seg.endFrame} muted style={{width:'100%',height:'100%',objectFit:'fill'}} /></Sequence>)}
    <Html5Audio src={staticFile(manifest.replacementAudio)} />
    {blur && <div style={{position:'absolute',...blur,backdropFilter:'blur(10px)',WebkitBackdropFilter:'blur(10px)',borderRadius:18,maskImage:'linear-gradient(to right, transparent, black 5%, black 95%, transparent), linear-gradient(to bottom, transparent, black 20%, black 80%, transparent)',maskComposite:'intersect'}} />}
    {caption && <div style={{position:'absolute',left:48,right:48,bottom:38,textAlign:'center',fontFamily:'"Hiragino Sans", "Yu Gothic", sans-serif',fontSynthesis:'none',fontSize:38,fontWeight:600,lineHeight:1.3,whiteSpace:'pre-line',color:'#fff',WebkitTextStroke:'2.2px #171717',paintOrder:'stroke fill',textShadow:'0 2px 3px rgba(0,0,0,0.75)'}}>{caption.speaker}「{caption.text}」</div>}
  </AbsoluteFill>;
};
