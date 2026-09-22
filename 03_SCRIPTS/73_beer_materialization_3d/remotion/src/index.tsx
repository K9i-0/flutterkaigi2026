import React, {useMemo, useLayoutEffect} from 'react';
import {registerRoot, Composition, AbsoluteFill, useCurrentFrame, staticFile, Audio, Sequence, interpolate} from 'remotion';
import {ThreeCanvas} from '@remotion/three';
import {useLoader, useThree, createPortal} from '@react-three/fiber';
import {GLTFLoader} from 'three/examples/jsm/loaders/GLTFLoader.js';
import {clone} from 'three/examples/jsm/utils/SkeletonUtils.js';
import * as THREE from 'three';
import manifest from './edit-manifest.json';
import {applySkitMotion, catalog, type SkitMotion} from '../../../../04_GAME_ASSETS/3d/motions/skit_v1/motions';
const {lines,composition}=manifest;
const clamp={extrapolateLeft:'clamp',extrapolateRight:'clamp'} as const;
const at=(f:number)=>lines.find(l=>f>=l.start&&f<l.end)??[...lines].reverse().find(l=>f>=l.start)??lines[0];
function Actor({name,x,yaw,motion,t,speaking,holding=false,mouth=0,sketching=false}:{name:string;x:number;yaw:number;motion:SkitMotion;t:number;speaking:boolean;holding?:boolean;mouth?:number;sketching?:boolean}){
 const gltf=useLoader(GLTFLoader,staticFile(`models/${name}.glb`));
 const {scene,mixer,rest}=useMemo(()=>{const scene=clone(gltf.scene);scene.traverse(o=>{if(o instanceof THREE.Mesh){o.castShadow=true;o.receiveShadow=true;}});const rest: {o:THREE.Object3D;p:THREE.Vector3;q:THREE.Quaternion;s:THREE.Vector3}[]=[];scene.traverse(o=>rest.push({o,p:o.position.clone(),q:o.quaternion.clone(),s:o.scale.clone()}));return {scene,mixer:new THREE.AnimationMixer(scene),rest};},[gltf]);
 useLayoutEffect(()=>{
  mixer.stopAllAction();rest.forEach(({o,p,q,s})=>{o.position.copy(p);o.quaternion.copy(q);o.scale.copy(s);});const anim=gltf.animations.find(a=>a.name===catalog[motion].base)??gltf.animations[0];
  if(anim){const a=mixer.clipAction(anim);a.reset().play();mixer.setTime(t%anim.duration);}
  scene.traverse(o=>{if(o instanceof THREE.Mesh&&o.morphTargetDictionary&&o.morphTargetInfluences){const k=o.morphTargetDictionary.SpeechOpen;if(k!==undefined)o.morphTargetInfluences[k]=speaking?mouth:0;}});
  applySkitMotion(scene,motion,t);
  if(sketching&&scene.parent){
   for(const [key,bone,offset] of [['sketch-book','LeftHand',new THREE.Vector3(-.05,.025,.10)],['sketch-pen','RightHand',new THREE.Vector3(.10,.005,.055)]] as const){
    const prop=scene.parent.getObjectByName(key),hand=scene.getObjectByName(bone);
    if(prop?.parent&&hand)prop.position.copy(prop.parent.worldToLocal(hand.getWorldPosition(new THREE.Vector3()))).add(offset);
   }
  }
  scene.updateMatrixWorld(true);
 },[scene,mixer,gltf,motion,t,speaking,holding,mouth,rest,sketching]);
 const socket=(scene.getObjectByName("PropSocketR")??scene.getObjectByName("PropSocket.R"));
 return <group position={[x,0,0]} rotation={[0,yaw,0]}><primitive object={scene}/>{holding&&socket&&createPortal(<RealMug held/>,socket)}{sketching&&<SketchProps scene={scene} t={t}/>}</group>;
}
function SketchProps({scene,t}:{scene:THREE.Object3D;t:number}){
 const book=React.useRef<THREE.Group>(null),pen=React.useRef<THREE.Group>(null);
 return <>
  <group ref={book} name="sketch-book" rotation={[.2,0,0]}>
   <Box p={[0,0,0]} s={[.30,.015,.24]} c="#f2e6bc"/>
   <Box p={[0,.01,0]} s={[.24,.008,.19]} c="#fffdf4"/>
   <mesh position={[0,.017,0]} rotation={[-Math.PI/2,0,0]}><ringGeometry args={[.045,.049,24]}/><meshBasicMaterial color="#4c4842"/></mesh>
   <Box p={[-.045,.018,.035]} s={[.006,.002,.07]} c="#4c4842"/>
   <Box p={[.045,.018,.035]} s={[.006,.002,.07]} c="#4c4842"/>
  </group>
  <group ref={pen} name="sketch-pen" rotation={[.55,0,-.5]}><mesh><cylinderGeometry args={[.005,.005,.18,6]}/><meshStandardMaterial color="#cf743a"/></mesh></group>
 </>;
}
function RealMug({held=false}:{held?:boolean}){
 const gltf=useLoader(GLTFLoader,staticFile('models/beer_mug.glb'));
 const scene=useMemo(()=>{
  const s=gltf.scene.clone(true);s.updateMatrixWorld(true);
  if(held){const grip=s.getObjectByName('Grip');if(grip){const m=grip.matrixWorld.clone().invert().multiply(s.matrixWorld);m.decompose(s.position,s.quaternion,s.scale);}}
  s.traverse(o=>{if(o instanceof THREE.Mesh){o.castShadow=true;const mats=Array.isArray(o.material)?o.material:[o.material];const cloned=mats.map(m=>{const c=m.clone() as THREE.MeshPhysicalMaterial;if(c.transmission){c.transmission=0;c.transparent=true;c.opacity=o.name.includes('Beer')?1:.22;}if(o.name==='BeerVolume'||o.name==='LiquidSurface'){c.color.set('#e8a128');c.opacity=1;c.transparent=false;c.roughness=.22;}return c;});o.material=Array.isArray(o.material)?cloned:cloned[0];}});
  return s;
 },[gltf,held]);
 return <primitive object={scene}/>;
}
function Box({p,s,c}:{p:[number,number,number];s:[number,number,number];c:string}){return <mesh position={p} receiveShadow castShadow><boxGeometry args={s}/><meshStandardMaterial color={c} roughness={0.8}/></mesh>}
function Mug({p,scale=1,ghost=false}:{p:[number,number,number];scale?:number;ghost?:boolean}){
 return <group position={p} scale={scale}>
 <mesh castShadow><cylinderGeometry args={[.13,.12,.3,32]}/><meshStandardMaterial color={ghost?'#8cfff0':'#f3ad26'} metalness={.15} roughness={.17} transparent opacity={ghost?.4:1}/></mesh>
 <mesh position={[0,.162,0]}><cylinderGeometry args={[.135,.13,.04,32]}/><meshStandardMaterial color="#fffbe4"/></mesh>
 <mesh position={[.153,.015,0]} rotation={[0,0,0]}><torusGeometry args={[.085,.022,10,24]}/><meshStandardMaterial color={ghost?'#9bfff0':'#d8f0ea'} metalness={.35} roughness={.18}/></mesh>
 {[0,1,2,3,4].map(i=><mesh key={i} position={[Math.sin(i*3)*.075,.19,Math.cos(i*3)*.075]}><sphereGeometry args={[.037,10,8]}/><meshStandardMaterial color="#fffbe4"/></mesh>)}
 </group>
}
function Set(){return <>
 <color attach="background" args={['#15282f']}/><fog attach="fog" args={['#15282f',8,18]}/>
 <ambientLight intensity={.85}/><hemisphereLight args={['#c4e4ff','#907453',1.5]}/>
 <directionalLight position={[-3,5,4]} intensity={3} color="#ffe4bd" castShadow shadow-mapSize={[1024,1024]}/>
 <pointLight position={[3,3,-2]} intensity={25} color="#5ddaca"/>
 <Box p={[0,-.1,0]} s={[12,.2,10]} c="#9b8467"/>
 {Array.from({length:11},(_,i)=><Box key={i} p={[i*.55-2.75,.004,0]} s={[.014,.008,8]} c="#725e4b"/>)}
 <Box p={[0,2,-2.5]} s={[10,4,.15]} c="#223f45"/>
 {[-3,-1.5,0,1.5,3].map(x=><Box key={x} p={[x,1.8,-2.37]} s={[.07,3.6,.13]} c="#152a2e"/>)}
 <Box p={[0,2.1,-2.35]} s={[3.8,1.5,.08]} c="#a6c9bb"/>
 <Box p={[0,2.1,-2.28]} s={[.065,1.5,.1]} c="#223d39"/>
 <Box p={[0,2.1,-2.28]} s={[3.8,.065,.1]} c="#223d39"/>
 <Box p={[0,.63,.45]} s={[.82,.08,.62]} c="#684833"/>
 {[-.32,.32].map(x=><Box key={x} p={[x,.3,.45]} s={[.055,.6,.45]} c="#302b26"/>)}
 <Box p={[-2,.47,-1.5]} s={[1.4,.1,.45]} c="#6e4934"/>
 </>}
