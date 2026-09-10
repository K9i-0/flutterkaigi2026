import React from 'react';
import {AbsoluteFill,Composition,OffthreadVideo,Sequence,registerRoot,staticFile,useCurrentFrame,interpolate} from 'remotion';
import {Effects} from './Effects';
import m from './edit-manifest.json';
const CM:React.FC=()=>{const f=useCurrentFrame();return <AbsoluteFill style={{backgroundColor:'#05080d'}}>
<Sequence durationInFrames={m.endcardStartFrame}><OffthreadVideo src={staticFile(m.inputVideo)} style={{width:'100%',height:'100%'}}/></Sequence>
{m.captions.map((c,i)=>{if(f<c.startFrame||f>=c.endFrame)return null;const opacity=interpolate(f,[c.startFrame,c.startFrame+3,c.endFrame-3,c.endFrame],[0,1,1,0],{extrapolateLeft:'clamp',extrapolateRight:'clamp'});return <div key={i} style={{position:'absolute',left:c.speaker==='いーさん'?440:36,right:36,bottom:27,textAlign:'center',opacity,fontFamily:'"Hiragino Kaku Gothic ProN",sans-serif',fontSize:27,fontWeight:600,lineHeight:1.4,letterSpacing:.4,color:c.speaker==='実況'?'#fff':'#ffe7a8',textShadow:'0 2px 3px #000, 0 0 7px #000',WebkitTextStroke:'1px rgba(0,0,0,.9)',paintOrder:'stroke fill',whiteSpace:'pre-line'}}><span style={{background:'rgba(4,10,20,.73)',padding:'5px 12px',boxDecorationBreak:'clone',borderRadius:3}}>{c.text}</span></div>})}
<Sequence from={m.endcardStartFrame} durationInFrames={m.composition.durationInFrames-m.endcardStartFrame}><div style={{position:'absolute',width:1920,height:1080,transform:'scale(0.4447916667,0.4444444444)',transformOrigin:'top left'}}><Effects mode="B" titleImage="titles/title_meme.png" notice/></div></Sequence>
</AbsoluteFill>};
registerRoot(()=> <Composition component={CM} {...m.composition}/>);
