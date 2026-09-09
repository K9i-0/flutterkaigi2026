import React from 'react';
import {AbsoluteFill, Composition, OffthreadVideo, staticFile, useCurrentFrame} from 'remotion';
import m from './edit-manifest-v2.json';

const CommercialV2: React.FC = () => {
  const frame = useCurrentFrame();
  const end = m.endcard;
  return <AbsoluteFill style={{background:'#0a1224',fontFamily:'Hiragino Sans, sans-serif',overflow:'hidden'}}>
    <OffthreadVideo muted src={staticFile(m.inputVideo)} style={{width:'100%',height:'100%',objectFit:'contain'}} />
    {frame >= end.from && frame < end.to && <AbsoluteFill>
      {end.coverGeneratedText && <div style={{position:'absolute',left:410,top:0,right:0,bottom:0,background:'#0a1224'}} />}
      <div style={{position:'absolute',left:433,top:137,right:28,color:'#f4f6fa',textShadow:'0 2px 6px #0008'}}>
        <div style={{fontSize:23,fontWeight:500,whiteSpace:'nowrap'}}>{end.copy}</div>
        <div style={{width:36,height:3,background:'#f33c4f',marginTop:27,marginBottom:24}} />
        <div style={{fontSize:33,fontWeight:700,letterSpacing:-1,whiteSpace:'nowrap',color:'#ff4053'}}>{end.productName}</div>
        <div style={{fontFamily:'Helvetica Neue, sans-serif',fontSize:29,fontStyle:'italic',fontWeight:700,marginTop:13,whiteSpace:'nowrap'}}>{end.englishName}</div>
      </div>
    </AbsoluteFill>}
  </AbsoluteFill>;
};
export const RootV2: React.FC = () => <Composition component={CommercialV2} {...m.composition} />;
