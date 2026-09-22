import React, {useMemo, useLayoutEffect} from 'react';
import {registerRoot, Composition, AbsoluteFill, useCurrentFrame, staticFile, Audio, Sequence, interpolate} from 'remotion';
import {ThreeCanvas} from '@remotion/three';
import {useLoader, useThree, createPortal} from '@react-three/fiber';
import {GLTFLoader} from 'three/examples/jsm/loaders/GLTFLoader.js';
import {clone} from 'three/examples/jsm/utils/SkeletonUtils.js';
import * as THREE from 'three';
import manifest from './edit-manifest.json';
import {applyDogLapping} from '../../../../04_GAME_ASSETS/3d/motions/skit_v1/flashback-motion';
import {applySkitMotion, catalog, type SkitMotion} from '../../../../04_GAME_ASSETS/3d/motions/skit_v1/motions';
const {lines,composition}=manifest;
const clamp={extrapolateLeft:'clamp',extrapolateRight:'clamp'} as const;
const at=(f:number)=>lines.find(l=>f>=l.start&&f<l.end)??[...lines].reverse().find(l=>f>=l.start)??lines[0];
function Actor({name,x,yaw,motion,t,speaking,holding=false,mouth=0,sketching=false,dog=false,z=0}:{name:string;x:number;yaw:number;motion:SkitMotion;t:number;speaking:boolean;holding?:boolean;mouth?:number;sketching?:boolean;dog?:boolean;z?:number}){
 const gltf=useLoader(GLTFLoader,staticFile(`models/${name}.glb`));
 const {scene,mixer,rest,mouthAnchor}=useMemo(()=>{const scene=clone(gltf.scene);scene.traverse(o=>{if(o instanceof THREE.Mesh){o.castShadow=true;o.receiveShadow=true;o.frustumCulled=false;
 const old=Array.isArray(o.material)?o.material:[o.material];
 const gradient=new THREE.DataTexture(new Uint8Array([75,75,75,255,170,170,170,255,255,255,255,255]),3,1,THREE.RGBAFormat);gradient.needsUpdate=true;gradient.magFilter=THREE.NearestFilter;gradient.minFilter=THREE.NearestFilter;
 const mats=old.map(m=>{const src=m as THREE.MeshStandardMaterial;return new THREE.MeshToonMaterial({map:src.map,color:src.color,vertexColors:src.vertexColors,gradientMap:gradient,side:src.side,transparent:src.transparent,opacity:src.opacity,alphaTest:src.alphaTest});});o.material=Array.isArray(o.material)?mats:mats[0];}});const rest: {o:THREE.Object3D;p:THREE.Vector3;q:THREE.Quaternion;s:THREE.Vector3}[]=[];scene.traverse(o=>rest.push({o,p:o.position.clone(),q:o.quaternion.clone(),s:o.scale.clone()}));scene.updateMatrixWorld(true);
 const head=scene.getObjectByName('Head');const mouthAnchor=new THREE.Matrix4();
 if(head)mouthAnchor.copy(head.matrixWorld).invert().multiply(scene.matrixWorld).multiply(new THREE.Matrix4().makeTranslation(.036,1.569,.212));
 return {scene,mixer:new THREE.AnimationMixer(scene),rest,mouthAnchor};},[gltf]);
 useLayoutEffect(()=>{
  mixer.stopAllAction();rest.forEach(({o,p,q,s})=>{o.position.copy(p);o.quaternion.copy(q);o.scale.copy(s);});const anim=gltf.animations.find(a=>a.name===catalog[motion].base)??gltf.animations[0];
  if(anim&&!dog){const a=mixer.clipAction(anim);a.reset().play();mixer.setTime(t%anim.duration);}
  scene.traverse(o=>{if(o instanceof THREE.Mesh&&o.morphTargetDictionary&&o.morphTargetInfluences){const k=o.morphTargetDictionary.SpeechOpen;if(k!==undefined)o.morphTargetInfluences[k]=speaking?mouth:0;}});
  if(dog)applyDogLapping(scene,t);else applySkitMotion(scene,motion,t);
  if(sketching&&scene.parent){
   for(const [key,bone,offset] of [['sketch-book','LeftHand',new THREE.Vector3(-.05,.025,.10)],['sketch-pen','RightHand',new THREE.Vector3(.10,.005,.055)]] as const){
    const prop=scene.parent.getObjectByName(key),hand=scene.getObjectByName(bone);
    if(prop?.parent&&hand)prop.position.copy(prop.parent.worldToLocal(hand.getWorldPosition(new THREE.Vector3()))).add(offset);
   }
  }
  scene.updateMatrixWorld(true);
 },[scene,mixer,gltf,motion,t,speaking,holding,mouth,rest,sketching,dog]);
 const socket=(scene.getObjectByName("PropSocketR")??scene.getObjectByName("PropSocket.R"));
 return <group position={[x,0,z]} rotation={[0,yaw,0]}><primitive object={scene}/>{holding&&socket&&createPortal(<RealMug held/>,socket)}{sketching&&<SketchProps scene={scene} t={t}/>} {dog&&scene.getObjectByName('Head')&&createPortal(<Tongue anchor={mouthAnchor} t={t}/>,scene.getObjectByName('Head')!)}</group>;
}
function Tongue({anchor,t}:{anchor:THREE.Matrix4;t:number}){
 const extend=.025+.035*(.5+.5*Math.sin(t*16));
 return <group matrix={anchor} matrixAutoUpdate={false}>
  <mesh position={[0,-.006,extend*.55]} scale={[.018,.008,extend*.6]}><sphereGeometry args={[1,16,8]}/><meshToonMaterial color="#ba6584"/></mesh>
  <mesh position={[0,-.019,extend+.013]} scale={[.009,.012,.012]}><sphereGeometry args={[1,12,8]}/><meshToonMaterial color="#f4eed9"/></mesh>
 </group>
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
function Box({p,s,c}:{p:[number,number,number];s:[number,number,number];c:string}){return <mesh position={p} receiveShadow castShadow><boxGeometry args={s}/><meshToonMaterial color={c}/></mesh>}
function Mug({p,scale=1,ghost=false}:{p:[number,number,number];scale?:number;ghost?:boolean}){
 return <group position={p} scale={scale}>
 <mesh castShadow><cylinderGeometry args={[.13,.12,.3,32]}/><meshStandardMaterial color={ghost?'#8cfff0':'#f3ad26'} metalness={.15} roughness={.17} transparent opacity={ghost?.4:1}/></mesh>
 <mesh position={[0,.162,0]}><cylinderGeometry args={[.135,.13,.04,32]}/><meshStandardMaterial color="#fffbe4"/></mesh>
 <mesh position={[.153,.015,0]} rotation={[0,0,0]}><torusGeometry args={[.085,.022,10,24]}/><meshStandardMaterial color={ghost?'#9bfff0':'#d8f0ea'} metalness={.35} roughness={.18}/></mesh>
 {[0,1,2,3,4].map(i=><mesh key={i} position={[Math.sin(i*3)*.075,.19,Math.cos(i*3)*.075]}><sphereGeometry args={[.037,10,8]}/><meshStandardMaterial color="#fffbe4"/></mesh>)}
 </group>
}
const memories=['02','03','05','06','07'];
function memoryAt(id:string){return memories.includes(id);}
function Set({memory,dog=false}:{memory:boolean;dog?:boolean}){return <>
 <color attach="background" args={[memory?'#9b899c':'#243c48']}/>
 <ambientLight intensity={.65}/><hemisphereLight args={[memory?'#ffe5cc':'#cbdff9',memory?'#635672':'#475871',1.15]}/>
 <directionalLight position={[-3,5,4]} intensity={2} color={memory?'#ffe7b9':'#f7d6ac'} castShadow shadow-mapSize={[1536,1536]}/>
 <Box p={[0,-.10,0]} s={[12,.2,10]} c={memory?'#b29b7c':'#8a6b56'}/>
 {Array.from({length:13},(_,i)=><Box key={i} p={[i*.5-3,.003,0]} s={[.012,.006,8]} c={memory?'#8d7a66':'#59493f'}/>)}
 <Box p={[0,2,-2.2]} s={[10,4,.15]} c={memory?'#c2b19a':'#234752'}/>
 <Box p={[0,.06,-2.05]} s={[10,.12,.1]} c="#6d574b"/>
 {memory?<>
  <Box p={[-1.65,1.5,-2.07]} s={[1.2,1.5,.05]} c="#e0cbae"/>
  {[-2.2,-1.65,-1.1].map(x=><Box key={x} p={[x,1.5,-2.01]} s={[.025,1.5,.07]} c="#64594e"/>)}
  {[.8,1.15,1.5,1.85,2.2].map(y=><Box key={y} p={[-1.65,y,-2.01]} s={[1.2,.025,.07]} c="#64594e"/>)}
 </>:<>
  <Box p={[0,2,-2.05]} s={[3.8,1.35,.04]} c="#59798b"/>
  {[-1.85,0,1.85].map(x=><Box key={x} p={[x,2,-1.99]} s={[.05,1.4,.08]} c="#142e3a"/>)}
  <Box p={[0,2,-1.99]} s={[3.8,.05,.08]} c="#142e3a"/>
 </>}
 {!memory&&<><Box p={[0,.67,.40]} s={[.85,.075,.62]} c="#785539"/>{[-.33,.33].map(x=><Box key={x} p={[x,.33,.40]} s={[.06,.66,.48]} c="#3c3029"/>)}</>}
 {memory&&!dog&&<Box p={[1.1,.35,-.05]} s={[.7,.7,.6]} c="#8d684b"/>}
 </>}
function Camera({shot,f,progress}:{shot:string;f:number;progress:number}){
 const {camera}=useThree();
 useLayoutEffect(()=>{
 let p:[number,number,number]=[2.1,1.75,4.1],target:[number,number,number]=[0,1.06,0];
 if(shot==='sobaya'){p=[.1,1.63,2.7];target=[-.65,1.36,0];}
 if(shot==='yametaro'){p=[.08,1.20,2.4];target=[.72,.96,0];}
 if(shot==='inspect'){p=[.8,1.8,2.6];target=[0,1.35,.10];}
 if(shot==='sketch'){p=[.8,2.12,2.1];target=[0,1.16,.3];}
 if(shot==='dog-wide'){p=[2.05,1.04,2.4];target=[0,.43,-.34];}
 if(shot==='dog-close'){p=[.84,.47,.62];target=[.035,.27,.10];}
 if(shot==='empty'){p=[.5,1.5,2.9];target=[0,1.1,0];}
 if(shot==='magic'){p=[1.55,1.40,2.6];target=[.12,1.02,.1];}
 if(shot==='reveal'){p=[.75,1.70,2.55];target=[0,1.28,.1];}
 const push=shot.startsWith('dog')?.12:.045;
 camera.position.set(p[0],p[1],p[2]-Math.min(1,progress)*push);camera.lookAt(...target);camera.updateProjectionMatrix();
 },[camera,shot,f,progress]);return null;
}
function Stage(){
 const original=useCurrentFrame(),f=Math.floor(original/2)*2,row=at(original),local=Math.max(0,(f-row.start)/24);
 const progress=(f-row.start)/(row.end-row.start),memory=memoryAt(row.id),dog=row.id==='03';
 let motion:SkitMotion='Explain',yam:SkitMotion='Listen';
 let holding=false,sketching=false,shot=row.shot;
 if(row.id==='01'&&local<1.6)shot='present-two';
 if(row.id==='02'){sketching=progress>.48;holding=!sketching;motion=sketching?'SketchMug':'InspectMug';shot=sketching?'sketch':'inspect';}
 if(dog){shot=progress<.48?'dog-wide':'dog-close';}
 if(row.id==='04'){yam='Tsukkomi';shot='yametaro';motion='EmptyHands';}
 if(row.id==='05'){motion='EmptyHands';shot='empty';}
 if(row.id==='06'){motion='Conjure';shot='magic';}
 if(row.id==='07'){motion='ProudToast';holding=true;shot='reveal';}
 if(row.id==='08'){yam='Wish';shot='yametaro';}
 if(row.id==='09')yam='DoubleTake';
 const actionTime=row.id==='02'&&progress>.48?local-(row.end-row.start)/24*.48:local;
 return <>
 <Camera shot={shot} f={original} progress={progress}/><Set memory={memory} dog={dog}/>
 <Actor name="sobaya" x={memory?0:-.70} yaw={memory?0:.43} motion={motion} t={actionTime} speaking={!memory&&row.speaker==='sobaya'} holding={holding} sketching={sketching} dog={dog}/>
 {!memory&&<Actor name="yametaro" x={.85} yaw={-.48} motion={yam} t={local} speaking={row.speaker==='yametaro'&&original<row.end} mouth={row.mouth?.[f-row.start]??0}/>}
 {!memory&&<Mug p={[0,.88,.4]} scale={.85}/>}
 {memory&&sketching&&<Mug p={[1.1,.88,-.05]} scale={.85}/>}
 {dog&&<>
  <Mug p={[.035,.095,.17]} scale={.6}/>
  <mesh rotation={[-Math.PI/2,0,0]} position={[.08,.007,.23]} scale={[.43,.27,1]}><circleGeometry args={[1,32]}/><meshToonMaterial color="#b99434" transparent opacity={.75}/></mesh>
  {Array.from({length:8},(_,i)=><mesh key={i} position={[.03+Math.sin(i*2.1)*.12,.04+((i*.017+local*.08)%.17),.20+Math.cos(i*2.1)*.09]} scale={[.012,.023,.012]}><sphereGeometry args={[1,8,6]}/><meshToonMaterial color="#eadbb4"/></mesh>)}
 </>}
 {row.id==='06'&&<Mug p={[.6,1.03,.25]} scale={.9+.035*Math.sin(f*.12)} ghost/>}
 {(row.id==='06'||row.id==='07')&&Array.from({length:36},(_,i)=><mesh key={i} position={[.2+Math.sin(i*2.4+f*.035)*(.24+i*.008),.68+((i*.073+f*.012)%1.25),.25+Math.cos(i*2.4+f*.035)*.3]} scale={.009+(i%3)*.005}><sphereGeometry args={[1,6,6]}/><meshBasicMaterial color="#ffe4a1"/></mesh>)}
 </>
}
const Film=()=>{
 const f=useCurrentFrame(),row=at(f),talking=f>=row.start&&f<row.end,memory=memoryAt(row.id),dog=row.id==='03';
 const fade=interpolate(f,[0,18,composition.durationInFrames-18,composition.durationInFrames-1],[1,0,0,1],clamp);
 const memoryStart=lines.find(l=>l.id==='02')!.start;
 const entryFlash=interpolate(f,[memoryStart-5,memoryStart,memoryStart+10],[0,.65,0],clamp);
 return <AbsoluteFill style={{background:'#111620',fontFamily:'"Hiragino Sans",sans-serif',color:'#fff'}}>
 <ThreeCanvas width={composition.width} height={composition.height} shadows dpr={1} camera={{fov:37,near:.05,far:30}} gl={{antialias:true}}><Stage/></ThreeCanvas>
 <AbsoluteFill style={{pointerEvents:'none',background:memory?'radial-gradient(ellipse,transparent 35%,rgba(58,27,64,.24)),linear-gradient(0deg,rgba(61,28,34,.35),transparent 35%)':'linear-gradient(0deg,rgba(4,14,24,.7),transparent 28%)'}}/>
 {dog&&<AbsoluteFill style={{opacity:.18,background:'repeating-linear-gradient(92deg,transparent 0px,transparent 42px,rgba(45,16,51,.45) 43px,transparent 45px)',maskImage:'linear-gradient(0deg,transparent 30%,black)'}}/>}
 <div style={{position:'absolute',top:0,left:0,right:0,height:28,background:'#10121a'}}/>
 <div style={{position:'absolute',bottom:0,left:0,right:0,height:28,background:'#10121a'}}/>
 {f<100&&<div style={{position:'absolute',left:52,top:47,fontSize:18,letterSpacing:5,color:'#e9ddbb'}}>窓際族物語　ビールの記憶</div>}
 {memory&&f-memoryStart<45&&f>=memoryStart&&<div style={{position:'absolute',left:55,top:53,fontSize:23,letterSpacing:6,color:'#eee0bc'}}>あの頃――</div>}
 {dog&&<div style={{position:'absolute',left:70,top:80,transform:'rotate(-9deg)',fontFamily:'serif',fontSize:46,letterSpacing:8,color:'#3b2541',textShadow:'1px 1px #e5d6c9'}}>ぺろ… ぺろ…</div>}
 {talking&&<div style={{position:'absolute',left:95,right:95,bottom:47,textAlign:'center',whiteSpace:'pre-line',fontSize:30,fontWeight:600,lineHeight:1.45,textShadow:'0 2px 4px #101018, 1px 0 2px #101018, -1px 0 2px #101018'}}>{row.text}</div>}
 {lines.map(l=>l.audio&&<Sequence key={l.id} from={l.start}><Audio src={staticFile(l.audio)}/></Sequence>)}
 <AbsoluteFill style={{background:'#fff4df',opacity:entryFlash}}/>
 <AbsoluteFill style={{background:'#10121a',opacity:fade}}/>
 </AbsoluteFill>
};
registerRoot(()=> <Composition id="BeerTraining" component={Film} {...composition}/>);
