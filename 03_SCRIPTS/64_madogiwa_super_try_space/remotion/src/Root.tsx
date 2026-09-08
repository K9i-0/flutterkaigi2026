import React from 'react';
import {AbsoluteFill,Audio,Composition,Img,staticFile,useCurrentFrame,interpolate} from 'remotion';
import m from './edit-manifest.json';
const mono='"SFMono-Regular", Menlo, monospace';
const Hud:React.FC=()=>{
 const f=useCurrentFrame(), alert=f>=m.events.alert, identified=f>=m.events.identified;
 const col=alert&&!identified?'#ffbf77':'#c5e8df';
 const x=610-Math.min(130,Math.max(0,f-75)*.8),y=214+Math.sin(f/48)*13;
 const pulse=Math.max(0,...m.audio.pulses.map(p=>f>=p&&f<p+9?1-(f-p)/9:0));
 const caption=m.captions.find(c=>f>=c.start&&f<c.end);
 return <AbsoluteFill style={{background:'#020507',color:'#d0e4e6',fontFamily:mono,overflow:'hidden'}}>
 <Audio src={staticFile(m.audio.file)}/>
 <Img src={staticFile('space_plate.png')} style={{position:'absolute',width:'104%',height:'104%',objectFit:'cover',left:-10+f*.015,top:-8,transform:`rotate(${-.35+f*.002}deg)`,filter:'brightness(.72) saturate(.7)'}}/>
 <AbsoluteFill style={{background:'radial-gradient(ellipse at 54% 48%,transparent 34%,rgba(0,8,12,.26) 65%,rgba(0,0,0,.85) 100%)'}}/>
 <AbsoluteFill style={{pointerEvents:'none',boxShadow:`inset 0 0 85px rgba(228,139,49,${pulse*.13})`}}/>
 <div style={{position:'absolute',inset:'30px 38px 63px',transform:`perspective(950px) rotateY(-2deg) rotateZ(${Math.sin(f/60)*.14}deg)`,textShadow:'0 0 4px #9dd9e54d'}}>
 <svg width="756" height="387" style={{position:'absolute',opacity:.42}}><path d="M 0 46 L 0 0 L 62 0 M 695 0 L 756 0 L 756 46 M 0 301 L 0 338 L 58 338 M 700 338 L 756 338 L 756 302" fill="none" stroke="#c6e3e9" strokeWidth=".7"/>
 {Array.from({length:29},(_,i)=><g key={i}><path d={`M ${190+i*13} 12 v ${i%5===0?8:3}`} stroke="#abc8d2" strokeWidth=".6"/>{i%5===0&&<text x={185+i*13} y={32} fill="#c2dce0" fontSize="8">{(i*2+240)%360}</text>}</g>)}
 <path d="M 371 2 l 4 5 l 4 -5 M 366 171 h 8 M 378 171 h 8 M 376 161 v 7 M 376 174 v 7" fill="none" stroke="#dbf1ec"/>
 {Array.from({length:17},(_,i)=><path key={i} d={`M 724 ${69+i*12} h ${i%4===0?12:5}`} stroke="#abc8d2" strokeWidth=".7"/>)}
 <text x="694" y="60" fill="#c2dce0" fontSize="9">REL VEL</text><text x="690" y="289" fill="#d9eded" fontSize="12">{alert?'−02.4':'00.0'}</text>
 </svg>
 <div style={{position:'absolute',top:14,left:13,fontSize:10,letterSpacing:2}}>EVA / 02 <span style={{color:'#86b7aa'}}>●</span></div>
 <div style={{position:'absolute',top:42,left:13,fontSize:8,opacity:.6}}>SUIT LINK · SECURE</div>
 <div style={{position:'absolute',left:14,top:88,width:140,transform:'perspective(600px) rotateY(9deg)',opacity:identified?.5:.92}}>
 <div style={{fontSize:9,letterSpacing:1,borderTop:'1px solid #9bc6cc66',padding:'7px 0'}}>● COMMS / OKAYAMAN</div>
 <div style={{height:105,overflow:'hidden',position:'relative',background:'#163038'}}>
 <Img src={staticFile('okayaman.jpg')} style={{width:'100%',height:'100%',objectFit:'cover',objectPosition:'50% 28%',filter:'grayscale(1) contrast(1.15) brightness(.7)',mixBlendMode:'screen'}}/>
 <AbsoluteFill style={{background:'linear-gradient(110deg, #1a515030, transparent 60%, #06373977)',boxShadow:'inset 0 0 18px #00191f'}}/>
 </div>
 <div style={{display:'flex',gap:2,height:16,alignItems:'center',opacity:.65}}>{Array.from({length:35},(_,i)=><div key={i} style={{width:2,height:2+Math.abs(Math.sin(i*1.9+f*.33))*9,background:'#bcdbd5'}}/>)}</div>
 <div style={{fontSize:8,opacity:.6}}>UPLINK  02 / ENCRYPTED</div>
 </div>
 <div style={{position:'absolute',left:14,top:290,fontSize:9,lineHeight:1.9,opacity:.72}}>O₂&nbsp; 098% &nbsp; ╱ &nbsp; 06:42<br/>PRES&nbsp; 4.3 PSI <span style={{color:'#acc7a4'}}>NOMINAL</span></div>
 {alert&&<><div style={{position:'absolute',left:231,top:60,color:col,filter:`brightness(${1+pulse*.6})`,opacity:Math.min(1,(f-74)/5)}}>
 <div style={{fontSize:9,letterSpacing:2,marginBottom:7}}>△ {identified?'CONTACT RESOLVED':'PROXIMITY CAUTION'} / 01</div>
 <div style={{fontSize:18,fontFamily:'"Hiragino Kaku Gothic ProN",sans-serif',letterSpacing:1,borderLeft:`2px solid ${col}`,paddingLeft:10}}>{identified?'そば屋と確認':'未確認窓際族 接近'}</div>
 <div style={{fontSize:9,letterSpacing:1,marginTop:7,opacity:.8}}>{identified?'IDENTIFIED: SOBAYA':'UNKNOWN MADOGIWA APPROACHING'}</div></div>
 <svg width="756" height="387" style={{position:'absolute',color:col}}><g transform={`translate(${x-38} ${y-30})`} stroke="currentColor" strokeWidth="1" fill="none"><path d="M -29 -12 v -16 h 16 M 13 -28 h 16 v 16 M 29 12 v 16 h -16 M -13 28 h -16 v -16"/><circle r="2" fill="currentColor" opacity=".7"/><path d="M -39 0 h -5 M 39 0 h 5" opacity=".5"/></g><path d={`M ${x-68} ${y-2} L ${x-94} ${y+32} H ${x-158}`} stroke="currentColor" fill="none" opacity=".5"/></svg>
 <div style={{position:'absolute',left:x-194,top:y+38,color:col,fontSize:10}}>{identified?'SOBAYA / NO SUIT':`${Math.max(24,186-Math.round((f-75)*1.2))} M / CLOSING`}<div style={{fontSize:8,opacity:.6,marginTop:5}}>TRACK 01 · {identified?'VISUAL ID':'ACQUIRING'}</div></div></>}
 </div>
 <div style={{position:'absolute',top:8,right:15,fontSize:8,letterSpacing:1,color:'#adc4c5',opacity:.55}}>HUD LOOK TEST · STILL PLATE / NO TARGET FOOTAGE</div>
 {caption&&<div style={{position:'absolute',bottom:35,width:'100%',textAlign:'center',fontFamily:'"Hiragino Kaku Gothic ProN",sans-serif',fontSize:21,color:'#f6f4ee',textShadow:'0 2px 4px #000, 1px 0 2px #000,-1px 0 2px #000'}}>{caption.text}</div>}
 </AbsoluteFill>;
};
export const Root=()=> <Composition id="HudTest" component={Hud} {...m.composition}/>;
