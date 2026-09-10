import React from 'react';
import {AbsoluteFill,Composition,OffthreadVideo,registerRoot,staticFile,useCurrentFrame,interpolate} from 'remotion';
import m from './edit-manifest-v2.json';
const Film:React.FC=()=>{const f=useCurrentFrame();const title=f>=m.titleCard.startFrame;return <AbsoluteFill style={{backgroundColor:'#000'}}>
<OffthreadVideo src={staticFile(m.inputVideo)} style={{width:'100%',height:'100%'}}/>
{m.captions.map((c,i)=>f>=c.startFrame&&f<c.endFrame?<div key={i} style={{position:'absolute',left:'5%',right:'5%',bottom:'9%',textAlign:'center',fontFamily:'"Hiragino Kaku Gothic ProN",sans-serif',fontSize:26,fontWeight:500,lineHeight:1.35,color:'#fff',whiteSpace:'pre-line',WebkitTextStroke:'1.3px #000',paintOrder:'stroke fill',textShadow:'0 2px 4px #000'}}>{c.text}</div>:null)}
{title?<AbsoluteFill style={{backgroundColor:'#000',justifyContent:'center',alignItems:'center'}}><div style={{opacity:interpolate(f,[m.titleCard.startFrame,m.titleCard.startFrame+4],[0,1],{extrapolateRight:'clamp'})}}><div style={{display:'flex',justifyContent:'center',gap:30,marginBottom:15}}>{m.titleCard.symbols.map((_,i)=><svg key={i} width="34" height="34" viewBox="0 0 40 40">{i===1?<path d="M20 4 L37 35 H3 Z" fill="none" stroke="#fff" strokeWidth="3"/>:<path d="M6 6 L34 34 M34 6 L6 34" stroke="#ed4993" strokeWidth="5"/>}</svg>)}</div><div style={{fontFamily:'"Hiragino Kaku Gothic ProN",sans-serif',fontSize:66,fontWeight:700,letterSpacing:7,color:'#fff'}}>タコ<span style={{color:'#ed4993'}}>ゲーム</span></div></div></AbsoluteFill>:null}
</AbsoluteFill>};
export default Film;
