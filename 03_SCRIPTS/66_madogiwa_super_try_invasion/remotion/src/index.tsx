import React from 'react';
import {AbsoluteFill,Composition,OffthreadVideo,registerRoot,staticFile,useCurrentFrame} from 'remotion';
import m from './edit-manifest.json';
import {Full} from './Full';
const Film=()=>{const f=useCurrentFrame();return <AbsoluteFill><OffthreadVideo src={staticFile('input.mp4')} muted/>{m.captions.filter(c=>f>=c.startFrame&&f<c.endFrame).map(c=><div key={c.startFrame} style={{position:'absolute',bottom:35,left:35,right:35,textAlign:'center',fontFamily:'Hiragino Sans, sans-serif',fontSize:28,fontWeight:600,color:'white',WebkitTextStroke:'1.4px #111',paintOrder:'stroke fill',textShadow:'0 2px 3px black',lineHeight:1.35}}>{c.text}</div>)}</AbsoluteFill>};
registerRoot(()=> <><Composition id="InvasionPart1" component={Film} durationInFrames={600} fps={30} width={854} height={480}/><Composition id="InvasionFull" component={Full} durationInFrames={1200} fps={30} width={854} height={480}/></>);
