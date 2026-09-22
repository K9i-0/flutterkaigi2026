import React, {useMemo, useLayoutEffect} from 'react';
import {AbsoluteFill, Composition, staticFile, useCurrentFrame, interpolate} from 'remotion';
import {ThreeCanvas} from '@remotion/three';
import {useLoader, useThree} from '@react-three/fiber';
import * as THREE from 'three';
import {GLTFLoader} from 'three/examples/jsm/loaders/GLTFLoader.js';
import {clone} from 'three/examples/jsm/utils/SkeletonUtils.js';
import study from './set-study-manifest.json';

const V=(x:number,y:number,z:number)=>new THREE.Vector3(x,y,z);
function reach(scene:THREE.Object3D,side:string,target:THREE.Vector3){
 const hand=scene.getObjectByName(side+'Hand'); if(!hand)return;
 scene.updateMatrixWorld(true); const goal=scene.localToWorld(target.clone());
 for(let n=0;n<8;n++)for(const key of [side+'ForeArm',side+'Arm']){
  const joint=scene.getObjectByName(key);if(!joint?.parent)continue;
  const jp=joint.getWorldPosition(V(0,0,0));
  const a=hand.getWorldPosition(V(0,0,0)).sub(jp).normalize(),b=goal.clone().sub(jp).normalize();
  const q=new THREE.Quaternion().setFromUnitVectors(a,b).multiply(joint.getWorldQuaternion(new THREE.Quaternion()));
  joint.quaternion.copy(joint.parent.getWorldQuaternion(new THREE.Quaternion()).invert().multiply(q));scene.updateMatrixWorld(true);
 }
}
function Actor({name,p,yaw,t,action}:{name:string;p:[number,number,number];yaw:number;t:number;action:string}){
 const gltf=useLoader(GLTFLoader,staticFile(`models/${name}.glb`));
 const {scene,mixer,rest}=useMemo(()=>{
  const scene=clone(gltf.scene);
  scene.traverse(o=>{if(o instanceof THREE.Mesh){o.castShadow=true;o.receiveShadow=true;o.frustumCulled=false;const mats=Array.isArray(o.material)?o.material:[o.material];o.material=mats.map(m=>m.clone());if(mats.length===1)o.material=o.material[0];}});
  const rest:{o:THREE.Object3D;p:THREE.Vector3;q:THREE.Quaternion;s:THREE.Vector3}[]=[];
  scene.traverse(o=>rest.push({o,p:o.position.clone(),q:o.quaternion.clone(),s:o.scale.clone()}));
  return {scene,mixer:new THREE.AnimationMixer(scene),rest};
 },[gltf]);
 useLayoutEffect(()=>{
  mixer.stopAllAction();rest.forEach(({o,p,q,s})=>{o.position.copy(p);o.quaternion.copy(q);o.scale.copy(s);});
  const clip=gltf.animations.find(a=>a.name===(name==='sobaya'?'Hybrid_Idle_A':'Idle'))??gltf.animations[0];
  if(clip){mixer.clipAction(clip).reset().play();mixer.setTime(t%clip.duration);}
  const head=scene.getObjectByName('Head');if(head)head.rotateX(.028*Math.sin(t*1.5)+(action==='pray'?.16:0));
  if(action==='pray'){
   reach(scene,'Right',V(-.035,1.25,.34));reach(scene,'Left',V(.035,1.25,.34));
  }else if(action==='wipe'){
   reach(scene,'Right',V(-.26+.13*Math.sin(t*1.4),1.31+.12*Math.cos(t*1.4),.50));
  }else if(action==='explain'){
   reach(scene,'Left',V(.30,1.04+.025*Math.sin(t*1.3),.27));
  }
  scene.updateMatrixWorld(true);
 },[scene,mixer,rest,gltf,name,t,action]);
 return <group position={p} rotation={[0,yaw,0]}><primitive object={scene}/></group>;
}
function Box({p,s,c,metal=0}:{p:[number,number,number];s:[number,number,number];c:string;metal?:number}){
 return <mesh position={p} castShadow receiveShadow><boxGeometry args={s}/><meshStandardMaterial color={c} roughness={metal?.36:.92} metalness={metal}/></mesh>;
}
function WindowShrine(){return <group position={[.35,0,-1.25]}>
 {[-1.15,1.15].map(x=><React.Fragment key={x}>
  <Box p={[x,.9,0]} s={[.13,1.8,.14]} c="#50462e"/>
  <Box p={[x,1.75,.09]} s={[.075,1.7,.09]} c="#b8bdb9" metal={.8}/>
 </React.Fragment>)}
 {[.91,2.59].map(y=><Box key={y} p={[0,y,.09]} s={[2.37,.075,.09]} c="#c3c7c2" metal={.85}/>)}
 <Box p={[0,1.75,.095]} s={[.05,1.62,.10]} c="#a9b2ad" metal={.8}/>
 {[-.58,.58].map(x=><mesh key={x} position={[x,1.75,.11]}>
  <planeGeometry args={[1.08,1.6]}/><meshPhysicalMaterial color="#c6e6d7" transparent opacity={.055} roughness={.15} side={THREE.DoubleSide} depthWrite={false}/>
 </mesh>)}
 <Box p={[.10,1.65,.18]} s={[.035,.14,.055]} c="#646d67" metal={.65}/>
 </group>}
