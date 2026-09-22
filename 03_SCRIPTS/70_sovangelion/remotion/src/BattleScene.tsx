import React,{useMemo,useLayoutEffect} from 'react';
import {useLoader,useThree,createPortal} from '@react-three/fiber';
import {staticFile} from 'remotion';
import {GLTFLoader} from 'three/examples/jsm/loaders/GLTFLoader.js';
import {clone} from 'three/examples/jsm/utils/SkeletonUtils.js';
import * as THREE from 'three';
import {applySkitMotion} from '../../../../04_GAME_ASSETS/3d/motions/skit_v1/motions';
export const ease=(n:number)=>{n=Math.max(0,Math.min(1,n));return n*n*(3-2*n)};
const v=(x:number,y:number,z:number)=>new THREE.Vector3(x,y,z);
export type P=[number,number,number];
export function Box({p=[0,0,0],s=[1,1,1],c='#52616b',r=[0,0,0],glow=false}:{p?:P;s?:P;c?:string;r?:P;glow?:boolean}){return <mesh position={p} rotation={r} castShadow receiveShadow><boxGeometry args={s}/>{glow?<meshBasicMaterial color={c}/>:<meshToonMaterial color={c}/>}</mesh>}
function turnWorld(b:THREE.Object3D,q:THREE.Quaternion){b.quaternion.copy(b.parent!.getWorldQuaternion(new THREE.Quaternion()).invert().multiply(q));b.updateMatrixWorld(true)}
function deltaWorld(scene:THREE.Object3D,name:string,x:number,y=0,z=0){const b=scene.getObjectByName(name);if(!b?.parent)return;scene.updateWorldMatrix(true,true);const space=scene.getWorldQuaternion(new THREE.Quaternion());turnWorld(b,space.clone().multiply(new THREE.Quaternion().setFromEuler(new THREE.Euler(x,y,z))).multiply(space.invert()).multiply(b.getWorldQuaternion(new THREE.Quaternion())))}
function reach(scene:THREE.Object3D,side:string,target:P){
 scene.updateWorldMatrix(true,true);const hand=scene.getObjectByName(side+'Hand');if(!hand)return;const goal=scene.localToWorld(v(...target));
 for(let i=0;i<8;i++)for(const name of [side+'ForeArm',side+'Arm']){const b=scene.getObjectByName(name);if(!b?.parent)continue;const origin=b.getWorldPosition(v(0,0,0));const from=hand.getWorldPosition(v(0,0,0)).sub(origin).normalize(),to=goal.clone().sub(origin).normalize();turnWorld(b,new THREE.Quaternion().setFromUnitVectors(from,to).multiply(b.getWorldQuaternion(new THREE.Quaternion())));scene.updateMatrixWorld(true)}
}
function seat(scene:THREE.Object3D,t:number,pose:string){
 // Seat the small canonical rig with world-space limb deltas, preserving bone lengths.
 deltaWorld(scene,'LeftUpLeg',-1.28);deltaWorld(scene,'RightUpLeg',-1.28);
 deltaWorld(scene,'LeftLeg',1.35);deltaWorld(scene,'RightLeg',1.35);
 const angry=pose==='panic'||pose==='brace';
 deltaWorld(scene,'Head',angry?-.05:.08,Math.sin(t*1.4)*(angry?.12:.055),angry?.035*Math.sin(t*15):0);
 reach(scene,'Left',[.23,.48+(angry?.045*Math.sin(t*11):0),.28]);
 reach(scene,'Right',[-.20,.46,.34]);
 if(pose==='type'){reach(scene,'Left',[.12,.44+.012*Math.sin(t*19),.38]);reach(scene,'Right',[-.1,.44+.012*Math.cos(t*17),.38])}
 if(pose==='exhausted')deltaWorld(scene,'Head',.20);
}
export function Actor({name='sobaya',p=[0,0,0],yaw=0,scale=1,clip='Hybrid_Idle_A',time=0,loop=true,pose='',mouth=0,mug=false,empty=false,lean=0}:{name?:string;p?:P;yaw?:number;scale?:number;clip?:string;time?:number;loop?:boolean;pose?:string;mouth?:number;mug?:boolean;empty?:boolean;lean?:number}){
 const gltf=useLoader(GLTFLoader,staticFile(`battle/${name}.glb`));
 const {scene,rest,mixer,windowAnchor}=useMemo(()=>{
  const scene=clone(gltf.scene);scene.traverse(o=>{if(o instanceof THREE.Mesh){o.frustumCulled=false;o.castShadow=true;o.receiveShadow=true;const old=Array.isArray(o.material)?o.material:[o.material];const ramp=new THREE.DataTexture(new Uint8Array([65,65,65,255,160,160,160,255,255,255,255,255]),3,1,THREE.RGBAFormat);ramp.needsUpdate=true;ramp.magFilter=THREE.NearestFilter;ramp.minFilter=THREE.NearestFilter;
   const mats=old.map(m=>{const a=m as THREE.MeshStandardMaterial;return new THREE.MeshToonMaterial({color:a.color,map:a.map,vertexColors:a.vertexColors,gradientMap:ramp,side:a.side,transparent:a.transparent,opacity:a.opacity,alphaTest:a.alphaTest})});o.material=Array.isArray(o.material)?mats:mats[0];
  }});const rest:{o:THREE.Object3D;p:THREE.Vector3;q:THREE.Quaternion;s:THREE.Vector3}[]=[];scene.traverse(o=>rest.push({o,p:o.position.clone(),q:o.quaternion.clone(),s:o.scale.clone()}));scene.updateMatrixWorld(true);const chest=scene.getObjectByName('Spine2');const windowAnchor=new THREE.Matrix4();if(chest)windowAnchor.copy(chest.matrixWorld).invert().multiply(scene.matrixWorld).multiply(new THREE.Matrix4().makeTranslation(0,.99,.225));return{scene,rest,mixer:new THREE.AnimationMixer(scene),windowAnchor};
 },[gltf]);
 useLayoutEffect(()=>{
  mixer.stopAllAction();rest.forEach(({o,p,q,s})=>{o.position.copy(p);o.quaternion.copy(q);o.scale.copy(s)});
  const anim=gltf.animations.find(a=>a.name===clip)??gltf.animations[0];if(anim){mixer.clipAction(anim).reset().play();mixer.setTime(loop?Math.max(0,time)%anim.duration:Math.min(Math.max(0,time),anim.duration-.005))}
  scene.updateWorldMatrix(true,true);
  if(name==='yametaro'){
   if(pose==='walk'){deltaWorld(scene,'LeftUpLeg',Math.sin(time*9)*.38);deltaWorld(scene,'RightUpLeg',-Math.sin(time*9)*.38);deltaWorld(scene,'LeftArm',-Math.sin(time*9)*.22);deltaWorld(scene,'RightArm',Math.sin(time*9)*.22);}
   else if(pose==='stand')applySkitMotion(scene,'Tsukkomi',time);
   else seat(scene,time,pose);
  }
  if(pose==='bound'){reach(scene,'Left',[.50,1.28,.15]);reach(scene,'Right',[-.50,1.28,.15]);deltaWorld(scene,'Head',.12)}
  if(pose==='shoulder'){deltaWorld(scene,'Spine2',.30);reach(scene,'Left',[.3,1.1,.2]);reach(scene,'Right',[-.3,1.18,.2]);}
  if(pose==='angry'){deltaWorld(scene,'Head',.20);deltaWorld(scene,'Spine2',.04)}
  scene.traverse(o=>{if(o instanceof THREE.Mesh&&o.morphTargetDictionary&&o.morphTargetInfluences){const n=o.morphTargetDictionary.SpeechOpen;if(n!==undefined)o.morphTargetInfluences[n]=mouth;}});scene.updateMatrixWorld(true);
 },[scene,rest,mixer,gltf,clip,time,loop,pose,mouth,name]);
 const socket=scene.getObjectByName('PropSocket.R')??scene.getObjectByName('PropSocketR');
 return <group position={p} rotation={[0,yaw,lean]} scale={scale}><primitive object={scene}/>{name==='sobaya'&&scene.getObjectByName('Spine2')&&createPortal(<group matrix={windowAnchor} matrixAutoUpdate={false}><Box s={[.22,.15,.025]} c="#24343c"/><Box p={[0,0,.015]} s={[.185,.115,.006]} c="#d5dbc0" glow/><Box p={[0,0,.022]} s={[.009,.12,.008]} c="#4b565b"/></group>,scene.getObjectByName('Spine2')!)}{mug&&socket&&createPortal(<HeldMug empty={empty}/>,socket)}</group>
}
function HeldMug({empty}:{empty:boolean}){
 const gltf=useLoader(GLTFLoader,staticFile('battle/mug.glb'));
 const scene=useMemo(()=>{const s=gltf.scene.clone(true);s.updateMatrixWorld(true);const grip=s.getObjectByName('Grip');if(grip){const m=grip.matrixWorld.clone().invert().multiply(s.matrixWorld);m.decompose(s.position,s.quaternion,s.scale)}s.traverse(o=>{if(o instanceof THREE.Mesh){o.castShadow=true;const old=Array.isArray(o.material)?o.material:[o.material];const mats=old.map(m=>{const c=m.clone() as THREE.MeshPhysicalMaterial;if(c.transmission){c.transmission=0;c.transparent=true;c.opacity=empty?.55:.28;if(empty){c.color.set('#b6d8e4');c.roughness=.18;c.metalness=.3;}}if(o.name==='BeerVolume'||o.name==='LiquidSurface'){if(empty)o.visible=false;else{c.color.set('#e7a032');c.opacity=1;c.transparent=false;}}if(empty&&/foam|bubble/i.test(o.name))o.visible=false;return c});o.material=Array.isArray(o.material)?mats:mats[0]}});return s},[gltf,empty]);return <primitive object={scene}/>
}
/** Animate the exact game-adopted skinned model; never replace its six tentacles. */
function reachTentacle(scene:THREE.Object3D,index:number,goal:P,weight:number){
 if(weight<=0)return;
 const base=scene.getObjectByName(`Tentacle${index}Base`),mid=scene.getObjectByName(`Tentacle${index}Mid`),tip=scene.getObjectByName(`Tentacle${index}Tip`);
 if(!base||!mid||!tip)return;
 scene.updateWorldMatrix(true,true);
 const origin=scene.worldToLocal(base.getWorldPosition(v(0,0,0)));
 // Stretch translations between native joints for a cinematic whip, keeping the original mesh and skin.
 const length=mid.position.length()+tip.position.length();
 const stretch=1+(Math.min(3.3,v(...goal).distanceTo(origin)/length)-1)*weight;
 mid.position.multiplyScalar(stretch);tip.position.multiplyScalar(stretch);
 scene.updateMatrixWorld(true);
 const target=tip.getWorldPosition(v(0,0,0)).lerp(scene.localToWorld(v(...goal)),weight);
 for(let step=0;step<12;step++)for(const bone of [mid,base]){
  const from=bone.getWorldPosition(v(0,0,0));
  const dir=tip.getWorldPosition(v(0,0,0)).sub(from).normalize(),toward=target.clone().sub(from).normalize();
  turnWorld(bone,new THREE.Quaternion().setFromUnitVectors(dir,toward).multiply(bone.getWorldQuaternion(new THREE.Quaternion())));scene.updateMatrixWorld(true);
 }
}
function Takosan({x=1.15,z=0,yaw=-1.02,t=0,attack=0,bind=false,fall=0,charge=0,broken=false}:{x?:number;z?:number;yaw?:number;t?:number;attack?:number;bind?:boolean;fall?:number;charge?:number;broken?:boolean}){
 const gltf=useLoader(GLTFLoader,staticFile('battle/takosan.glb'));
 const {scene,mixer,rest}=useMemo(()=>{
  const scene=clone(gltf.scene);
  scene.traverse(o=>{if(o instanceof THREE.Mesh){o.castShadow=true;o.receiveShadow=true;o.frustumCulled=false;}});
  const rest:{o:THREE.Object3D;p:THREE.Vector3;q:THREE.Quaternion;s:THREE.Vector3}[]=[];
  scene.traverse(o=>rest.push({o,p:o.position.clone(),q:o.quaternion.clone(),s:o.scale.clone()}));
  return {scene,mixer:new THREE.AnimationMixer(scene),rest};
 },[gltf]);
 useLayoutEffect(()=>{
  mixer.stopAllAction();rest.forEach(({o,p,q,s})=>{o.position.copy(p);o.quaternion.copy(q);o.scale.copy(s)});
  const idle=gltf.animations.find(a=>a.name==='Idle');if(idle){mixer.clipAction(idle).reset().play();mixer.setTime(Math.floor(t*12)/12%idle.duration)}
  scene.updateWorldMatrix(true,true);
  if(bind){
   reachTentacle(scene,1,[-.32,.97,.95],.92);
   reachTentacle(scene,2,[-.04,1.03,.95],.92);
   reachTentacle(scene,3,[.22,.82,.94],.92);
  }else if(attack>0){reachTentacle(scene,1,[-.20,.40+attack*.55,.50+attack*.85],attack);}
  scene.updateMatrixWorld(true);
 },[scene,mixer,rest,gltf,t,attack,bind]);
 return <group position={[x,.025,z]} rotation={[fall*.9,yaw,fall*.8]} scale={1.25}><primitive object={scene}/>
 {!broken&&<mesh position={[0,.64,.265]}><sphereGeometry args={[.085,24,16]}/><meshStandardMaterial color="#a60824" emissive="#ff193a" emissiveIntensity={.5+charge*3} metalness={.35} roughness={.18}/></mesh>}
 {charge>0&&<pointLight position={[0,.82,.35]} color="#ff3249" intensity={charge*3} distance={3}/>}
 </group>
}
function Building({x,z,h,w=.42,broken=false}:{x:number;z:number;h:number;w?:number;broken?:boolean}){return <group position={[x,0,z]} rotation={[0,0,broken?-.22:0]}>
 <Box p={[0,h/2,0]} s={[w,h,w*.75]} c={broken?'#273039':'#263944'}/>
 {Array.from({length:Math.floor(h/.12)},(_,y)=><group key={y}>{[0,1,2].map(i=><Box key={i} p={[(i-1)*w*.25,.08+y*.12,w*.38]} s={[w*.11,.042,.003]} c={(i+y)%4===0?'#edac63':'#4e8792'} glow/>)}</group>)}
 <Box p={[0,h+.018,0]} s={[w+.025,.035,w*.8]} c="#1c2833"/>
 </group>}
