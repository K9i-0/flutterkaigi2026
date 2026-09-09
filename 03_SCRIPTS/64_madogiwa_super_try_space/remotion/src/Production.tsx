import React from 'react';
import {AbsoluteFill,Audio,Img,OffthreadVideo,Sequence,staticFile,useCurrentFrame,interpolate} from 'remotion';
import m from './production-manifest.json';
const mono='"SFMono-Regular", Menlo, monospace';
export const Production:React.FC<{preview:boolean}>=({preview})=>{
 const f=useCurrentFrame();
 const comm=m.comms.find(c=>f>=c.start&&f<c.end);
 const hud=m.hud.some(c=>f>=c.start&&f<c.end);
 const alert=f>=m.events.alert&&f<m.events.hudEnd, identified=f>=m.events.identified;
 const col=identified?'#c5e8df':'#ffbf77';
 const cap=m.captions.find(c=>f>=c.start&&f<c.end);
 const times=m.tracking.map(k=>k.frame);
 const at=(key:'x'|'y'|'size')=>interpolate(f,times,m.tracking.map(k=>k[key]),{extrapolateLeft:'clamp',extrapolateRight:'clamp'});
 const x=at('x'),y=at('y'),s=at('size');
 const peaks=[270,303,330,352,375,408,435,457];
 const pulse=Math.max(0,...peaks.map(p=>f>=p&&f<p+9?1-(f-p)/9:0));
 return <AbsoluteFill style={{background:'#020507',color:'#c9e1e3',fontFamily:mono}}>
 {preview?<Img src={staticFile(m.background)} style={{width:'100%',height:'100%',objectFit:'cover'}}/>:<><OffthreadVideo muted src={staticFile(m.inputVideo)} style={{width:'100%',height:'100%'}}/><Audio src={staticFile(m.inputVideo)}/></>}
 {comm&&<AbsoluteFill><Img src={staticFile(m.background)} style={{position:'absolute',width:'104%',height:'104%',objectFit:'cover',left:-12+(f-comm.start)*.025,top:-7,filter:'brightness(.78) saturate(.8)'}}/>
 <div style={{position:'absolute',left:53,top:139,width:160,height:117,overflow:'hidden',boxShadow:'0 0 12px #8ac8d022',filter:'saturate(.35) contrast(1.08)'}}>
 {preview?<Img src={staticFile('okayaman.jpg')} style={{width:'100%',height:'100%',objectFit:'cover'}}/>:<Sequence from={comm.start} durationInFrames={comm.end-comm.start} layout="none"><OffthreadVideo muted startFrom={comm.start} src={staticFile(m.inputVideo)} style={{width:'100%',height:'100%',objectFit:'cover'}}/></Sequence>}
 </div><div style={{position:'absolute',left:53,top:119,fontSize:10,letterSpacing:1}}>● COMMS / OKAYAMAN</div><div style={{position:'absolute',left:53,top:262,fontSize:8,letterSpacing:1,opacity:.6}}>UPLINK 02 / ENCRYPTED</div></AbsoluteFill>}
 {hud&&<AbsoluteFill style={{textShadow:'0 0 4px #9dd9e54d',boxShadow:`inset 0 0 85px rgba(228,139,49,${pulse*.13})`}}>
 <svg width="832" height="480" style={{position:'absolute',opacity:.45}}><path d="M 39 75 V 31 H 99 M 735 31 H 793 V 75 M 39 330 V 368 H 100 M 735 368 H 793 V 330" fill="none" stroke="#c6e3e9" strokeWidth=".7"/>
 {Array.from({length:29},(_,i)=><path key={i} d={`M ${230+i*13} 44 v ${i%5===0?8:3}`} stroke="#b6d5df" strokeWidth=".7"/>)}
 <path d="M 407 220 h 7 M 418 220 h 7 M 416 210 v 7 M 416 224 v 7" stroke="#c6e3e9"/>
 </svg><div style={{position:'absolute',left:52,top:45,fontSize:10,letterSpacing:2}}>EVA / 02 ●</div><div style={{position:'absolute',left:52,top:325,fontSize:9,lineHeight:1.8,opacity:.65}}>O₂ 098% / PRES 4.3 PSI<br/>TETHER SECURED</div>
 {alert&&<><div style={{position:'absolute',left:265,top:87,color:col,filter:`brightness(${1+pulse*.6})`}}><div style={{fontSize:9,letterSpacing:2,marginBottom:8}}>△ {identified?'CONTACT RESOLVED':'PROXIMITY CAUTION'} / 01</div><div style={{fontSize:19,fontFamily:'"Hiragino Kaku Gothic ProN",sans-serif',borderLeft:`2px solid ${col}`,paddingLeft:10}}>{identified?'そば屋と確認':'未確認窓際族 接近'}</div><div style={{fontSize:9,marginTop:8,letterSpacing:1}}>{identified?'IDENTIFIED: SOBAYA':'UNKNOWN MADOGIWA APPROACHING'}</div></div>
 {f>=390&&<svg width="832" height="480" style={{position:'absolute',color:col}}><g transform={`translate(${x} ${y})`} stroke="currentColor" fill="none" strokeWidth=".8"><path d={`M ${-s/2} ${-s/2+12} v -12 h 12 M ${s/2-12} ${-s/2} h 12 v 12 M ${s/2} ${s/2-12} v 12 h -12 M ${-s/2+12} ${s/2} h -12 v -12`}/></g><text x={Math.min(620,x+s/2+10)} y={y+15} fontSize="10" fill="currentColor">{identified?'NO SUIT':`${Math.max(9,Math.round(190-(f-390)*1.7))} M`}</text></svg>}</>}
 </AbsoluteFill>}
 {m.audioSegments.map((s,i)=><Sequence key={i} from={s.from} durationInFrames={s.duration}><Audio src={staticFile(m.alertAudio)} startFrom={s.startFrom} volume={t=>Math.min(1,t/2,(s.duration-1-t)/3)*.8}/></Sequence>)}
 {cap&&<div style={{position:'absolute',bottom:36,width:'100%',textAlign:'center',fontFamily:'"Hiragino Kaku Gothic ProN",sans-serif',fontSize:21,color:'#f6f4ee',textShadow:'0 2px 4px #000, 1px 0 2px #000,-1px 0 2px #000'}}>{cap.text}</div>}
 {f>=m.events.brand&&<div style={{position:'absolute',left:390,top:160,width:404,color:'#fff',textShadow:'0 2px 7px #000',fontFamily:'"Hiragino Kaku Gothic ProN",sans-serif',opacity:Math.min(1,(f-m.events.brand)/6)}}><div style={{fontSize:24,letterSpacing:1,marginBottom:27}}>{m.brandCopy[0]}</div><div style={{fontSize:29,fontWeight:600,whiteSpace:'nowrap'}}>{m.brandCopy[1]}</div><div style={{fontSize:19,letterSpacing:2,marginTop:12}}>{m.brandCopy[2]}</div></div>}
 {preview&&<div style={{position:'absolute',top:7,right:15,fontSize:8,color:'#ccc'}}>EDIT PREVIEW / WAN FOOTAGE PENDING</div>}
 </AbsoluteFill>;
};
