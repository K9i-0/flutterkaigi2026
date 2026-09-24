import React from 'react';
import {AbsoluteFill, Composition, interpolate, registerRoot, useCurrentFrame} from 'remotion';
import m from './edit-manifest.json';

const C={cyan:'#78f5df',dim:'#69928e',white:'#e6f5ef',amber:'#ffc66b',red:'#ff685d',panel:'rgba(5,19,22,.92)'};
const mono='"SFMono-Regular", Menlo, monospace';
const font='"Hiragino Sans", "Noto Sans JP", sans-serif';
const lerp=(f:number,a:number,b:number)=>interpolate(f,[a,b],[0,1],{extrapolateLeft:'clamp',extrapolateRight:'clamp'});
const fmt=(n:number)=>Math.round(n).toLocaleString('en-US');
const Line:React.FC<{children:React.ReactNode,color?:string}>=({children,color=C.dim})=><div style={{fontSize:18,letterSpacing:2,color,fontFamily:mono}}>{children}</div>;

const Target:React.FC<{i:number}>=({i})=>{
 const f=useCurrentFrame(),s=m.subjects[i],start=i?m.timing.yameStart:m.timing.fukuStart,end=i?m.timing.yameEnd:m.timing.fukuEnd;
 const p=lerp(f,start,end),done=f>=end,active=f>=start,capture=f>=m.timing.capture;
 const alarm=i===1&&p*s.value>=m.reference.outlier;
 const color=capture||alarm?C.red:i===0&&done?C.amber:C.cyan;
 return <>
  <div style={{position:'absolute',left:s.x,top:s.y,width:s.w,height:s.h,color,opacity:lerp(f,3,20)}}>
   <div style={{position:'absolute',top:-37,width:'100%',fontFamily:mono,fontSize:19,letterSpacing:3}}>SUBJECT / {s.id}<span style={{float:'right',fontSize:15}}>{done?'LOCKED':active?'SCANNING':'STANDBY'}</span></div>
   <svg width={s.w} height={s.h} style={{position:'absolute'}}><path d={`M 0 55 V 0 H 55 M ${s.w-55} 0 H ${s.w} V 55 M 0 ${s.h-55} V ${s.h} H 55 M ${s.w-55} ${s.h} H ${s.w} V ${s.h-55}`} fill="none" stroke={color} strokeWidth="3"/><path d={`M ${s.w/2-15} ${s.h/2} h 30 M ${s.w/2} ${s.h/2-15} v 30`} stroke={color} opacity=".35"/></svg>
   {active&&!done&&<div style={{position:'absolute',left:2,right:2,top:p*(s.h-40),height:40,background:`linear-gradient(transparent,${color}25)`,borderBottom:`2px solid ${color}`,boxShadow:`0 8px 24px ${color}15`}}/>}
   <div style={{position:'absolute',bottom:15,left:18,fontFamily:mono,fontSize:15,letterSpacing:2,color:C.dim}}>{done?'ANALYSIS COMPLETE':'BIO-SIGNAL ACQUISITION'}</div>
  </div>
  <div style={{position:'absolute',left:s.x,top:680,width:s.w,height:228,background:C.panel,borderTop:`3px solid ${color}`,padding:'21px 25px',boxSizing:'border-box'}}>
   <div style={{display:'flex',alignItems:'center',justifyContent:'space-between'}}><span style={{fontSize:28}}>{s.name}</span><span style={{fontSize:17,color,letterSpacing:2}}>{capture?'捕獲対象':done?s.classification:active?'測定中':'測定待機'}</span></div>
   <div style={{display:'flex',alignItems:'baseline',gap:14,marginTop:6}}><span style={{fontFamily:mono,fontSize:76,letterSpacing:-3,color,fontVariantNumeric:'tabular-nums'}}>{active?fmt(s.value*p):'—'}</span><span style={{fontFamily:mono,fontSize:24,color:C.dim}}>MW</span></div>
   <div style={{display:'flex',justifyContent:'space-between',fontSize:17,color:C.dim}}><span>窓際力</span><span style={{fontFamily:mono}}>{done?`標準比 × ${(s.value/10).toFixed(1)}`:'CALIBRATING'}</span></div>
   <div style={{height:3,background:'#203b3c',marginTop:17}}><div style={{width:`${p*100}%`,height:'100%',background:color}}/></div>
  </div>
 </>;
};