function City({t,ruined=false}:{t:number;ruined?:boolean}){return <>
 <ambientLight intensity={.85}/><hemisphereLight args={['#a7d8f7','#31303a',1.15]}/>
 <directionalLight position={[-2,4,3]} color="#ceeafa" intensity={2.1} castShadow shadow-mapSize={[1024,1024]} shadow-camera-left={-5} shadow-camera-right={5} shadow-camera-top={5} shadow-camera-bottom={-5}/>
 <directionalLight position={[3,1,-2]} color="#ff914c" intensity={2.8}/>
 <Box p={[0,-.06,0]} s={[24,.1,22]} c="#17262f"/>
 {Array.from({length:16},(_,i)=><Box key={i} p={[-7+i,.002,.75]} s={[.42,.005,.04]} c="#677174"/>)}
 {Array.from({length:19},(_,i)=><Building key={i} x={(i-9)*.57} z={-1.6-(i%3)*.55} h={.48+(i*7%11)*.12} w={.34+(i%3)*.08} broken={ruined&&i%4===0}/>)}
 {[-2.5,2.5].map(x=><Building key={x} x={x} z={.1} h={.7} broken={ruined}/>)}
 {Array.from({length:30},(_,i)=><Box key={'r'+i} p={[Math.sin(i*31)*3,.035,-.8+Math.cos(i*13)*1.7]} s={[.04+(i%4)*.022,.05,.045]} r={[i*.5,i,0]} c="#53616a"/>)}
 {Array.from({length:14},(_,i)=><mesh key={'e'+i} position={[Math.sin(i*15)*3,.1+((t*.19+i*.27)%2.5),-1.0+Math.cos(i)*.5]} scale={.006+(i%3)*.003}><sphereGeometry args={[1,6,4]}/><meshBasicMaterial color="#ffc472"/></mesh>)}
 </>}
