import React,{useLayoutEffect,useMemo} from 'react';
import {AbsoluteFill,Audio,Img,Sequence,staticFile,useCurrentFrame,interpolate} from 'remotion';
import {ThreeCanvas} from '@remotion/three';
import {useLoader,useThree} from '@react-three/fiber';
import * as THREE from 'three';
import {GLTFLoader} from 'three/examples/jsm/loaders/GLTFLoader.js';
import {clone} from 'three/examples/jsm/utils/SkeletonUtils.js';
import {createMotionPlayer} from '../../../../04_GAME_ASSETS/3d/stage_video/motion-player';
import manifest from './edit-manifest.json';
const FPS=24;
const clamp=(v:number)=>Math.max(0,Math.min(1,v));
const ease=(v:number)=>{v=clamp(v);return v*v*(3-2*v)};
type Line=typeof manifest.lines[number];
const active=(f:number)=>manifest.lines.find(l=>f>=l.start&&f<l.end+l.pauseFrames)||manifest.lines[0];

function Actor({frame,line}:{frame:number;line:Line}){
 const gltf=useLoader(GLTFLoader,staticFile('models/sobaya.glb'));
 const actor=useMemo(()=>{
  const scene=clone(gltf.scene);
  scene.traverse(o=>{if(o instanceof THREE.Mesh){o.frustumCulled=false;o.castShadow=true;o.receiveShadow=true;
   const modify=(src:THREE.Material)=>{const m=src.clone() as THREE.MeshStandardMaterial;
    if(src.name==='Sobaya_Imagegen_Mask_v1'){
     m.roughness=.91;
     m.onBeforeCompile=s=>{
      s.vertexShader='varying vec3 keynotePosition;\n'+s.vertexShader;
      s.vertexShader=s.vertexShader.replace('#include <begin_vertex>','#include <begin_vertex>\nkeynotePosition=position;');
      s.fragmentShader='varying vec3 keynotePosition;\n'+s.fragmentShader;
      s.fragmentShader=s.fragmentShader.replace('#include <map_fragment>',`#include <map_fragment>
       vec3 p=keynotePosition;
       float torso=step(.83,p.y)*(1.-step(1.62,p.y))*(1.-step(.265,abs(p.x)));
       float sleeve=step(.94,p.y)*(1.-step(1.62,p.y))*step(.20,abs(p.x));
       float collar=step(1.42,p.y)*(1.-step(1.62,p.y))*(1.-step(.103,abs(p.x)));
       float shirt=max(max(torso,sleeve),collar);
       float knit=.88+.12*sin(p.y*870.);
       diffuseColor.rgb=mix(diffuseColor.rgb,vec3(.014,.017,.022)*knit,shirt);
       float jeans=step(.135,p.y)*(1.-step(.835,p.y))*(1.-step(.27,abs(p.x)));
       float weave=.85+.15*sin(p.x*920.+p.y*730.);
       diffuseColor.rgb=mix(diffuseColor.rgb,vec3(.028,.065,.125)*weave,jeans);
      `);
     }; m.customProgramCacheKey=()=> 'keynote-costume-v1';
    }return m;};
   o.material=Array.isArray(o.material)?o.material.map(modify):modify(o.material);
  }});
  const player=createMotionPlayer(scene,gltf.animations,'sobaya');
  const mixer=new THREE.AnimationMixer(scene);
  const clips=Object.fromEntries(gltf.animations.map(c=>[c.name,c]));
  const hand=scene.getObjectByName('RightHand');
  if(hand){const clicker=new THREE.Mesh(new THREE.BoxGeometry(.022,.07,.017),new THREE.MeshStandardMaterial({color:'#24272b',roughness:.5}));clicker.position.set(0,.027,.035);hand.add(clicker);}
  const rig:THREE.Object3D[]=[];scene.traverse(o=>{if(o instanceof THREE.Bone)rig.push(o)});
  return {scene,player,mixer,clips,rig};
 },[gltf]);
 const local=(frame-line.start)/FPS,seconds=frame/FPS;
 const speaking=frame>=line.start&&frame<line.end;
 const walk=frame<52;
 const bow=frame>manifest.lines[manifest.lines.length-1].end;
 useLayoutEffect(()=>{
  actor.mixer.stopAllAction();
  actor.player.sample(line.id==='arms'?'EmptyHands':'Explain',line.id==='arms'?Math.max(0,local):seconds);
  const talk=actor.rig.map(o=>({p:o.position.clone(),q:o.quaternion.clone()}));
  const name=walk?'Hybrid_Walk':bow?'Hybrid_Bow':'Hybrid_Idle_A';
  const clip=actor.clips[name];if(!clip)throw Error('Missing '+name);
  actor.mixer.clipAction(clip).reset().play();actor.mixer.setTime(walk?seconds:bow?(frame-manifest.lines[manifest.lines.length-1].end)/FPS:seconds%clip.duration);
  if(!walk&&!bow){
   const weight=ease((frame-line.start+5)/12)*ease((line.end+7-frame)/13);
   actor.rig.forEach((o,i)=>{o.position.lerp(talk[i].p,weight);o.quaternion.slerp(talk[i].q,weight);});
  }
  actor.scene.updateMatrixWorld(true);
 },[actor,frame,line.id,local,speaking,walk,bow,seconds]);
 return <group position={[-1.46-(walk?(1-ease(frame/52))*.8:0),0,0]} rotation={[0,walk?.4:.075,0]}><primitive object={actor.scene}/></group>;
}
function Camera({close}:{close:boolean}){const {camera}=useThree();useLayoutEffect(()=>{camera.position.set(close?-.52:0,close?1.48:1.55,close?2.65:5.0);camera.lookAt(close?-.52:0,close?1.24:1.02,0);camera.updateProjectionMatrix();},[camera,close]);return null;}
function Stage({frame,line,close}:{frame:number;line:Line;close:boolean}){
 return <div style={{position:'absolute',left:0,top:0,width:1280,height:720}}><ThreeCanvas width={1280} height={720} shadows camera={{fov:35}} gl={{antialias:true,alpha:true}}>
  <Camera close={close}/><ambientLight intensity={.8}/><directionalLight position={[-2,5,4]} intensity={3.1} castShadow shadow-mapSize={[1024,1024]}/><directionalLight position={[2,4,-2]} intensity={2.5} color='#8099bd'/><pointLight position={[-3,2,1]} intensity={3}/>
  <mesh rotation={[-Math.PI/2,0,0]} position={[0,-.012,0]} receiveShadow><planeGeometry args={[35,35]}/><meshStandardMaterial color='#0e1117' roughness={.78}/></mesh>
  <Actor frame={frame} line={line}/>
 </ThreeCanvas></div>;
}
function ShirtIcon({size=210}:{size?:number}){return <svg width={size} height={size} viewBox='0 0 240 240'><path d='M75 40 L35 66 L12 114 L52 137 L65 112 L65 211 L175 211 L175 112 L188 137 L228 114 L205 66 L165 40 Q120 67 75 40Z' fill='#f6f6f8' stroke='#d4d5d9' strokeWidth='2'/><path d='M92 48 Q120 76 148 48' fill='none' stroke='#c5c6cc' strokeWidth='3'/></svg>}
function Product({width=500,detail=false}:{width?:number;detail?:boolean}){
 // CSS viewport only: preserve the original product asset; never raster-edit/repaint the print.
 const crop=detail?{x:808,y:207,w:213,h:235}:{x:620,y:92,w:556,h:485};
 const scale=width/crop.w;
 return <div style={{position:'relative',width,height:crop.h*scale,overflow:'hidden',background:'white'}}><Img src={staticFile('goods/madogiwa-tshirt.webp')} style={{position:'absolute',width:1200*scale,maxWidth:'none',height:630*scale,left:-crop.x*scale,top:-crop.y*scale}}/></div>;
}
function Crew({size=220}:{size?:number}){return <div style={{width:size,height:size,overflow:'hidden',borderRadius:10,background:'white',display:'flex',justifyContent:'center',alignItems:'center'}}><Product width={size*.88} detail/></div>}
const titleStyle:React.CSSProperties={fontSize:74,fontWeight:500,letterSpacing:-3,margin:0};
function Slide({line,frame}:{line:Line;frame:number}){
 const scene=line.scene,local=frame-line.start;
 const fade=ease(local/10);
 const repeat=scene==='repeat1'||scene==='repeat2'||scene==='understand'||scene==='notthree';
 const items=['窓際族','T','シャツ'];
 const index=Math.min(2,Math.floor(clamp(local/Math.max(1,line.end-line.start))*3));
 const fullProduct=['reveal','reinvent','buy','closing','end'].includes(scene);
 if(fullProduct){return <div style={{display:'flex',height:'100%',alignItems:'center',justifyContent:'center',gap:28}}>
   <div style={{borderRadius:5,overflow:'hidden',boxShadow:'0 10px 50px #000',transform:`scale(${scene==='reveal'?.92+.08*ease(local/28):1})`}}><Product width={scene==='end'?392:340}/></div>
   <div style={{width:scene==='end'?360:290}}><div style={{fontSize:15,letterSpacing:4,color:'#aaa',marginBottom:20}}>WINDOW-SIDE CREW</div><div style={{fontSize:scene==='end'?65:53,lineHeight:1.2,fontWeight:600,letterSpacing:-2}}>窓際族<br/>Tシャツ</div>{['buy','end'].includes(scene)&&<><div style={{fontSize:27,marginTop:30}}>公式サイトから購入</div><div style={{width:42,height:2,background:'white',marginTop:20}}/></>}{scene==='closing'&&<div style={{display:'flex',gap:9,fontSize:25,marginTop:27}}>{items.map((s,i)=><span key={s} style={{opacity:i===index?1:.3}}>{s}</span>)}</div>}{scene==='end'&&<div style={{fontSize:25,color:'#c5c7cc',marginTop:27}}>すべてが、この1枚に。</div>}</div>
  </div>}
 if(scene==='intro') return <div style={{textAlign:'center'}}><div style={{fontSize:17,letterSpacing:8,color:'#a3a6ab',marginBottom:32}}>MADOGIWA</div><div style={{fontSize:72,fontWeight:300,letterSpacing:-2}}>Special Event</div></div>;
 if(scene==='revolution')return <h1 style={titleStyle}>革命。</h1>;
 if(scene==='three')return <div style={{fontSize:230,fontWeight:300,lineHeight:1}}>3</div>;
 if(scene==='first')return <div style={{textAlign:'center',opacity:fade}}><Crew size={246}/><div style={{fontSize:43,marginTop:18}}>窓際族</div></div>;
 if(scene==='second')return <div style={{fontSize:250,fontWeight:400,lineHeight:1,opacity:fade}}>T</div>;
 if(scene==='third')return <div style={{textAlign:'center',opacity:fade}}><ShirtIcon size={256}/><div style={{fontSize:43,marginTop:8}}>シャツ</div></div>;
 if(repeat)return <div style={{display:'flex',alignItems:'center',gap:36}}>{items.map((s,i)=><div key={s} style={{textAlign:'center',width:178,opacity:scene.startsWith('repeat')?(index===i?1:.28):1,transform:`scale(${scene.startsWith('repeat')&&index===i?1.07:1})`}}><div style={{height:187,display:'flex',justifyContent:'center',alignItems:'center'}}>{i===0?<Crew size={170}/>:i===1?<span style={{fontSize:181,lineHeight:1}}>T</span>:<ShirtIcon size={184}/>}</div><div style={{fontSize:35,marginTop:25}}>{s}</div></div>)}</div>;
 if(scene==='one')return <div style={{display:'flex',alignItems:'center',gap:36*(1-ease(local/30)),fontSize:69,fontWeight:500,whiteSpace:'nowrap'}}>{items.map(s=><span key={s}>{s}</span>)}</div>;
 if(scene==='how')return <h1 style={titleStyle}>使い方。</h1>;
 if(scene==='born')return <div style={{fontSize:53,textAlign:'center',lineHeight:1.6}}>生まれたときから、<br/>持っているもの。</div>;
 if(scene==='arms')return <h1 style={{...titleStyle,fontSize:155}}>腕。</h1>;
 if(['right','left','head','wear'].includes(scene))return <div style={{textAlign:'center'}}><div style={{position:'relative',width:300,height:265,margin:'0 auto'}}><ShirtIcon size={265}/>{scene!=='wear'&&<svg style={{position:'absolute',inset:0}} width='300' height='265' viewBox='0 0 300 265'><defs><marker id='arrow' markerWidth='7' markerHeight='7' refX='5' refY='3' orient='auto'><path d='M0,0 L6,3 L0,6' fill='#61b7ff'/></marker></defs><path d={scene==='right'?'M8 154 Q26 120 65 120':scene==='left'?'M294 154 Q256 119 218 120':'M133 0 L133 63'} fill='none' stroke='#61b7ff' strokeWidth='8' markerEnd='url(#arrow)'/></svg>}</div><div style={{fontSize:44,marginTop:12}}>{scene==='right'?'右腕を通す。':scene==='left'?'左腕を通す。':scene==='head'?'頭を通す。':'着られました。'}</div></div>;
 if(scene==='detail')return <div style={{display:'flex',alignItems:'center',gap:30}}><div style={{borderRadius:5,overflow:'hidden'}}><Product detail width={300}/></div><div style={{fontSize:40,lineHeight:1.6}}>窓際族が、<br/>全員ここに。</div></div>;
 if(scene==='when')return <h1 style={titleStyle}>いつ？</h1>;
 if(scene==='today')return <h1 style={{...titleStyle,fontSize:140}}>本日。</h1>;
 return null;
}
export function Film(){
 const frame=useCurrentFrame(),line=active(frame);
 const endcard=frame>=manifest.endcardStart;
 const close=['lucky','understand','notthree','born','arms','perfect','when'].includes(line.id);
 const subtitle=frame>=line.start&&frame<line.end?line.text:'';
 return <AbsoluteFill style={{background:'radial-gradient(ellipse at 35% 87%,#19202b 0%,#050608 47%,#000 83%)',color:'white',fontFamily:'Helvetica Neue, Hiragino Kaku Gothic ProN, sans-serif'}}>
  {!endcard&&<Stage frame={frame} line={line} close={close}/>}
  <div style={{position:'absolute',left:endcard?75:505,top:endcard?90:53,width:endcard?1130:725,height:endcard?490:434,background:'#050506',border:endcard?'none':'1px solid #24272b',boxShadow:endcard?'none':'0 20px 65px #000',display:'flex',alignItems:'center',justifyContent:'center',overflow:'hidden'}}><Slide line={endcard?{...line,scene:'end'}:line} frame={frame}/></div>
  {!endcard&&<div style={{position:'absolute',left:508,top:503,color:'#686e78',fontSize:11,letterSpacing:5}}>MADOGIWA SPECIAL EVENT</div>}
  {subtitle&&<div style={{position:'absolute',bottom:36,left:42,right:42,textAlign:'center',fontSize:30,fontWeight:500,lineHeight:1.5,textShadow:'0 2px 7px #000, 0 0 14px #000'}}><span style={{background:'rgba(0,0,0,.64)',padding:'7px 18px',borderRadius:3}}>{subtitle}</span></div>}
  {endcard&&<div style={{position:'absolute',bottom:17,left:40,right:40,textAlign:'center',fontSize:13,color:'#92969c'}}>Audience laughter: Kyster / Freesound 124028 / CC BY 4.0 · edited</div>}
  {manifest.audioReady&&<Audio src={staticFile('audio/master.wav')}/>}
  <AbsoluteFill style={{background:'black',opacity:frame<14?1-frame/14:frame>manifest.durationInFrames-16?(frame-(manifest.durationInFrames-16))/16:0,pointerEvents:'none'}}/>
 </AbsoluteFill>;
}
