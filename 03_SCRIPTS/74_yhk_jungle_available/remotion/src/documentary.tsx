import {useLayoutEffect,useMemo} from 'react';
import {AbsoluteFill,Audio,Img,Sequence,staticFile,useCurrentFrame,interpolate,Composition} from 'remotion';
import {ThreeCanvas} from '@remotion/three';
import {useThree} from '@react-three/fiber';
import * as THREE from 'three';
import {Actor,Set,Box} from './set-study';
import manifest from './edit-manifest.json';
import './documentary.css';
const {composition,scenes,lines}=manifest;
const clamp={extrapolateLeft:'clamp',extrapolateRight:'clamp'} as const;
const sceneAt=(f:number)=>scenes.find(s=>f>=s.startFrame&&f<s.endFrame)??scenes[scenes.length-1];
const activeAt=(f:number)=>lines.find(l=>f>=l.startFrame&&f<l.endFrame);
const lastAt=(f:number)=>[...lines].reverse().find(l=>f>=l.startFrame);
const line=(id:string)=>lines.find(l=>l.id===id)!;
const shotFor=(f:number)=>{
 const scene=sceneAt(f), local=(f-scene.startFrame)/24,row=lastAt(f),active=activeAt(f);
 if(scene.id==='discovery')return local<3?'window':'prayer-wide';
 if(scene.id==='offering'){
  if(f>line('s02').endFrame&&f<line('n04').startFrame)return 'crate';
  if(active?.mode==='narration'||local<1)return 'two';
 }
 if(scene.id==='window'){
  if(local<2)return 'wipe';
  if(f>line('s04').endFrame)return 'through';
 }
 if(scene.id==='prayer'&&f<line('q04').startFrame)return 'prayer-side';
 if(scene.id==='waiting'){
  if(local<2)return 'window';
  if(f>line('s08').endFrame)return 'wipe';
 }
 if(scene.id==='identity'){
  if(f<line('n05').startFrame+72)return 'badge';
  if(f<line('n05').endFrame)return 'two';
 }
 if(scene.id==='ending')return 'ending';
 if(row?.speaker==='yametaro'&&row.mode==='dialogue')return 'reporter';
 return 'chief';
};
function Camera({shot,f}:{shot:string;f:number}){
 const {camera}=useThree();const sc=sceneAt(f);const local=(f-sc.startFrame)/24;
 useLayoutEffect(()=>{
  const positions:Record<string,{p:[number,number,number];to:[number,number,number];fov?:number}>={
   'prayer-wide':{p:[2.8,1.88,6.3],to:[.2,1.32,-.6]},
   'prayer-side':{p:[-2.8,1.85,4.5],to:[.2,1.35,-.8]},
   two:{p:[1.6,1.56,4.5],to:[-.53,1.12,0]},
   chief:{p:[-.12,1.65,2.40],to:[-.65,1.42,0],fov:32},
   reporter:{p:[-.95,1.13,2.15],to:[-1.65,.85,.65],fov:31},
   window:{p:[1.25,1.95,1.45],to:[.4,1.90,-1.2],fov:35},
   through:{p:[.30,1.74,1.45],to:[.35,1.80,-1.25],fov:43},
   wipe:{p:[2.45,1.68,1.45],to:[1.08,1.42,-.55],fov:32},
   crate:{p:[2.08,1.10,1.75],to:[1.48,.30,.62],fov:36},
   badge:{p:[1.17,1.34,.28],to:[1.16,1.26,-.33],fov:30},
   ending:{p:[2.8,2.15,7.4+local*.018],to:[.2,1.23,-.75],fov:37}
  };
  const s=positions[shot]??positions.two;
  camera.position.set(s.p[0]+Math.sin(local*.32)*.003,s.p[1]+Math.sin(local*.42)*.002,s.p[2]);
  if(camera instanceof THREE.PerspectiveCamera)camera.fov=s.fov??37;
  camera.lookAt(...s.to);camera.updateProjectionMatrix();
 },[camera,shot,f,local]);return null;
}
function Ferns(){
 const shape=useMemo(()=>{const s=new THREE.Shape();s.moveTo(0,0);s.bezierCurveTo(-.11,.17,-.13,.39,0,.68);s.bezierCurveTo(.13,.39,.11,.17,0,0);return s;},[]);
 return <>{Array.from({length:28},(_,i)=>{
  const x=(i-13.5)*.46,z=-5.5+.34*Math.sin(i*2.3);
  return <group key={i} position={[x,.01,z]} scale={.8+(i%4)*.16}>
   {Array.from({length:8},(_,j)=><mesh key={j} rotation={[-.35-(j%3)*.23,j*.79,i*.12]} position={[0,(j%2)*.1,0]}><shapeGeometry args={[shape,6]}/><meshStandardMaterial color={['#31442b','#425132','#263c29'][j%3]} side={THREE.DoubleSide} roughness={.95}/></mesh>)}
  </group>;
 })}</>;
}
function Stage(){
 const f=useCurrentFrame(),sc=sceneAt(f),shot=shotFor(f),row=activeAt(f),t=f/24;
 const pray=['discovery','ending'].includes(sc.id)||(sc.id==='prayer'&&f<line('q04').startFrame);
 const crate=f>=line('s02').endFrame;
 let chiefAction=pray?'pray':row?.speaker==='sobaya'?'explain':'listen';
 if(sc.id==='offering'&&f<line('s01').startFrame)chiefAction='stop';
 if(sc.id==='offering'&&f>=line('n04').startFrame)chiefAction='welcome';
 if(['s08','s11'].includes(row?.id??''))chiefAction='look';
 if(sc.id==='identity'&&f>line('s09').endFrame)chiefAction='nod';
 const reporterAction=sc.id==='offering'&&f<line('s02').endFrame?'offer':'listen';
 const envelope=row?.mouth[Math.max(0,f-row.startFrame)]??0;
 const evening=sc.id==='ending'?interpolate(f,[sc.startFrame,sc.endFrame],[.35,.8],clamp):0;
 return <><Camera shot={shot} f={f}/><Set showCrate={crate} evening={evening}/><Ferns/>
  <Actor name="sobaya" p={[-.65,0,0]} yaw={pray?Math.PI:-.32} t={t} action={chiefAction}/>
  <Actor name="fukuchan" p={[1.13,0,-.48]} yaw={sc.id==='identity'?.05:Math.PI} t={t+.3} action={pray?'pray':sc.id==='identity'?'listen':'wipe'} badge/>
  {!pray&&<Actor name="yametaro" p={[-1.65,0,.65]} yaw={.75} t={t} action={reporterAction} heldCan={reporterAction==='offer'} mouth={row?.speaker==='yametaro'&&row.mode==='dialogue'?envelope:0}/>}
  {!pray&&<group position={[-1.65,0,.65]}><Box p={[0,.18,-.3]} s={[.38,.035,.32]} c="#62523b"/>{[-.13,.13].map(x=><Box key={x} p={[x,.09,-.3]} s={[.055,.18,.27]} c="#423e2d"/>)}</group>}
 </>;
}
function Intro(){
 const f=useCurrentFrame(),sc=scenes[0];
 const cuts=[0,line('n02').startFrame-12,line('n03').startFrame-12,sc.endFrame];
 const names=['intro_island','intro_trail','intro_leaves'];
 const i=f<cuts[1]?0:f<cuts[2]?1:2;
 const local=f-cuts[i],n=cuts[i+1]-cuts[i];
 const z=interpolate(local,[0,n],[1,1.055],clamp);
 return <AbsoluteFill style={{overflow:'hidden'}}>
  <Img src={staticFile(`backgrounds/${names[i]}.png`)} style={{width:'100%',height:'100%',objectFit:'cover',transform:`scale(${z}) translateX(${i===1?-local/n*8:0}px)`}}/>
  <AbsoluteFill style={{background:'linear-gradient(0deg,#08170b33,transparent 50%)'}}/>
  {i===0&&f>48&&<div className="intro-label" style={{opacity:Math.min(1,(f-48)/24)}}>孤島の密林、その奥地へ</div>}
  {i===2&&<div className="intro-label">YHK取材班</div>}
 </AbsoluteFill>;
}
function wrap(text:string){
 if(text.length<=25)return text;
 const target=Math.floor(text.length/2);let split=text.lastIndexOf('、',target+4)+1;
 if(split<7)split=text.indexOf('。',8)+1;
 if(split<7||split>27)split=Math.min(25,target);
 return text.slice(0,split)+'\n'+text.slice(split);
}
export const Documentary=()=>{
 const f=useCurrentFrame(),sc=sceneAt(f),row=activeAt(f);
 const end=composition.durationInFrames;
 const title=sc.id==='discovery'&&f>sc.startFrame+60;
 const intro=sc.id==='intro';
 const fade=interpolate(f,[0,36,end-96,end-36],[1,0,0,1],clamp);
 const speech=lines.some(l=>f>=l.startFrame-8&&f<l.endFrame+12);
 return <AbsoluteFill className="yhk-film">
  {intro?<Intro/>:<ThreeCanvas width={composition.width} height={composition.height} dpr={1} shadows camera={{fov:37,near:.025,far:150}} gl={{antialias:true}}><Stage/></ThreeCanvas>}
  <AbsoluteFill style={{background:'linear-gradient(0deg,rgba(4,12,7,.58),transparent 29%)',pointerEvents:'none'}}/>
  <div className="yhk-bug">YHK</div>
  {title&&<div className="film-title" style={{opacity:Math.min(1,(f-sc.startFrame-60)/18)}}><div className="eyebrow">YHK ドキュメンタリー</div><div>密林のアベイラブル</div><div className="subtitle">窓に祈る マドギワ族</div></div>}
  {sc.id==='offering'&&f>=line('s01').startFrame&&f<line('s02').endFrame&&<div className="nameplate"><small>マドギワ族　族長</small><strong>そば屋</strong></div>}
  {sc.id==='identity'&&f>=line('n05').startFrame&&f<line('n05').endFrame&&<div className="identity-caption">元アクシデンチュア社員</div>}
  {row&&row.mode!=='narration'&&<div className="film-caption" style={{opacity:Math.min(1,(f-row.startFrame+1)/4)}}>{wrap(row.text)}</div>}
  {lines.map(l=><Sequence key={l.id} from={l.startFrame} durationInFrames={l.endFrame-l.startFrame}><Audio src={staticFile(l.audio)} volume={l.mode==='chant'?.72:1}/></Sequence>)}
  <Audio src={staticFile(manifest.ambience)} startFrom={48*24} volume={f<36?f/36*.17:f>end-96?(end-f)/96*.12:speech?.09:.17}/>
  <AbsoluteFill style={{background:'#08100b',opacity:fade,pointerEvents:'none'}}/>
  {f>=manifest.creditsStartFrame&&<div className="credits" style={{opacity:Math.min(1,(f-manifest.creditsStartFrame)/20)}}><div>制作・著作　<span>YHK</span></div><small>取材・語り　やめ太郎</small></div>}
 </AbsoluteFill>;
};
export const DocumentaryRoot=()=> <Composition id="YhkDocumentary" component={Documentary} {...composition}/>;