function Debris({t,origin=[0,.2,0],power=1}:{t:number;origin?:P;power?:number}){if(t<0||t>2.5)return null;return <group position={origin}>{Array.from({length:32},(_,i)=>{const a=i*2.4,speed=(.4+(i%7)*.12)*power;return <Box key={i} p={[Math.sin(a)*speed*t,Math.max(.01,(.65+(i%4)*.3)*t-1.4*t*t),Math.cos(a)*speed*t]} s={[.035+(i%3)*.02,.04,.035]} r={[t*3+i,t*5,0]} c={i%4===0?'#ffcb7d':'#77818a'}/>})}</group>}
function Beam({a,b,power=1}:{a:P;b:P;power?:number}){const A=v(...a),B=v(...b);return <group><mesh position={A.clone().add(B).multiplyScalar(.5)} quaternion={new THREE.Quaternion().setFromUnitVectors(v(0,1,0),B.clone().sub(A).normalize())}><cylinderGeometry args={[.026*power,.026*power,A.distanceTo(B),12]}/><meshBasicMaterial color="#fff1d2"/></mesh><mesh position={B}><sphereGeometry args={[.12*power,16,8]}/><meshBasicMaterial color="#ff9e67" transparent opacity={.75}/></mesh><pointLight position={B} color="#ff8844" intensity={5*power} distance={5}/></group>}
export function BattleCamera({pos,target,fov=39,shake=0,t=0}:{pos:P;target:P;fov?:number;shake?:number;t?:number}){const {camera}=useThree();useLayoutEffect(()=>{camera.position.set(pos[0]+Math.sin(t*47)*shake,pos[1]+Math.cos(t*61)*shake,pos[2]);camera.lookAt(...target);(camera as THREE.PerspectiveCamera).fov=fov;camera.updateProjectionMatrix()},[camera,pos,target,fov,shake,t]);return null}
export function Battlefield({id,t}:{id:string;t:number}){
 let sx=-1.05,tx=1.0,sz=0,tz=0,clip='Hybrid_Idle_A',pose='',at=t,loop=true,mug=false,empty=false,lean=0,fall=0,charge=0,attack=0,bind=false,showSoba=true;
 let pos:P=[.15,1.2,4.5],target:P=[0,.85,0],shake=0,blast=-1;
 if(id==='opening'){showSoba=false;tx=0;pos=[1.7,.7,3];target=[0,.9,0];charge=ease((t-1)/1.2);attack=ease(t/2);blast=t-3.3;}
 if(id==='land'){sx=-1;clip='Library_Jump_Land';at=t*.6;loop=false;blast=t-.15;pos=[-2.4,.38,3.2];target=[-.6,.8,0];shake=.04*(1-ease(t/2));}
 if(id==='walk-command'){clip='Hybrid_Idle_A';sx=-1.05;pos=[-.5,.65,3.9]}
 if(id==='whip'){attack=Math.sin(Math.PI*ease(t/1.4));clip=t<1?'Hybrid_Idle_A':'Library_Hit_Chest';at=Math.max(0,t-1);loop=false;sx=-1.05-ease((t-1)/1.3)*.65;lean=-ease((t-1)/.4)*.13;blast=t-1.4;shake=.06*Math.sin(Math.PI*ease(t/4));pos=[-.1,.6,3.6]}
 if(id==='counter'){const u=ease(t/2);sx=-1.7+u*1.4;tx=.8;clip=t<2?'Hybrid_Walk':'Hybrid_Punch_Jab';at=t<2?t:(t-2)*.7;loop=t<2;tx+=ease((t-2.58)/.55)*.5;blast=t-2.58;pos=t<3?[-.2,1.3,3.4]:[.2,.95,3.6];target=[.1,.95,0]}
 if(id==='mug'){sx=-.7;tx=1.25;clip='Hybrid_MugHold';mug=true;pos=[-1.15,1.28,1.8];target=[-.65,1.3,0]}
 if(id==='beam'){sx=-.7;tx=1.25;clip='Hybrid_MugHold';mug=true;charge=ease(t/.8);pos=[.0,.95,3.2];target=[.1,.95,0];shake=t>1.2?.025:0}
 if(id==='spill'){sx=-.7;tx=1.25;clip='Hybrid_MugHold';mug=true;empty=true;pos=[-1.0,1.5,1.55];target=[-.58,1.25,.18]}
 if(id==='anger'){sx=-.65;tx=2;clip='Hybrid_MugHold';mug=true;empty=true;pose='angry';pos=[-.03,1.55,1.2];target=[-.63,1.53,0]}
 if(id==='rush'){sx=-1.4+ease(t/4)*.75;tx=1.2;clip='Hybrid_MugRun';mug=true;empty=true;at=t*1.35;pos=[-1.65,.44,2.25];target=[sx,.9,0];blast=(t%1.4);shake=.015}
 if(id==='dodge'){sx=-.7+ease(t/4)*.3;tx=.9;clip='Hybrid_Crouch_Walk';mug=true;empty=true;attack=Math.sin(Math.PI*ease(t/2));pos=[0,.42,3.1];target=[.15,.6,0];blast=t-1.4}
 if(id==='shoulder'){sx=-.45+ease(t/1.8)*.65;tx=.85+ease((t-1.4)/1.2)*.55;clip='Hybrid_MugRun';pose='shoulder';at=.4;loop=false;mug=true;empty=true;blast=t-1.4;pos=[-.2,.65,3.1];target=[.35,.85,0];shake=.03}
 if(id==='bind'||id==='struggle'){sx=-.4;tx=.65;clip='Hybrid_Idle_A';pose='bound';mug=true;empty=true;bind=true;charge=id==='struggle'?ease(t/3):.1;pos=id==='bind'?[.25,1.65,3.2]:[-.8,1.1,2.3];target=[.0,1.05,0];shake=id==='struggle'?.012:0}
 if(id==='pull'){sx=-.4-ease(t/2)*.18;tx=.85-ease(t/2)*.42;clip='Library_Push';at=t*.55;loop=false;mug=true;empty=true;bind=t<2;fall=ease(t/3)*.22;charge=.85;pos=[0,1.6,2.75];target=[0,.92,0];blast=t-2.3}
 if(id==='smash'){sx=-.6+ease(t/2)*.28;tx=.5;clip='Hybrid_MugSmash';at=t<2.6?.6*ease(t/2.6):.6+.4*ease((t-2.6)/1.4);loop=false;mug=true;empty=true;fall=.18;charge=1;pos=[-.2,.7,2.55];target=[.0,.9,0];shake=.01}
 if(id==='explosion'||id==='aftermath'){sx=-.35;tx=.65;clip='Hybrid_MugHold';mug=true;empty=true;fall=1.1;pos=[-.4,1.15,4];target=[.0,.75,0];blast=id==='explosion'?t:-1;shake=id==='explosion'?.03*(1-ease(t/4)):0}
 if(id==='impact'){sx=-.35;tx=.5;clip='Hybrid_MugSmash';at=1;loop=false;mug=true;empty=true;charge=1;fall=.2+ease(t/2)*.5;pos=[.8,.95,1.9];target=[.35,.85,0];blast=t;shake=.035;}
 if(id==='ending'){sx=0;tx=3;clip='Hybrid_Idle_A';pos=[2.8,1.9,5.5+ease(t/6)];target=[0,.8,0];fall=1.1;}
 const beamOn=(id==='beam'&&t>1.2)||(id==='opening'&&t>2.2&&t<3.5);
 return <><color attach="background" args={['#101c30']}/><fog attach="fog" args={['#101c30',6,18]}/><City t={t} ruined/><BattleCamera pos={pos} target={target} shake={shake} t={t}/>
 {showSoba&&<Actor p={[sx,0,sz]} yaw={id==='ending'?.2:1.3} clip={clip} time={Math.floor(at*12)/12} loop={loop} pose={pose} mug={mug} empty={empty} lean={lean}/>}
 <Takosan yaw={id==='opening'?-.1:-1.02} x={tx} z={tz} t={t} attack={attack} bind={bind} fall={fall} charge={charge} broken={id==='explosion'||id==='aftermath'||id==='ending'||(id==='impact'&&t>.25)}/>
 {beamOn&&<Beam a={[tx-.30,1.26,0]} b={id==='opening'?[-1.6,.4,.1]:[sx+.24,1.18,.15]} power={1+.2*Math.sin(t*44)}/>}
 <Debris t={blast} origin={[id==='whip'?sx:id==='counter'?tx:0,.1,0]} power={id==='explosion'?2:1}/>
 {id==='impact'&&t>.25&&Array.from({length:18},(_,i)=><Box key={'core'+i} p={[.35+Math.sin(i*2.4)*(t-.25)*.7,.85+Math.cos(i*1.8)*(t-.25)*.6,.1+Math.sin(i*3.1)*(t-.25)*.7]} s={[.025,.035,.025]} r={[i+t*4,i,0]} c="#ff3453" glow/>)}
 {id==='spill'&&Array.from({length:24},(_,i)=><mesh key={i} position={[sx+.35+Math.sin(i*2.4)*t*.1,Math.max(.04,1.3-t*.6-(i%4)*.1),.18+Math.cos(i)*t*.1]} scale={[.018,.045,.018]}><sphereGeometry args={[1,8,4]}/><meshBasicMaterial color="#efa52b"/></mesh>)}
 {id==='explosion'&&<mesh position={[tx,.8,0]} scale={.1+ease(t/1.2)*2.6}><sphereGeometry args={[1,24,16]}/><meshBasicMaterial color={t<.5?'#fff8e7':'#e58337'} transparent opacity={1-ease((t-.7)/2.7)}/></mesh>}
 </>
}
export function VoxelCast({name,t,speaking=false,p=[0,0,0],yaw=0,scale=1,gesture=''}:{name:'yotan'|'fukuchan';t:number;speaking?:boolean;p?:P;yaw?:number;scale?:number;gesture?:string}){
 const gltf=useLoader(GLTFLoader,staticFile(`battle/${name}.glb`));
 const {scene,head,rest}=useMemo(()=>{
  const scene=gltf.scene.clone(true);scene.updateMatrixWorld(true);
  const root=scene.getObjectByName(name==='yotan'?'YotanVoxel_Root':'FukuchanVoxel_Root')??scene;
  const heads:THREE.Object3D[]=[];scene.traverse(o=>{if(o instanceof THREE.Mesh){o.castShadow=true;o.receiveShadow=true;o.frustumCulled=false;if(/Bang|FacePanel|Hair|HeadCube|Glasses/.test(o.name))heads.push(o)}});
  const head=new THREE.Group();head.name='PerformanceHeadPivot';head.position.set(0,name==='yotan'?1.98:2.04,0);root.add(head);root.updateMatrixWorld(true);heads.forEach(o=>head.attach(o));
  const rest:{o:THREE.Object3D;q:THREE.Quaternion}[]=[];scene.traverse(o=>rest.push({o,q:o.quaternion.clone()}));return {scene,head,rest};
 },[gltf,name]);
 useLayoutEffect(()=>{
  rest.forEach(({o,q})=>o.quaternion.copy(q));
  const arm=scene.getObjectByName('VoxelRig_ArmSecondary'),primary=scene.getObjectByName('VoxelRig_ArmPrimary');
  const accent=speaking?(.5+.5*Math.sin(t*4)):0;
  head.rotation.y=.09*Math.sin(t*1.2);head.rotation.x=(speaking?.035*Math.sin(t*5):0)+(name==='yotan'?.045:-.025);
  if(name==='fukuchan'){
   if(arm){arm.rotation.x=-.40-.50*accent;arm.rotation.z=-.24-.1*accent;}
   if(primary){primary.rotation.x=-.20-.20*accent;primary.rotation.z=.2;}
  }else{if(arm){arm.rotation.x=-.15-.52*accent;arm.rotation.z=-.14;}if(primary)primary.rotation.z=.06*Math.sin(t*2);}
  if(gesture==='block'&&arm){arm.rotation.x=-.1;arm.rotation.z=-1.15;head.rotation.y=-.2;}
  scene.updateMatrixWorld(true);
 },[scene,head,rest,name,t,speaking,gesture]);
 return <group position={p} rotation={[0,yaw,0]} scale={scale}><primitive object={scene}/></group>
}
export function CommandRoom({person,t,speaking=false}:{person:'yotan'|'fukuchan';t:number;speaking?:boolean}){return <>
 <color attach="background" args={['#0a1c29']}/><ambientLight intensity={1}/><hemisphereLight args={['#c0dce7','#263240',1.3]}/><directionalLight position={[-2,4,3]} intensity={2.4} color="#dbe5e4"/><pointLight position={[2,1,-1]} color="#568dcb" intensity={5}/>
 <BattleCamera pos={[.45,1.95,3.6]} target={[0,1.75,0]} fov={39} t={t}/>
 <VoxelCast name={person} t={t} speaking={speaking} yaw={-.08}/>
 <Box p={[0,.62,.65]} s={[3,.12,.70]} c="#263d49"/>
 <Box p={[0,.72,.69]} s={[2,.055,.34]} c="#345563"/>
 {Array.from({length:9},(_,i)=><Box key={i} p={[-.8+i*.2,.755,.66]} s={[.10,.01,.035]} c={i%3===0?'#d48854':'#65a6ac'} glow/>)}
 {[-1.5,1.5].map(x=><group key={x}><Box p={[x,1.7,-.9]} s={[1.1,1.15,.07]} c="#294b60"/><Box p={[x,1.7,-.85]} s={[.95,.95,.025]} c="#172e43"/>{[0,1,2].map(i=><Box key={i} p={[x,1.43+i*.21,-.827]} s={[.7,.012,.006]} c="#467f91" glow/>)}</group>)}
 </>}
