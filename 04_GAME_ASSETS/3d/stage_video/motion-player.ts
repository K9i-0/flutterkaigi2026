import * as THREE from 'three';
import {applySkitMotion,catalog,SkitMotion} from '../motions/skit_v1/motions';
import {applyDogLapping,applyDogSniff,dogSniffOrbit} from '../motions/skit_v1/flashback-motion';
export type MotionName=SkitMotion|'DogLapping'|'DogSniff';
export {catalog};
/** One player per cloned actor. Capture BEFORE playing any clip. Seconds are shot-local. */
export function createMotionPlayer(scene:THREE.Object3D,clips:THREE.AnimationClip[],actor:string){
 const rest:{o:THREE.Object3D;p:THREE.Vector3;q:THREE.Quaternion;s:THREE.Vector3;weights?:number[]}[]=[];
 scene.traverse(o=>rest.push({o,p:o.position.clone(),q:o.quaternion.clone(),s:o.scale.clone(),weights:(o as THREE.Mesh).morphTargetInfluences?.slice()}));
 const mixer=new THREE.AnimationMixer(scene);
 return {
  sample(name:MotionName,seconds:number){
   if(!Number.isFinite(seconds)||seconds<0)throw new Error('Motion seconds must be finite and nonnegative');
   const dog=name==='DogLapping'||name==='DogSniff';
   if(dog&&actor!=='sobaya')throw new Error('Dog motions are calibrated only for canonical Sobaya v3');
   if(!dog&&catalog[name as SkitMotion].actor!==actor)throw new Error(`Motion ${name} is not calibrated for ${actor}`);
   mixer.stopAllAction();
   rest.forEach(({o,p,q,s,weights})=>{o.position.copy(p);o.quaternion.copy(q);o.scale.copy(s);if(weights)(o as THREE.Mesh).morphTargetInfluences=weights.slice();});
   scene.updateWorldMatrix(true,true);
   if(dog){
    for(const bone of ['Hips','Head',...['Left','Right'].flatMap(s=>['Arm','ForeArm','Hand','UpLeg','Leg','Foot'].map(b=>s+b))])if(!scene.getObjectByName(bone))throw new Error(`Missing dog rig bone: ${bone}`);
    if(name==='DogSniff')applyDogSniff(scene,seconds);else applyDogLapping(scene,seconds);
   }else{
    const spec=catalog[name as SkitMotion],clip=clips.find(c=>c.name===spec.base);
    if(!clip)throw new Error(`Missing required base clip: ${spec.base}`);
    mixer.clipAction(clip).reset().play();mixer.setTime(seconds%clip.duration);
    applySkitMotion(scene,name as SkitMotion,seconds);
   }
   scene.updateMatrixWorld(true);
  },
  dispose(){mixer.stopAllAction();mixer.uncacheRoot(scene);},
 };
}
/** Apply to the actor's INNER group; put set placement/yaw on an OUTER group. */
export function motionPlacement(name:MotionName,seconds:number){
 if(name==='DogSniff'){const p=dogSniffOrbit(seconds);return {x:p.x,z:p.z,yaw:p.yaw};}
 return {x:0,z:0,yaw:0};
}
