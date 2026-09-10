import React from 'react';
import {AbsoluteFill, Audio, Img, Sequence, interpolate, staticFile, useCurrentFrame} from 'remotion';
import m from './edit-manifest.json';
import effects from './effects-manifest.json';
export type Mode='A'|'B'|'C';
const clamp={extrapolateLeft:'clamp',extrapolateRight:'clamp'} as const;
const shape='M358 130 Q512 105 668 129 L665 155 Q668 177 690 216 L690 753 Q689 773 662 785 L652 800 Q513 820 375 800 L364 785 Q334 775 334 752 L334 216 Q359 176 360 155 Z';
const rand=(n:number)=>{const x=Math.sin(n*127.1+311.7)*43758.5453;return x-Math.floor(x);};
const drops=Array.from({length:200},(_,i)=>{
 // Concentrate condensation near silver sides, leaving the printed center readable.
 const edge=rand(i+1)<.74;
 const x=edge?(rand(i+501)<.5?346+rand(i+31)*45:632+rand(i+31)*44):354+rand(i+31)*315;
 return {x,y:166+rand(i+81)*586,r:1.2+Math.pow(rand(i+91),2)*3.8};
});
export const Effects:React.FC<{mode:Mode;titleImage?:string;notice?:boolean}>=({mode,titleImage,notice=false})=>{
 const f=useCurrentFrame(); const cfg=effects.variants[mode];
 const t=interpolate(f,[0,effects.composition.durationInFrames-1],[0,1],clamp);
 const sweep=interpolate(f,effects.events.lightSweep,[275,750],clamp);
 const pulse=Math.sin(Math.PI*interpolate(f,effects.events.lightSweep,[0,1],clamp));
 const textOpacity=interpolate(f,effects.events.textFade,[0,1],clamp);
 const image=staticFile(effects.image);
 const audioFrames=m.audioSource.endFrame-m.audioSource.startFrame;
 return <AbsoluteFill style={{background:'#05080d'}}>
  <AbsoluteFill style={{transform:`scale(${1+t*.012})`,transformOrigin:'31% 65%',opacity:interpolate(f,effects.events.pictureFade,[0,1],clamp)}}>
   <Img src={image} style={{width:'100%',height:'100%',filter:`blur(${cfg.blur}px)`,transform:'scale(1.005)'}}/>
   <svg viewBox="0 0 1672 941" style={{position:'absolute',width:'100%',height:'100%'}}>
    <defs>
     <clipPath id="can"><path d={shape}/></clipPath>
     <linearGradient id="sweep"><stop stopColor="#bbdfff" stopOpacity="0"/><stop offset=".47" stopColor="#ecf7ff" stopOpacity=".75"/><stop offset=".54" stopColor="white"/><stop offset="1" stopColor="#bce3ff" stopOpacity="0"/></linearGradient>
     <radialGradient id="drop" cx=".3" cy=".2" r=".85"><stop stopColor="#eaf9ff" stopOpacity=".05"/><stop offset=".58" stopColor="#06131e" stopOpacity=".05"/><stop offset=".86" stopColor="#05131b" stopOpacity=".55"/><stop offset="1" stopColor="#edfbff" stopOpacity=".55"/></radialGradient>
     <radialGradient id="bloom"><stop stopColor="#c8eeff" stopOpacity=".7"/><stop offset=".13" stopColor="#91caff" stopOpacity=".28"/><stop offset="1" stopColor="#61a9ef" stopOpacity="0"/></radialGradient>
    </defs>
    <image href={image} width="1672" height="941" clipPath="url(#can)"/>
    <g clipPath="url(#can)">
     <g opacity={cfg.dropletOpacity}>
      {drops.slice(0,cfg.drops).map((d,i)=>{
       const falling=mode==='C'&&i===4?interpolate(f,effects.events.fallingDrop,[0,31],clamp):0;
       const r=d.r; const light=.4+.5*Math.exp(-Math.pow((sweep-d.x)/90,2));
       return <g key={i} transform={`translate(${d.x} ${d.y+falling})`}>
        <ellipse rx={r} ry={r*1.25} fill="url(#drop)"/>
        <path d={`M${-r*.65} ${-r*.1} Q${-r*.6} ${-r*.95} ${r*.08} ${-r*.98}`} fill="none" stroke="#f1fbff" strokeWidth={Math.max(.65,r*.22)} strokeLinecap="round" opacity={light}/>
        <ellipse cx={r*.12} cy={r*.76} rx={r*.42} ry={r*.14} fill="#e5f6ff" opacity=".5"/>
       </g>;
      })}
     </g>
     <rect x={sweep-85} y="112" width="170" height="712" fill="url(#sweep)" opacity={cfg.sweep*pulse} style={{mixBlendMode:'screen'}}/>
    </g>
    {mode==='C'&&<g opacity={pulse*.46} style={{mixBlendMode:'screen'}}>
     <ellipse cx="360" cy="158" rx="120" ry="64" fill="url(#bloom)"/>
     <ellipse cx="672" cy="750" rx="80" ry="40" fill="url(#bloom)"/>
    </g>}
   </svg>
  </AbsoluteFill>
  {titleImage ? <Img src={staticFile(titleImage)} style={{position:'absolute',left:950,top:150,width:850,height:780,objectFit:'contain',opacity:textOpacity,transform:`translateY(${interpolate(f,effects.events.textFade,[10,0],clamp)}px)`}}/> : <div style={{position:'absolute',left:1030,top:315,width:735,opacity:textOpacity,transform:`translateY(${interpolate(f,effects.events.textFade,[10,0],clamp)}px)`,fontFamily:'"Hiragino Kaku Gothic ProN",sans-serif',color:'#f4f3ef',textShadow:'0 2px 14px rgba(0,0,0,.25)'}}>
   <div style={{fontSize:78,fontWeight:600,letterSpacing:12,lineHeight:1.4}}>窓際</div>
   <div style={{fontSize:64,fontWeight:600,letterSpacing:6,lineHeight:1.6,marginTop:24}}>スーパー</div>
   <div style={{fontFamily:'"Hiragino Maru Gothic ProN",sans-serif',fontSize:166,fontWeight:400,letterSpacing:4,lineHeight:1.15,color:'#ed3733'}}>つらい</div>
  </div>}
  {notice && <div style={{position:'absolute',left:effects.sampleCopy.left,top:effects.sampleCopy.top,width:effects.sampleCopy.width,textAlign:'center',fontFamily:'"Hiragino Kaku Gothic ProN",sans-serif',fontSize:effects.sampleCopy.fontSize,fontWeight:effects.sampleCopy.fontWeight,letterSpacing:effects.sampleCopy.letterSpacing,color:'#faf8f1',lineHeight:1.5,textShadow:'0 2px 0 #18202a, 0 4px 14px rgba(0,0,0,.6)',opacity:textOpacity}}>{effects.sampleCopy.text}</div>}
  {notice && <div style={{position:'absolute',left:64,top:118,display:'flex',gap:13,color:'#f6f6f2',fontFamily:'"Hiragino Kaku Gothic ProN",sans-serif',fontSize:27,fontWeight:500,lineHeight:1.6,letterSpacing:3,textShadow:'0 1px 5px #000, 0 0 12px #000',opacity:interpolate(f,effects.events.pictureFade,[0,1],clamp)}}>
   <div style={{writingMode:'vertical-rl'}}>飲酒運転はしない。</div>
   <div style={{writingMode:'vertical-rl'}}>お酒は<span style={{textCombineUpright:'all',letterSpacing:0}}>20</span>歳になってから。</div>
  </div>}
  <Sequence from={m.audioStartFrame} durationInFrames={audioFrames}><Audio src={staticFile(m.audio)} volume={af=>interpolate(af,[0,m.audioFadeInFrames,audioFrames-m.audioFadeOutFrames,audioFrames-1],[0,1,1,0],clamp)}/></Sequence>
 </AbsoluteFill>;
};