export function Dock3D({t,launch=false,mouth=0,wide=false,id='dock'}:{t:number;launch?:boolean;mouth?:number;wide?:boolean;id?:string}){
 const boarding=id==='boarding',order=id==='order',u=ease(t/3.5),water=.8;
 return <>
 <color attach="background" args={['#071721']}/><ambientLight intensity={1}/><directionalLight position={[0,6,4]} intensity={3} color="#bbddf1"/><pointLight position={[2,3,-2]} intensity={25} color="#b299ef"/>
 <BattleCamera pos={launch?[3,3.3,7.2]:wide?[3.6,3.1,7.7]:boarding?[-2.8,2.5,4.2]:[0,1.85,3.7]} target={launch?[0,1.9,0]:wide?[0,1,-.5]:boarding?[0,1.3,-.3]:[0,1.32,.8]} t={t} shake={launch?.02:0}/>
 <Actor p={[0,-2.15+(launch?ease(t/3)*3.6:Math.sin(t*1.2)*.018),-1.65]} scale={2.5} clip="Hybrid_Idle_A" time={t}/>
 <Box p={[0,-1.1,-1.6]} s={[5,3.7,3.8]} c="#735124"/>
 <Box p={[0,water,-1.6]} s={[4.85,.025,3.65]} c="#d99919"/>
 {Array.from({length:32},(_,i)=><mesh key={i} position={[Math.sin(i*2.7)*2.2,water+.02+Math.sin(t*2+i)*.008,-1.6+Math.cos(i*4.7)*1.6]} rotation={[-Math.PI/2,0,0]}><circleGeometry args={[.045+(i%4)*.02,12]}/><meshBasicMaterial color="#fff0b9"/></mesh>)}
 {[-2.5,2.5].map(x=><Box key={x} p={[x,.86,-1.6]} s={[.16,.26,3.9]} c="#777f80"/>)}
 <Box p={[0,.87,.36]} s={[5.2,.26,.15]} c="#78868a"/>
 {[-2.8,2.8].map(x=><group key={x}><Box p={[x,2,-1.8]} s={[.45,4,.6]} c="#403550"/>{Array.from({length:7},(_,i)=><Box key={i} p={[x,.4+i*.5,-1.48]} s={[.45,.07,.02]} c="#c1493f" glow/>)}</group>)}
 <Box p={[0,.86,.92]} s={[6,.16,1.2]} c="#354451"/>
 <Box p={[-.6,.88,-.25]} s={[.7,.13,1.5]} c="#66777c"/>
 {!launch&&<group position={[-.6,1.4,-1.16]}><Box s={[.77,1.08,.12]} c="#5b6b6f"/><Box p={[0,0,.07]} s={[.6,.92,.025]} c="#07131c"/><Box p={[0,.57,.09]} s={[.7,.05,.04]} c="#b5f4b3" glow/>{(!boarding||t>3.5)&&<Box p={[0,0,.11]} s={[.58,.9,.04]} c="#abb4a9"/>}</group>}
 {!launch&&<VoxelCast name="fukuchan" p={[.65,.96,.96]} scale={.38} yaw={-.75} t={t} speaking={order} gesture={order?'':'block'}/>}
 {!launch&&t<(boarding?3.6:100)&&<Actor name="yametaro" p={boarding?[-.3-u*.3,.96,1.05-u*2.15]:[-.3,.96,1.05]} yaw={boarding?Math.PI:1.2} clip="Talk" time={t} pose={boarding?'walk':'stand'} mouth={mouth}/>}
 </>}
