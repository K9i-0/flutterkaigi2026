import React from 'react';
import {AbsoluteFill,Audio,Loop,Sequence,staticFile,useCurrentFrame,interpolate} from 'remotion';
import {ThreeCanvas} from '@remotion/three';
import {Battlefield,Cockpit,Dock3D,CommandRoom,ease} from './BattleScene';
import m from './battle-manifest.json';
const FPS=24;
const color={ink:'#09161e',cyan:'#93c6cf',paper:'#eee9d9',red:'#ce3e39'};
const font='"Hiragino Sans","Noto Sans JP",sans-serif';
const mono='"Menlo",monospace';
function Title(){return <AbsoluteFill style={{background:'#000',color:'#fff',fontFamily:'"Hiragino Mincho ProN","YuMincho",serif',fontWeight:900,overflow:'hidden'}}>
 <div style={{position:'absolute',left:65,top:42,fontSize:86,letterSpacing:-9,lineHeight:1,WebkitTextStroke:'1.5px white'}}>第七拾話</div>
 <div style={{position:'absolute',right:67,top:60,fontFamily:'Arial,sans-serif',fontSize:20,fontWeight:900,letterSpacing:-.5,lineHeight:1.12,textAlign:'right'}}>MADOGIWA<br/>SOVANGELION<br/>EPISODE:70</div>
 <div style={{position:'absolute',left:55,top:187,fontSize:140,letterSpacing:-12,lineHeight:1,whiteSpace:'nowrap',transform:'scaleY(1.27)',transformOrigin:'left top',WebkitTextStroke:'2px white'}}>ソヴァンゲリオン</div>
 <div style={{position:'absolute',right:67,top:395,fontSize:123,letterSpacing:-10,lineHeight:1,transform:'scaleY(1.12)',transformOrigin:'right top',WebkitTextStroke:'1.5px white'}}>終わらない</div>
 <div style={{position:'absolute',right:63,top:524,fontSize:159,letterSpacing:-13,lineHeight:1,WebkitTextStroke:'2px white'}}>残業</div>
 <div style={{position:'absolute',left:68,bottom:57,fontFamily:'Arial,sans-serif',fontSize:22,fontWeight:900,letterSpacing:-.6,lineHeight:1.05}}>THE OVERTIME<br/>NEVER ENDS.</div>
 </AbsoluteFill>}
