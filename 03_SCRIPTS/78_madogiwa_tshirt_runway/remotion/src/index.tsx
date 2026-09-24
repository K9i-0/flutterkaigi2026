import React from 'react';
import {AbsoluteFill, Audio, Composition, Img, OffthreadVideo, Sequence, interpolate, registerRoot, staticFile, useCurrentFrame} from 'remotion';
import m from './edit-manifest.json';
const Endcard: React.FC = () => {
 const frame=useCurrentFrame(); const e=m.endcard;
 const opacity=interpolate(frame,[0,e.fadeInFrames],[0,1],{extrapolateLeft:'clamp',extrapolateRight:'clamp'});
 const productOpacity=interpolate(frame,[e.productFrom,e.productFrom+e.fadeInFrames],[0,1],{extrapolateLeft:'clamp',extrapolateRight:'clamp'});
 const image=e.image; const scale=500/image.crop.width;
 return <AbsoluteFill style={{backgroundColor:'#000',color:'#f6f3ed',fontFamily:'"Hiragino Mincho ProN", "Yu Mincho", serif'}}>
   <div style={{position:'absolute',left:80,top:140,width:500,height:image.crop.height*scale,overflow:'hidden',opacity,backgroundColor:'#fff'}}>
     <Img src={staticFile(image.file)} style={{position:'absolute',width:image.sourceWidth*scale,maxWidth:'none',left:-image.crop.x*scale,top:-image.crop.y*scale}}/>
   </div>
   <div style={{position:'absolute',left:660,top:245,width:540,opacity,fontSize:48,lineHeight:1.75,letterSpacing:'0.05em',fontWeight:300}}>{e.copy.map(line=><div key={line}>{line}</div>)}</div>
   <div style={{position:'absolute',left:664,top:470,opacity:productOpacity,fontFamily:'"Hiragino Kaku Gothic ProN", sans-serif',fontSize:23,letterSpacing:'0.2em'}}>{e.product}</div>
 </AbsoluteFill>;
};
const EndcardPreview:React.FC=()=> <><Audio src={staticFile('final_audio.wav')} startFrom={m.endcard.from}/><Endcard/></>;
const Film:React.FC=()=> <AbsoluteFill style={{backgroundColor:'black'}}>
 <Audio src={staticFile('final_audio.wav')}/>
 <Sequence durationInFrames={m.endcard.from}><OffthreadVideo src={staticFile(m.inputVideo)} muted style={{width:'100%',height:'100%',objectFit:'contain'}}/></Sequence>
 <Sequence from={m.endcard.from} durationInFrames={m.endcard.durationInFrames}><Endcard/></Sequence>
</AbsoluteFill>;
registerRoot(()=> <><Composition component={Film} {...m.composition}/><Composition id="RunwayEndcard" component={EndcardPreview} width={m.composition.width} height={m.composition.height} fps={m.composition.fps} durationInFrames={m.endcard.durationInFrames}/></>);