function Set(){
 const tex=useLoader(THREE.TextureLoader,staticFile('backgrounds/jungle_wall_day_v1.png'));
 useMemo(()=>{tex.colorSpace=THREE.SRGBColorSpace;tex.anisotropy=4;tex.wrapS=THREE.MirroredRepeatWrapping;tex.repeat.set(3,1);},[tex]);
 const floorTex=useLoader(THREE.TextureLoader,staticFile('backgrounds/jungle_floor_v1.png'));
 useMemo(()=>{floorTex.colorSpace=THREE.SRGBColorSpace;floorTex.wrapS=THREE.RepeatWrapping;floorTex.wrapT=THREE.RepeatWrapping;floorTex.repeat.set(12,12);floorTex.anisotropy=8;},[floorTex]);
 return <>
  <color attach="background" args={['#233328']}/>
  <ambientLight intensity={.7}/><hemisphereLight args={['#d9e3d4','#4c4433',1.5]}/>
  <directionalLight position={[-4,7,4]} intensity={1.7} color="#f2ecda" castShadow shadow-mapSize={[1024,1024]} shadow-camera-left={-6} shadow-camera-right={6} shadow-camera-top={6} shadow-camera-bottom={-6} shadow-normalBias={.025}/>
  <mesh position={[0,5.1,-8]}><planeGeometry args={[120,22.5]}/><meshBasicMaterial map={tex} toneMapped={false}/></mesh>
  <mesh rotation={[-Math.PI/2,0,0]} position={[0,-.035,0]} receiveShadow><planeGeometry args={[30,30]}/><meshStandardMaterial map={floorTex} color="#aca491" roughness={1}/></mesh>
  {Array.from({length:65},(_,i)=><mesh key={i} position={[Math.sin(i*16.3)*5,.005,Math.cos(i*3.7)*3.4]} rotation={[-Math.PI/2,.04, i*2.7]} scale={[.09+(i%4)*.035,.035,1]}><circleGeometry args={[1,5]}/><meshStandardMaterial color={['#5c5235','#403b28','#75613d'][i%3]} roughness={1}/></mesh>)}
  {[-4.8,-3.9,4.6,5.3].map((x,i)=><group key={x} position={[x,0,-3.7+(i%2)]}>
   {Array.from({length:9},(_,j)=><mesh key={j} position={[Math.sin(j*2)*.3,.22+j*.025,Math.cos(j*2)*.2]} rotation={[-.3,j*1.8,.8]} scale={[.07,.45,.009]}><sphereGeometry args={[1,12,6]}/><meshStandardMaterial color={j%2?'#35472c':'#485536'} roughness={1}/></mesh>)}
  </group>)}
  <WindowShrine/>
  <group position={[1.48,0,.62]}>
   <Box p={[0,.19,0]} s={[.58,.38,.40]} c="#8b7048"/>
   <Box p={[0,.385,0]} s={[.50,.015,.32]} c="#302a20"/>
   {[-.18,0,.18].flatMap(x=>[-.09,.09].map(z=><group key={`${x}-${z}`} position={[x,.43,z]}><mesh><cylinderGeometry args={[.057,.057,.18,16]}/><meshStandardMaterial color="#b7b9b5" metalness={.8} roughness={.35}/></mesh><mesh position={[0,.003,0]}><cylinderGeometry args={[.058,.058,.045,16]}/><meshStandardMaterial color="#9a3029" roughness={.6}/></mesh></group>))}
  </group>
 </>;
}
function Camera({shot,t}:{shot:number;t:number}){
 const {camera}=useThree();
 useLayoutEffect(()=>{
  const shots=[{p:[3.6,2.1,7.8],look:[.1,1.25,-.8]}, {p:[2.5,1.8,4.2],look:[-.25,1.02,0]}, {p:[-2.7,2.0,3.8],look:[.3,1.55,-1]}, {p:[.0,1.64,2.30],look:[-.62,1.44,.05]}];
  const s=shots[shot];camera.position.set(s.p[0]+Math.sin(t*.13)*.012,s.p[1],s.p[2]-t*.01);camera.lookAt(...s.look as [number,number,number]);camera.updateProjectionMatrix();
 },[camera,shot,t]);return null;
}
function Stage(){
 const f=useCurrentFrame(),t=f/24,shot=study.shots.findIndex(s=>f>=s.startFrame&&f<s.endFrame);
 const prayer=shot===0||shot===2;
 return <><Camera shot={Math.max(0,shot)} t={t}/><Set/>
  <Actor name="sobaya" p={[-.65,0,0]} yaw={prayer?Math.PI:.22} t={t} action={prayer?'pray':'explain'}/>
  <Actor name="fukuchan" p={[1.13,0,-.48]} yaw={Math.PI} t={t+.5} action={prayer?'pray':'wipe'}/>
  {!prayer&&<Actor name="yametaro" p={[-1.95,0,.65]} yaw={.85} t={t} action="listen"/>}
 </>;
}
const Film=()=>{
 const f=useCurrentFrame();const shot=study.shots.find(s=>f>=s.startFrame&&f<s.endFrame)!;
 const fade=interpolate(f,[0,18,study.composition.durationInFrames-18,study.composition.durationInFrames-1],[1,0,0,1],{extrapolateLeft:'clamp',extrapolateRight:'clamp'});
 return <AbsoluteFill style={{background:'#152219',color:'#fff',fontFamily:'"Hiragino Sans",sans-serif'}}>
  <ThreeCanvas width={854} height={480} dpr={1} shadows camera={{fov:37,near:.05,far:50}} gl={{antialias:true}}><Stage/></ThreeCanvas>
  <AbsoluteFill style={{background:'linear-gradient(0deg,#0b130d99,transparent 28%)',pointerEvents:'none'}}/>
  <div style={{position:'absolute',top:24,right:42,fontSize:23,letterSpacing:3,color:'#ffffffe0'}}>YHK</div>
  <div style={{position:'absolute',top:28,left:42,fontSize:12,letterSpacing:1.5,textShadow:'0 1px 5px #000'}}>3Dセット・演技確認　／　音声未収録</div>
  {f<168&&<div style={{position:'absolute',left:42,top:88,fontFamily:'"Hiragino Mincho ProN",serif',fontSize:34,textShadow:'0 2px 8px #000'}}>密林のアベイラブル</div>}
  <div style={{position:'absolute',bottom:27,left:42,fontSize:15,letterSpacing:1,textShadow:'0 2px 6px #000'}}>{shot.label}</div>
  <AbsoluteFill style={{background:'#101711',opacity:fade}}/>
 </AbsoluteFill>;
};
export const SetStudyRoot=()=> <Composition id="YhkSetStudy" component={Film} {...study.composition}/>;
