import React from 'react';
import {AbsoluteFill, Composition, Img, OffthreadVideo, staticFile, useCurrentFrame, useVideoConfig} from 'remotion';
import manifest from './edit-manifest.json';

type Props = {previewOnly: boolean};
const Commercial: React.FC<Props> = ({previewOnly}) => {
  const frame = useCurrentFrame();
  const {width, height} = useVideoConfig();
  const end = manifest.endcard;
  return <AbsoluteFill style={{backgroundColor:'#10151b', fontFamily:'Hiragino Sans, sans-serif'}}>
    {!previewOnly && <OffthreadVideo src={staticFile(manifest.inputVideo)} style={{width:'100%',height:'100%',objectFit:'contain'}} />}
    {previewOnly && <Img src={staticFile('endcard_background.png')} style={{width:'100%',height:'100%'}} />}
    {frame >= end.from && frame < end.to && <AbsoluteFill>
      <div style={{position:'absolute',width:1280,height:720,transform:`scale(${width/1280},${height/720})`,transformOrigin:'top left'}}>
      <div style={{position:'absolute',left:604,right:40,top:154,color:'#f3f5f7',textShadow:'0 2px 10px rgba(0,0,0,.55)'}}>
        <div style={{fontSize:30,fontWeight:600,letterSpacing:1,whiteSpace:'nowrap'}}>{end.copy}</div>
        <div style={{width:54,height:5,background:'#ef2038',marginTop:36,marginBottom:29}} />
        <div style={{fontSize:52,fontWeight:900,letterSpacing:-2,color:'#ff354b',whiteSpace:'nowrap'}}>{end.productName}</div>
        <div style={{fontFamily:'Helvetica Neue, sans-serif',fontSize:43,fontWeight:800,fontStyle:'italic',marginTop:15,whiteSpace:'nowrap'}}>{end.englishName}</div>
      </div>
      </div>
    </AbsoluteFill>}
  </AbsoluteFill>;
};
export const Root: React.FC = () => <Composition id={manifest.composition.id} component={Commercial} width={manifest.composition.width} height={manifest.composition.height} fps={manifest.composition.fps} durationInFrames={manifest.composition.durationInFrames} defaultProps={{previewOnly:false}} />;