const Compare:React.FC=()=>{
 const f=useCurrentFrame(),done=f>=m.timing.yameEnd;
 const rows=[{n:'標準窓際社員',v:10,c:C.dim},{n:'福ちゃん',v:213,c:C.amber},{n:'やめ太郎',v:5082,c:C.red},{n:'そば屋 / 原体',v:10247,c:C.cyan}];
 return <div style={{position:'absolute',left:1270,top:192,width:520,height:716,background:C.panel,border:'1px solid #274244',padding:'28px 30px',boxSizing:'border-box'}}>
  <Line>COMPARATIVE ANALYSIS</Line><div style={{fontSize:29,marginTop:12,marginBottom:28}}>窓際力 比較</div>
  {rows.map((r,i)=><div key={r.n} style={{marginBottom:26,opacity:((i===1&&f<m.timing.fukuEnd)||(i===2&&!done))?.35:1}}><div style={{display:'flex',justifyContent:'space-between',fontSize:20,marginBottom:10}}><span>{r.n}</span><span style={{fontFamily:mono,color:r.c}}>{((i===1&&f<m.timing.fukuEnd)||(i===2&&!done))?'—':fmt(r.v)} <small style={{fontSize:14}}>MW</small></span></div><div style={{height:6,background:'#193234'}}><div style={{height:'100%',width:`${((i===1&&f<m.timing.fukuEnd)||(i===2&&!done))?0:Math.log10(r.v)/Math.log10(12000)*100}%`,background:r.c}}/></div></div>)}
  <div style={{fontFamily:mono,fontSize:13,color:C.dim,textAlign:'right',letterSpacing:2}}>LOG SCALE / 対数表示</div>
  <div style={{borderTop:'1px solid #274244',marginTop:28,paddingTop:23}}><Line color={done?C.red:C.cyan}>{done?'ANOMALY DETECTED':'REFERENCE STANDARD'}</Line><div style={{fontSize:27,marginTop:12,color:done?C.red:C.white}}>{done?'規格外個体を検出':'標準窓際社員 ＝ 10 MW'}</div><div style={{fontSize:19,color:C.dim,marginTop:12,lineHeight:1.8}}>{done?<>やめ太郎：原体の49.6%<br/>比較研究対象として確保</>:<>基準個体を10とする相対尺度<br/>原体：そば屋 / 10,247 MW</>}</div></div>
 </div>;
};

export const MadogiwaScanner:React.FC<{preview?:boolean}>=({preview=false})=>{
 const f=useCurrentFrame(),capture=f>=m.timing.capture,alarm=f>=m.timing.yameStart+(m.timing.yameEnd-m.timing.yameStart)*1000/5082;
 return <AbsoluteFill style={{fontFamily:font,color:C.white,fontWeight:400,background:preview?'#061114':'transparent'}}>
  {preview&&<AbsoluteFill style={{backgroundImage:'radial-gradient(ellipse at 30% 40%, #143331 0%, transparent 65%),linear-gradient(#17343133 1px,transparent 1px),linear-gradient(90deg,#17343133 1px,transparent 1px)',backgroundSize:'100% 100%,60px 60px,60px 60px'}}><div style={{position:'absolute',left:140,top:380,width:1030,textAlign:'center',color:'#517771',fontSize:20,letterSpacing:5}}>監視映像 合成エリア</div></AbsoluteFill>}
  <AbsoluteFill style={{opacity:lerp(f,0,m.timing.bootEnd)}}>
   <div style={{position:'absolute',left:96,top:62,right:96,display:'flex',justifyContent:'space-between',alignItems:'center',borderBottom:'1px solid #42615f',paddingBottom:24}}>
    <div><Line color={C.cyan}>MADOGIWA RESEARCH / BIO-OBSERVATION SYSTEM</Line><div style={{fontSize:38,letterSpacing:4,marginTop:10}}>窓際力解析システム</div></div>
    <div style={{textAlign:'right'}}><div style={{fontFamily:mono,fontSize:18,color:alarm?C.red:C.cyan,letterSpacing:3}}>● {capture?'CONTAINMENT':alarm?'ANOMALY':'LIVE SCAN'} / LAB 07</div><div style={{fontSize:20,marginTop:12,color:C.dim}}>基準：標準窓際社員 ＝ 10 MW</div></div>
   </div>
   <Target i={0}/><Target i={1}/><Compare/>
   <div style={{position:'absolute',left:96,right:96,top:950,height:64,display:'flex',alignItems:'center',justifyContent:'space-between',padding:'0 25px',background:capture?'#401d1bef':'#071c20eb',borderLeft:`4px solid ${alarm?C.red:C.cyan}`,boxSizing:'border-box'}}>
    <span style={{fontSize:23,letterSpacing:3,color:alarm?C.red:C.cyan}}>{capture?'捕獲対象：福ちゃん ／ やめ太郎':alarm?'警告：規格外の窓際力を検出':'生体信号を取得中'}</span>
    <span style={{fontFamily:mono,fontSize:17,letterSpacing:2,color:capture?C.red:C.dim}}>{capture?'生体回収 / 出口封鎖':`SCAN ${String(Math.floor(f/30)).padStart(2,'0')}:${String(f%30).padStart(2,'0')} / 02 SUBJECTS`}</span>
   </div>
  </AbsoluteFill>
 </AbsoluteFill>;
};
const Root:React.FC=()=> <>{[true,false].map(preview=><Composition key={String(preview)} id={preview?'ScannerPreview':'ScannerOverlay'} component={MadogiwaScanner} {...m.composition} defaultProps={{preview}}/>)}</>;
registerRoot(Root);
