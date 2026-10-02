import React from 'react';
import {AbsoluteFill, Audio, Composition, Loop, OffthreadVideo, Sequence, interpolate, registerRoot, staticFile, useCurrentFrame} from 'remotion';
import m from './edit-manifest.json';
const gold='#efb84d',cream='#f5ebd2';
const ease=(f:number,a:number,b:number)=>interpolate(f,[a,b],[0,1],{extrapolateLeft:'clamp',extrapolateRight:'clamp'});
const Shot:React.FC<{shot:typeof m.shots[number]}>=({shot:s})=>{
 const f=useCurrentFrame(), reveal=ease(f,0,10), danger=s.kicker.startsWith('WARNING');
 const macro=s.view==='macro';
 return <AbsoluteFill>
   <div style={{position:'absolute',left:95,top:166,width:macro?700:860,opacity:reveal,transform:`translateY(${(1-reveal)*22}px)`}}>
    <div style={{fontSize:23,letterSpacing:5,color:danger?'#f28a6d':gold,marginBottom:35}}>{s.kicker}</div>
    <div style={{fontSize:macro?78:92,lineHeight:1.24,fontWeight:700,whiteSpace:'pre-line',letterSpacing:-2}}>{s.headline}</div>
    <div style={{marginTop:42,fontSize:29,lineHeight:1.7,color:'#c8cbbd'}}>{s.detail}</div>
    {s.kicker.includes('BALANCE')&&<div style={{display:'flex',width:610,height:66,marginTop:48,borderRadius:12,overflow:'hidden'}}><div style={{width:'70%',background:gold,color:'#18251f',padding:'12px 20px',fontSize:28}}>BEER 70%</div><div style={{width:'30%',background:cream,color:'#18251f',padding:'12px 15px',fontSize:28}}>30%</div></div>}
    <div style={{display:'inline-block',marginTop:42,border:`1px solid ${danger?'#be634d':'#67705b'}`,borderRadius:30,padding:'12px 27px',fontSize:24,color:danger?'#f5a591':gold}}>{s.tag}</div>
   </div>
   <div style={{position:'absolute',left:macro?850:1120,top:macro?134:45,width:macro?980:440,height:macro?720:957,borderRadius:macro?28:38,overflow:'hidden',border:'1px solid #687060',boxShadow:'0 30px 100px #0008',background:'#122520'}}>
    <OffthreadVideo src={staticFile(s.source)} trimBefore={s.trimBefore} muted style={macro?{position:'absolute',width:1000,height:2174,left:-10,top:-650}:{width:'100%',height:'100%'}}/>
   </div>
   {macro&&<div style={{position:'absolute',left:870,top:878,fontSize:21,color:'#aeb9a7',letterSpacing:2}}>実際のゲーム画面から接写</div>}
 </AbsoluteFill>;
};
const Trailer=()=>{
 const frame=useCurrentFrame();
 return <AbsoluteFill style={{background:'radial-gradient(ellipse at 80% 35%,#354330 0%,#13251f 43%,#081510 100%)',color:cream,fontFamily:'"Hiragino Sans", "Noto Sans JP", sans-serif',fontSynthesis:'none'}}>
  <div style={{position:'absolute',left:95,top:65,fontSize:21,letterSpacing:6,color:'#a4af9a'}}>MADOGIWA MULTIMEDIA UNIVERSE</div>
  <div style={{position:'absolute',left:95,bottom:53,fontSize:18,letterSpacing:2,color:'#8e9c89'}}>iPhoneシミュレーター収録 / 開発中の映像</div>
  {m.shots.map(s=><Sequence key={s.startFrame} from={s.startFrame} durationInFrames={s.endFrame-s.startFrame}><Shot shot={s}/></Sequence>)}
  {m.soundtrack.map((a,i)=><Sequence key={`audio${i}`} from={a.startFrame} durationInFrames={a.endFrame-a.startFrame}>{a.loop?<Loop durationInFrames={60}><Audio src={staticFile(a.audio)} volume={a.volume}/></Loop>:<Audio src={staticFile(a.audio)} volume={a.volume}/>}</Sequence>)}
  {m.captions.map(c=><Sequence key={c.startFrame} from={c.startFrame} durationInFrames={c.endFrame-c.startFrame}><Audio src={staticFile(c.audio)} volume={.9}/><div style={{position:'absolute',bottom:106,left:95,maxWidth:960,fontSize:32,lineHeight:1.5,color:cream,background:'#081510e8',borderLeft:`4px solid ${gold}`,padding:'17px 25px',borderRadius:4}}>{c.text}</div></Sequence>)}
  <div style={{position:'absolute',bottom:0,left:0,height:5,width:`${frame/m.composition.durationInFrames*100}%`,background:gold}}/>
 </AbsoluteFill>
};
const VerticalShot:React.FC<{shot:typeof m.shots[number];index:number}>=({shot:s,index})=>{
 const f=useCurrentFrame(), reveal=ease(f,0,6), danger=index===3;
 return <AbsoluteFill>
  <OffthreadVideo src={staticFile(s.source)} trimBefore={s.trimBefore} muted style={{position:'absolute',width:1080,height:1080*2622/1206,left:0,top:-170}}/>
  <div style={{position:'absolute',inset:0,background:'linear-gradient(to bottom,#07110feb 0%,#07110f80 12%,transparent 24%,transparent 80%,#07110fb0 100%)'}}/>
  <div style={{position:'absolute',top:0,left:0,right:0,height:272,background:'linear-gradient(180deg,#071712 0%,#10221b 100%)'}}/>
  <div style={{position:'absolute',top:84,left:54,right:54,textAlign:'center',opacity:index===0?1:reveal,transform:`translateY(${index===0?0:(1-reveal)*14}px)`}}>
   <div style={{fontSize:25,fontWeight:600,letterSpacing:4,color:danger?'#ff9b7c':gold,marginBottom:16}}>{index===0?'18秒の真剣勝負':index===5?'そば屋の一杯':s.tag}</div>
   <div style={{fontSize:index===0?100:72,fontWeight:700,lineHeight:1.25,letterSpacing:-2,textShadow:'0 3px 14px #000b',color:danger?'#ff9674':cream}}>{m.verticalHeadlines[index]}</div>
  </div>
 </AbsoluteFill>;
};
const VerticalCaption:React.FC<{text:string;length:number}>=({text,length})=>{
 const f=useCurrentFrame();const opacity=Math.min(ease(f,0,5),1-ease(f,length-5,length));
 return <div style={{position:'absolute',left:54,right:54,bottom:188,textAlign:'center',fontSize:49,fontWeight:600,lineHeight:1.5,whiteSpace:'pre-line',opacity,textShadow:'0 2px 5px #000',background:'#071510de',borderRadius:20,padding:'22px 14px',borderTop:'2px solid #efb84d88'}}>{text}</div>;
};
const VerticalTrailer=()=>{
 const frame=useCurrentFrame();
 return <AbsoluteFill style={{background:'#122520',color:cream,fontFamily:'"Hiragino Sans", "Noto Sans JP", sans-serif',fontSynthesis:'none',overflow:'hidden'}}>
  {m.shots.map((s,i)=><Sequence key={s.startFrame} from={s.startFrame} durationInFrames={s.endFrame-s.startFrame}><VerticalShot shot={s} index={i}/></Sequence>)}
  {m.soundtrack.map((a,i)=><Sequence key={`audio${i}`} from={a.startFrame} durationInFrames={a.endFrame-a.startFrame}>{a.loop?<Loop durationInFrames={60}><Audio src={staticFile(a.audio)} volume={a.volume}/></Loop>:<Audio src={staticFile(a.audio)} volume={a.volume}/>}</Sequence>)}
  {m.captions.map((c,i)=><Sequence key={c.startFrame} from={c.startFrame} durationInFrames={c.endFrame-c.startFrame}><Audio src={staticFile(c.audio)} volume={.9}/><VerticalCaption text={m.verticalCaptions[i]} length={c.endFrame-c.startFrame}/></Sequence>)}
  <div style={{position:'absolute',bottom:86,width:'100%',textAlign:'center',fontSize:23,color:'#dddccc',textShadow:'0 2px 6px #000'}}>iPhoneシミュレーター収録・開発中の映像</div>
  <div style={{position:'absolute',bottom:0,left:0,height:6,width:`${frame/m.composition.durationInFrames*100}%`,background:gold}}/>
 </AbsoluteFill>;
};
registerRoot(()=> <><Composition {...m.composition} component={Trailer}/><Composition {...m.verticalComposition} component={VerticalTrailer}/></>);