export function Cockpit({id,t,mouth=0}:{id:string;t:number;mouth?:number}){

 const shaking=['lift','slide','passenger'].includes(id),panic=['slide','passenger','approve','walk-question'].includes(id),typing=['clockin','exhausted','lastline'].includes(id);
 const shift=id==='slide'?ease(t/1.4)*.25:0;
 let pos:P=[1.45,1.15,2.3],target:P=[0,.62,0];
 if(['how','confused','lastline','approve','walk-question'].includes(id)){pos=[.65,.95,1.65];target=[0,.70,-.03]}
 if(id==='ui-author'){pos=[.06,.83,.88];target=[0,.78,-.07]}
 if(id==='lift'){pos=[1.5,1.45,2.0];target=[0,.60,0]}
 return <><color attach="background" args={['#9bacae']}/><ambientLight intensity={1.6}/><directionalLight position={[0,4,2]} intensity={2} color="#f1f5df"/>
 <BattleCamera pos={pos} target={target} t={t} shake={shaking?.025:0} fov={40}/>
 <Box p={[0,-.06,0]} s={[5,.12,4]} c="#727c7d"/>
 <Box p={[0,1.2,-1]} s={[4,2.4,.08]} c="#b2b8b0"/>
 <Box p={[0,1.15,-.933]} s={[2.8,1.45,.012]} c="#15273b"/>
 <group position={[0,.46,-.87]} scale={.44}>{Array.from({length:9},(_,i)=><Building key={i} x={(i-4)*.65} z={0} h={.6+(i*7%5)*.34}/>)}</group>
 {[-1.4,0,1.4].map(x=><Box key={x} p={[x,1.15,-.88]} s={[.055,1.5,.06]} c="#697373"/>)}
 <Box p={[0,1.16,-.88]} s={[2.8,.055,.06]} c="#697373"/>
 {!['exhausted','lastline'].includes(id)&&<group position={[.6,.56,-1.02]} scale={.28}><Takosan x={0} yaw={-.3} t={t} attack={.3}/></group>}
 {[0,1].map(i=><Box key={i} p={[-.7+i*1.4,2.2,.2]} s={[1,.025,.13]} c="#f9ffe4" glow/>)}
 <group position={[shift,0,0]} rotation={[0,0,shaking?Math.sin(t*8)*.025:0]}>
 <Box p={[0,.38,.37]} s={[1.48,.065,.62]} c="#bdc5bd"/>
 {[-.63,.63].map(x=><Box key={x} p={[x,.17,.37]} s={[.055,.34,.5]} c="#5d6666"/>)}
 <Box p={[.34,.51,.56]} s={[.46,.30,.03]} c="#34423f"/>
 <Box p={[.34,.52,.539]} s={[.40,.24,.006]} c={id==='confused'?'#ba4c3f':'#c8ddd1'} glow/>
 <Box p={[.34,.40,.51]} s={[.16,.015,.16]} c="#525f5a"/>
 <Box p={[.0,.421,.34]} s={[.4,.025,.13]} c="#545c59"/>
 {Array.from({length:7},(_,i)=><Box key={i} p={[-.14+i*.043,.437,.34]} s={[.027,.006,.07]} c="#bac4b9"/>)}
 <Box p={[-.48,.45,.52]} s={[.32,.10,.24]} c="#e2dec9"/>
 <Box p={[-.48,.509,.52]} s={[.30,.008,.23]} c="#f5f2df"/>
 <mesh position={[-.42,.46,.25]}><cylinderGeometry args={[.035,.027,.09,12]}/><meshToonMaterial color="#f0eddb"/></mesh>
 <Box p={[0,.19,-.08]} s={[.43,.38,.38]} c="#aa885c"/>
 <Box p={[0,.42,-.25]} s={[.43,.32,.05]} c="#b7976a"/>
 <Actor name="yametaro" p={[0,.05,-.10]} clip="Talk" time={Math.floor(t*12)/12} pose={panic?'panic':typing?'type':id==='exhausted'?'exhausted':'seat'} mouth={mouth}/>
 </group>
 {[-1.05,1.04].map(x=><Box key={x} p={[x,.20,-.4]} s={[.42,.4,.4]} c="#a38e6a"/>)}
 {shaking&&Array.from({length:7},(_,i)=><Box key={i} p={[Math.sin(t*2+i)*.75,.65+Math.abs(Math.sin(t*1.7+i))*.65,.25+Math.cos(t+i)*.3]} s={[.18,.003,.13]} r={[t*3+i,0,t+i]} c="#f3efda"/>)}
 </>
}