function Camera({shot,f}:{shot:string;f:number}){
 const {camera}=useThree();
 useLayoutEffect(()=>{
 const move=Math.sin(f/160)*.045;
 let p:[number,number,number]=[3.25,2.05,5.4],target:[number,number,number]=[0,1.02,0];
 if(shot==='sobaya'){p=[.1,1.7,3.1];target=[-.78,1.3,0];}
 if(shot==='yametaro'){p=[.0,1.37,2.7];target=[.82,.94,0];}
 if(shot==='inspect'){p=[.2,1.85,2.5];target=[-.75,1.3,.13];}
 if(shot==='sketch'){p=[.55,2.25,2.3];target=[-.65,1.16,.25];}
 if(shot==='magic'||shot==='reveal'){p=[2.55,1.72,3.85];target=[-.1,1.02,.3];}
 camera.position.set(p[0]+move,p[1],p[2]);camera.lookAt(...target);camera.updateProjectionMatrix();
 },[camera,shot,f]);return null;
}
function Stage(){
 const f=useCurrentFrame(),row=at(f),local=Math.max(0,(f-row.start)/24);
 const progress=(f-row.start)/(row.end-row.start);
 let motion:SkitMotion='Explain',yam:SkitMotion='Listen';
 let holding=false,sketching=false,shot=row.shot;
 if(row.id==='02'){sketching=progress>.48;holding=!sketching;motion=sketching?'SketchMug':'InspectMug';shot=sketching?'sketch':'inspect';}
 if(row.id==='03'){holding=true;motion=progress<.53?'SniffMug':'ListenFoam';shot='inspect';}
 if(row.id==='04'){yam='Tsukkomi';motion='EmptyHands';}
 if(row.id==='05'){motion='EmptyHands';yam='DoubleTake';}
 if(row.id==='06'){motion='Conjure';yam='DoubleTake';}
 if(row.id==='07'){motion='ProudToast';holding=true;yam='DoubleTake';}
 if(row.id==='08')yam='Wish';
 if(row.id==='09')yam='DoubleTake';
 const split=row.id==='02'?.48:row.id==='03'?.53:0;
 const actionTime=split&&progress>split?local-(row.end-row.start)/24*split:local;
 const magic=row.shot==='magic',reveal=Number(row.id)>=7;
 const visible=(Number(row.id)<5||magic||reveal)&&!holding;
 const sc=magic?(.85+.1*Math.sin(f*.12)):1;
 return <>
 <Camera shot={shot} f={f}/><Set/>
 <Actor name="sobaya" x={-.85} yaw={.24} motion={motion} t={actionTime} speaking={row.speaker==='sobaya'} holding={holding} sketching={sketching}/>
 <Actor name="yametaro" x={.9} yaw={-.35} motion={yam} t={local} speaking={row.speaker==='yametaro'&&f<row.end} mouth={row.mouth?.[f-row.start]??0}/>
 {visible&&<Mug p={[0,.86+(magic?.045*Math.sin(f*.1):0),.48]} scale={sc} ghost={magic}/>}
 {(magic||row.shot==='reveal')&&Array.from({length:36},(_,i)=><mesh key={i} position={[Math.sin(i*2.4+f*.035)*(.24+i*.008),.68+((i*.073+f*.012)%1.25),.48+Math.cos(i*2.4+f*.035)*.3]} scale={.009+(i%3)*.005}><sphereGeometry args={[1,6,6]}/><meshBasicMaterial color={magic?'#84fff0':'#ffe192'}/></mesh>)}
 </>
}
const Film=()=>{
 const f=useCurrentFrame(),row=at(f);const talking=f>=row.start&&f<row.end;
 const fade=interpolate(f,[0,18,composition.durationInFrames-18,composition.durationInFrames-1],[1,0,0,1],clamp);
 return <AbsoluteFill style={{background:'#13282d',fontFamily:'"Hiragino Sans",sans-serif',color:'#fff'}}>
 <ThreeCanvas width={composition.width} height={composition.height} shadows dpr={1} camera={{fov:37,near:.1,far:30}} gl={{antialias:true}}><Stage/></ThreeCanvas>
 <AbsoluteFill style={{background:'linear-gradient(180deg,rgba(5,18,21,.55),transparent 25%,transparent 67%,rgba(5,18,21,.9))'}}/>
 <div style={{position:'absolute',top:32,left:48,fontSize:16,letterSpacing:4,color:'#e6c78e'}}>窓際族物語　／　ビール具現化修業</div>
 <div style={{position:'absolute',top:63,left:48,fontSize:30,fontWeight:600}}>{row.chapter}</div>
 <div style={{position:'absolute',right:48,top:34,fontSize:14,letterSpacing:2,color:'#bad0ca'}}>そば屋 × やめ太郎</div>
 {talking&&<div style={{position:'absolute',left:100,right:100,bottom:43,textAlign:'center'}}><div style={{display:'inline-block',background:row.speaker==='sobaya'?'#c99948':'#8473b5',padding:'5px 18px',borderRadius:3,fontSize:16,marginBottom:12}}>{row.speaker==='sobaya'?'そば屋':'やめ太郎'}</div><div style={{whiteSpace:'pre-line',fontSize:31,fontWeight:600,lineHeight:1.5,textShadow:'0 2px 5px #000'}}>{row.text}</div></div>}
 {lines.map(l=>l.audio&&<Sequence key={l.id} from={l.start}><Audio src={staticFile(l.audio)}/></Sequence>)}
 <AbsoluteFill style={{background:'#07181c',opacity:fade}}/>
 </AbsoluteFill>
};
registerRoot(()=> <Composition id="BeerTraining" component={Film} {...composition}/>);
