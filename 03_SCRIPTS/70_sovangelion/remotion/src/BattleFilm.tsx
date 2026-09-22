import React from 'react';
import {AbsoluteFill,Audio,Img,Loop,Sequence,staticFile,useCurrentFrame,interpolate} from 'remotion';
import {ThreeCanvas} from '@remotion/three';
import {Battlefield,Cockpit,Dock3D,ease} from './BattleScene';
import m from './battle-manifest.json';
const FPS=24;
const color={ink:'#09161e',cyan:'#93c6cf',paper:'#eee9d9',red:'#ce3e39'};
const font='"Hiragino Sans","Noto Sans JP",sans-serif';
const mono='"Menlo",monospace';
function Plate({src,t,end=false}:{src:string;t:number;end?:boolean}){return <AbsoluteFill style={{overflow:'hidden'}}><Img src={staticFile('battle/'+src)} style={{width:'100%',height:'100%',objectFit:'cover',transform:`scale(${end?.96-ease(t/6)*.02:1.02+Math.min(t,8)*.007})`}}/></AbsoluteFill>}
function Title(){const f=useCurrentFrame();return <AbsoluteFill style={{background:'#0b0e13',color:color.paper,justifyContent:'center',paddingLeft:95}}>
 <div style={{fontSize:18,letterSpacing:9,color:'#97aab1',marginBottom:28}}>窓際族物語　第70話 拡張版</div>
 <div style={{fontFamily:'"Hiragino Mincho ProN",serif',fontSize:92,fontWeight:900,letterSpacing:-7,lineHeight:1.1}}>ソヴァンゲリオン</div>
 <div style={{width:990,height:2,background:'#a13636',margin:'30px 0'}}/>
 <div style={{fontSize:32,letterSpacing:14}}>終わらない残業</div>
 <div style={{position:'absolute',right:78,bottom:80,color:'#704040',fontFamily:mono,fontSize:16}}>SOVA / OVERTIME</div>
 </AbsoluteFill>}
function Comms({person,t,label}:{person:string;t:number;label:string}){return <AbsoluteFill style={{background:'radial-gradient(ellipse at 28% 45%,#294856,#0b1925 70%)',padding:'70px 80px',display:'flex',flexDirection:'row',gap:55}}>
 <div style={{width:460,height:525,position:'relative',overflow:'hidden',border:'1px solid #7b9caa',boxShadow:'0 0 60px #071420'}}>
  <Img src={staticFile(`battle/${person}.jpg`)} style={{width:'100%',height:'100%',objectFit:'cover',objectPosition:person==='yotan'?'50% 4%':'50% 0%',filter:'saturate(.72) contrast(1.08) brightness(.85)',transform:`scale(${1.02+t*.004})`,transformOrigin:'50% 22%'}}/>
  <AbsoluteFill style={{background:'repeating-linear-gradient(0deg,transparent 0px,transparent 3px,#08252b55 4px)',pointerEvents:'none'}}/>
  <div style={{position:'absolute',bottom:0,left:0,right:0,padding:'15px 22px',background:'#091921e8',fontSize:23,letterSpacing:5}}>{person==='yotan'?'よーたん':'福ちゃん'}</div>
 </div>
 <div style={{flex:1,paddingTop:65}}>
  <div style={{fontFamily:mono,fontSize:14,letterSpacing:4,color:'#73a4b3'}}>SOVA OPERATIONS / VOICE LINK</div>
  <div style={{marginTop:24,fontSize:47,letterSpacing:7,lineHeight:1.4}}>{label}</div>
  <div style={{height:1,background:'#487078',margin:'32px 0'}}/>
  <div style={{color:'#8dafb6',fontSize:17,letterSpacing:4}}>第３窓際指令所</div>
  <div style={{display:'flex',gap:5,alignItems:'center',height:55,marginTop:35}}>{Array.from({length:42},(_,i)=><div key={i} style={{width:5,height:5+Math.abs(Math.sin(i*1.9+t*8))*34,background:'#86babf',opacity:.55}}/>)}</div>
  <div style={{fontFamily:mono,fontSize:13,color:'#5f8593',letterSpacing:2}}>LINK 01   /   CONNECTED</div>
 </div>
 </AbsoluteFill>}
