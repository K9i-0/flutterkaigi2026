import React from 'react';
import {AbsoluteFill,Sequence,OffthreadVideo,staticFile,useCurrentFrame} from 'remotion';
import m from './full-manifest.json';
export const Full=()=>{const f=useCurrentFrame();return <AbsoluteFill style={{backgroundColor:'black'}}>
<Sequence from={0} durationInFrames={600}><OffthreadVideo src={staticFile('input.mp4')} muted/></Sequence>
<Sequence from={600} durationInFrames={498}><OffthreadVideo src={staticFile('part2.mp4')} muted/></Sequence>
<Sequence from={1098} durationInFrames={102}><OffthreadVideo src={staticFile('space64.mp4')} startFrom={798} muted/></Sequence>
{m.captions.filter(c=>f>=c.startFrame&&f<c.endFrame).map(c=><div key={c.startFrame} style={{position:'absolute',bottom:35,left:35,right:35,textAlign:'center',fontFamily:'Hiragino Sans, sans-serif',fontSize:28,fontWeight:600,color:'white',WebkitTextStroke:'1.4px #111',paintOrder:'stroke fill',textShadow:'0 2px 3px black',lineHeight:1.35}}>{c.text}</div>)}
{f>=680&&f<723&&<div style={{position:'absolute',bottom:38,left:460,right:32,padding:'10px 14px',background:'rgba(5,17,27,.94)',color:'#bcefff',fontFamily:'Hiragino Sans,sans-serif',fontSize:17,lineHeight:1.6}}>地球資源回収作戦<br/>回収対象：BEER<br/>貯蔵量：100%</div>}
{f>=1098&&<div style={{position:'absolute',left:365,right:35,top:150,color:'white',fontFamily:'Hiragino Sans,sans-serif',textShadow:'0 2px 5px #000'}}><div style={{fontSize:26,fontWeight:600,marginBottom:25}}>この一杯のために、来た。</div><div style={{fontSize:32,fontWeight:800,whiteSpace:'nowrap'}}>窓際スーパーつらい</div><div style={{fontSize:23,marginTop:12,letterSpacing:1}}>Madogiwa Super TRY</div></div>}
</AbsoluteFill>};