function Comms({person,t,label,speaking}:{person:'yotan'|'fukuchan';t:number;label:string;speaking:boolean}){return <AbsoluteFill style={{background:'radial-gradient(ellipse at 28% 45%,#294856,#0b1925 70%)',padding:'70px 80px',display:'flex',flexDirection:'row',gap:55}}>
 <div style={{width:460,height:525,position:'relative',overflow:'hidden',border:'1px solid #7b9caa',boxShadow:'0 0 60px #071420'}}>
  <ThreeCanvas width={460} height={525} shadows dpr={1} camera={{near:.05,far:30}} gl={{antialias:true}}><CommandRoom person={person} t={t} speaking={speaking}/></ThreeCanvas>
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
 const wait=id==='ui-wait',report=id==='ui-report',override=id==='override',bad=id==='bad-ui',click=!bad&&t>1;
 const button:React.CSSProperties={border:'3px outset #fff',background:'#c0c0c0',padding:'5px 10px',color:'#000',fontSize:16};
 return <AbsoluteFill style={{background:'#008080',padding:'36px 35px',color:'#000',fontFamily:'"MS Gothic","Hiragino Kaku Gothic ProN",monospace'}}>
 <div style={{height:615,background:'#c0c0c0',border:'4px outset #eee',position:'relative'}}>
 <div style={{background:'linear-gradient(90deg,navy,#3882be)',color:'white',padding:6,fontSize:19,fontWeight:800}}>ソヴァ操作支援システム（本番） - 最終版_修正2 - Microsoft Internet Explorer <span style={{float:'right'}}>＿ □ ×</span></div>
 <div style={{borderBottom:'2px groove white',fontSize:15,padding:6}}>ファイル(F)　編集(E)　表示(V)　お気に入り(A)　ツール(T)　ヘルプ(H)</div>
 <div style={{background:'#ffffad',color:'red',padding:7,fontSize:18}}>※「実行」の前に必ず「登録」を押して下さい（登録だけでは実行されません）</div>
 <div style={{display:'flex',height:475}}><div style={{width:185,background:'#dedede',padding:12,fontSize:16,lineHeight:2.05,borderRight:'4px ridge white'}}>{['メニュー','●操縦管理','　操縦登録','　操縦登録（新）','　新操縦（旧）','●申請管理','　移動する','　移動申請一覧','●マスタ管理','　ユーザーマスタ','●その他','　ログアウト'].map((x,i)=><div key={i} style={{color:i%3===0?'purple':'blue',textDecoration:'underline'}}>{x}</div>)}</div>
 <div style={{flex:1,padding:'8px 12px',position:'relative'}}>
 <div style={{fontSize:23,color:'#c00000',fontWeight:900,background:'#ff0',display:'inline-block'}}>★☆ ソヴァ操作メニューへようこそ ☆★</div>
 <div style={{fontSize:12,margin:'7px 0'}}>推奨環境：Internet Explorer 6.0 ／ 1024×768 ／ 戻るボタン禁止</div>
 <div style={{display:'flex',gap:4}}>{['基本情報','詳細情報','詳細情報２','その他','その他２','備考'].map(x=><span key={x} style={button}>{x}</span>)}</div>
 <div style={{border:'2px inset white',background:'#eee',padding:9,marginTop:7,fontSize:16,lineHeight:1.85}}>
 <div>所属コード<span style={{color:'red'}}>【必須】</span> <span style={{background:'white',border:'2px inset white'}}> 00000003 </span>　※半角数字８桁</div>
 <div>操縦日付<span style={{color:'red'}}>【必須】</span> <span style={{background:'white'}}>2026</span>年 <span style={{background:'white'}}>09</span>月 <span style={{background:'white'}}>22</span>日　<span style={button}>検索</span></div>
 <div>移動区分<span style={{color:'red'}}>【必須】</span> <span style={{background:'white'}}>選択してください　▼</span>　<span style={button}>再読込</span></div>
 <div>前進フラグ　○する　○しない　○未設定　 ※歩行は別画面です</div>
 <div>申請理由　<span style={{background:'white',border:'2px inset white'}}>　　　　　　　　　　　　　　　　　</span></div>
 </div>
 <div style={{marginTop:12,display:'flex',gap:7}}>{['登録','保存','反映','適用','実行','確定','取消','クリア'].map(x=><span key={x} style={button}>{x}</span>)}</div>
 <div style={{fontSize:12,color:'#777',marginTop:9}}>※保存内容は反映されません。確定後に適用してください。</div>
 <div style={{marginTop:14,display:'flex',gap:11}}>{['出勤','前進申請','退勤'].map(x=><span key={x} style={{...button,fontSize:19}}>{x}</span>)}<span style={{fontSize:11,color:'blue',textDecoration:'underline',paddingTop:15}}>歩行はこちら（別窓）</span></div>
 </div></div>
 <div style={{position:'absolute',bottom:0,left:0,right:0,border:'2px inset white',padding:3,fontSize:12}}>完了　｜　ログイン：やめ太郎　｜　管理者に連絡してください　｜　Num</div>
 </div>
 {(bad||click)&&<div style={{position:'absolute',left:bad?610:410,top:bad?290:205,width:bad?490:560,background:'#c0c0c0',border:'4px outset white',boxShadow:'7px 7px #0005',padding:5}}>
 <div style={{background:'navy',color:'white',fontSize:17,padding:4}}>確認 <span style={{float:'right'}}>×</span></div>
 <div style={{display:'flex',padding:'24px 12px',gap:18}}><span style={{fontSize:40}}>⚠</span><div style={{fontSize:bad?20:27,lineHeight:1.6}}>{bad?'入力内容を確認しますか？\n※まだ登録されていません。'.split('\n').map(x=><div key={x}>{x}</div>):override?'操縦権限：そば屋本人':wait?'承認待ち':report?'業務報告書を提出してください':'業務開始'}</div></div>
 <div style={{display:'flex',justifyContent:'center',gap:25,paddingBottom:15}}><span style={button}>{bad?'いいえ(N)':'OK'}</span><span style={button}>{bad?'はい(Y)':'キャンセル'}</span></div>
 </div>}
 <div style={{position:'absolute',left:bad?620+Math.sin(t*1.6)*240:820,top:bad?465+Math.cos(t*2)*55:420,fontSize:36,textShadow:'1px 1px white'}}>↖</div>
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
 let portrait:'yotan'|'fukuchan'=shot.id==='commander'||shot.id==='confirmed'?'yotan':'fukuchan';
 const flash=shot.id==='impact'?Math.max(0,1-t*5):shot.id==='explosion'?Math.max(0,.7-t*1.3):0;
 const shake=shot.id==='impact'?Math.sin(t*70)*5:0;
 return <AbsoluteFill style={{background:color.ink,color:color.paper,fontFamily:font,overflow:'hidden'}}>
  {(battle||cockpit||shot.kind==='dock3d'||shot.kind==='launch')&&<AbsoluteFill style={{transform:`translateX(${shake}px)`}}>
   <ThreeCanvas width={1280} height={720} shadows dpr={1} camera={{fov:39,near:.025,far:100}} gl={{antialias:true,alpha:true}}>
    {battle?<Battlefield id={shot.id} t={t}/>:cockpit?<Cockpit id={shot.id} t={t} mouth={mouth}/>:<Dock3D id={shot.id} t={t} wide={shot.id==='dock'} launch={shot.kind==='launch'} mouth={mouth}/>}
   </ThreeCanvas>
  </AbsoluteFill>}
  {shot.id==='title'&&<Title/>}

  {shot.kind==='comms'&&<Comms person={portrait} t={t} speaking={line?.speaker===portrait} label={shot.id==='commander'?'搭乗命令':shot.id==='confirmed'?'申請確認':shot.id==='silenced'?'目標、沈黙':'発進準備'}/>}
  {shot.kind==='ui'&&<Desktop id={shot.id} t={t}/>}
  {battle&&<AbsoluteFill style={{background:'linear-gradient(0deg,#030c15aa,transparent 35%,transparent 80%,#04111c55)',pointerEvents:'none'}}/>}
  {(shot.id==='opening'||shot.id==='land')&&<div style={{position:'absolute',left:55,top:57,fontSize:17,letterSpacing:6,color:'#bed4d9'}}>{shot.id==='opening'?'19:00　第３窓際市':'ソヴァ、出撃'}</div>}
  {shot.id==='boarding'&&<div style={{position:'absolute',left:70,top:65,padding:'14px 22px',background:'#101b2bea',border:'1px solid #7896a2',fontSize:27}}>やめ太郎 移動中{'・'.repeat(Math.floor(t*2)%4)}<div style={{fontSize:16,marginTop:10}}>搭乗口 → ソヴァ内部・窓際席</div></div>}
  {shot.id==='ui-author'&&<div style={{position:'absolute',right:65,top:58,padding:12,background:'#223344',fontSize:19}}>通信：福ちゃん</div>}
  {shot.id==='inside'&&t<2&&<div style={{position:'absolute',left:60,top:55,fontSize:22,letterSpacing:5,color:'#243639'}}>ソヴァ内部・窓際席</div>}
  {cockpit&&shot.id!=='ui-author'&&<div style={{position:'absolute',left:58,bottom:115,padding:'6px 12px',background:'#d0b389',color:'#5c4b36',fontSize:14,letterSpacing:2}}>アーロンチュア　／　AERON CHUA</div>}
  {shot.id==='walk-command'&&<div style={{position:'absolute',right:65,top:58,padding:'10px 20px',border:'1px solid #91b8bf',background:'#0d2731cc',fontSize:17}}>通信：福ちゃん</div>}
  {shot.id==='counter'&&t<1.5&&<div style={{position:'absolute',right:60,top:60,color:'#bce6cf',padding:20,background:'#16352ee0',fontSize:23,letterSpacing:5}}>移動申請　承認</div>}
  {shot.id==='anger'&&<AbsoluteFill style={{background:'radial-gradient(ellipse,transparent 20%,#31081288)',pointerEvents:'none'}}/>}
  {shot.id==='bind'&&<div style={{position:'absolute',right:55,top:62,color:'#f29a82',letterSpacing:5,fontSize:20}}>拘束</div>}
  {shot.id==='impact'&&<AbsoluteFill style={{boxShadow:'inset 0 0 100px #370700',transform:`translate(${Math.sin(t*60)*3}px,0)`}}/>}
  <div style={{position:'absolute',top:0,left:0,right:0,height:25,background:'#070b11'}}/>
  <div style={{position:'absolute',bottom:0,left:0,right:0,height:25,background:'#070b11'}}/>
  {line&&<div style={{position:'absolute',bottom:48,left:85,right:85,textAlign:'center',fontSize:line.text.length>30?26:31,fontWeight:600,lineHeight:1.45,whiteSpace:'pre-line',textShadow:'0 2px 5px #000,1px 0 2px #000,-1px 0 2px #000'}}>{line.text}</div>}
  <Sequence from={8*24} durationInFrames={94*24}><Loop durationInFrames={36}><Audio src={staticFile('battle/dock.wav')} volume={.055}/></Loop></Sequence>
  {m.lines.map(l=><Sequence key={l.id} from={l.start} durationInFrames={l.end-l.start}><Audio src={staticFile(l.audio)} volume={.80}/></Sequence>)}
  {sfx.map((s,i)=><Sequence key={'s'+i} from={s.frame+(s.frame>=27*24?96:0)+(s.frame>=40*24?288:0)}><Audio src={staticFile('battle/'+s.name+'.wav')} volume={s.volume}/></Sequence>)}
  <AbsoluteFill style={{background:'#fff3da',opacity:flash,pointerEvents:'none'}}/>
  <AbsoluteFill style={{background:'#070b11',opacity: f>m.composition.durationInFrames-30?(f-(m.composition.durationInFrames-30))/29:0,pointerEvents:'none'}}/>
  {f<36&&<Title/>}
 </AbsoluteFill>
};
