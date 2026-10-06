import React from 'react';
import {AbsoluteFill, Html5Audio, OffthreadVideo, staticFile, useCurrentFrame, Sequence, interpolate} from 'remotion';
import manifest from './part1-manifest.json';
import {EditComposition} from './Composition';
export const Part1: React.FC = () => {
  const frame=useCurrentFrame();
  const videoStyle: React.CSSProperties={width:'100%',height:'100%',objectFit:'fill'};
  const caption=manifest.captions.find(c=>frame>=c.startFrame&&frame<c.endFrame);
  return <AbsoluteFill style={{backgroundColor:'#000',overflow:'hidden'}}>
    {manifest.sourceSegments.map((seg,i)=><Sequence key={i} from={manifest.sourceSegments.slice(0,i).reduce((n,s)=>n+s.endFrame-s.startFrame,0)} durationInFrames={seg.endFrame-seg.startFrame}><OffthreadVideo src={staticFile('part1.mp4')} startFrom={seg.startFrame} endAt={seg.endFrame} muted style={videoStyle} /></Sequence>)}
    <Sequence from={180} durationInFrames={104}><OffthreadVideo src={staticFile('fukuchan_closeup.mp4')} muted style={videoStyle}/></Sequence>
    <Html5Audio src={staticFile('part1_audio.wav')}/>
    {caption&&<div style={{position:'absolute',left:48,right:48,bottom:38,textAlign:'center',fontFamily:'"Hiragino Sans", "Yu Gothic", sans-serif',fontSynthesis:'none',fontSize:38,fontWeight:600,lineHeight:1.3,whiteSpace:'pre-line',color:'#fff',WebkitTextStroke:'2.2px #171717',paintOrder:'stroke fill',textShadow:'0 2px 3px rgba(0,0,0,0.75)'}}>{caption.speaker}「{caption.text}」</div>}
  </AbsoluteFill>;
};
export const FullFilm: React.FC=()=> {
  const frame=useCurrentFrame();
  const end=manifest.composition.durationInFrames;
  const next=end+45;
  const fade=frame<end
    ? interpolate(frame,[end-12,end-1],[0,1],{extrapolateLeft:'clamp',extrapolateRight:'clamp'})
    : frame>=next ? interpolate(frame,[next,next+12],[1,0],{extrapolateLeft:'clamp',extrapolateRight:'clamp'}) : 1;
  const creditStart=next+663+12;
  const endFade=interpolate(frame,[next+663,creditStart],[0,1],{extrapolateLeft:'clamp',extrapolateRight:'clamp'});
  const titleOpacity=interpolate(frame,[end,end+8,end+34,end+44],[0,1,1,0],{extrapolateLeft:'clamp',extrapolateRight:'clamp'});
  return <AbsoluteFill style={{backgroundColor:'#000'}}>
    <Html5Audio src={staticFile('bgm_mix.wav')}/>
    <Sequence durationInFrames={end}><Part1/></Sequence>
    <Sequence from={next} durationInFrames={693}><EditComposition/></Sequence>
    <AbsoluteFill style={{backgroundColor:'#000',opacity:Math.max(fade,endFade)}}/>
    {frame>=creditStart&&<AbsoluteFill style={{justifyContent:'center',alignItems:'center',color:'#eee',fontFamily:'"Hiragino Sans", sans-serif',textAlign:'center',lineHeight:1.65}}>
      <div style={{fontSize:24,color:'#aaa',marginBottom:18}}>MUSIC</div>
      <div style={{fontSize:32}}>Divertissement - Pizzicato (from the ballet Sylvia)</div>
      <div style={{fontSize:30,marginTop:12}}>Kevin MacLeod (incompetech.com)</div>
      <div style={{fontSize:20,marginTop:10}}>incompetech.com/music/royalty-free/index.html?isrc=USUAN1100256</div>
      <div style={{fontSize:24,marginTop:22}}>Licensed under Creative Commons: By Attribution 4.0</div>
      <div style={{fontSize:24}}>https://creativecommons.org/licenses/by/4.0/</div>
      <div style={{fontSize:22,marginTop:20,color:'#bbb'}}>編集：抜粋・音量調整・フェード</div>
    </AbsoluteFill>}
    {frame>=end&&frame<next&&<AbsoluteFill style={{justifyContent:'center',alignItems:'center',color:'#eee',fontFamily:'"Hiragino Mincho ProN", serif',fontSize:34,letterSpacing:5,opacity:titleOpacity}}>しばらくして…</AbsoluteFill>}
  </AbsoluteFill>;
};