function Desktop({id,t}:{id:string;t:number}){
 const start=id==='ui-start',wait=id==='ui-wait',override=id==='override',report=id==='ui-report';
 const click=start?t>1:wait?t>1.0:report?t>.6:false;
 return <AbsoluteFill style={{background:override?'#210c12':'#818e91',padding:'50px 95px',color:'#26343c',fontFamily:font}}>
 <div style={{height:560,background:override?'#181b23':'#d5dad6',border:'3px solid #46565c',boxShadow:'0 15px 45px #0007',position:'relative'}}>
  <div style={{height:37,background:override?'#982d35':'#2c4655',color:'#eef0e2',fontSize:16,padding:'8px 15px',letterSpacing:1}}>ACCIDENCHUA　勤怠・業務管理システム</div>
  <div style={{padding:'30px 42px',fontSize:17,color:override?'#c0a9aa':'#596564'}}>やめ太郎　｜　所属：窓際族　｜　19:00</div>
  {override?<div style={{padding:'30px 45px',color:'#f3d8d1'}}><div style={{fontSize:20,letterSpacing:8,color:'#ce6f70'}}>権限変更通知</div><div style={{fontSize:43,lineHeight:1.55,marginTop:35}}>操縦権限が<br/>変更されました</div><div style={{fontSize:21,marginTop:30,color:'#d28d8b'}}>やめ太郎 → そば屋本人</div></div>:<>
   <div style={{padding:'5px 42px',fontSize:34,fontWeight:600}}>{wait?'移動申請':report?'本日の勤務':'勤怠打刻'}</div>
   <div style={{margin:'25px 42px',padding:'24px',border:'1px solid #adb7b2',background:'#e9eae1',width:590,fontSize:20,lineHeight:1.7}}>{wait?'申請内容：前進する\n申請先：よーたん'.split('\n').map(x=><div key={x}>{x}</div>):report?'本日の業務：巨大たこさんの撃破':'現在の状態：未出勤'}</div>
   <div style={{margin:'20px 42px',display:'inline-block',padding:'15px 60px',fontSize:25,color:'#fff',background:click?'#637673':'#31677a',boxShadow:'2px 3px #293b43'}}>{wait?'申請する':report?'退勤':'出勤'}</div>
   {click&&<div style={{position:'absolute',left:260,top:150,width:580,padding:'35px 32px',background:'#f3f1e7',border:'2px solid #6f7c7e',boxShadow:'10px 15px 25px #0004'}}>
    <div style={{fontSize:17,color:'#707a74',letterSpacing:3}}>{wait?'申請状況':report?'入力内容をご確認ください':'打刻完了'}</div>
    <div style={{fontSize:report?32:46,fontWeight:600,marginTop:30,lineHeight:1.5,color:report?'#a43730':'#294650'}}>{wait?'承認待ち':report?'業務報告書を\n提出してください'.split('\n').map(x=><div key={x}>{x}</div>):'業務開始'}</div>
    {wait&&<div style={{marginTop:25,fontSize:18,color:'#737a6b'}}>上長による承認をお待ちください。</div>}
    {report&&<div style={{marginTop:20,fontSize:18,color:'#78746e'}}>未提出のため、退勤できません。</div>}
   </div>}
   <div style={{position:'absolute',left:click?760:205+t*18,top:click?405:370,transform:'rotate(-20deg)',fontSize:40,color:'#162129',textShadow:'1px 1px #fff'}}>➤</div>
  </>}
 </div>
 </AbsoluteFill>
}
const sfx:{frame:number;name:string;volume:number}[]=[
 {frame:0,name:'rumble',volume:.5},{frame:55,name:'beam',volume:.6},{frame:80,name:'impact',volume:.8},{frame:47*24,name:'dock',volume:.5},
 {frame:50*24,name:'rumble',volume:.65},{frame:53*24+3,name:'impact',volume:.65},{frame:68*24,name:'impact',volume:.8},
 {frame:84*24+14,name:'impact',volume:.85},{frame:95*24+4,name:'beam',volume:.6},{frame:98*24,name:'impact',volume:.45},
 ...[114,115.5,117,118.5,120.3,124.4,128.1,132.2,142.3,146.4].map(s=>({frame:Math.round(s*24),name:s===124.4||s===142.3?'impact':'rumble',volume:.42})),
 {frame:149*24,name:'impact',volume:.95},{frame:151*24,name:'impact',volume:.8},{frame:152*24,name:'rumble',volume:.45}
];
export const BattleFilm:React.FC=()=>{
 const f=useCurrentFrame(),shot=m.shots.find(s=>f>=s.start&&f<s.end)??m.shots[m.shots.length-1],t=(f-shot.start)/FPS;
 const line=m.lines.find(l=>f>=l.start&&f<l.end),mouth=line?.speaker==='yametaro'?(line.mouth[f-line.start]??0):0;
 const battle=shot.kind==='battle',cockpit=shot.kind==='cockpit';
 let portrait=shot.id==='commander'||shot.id==='confirmed'?'yotan':'fukuchan';
 const flash=shot.id==='impact'?Math.max(0,1-t*5):shot.id==='explosion'?Math.max(0,.7-t*1.3):0;
 const shake=shot.id==='impact'?Math.sin(t*70)*5:0;
 return <AbsoluteFill style={{background:color.ink,color:color.paper,fontFamily:font,overflow:'hidden'}}>
  {battle&&<Plate src="city.png" t={t}/>}
  {(battle||cockpit||shot.kind==='dock3d'||shot.kind==='launch')&&<AbsoluteFill style={{transform:`translateX(${shake}px)`}}>
   <ThreeCanvas width={1280} height={720} shadows dpr={1} camera={{fov:39,near:.025,far:100}} gl={{antialias:true,alpha:true}}>
    {battle?<Battlefield id={shot.id} t={t}/>:cockpit?<Cockpit id={shot.id} t={t} mouth={mouth}/>:<Dock3D t={t} launch={shot.kind==='launch'} mouth={mouth}/>}
   </ThreeCanvas>
  </AbsoluteFill>}
  {shot.id==='title'&&<Title/>}
  {shot.kind==='plate'&&<Plate src={shot.id==='dock'?'dock.png':shot.id==='impact'?'impact.png':'ending.png'} t={t} end={shot.id==='ending'}/>}
  {shot.kind==='comms'&&<Comms person={portrait} t={t} label={shot.id==='commander'?'搭乗命令':shot.id==='confirmed'?'申請確認':shot.id==='silenced'?'目標、沈黙':'発進準備'}/>}
  {shot.kind==='ui'&&<Desktop id={shot.id} t={t}/>}
  {battle&&<AbsoluteFill style={{background:'linear-gradient(0deg,#030c15aa,transparent 35%,transparent 80%,#04111c55)',pointerEvents:'none'}}/>}
  {(shot.id==='opening'||shot.id==='land')&&<div style={{position:'absolute',left:55,top:57,fontSize:17,letterSpacing:6,color:'#bed4d9'}}>{shot.id==='opening'?'19:00　第３窓際市':'ソヴァ、出撃'}</div>}
  {shot.id==='inside'&&t<2&&<div style={{position:'absolute',left:60,top:55,fontSize:22,letterSpacing:5,color:'#243639'}}>ソヴァ内部・窓際席</div>}
  {cockpit&&<div style={{position:'absolute',left:58,bottom:115,padding:'6px 12px',background:'#d0b389',color:'#5c4b36',fontSize:14,letterSpacing:2}}>アーロンチュア　／　AERON CHUA</div>}
  {shot.id==='walk-command'&&<div style={{position:'absolute',right:65,top:58,padding:'10px 20px',border:'1px solid #91b8bf',background:'#0d2731cc',fontSize:17}}>通信：福ちゃん</div>}
  {shot.id==='counter'&&t<1.5&&<div style={{position:'absolute',right:60,top:60,color:'#bce6cf',padding:20,background:'#16352ee0',fontSize:23,letterSpacing:5}}>移動申請　承認</div>}
  {shot.id==='anger'&&<AbsoluteFill style={{background:'radial-gradient(ellipse,transparent 20%,#31081288)',pointerEvents:'none'}}/>}
  {shot.id==='bind'&&<div style={{position:'absolute',right:55,top:62,color:'#f29a82',letterSpacing:5,fontSize:20}}>拘束</div>}
  {shot.id==='impact'&&<AbsoluteFill style={{boxShadow:'inset 0 0 100px #370700',transform:`translate(${Math.sin(t*60)*3}px,0)`}}/>}
  <div style={{position:'absolute',top:0,left:0,right:0,height:25,background:'#070b11'}}/>
  <div style={{position:'absolute',bottom:0,left:0,right:0,height:25,background:'#070b11'}}/>
  {line&&<div style={{position:'absolute',bottom:48,left:85,right:85,textAlign:'center',fontSize:31,fontWeight:600,lineHeight:1.45,whiteSpace:'pre-line',textShadow:'0 2px 5px #000,1px 0 2px #000,-1px 0 2px #000'}}>{line.text}</div>}
  <Sequence from={8*24} durationInFrames={94*24}><Loop durationInFrames={36}><Audio src={staticFile('battle/dock.wav')} volume={.055}/></Loop></Sequence>
  {m.lines.map(l=><Sequence key={l.id} from={l.start} durationInFrames={l.end-l.start}><Audio src={staticFile(l.audio)} volume={.80}/></Sequence>)}
  {sfx.map((s,i)=><Sequence key={'s'+i} from={s.frame}><Audio src={staticFile('battle/'+s.name+'.wav')} volume={s.volume}/></Sequence>)}
  <AbsoluteFill style={{background:'#fff3da',opacity:flash,pointerEvents:'none'}}/>
  <AbsoluteFill style={{background:'#070b11',opacity: f<14?1-f/14:f>4290?(f-4290)/29:0,pointerEvents:'none'}}/>
 </AbsoluteFill>
};
