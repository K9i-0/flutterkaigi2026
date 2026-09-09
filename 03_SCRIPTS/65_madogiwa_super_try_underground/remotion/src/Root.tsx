import React from 'react';
import {AbsoluteFill, Composition, Img, OffthreadVideo, staticFile, useCurrentFrame} from 'remotion';
import m from './edit-manifest.json';
const Commercial: React.FC = () => {
 const f=useCurrentFrame(); const c=m.crop; const crop=f>=c.from&&f<c.to; const e=m.endcard;
 return <AbsoluteFill style={{background:'#0b1322',fontFamily:'Hiragino Sans, sans-serif',overflow:'hidden'}}>
  <OffthreadVideo muted src={staticFile(m.inputVideo)} style={crop?{position:'absolute',width:854*854/c.width,height:480*480/c.height,left:-c.x*854/c.width,top:-c.y*480/c.height}:{width:'100%',height:'100%'}} />
  {f>=m.posterInsert.from&&f<m.posterInsert.to&&<AbsoluteFill style={{background:'#161b21',alignItems:'center',justifyContent:'center'}}><Img src={staticFile('points.png')} style={{height:456,boxShadow:'0 8px 30px #000',transform:`scale(${1+(f-m.posterInsert.from)*0.0003})`}} /></AbsoluteFill>}
  {f>=e.from&&<AbsoluteFill><div style={{position:'absolute',left:410,top:0,right:0,bottom:0,background:'linear-gradient(90deg,#0a1224,#0a1224)'}}/><div style={{position:'absolute',left:433,top:137,right:28,color:'#f4f6fa'}}><div style={{fontSize:23,fontWeight:500,whiteSpace:'nowrap'}}>{e.copy}</div><div style={{width:36,height:3,background:'#f33c4f',marginTop:27,marginBottom:24}}/><div style={{fontSize:33,fontWeight:700,letterSpacing:-1,whiteSpace:'nowrap',color:'#ff4053'}}>{e.productName}</div><div style={{fontFamily:'Helvetica Neue, sans-serif',fontSize:29,fontStyle:'italic',fontWeight:700,marginTop:13,whiteSpace:'nowrap'}}>{e.englishName}</div></div></AbsoluteFill>}
 </AbsoluteFill>;
};
export const Root: React.FC=()=> <Composition component={Commercial} {...m.composition}/>;
