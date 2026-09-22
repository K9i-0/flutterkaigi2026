/** Frame-addressable acting overlays for the canonical Sobaya v3 / Yametaro rigs.
 * Original procedural motions; evaluate after sampling the listed base clip.
 * Units: meters / radians. No clock, random numbers, or accumulated transforms.
 */
import * as THREE from 'three';
export type SkitMotion = 'Explain'|'InspectMug'|'SketchMug'|'SniffMug'|'ListenFoam'|'EmptyHands'|'Conjure'|'ProudToast'|'Tsukkomi'|'Wish'|'DoubleTake'|'Listen';
export const catalog: Record<SkitMotion,{base:string;actor:string;duration:number}> = {
 Explain:{base:'Hybrid_Idle_Talking',actor:'sobaya',duration:5},
 InspectMug:{base:'CharacterSheet_MugStand',actor:'sobaya',duration:4},
 SketchMug:{base:'CharacterSheet_MugStand',actor:'sobaya',duration:4},
 SniffMug:{base:'CharacterSheet_MugStand',actor:'sobaya',duration:3},
 ListenFoam:{base:'CharacterSheet_MugStand',actor:'sobaya',duration:3},
 EmptyHands:{base:'Hybrid_Idle_Talking',actor:'sobaya',duration:4},
 Conjure:{base:'Hybrid_Idle_Talking',actor:'sobaya',duration:6},
 ProudToast:{base:'CharacterSheet_MugStand',actor:'sobaya',duration:4},
 Tsukkomi:{base:'Talk',actor:'yametaro',duration:4},
 Wish:{base:'Talk',actor:'yametaro',duration:4},
 DoubleTake:{base:'Idle',actor:'yametaro',duration:3},
 Listen:{base:'Idle',actor:'yametaro',duration:4},
};
const V=(x:number,y:number,z:number)=>new THREE.Vector3(x,y,z);
const smooth=(x:number)=>{x=THREE.MathUtils.clamp(x,0,1);return x*x*(3-2*x);};
const pulse=(t:number,a:number,b:number,c:number,d:number)=>smooth((t-a)/(b-a))*(1-smooth((t-c)/(d-c)));
function rotate(scene:THREE.Object3D,name:string,x=0,y=0,z=0){const b=scene.getObjectByName(name);if(b)b.quaternion.multiply(new THREE.Quaternion().setFromEuler(new THREE.Euler(x,y,z)));}
function wristTilt(scene:THREE.Object3D,side:string,x:number,z:number){
 const hand=scene.getObjectByName(side+'Hand');if(!hand?.parent)return;
 scene.updateMatrixWorld(true);
 const space=scene.getWorldQuaternion(new THREE.Quaternion());
 const delta=space.clone().multiply(new THREE.Quaternion().setFromEuler(new THREE.Euler(x,0,z))).multiply(space.clone().invert());
 const world=delta.multiply(hand.getWorldQuaternion(new THREE.Quaternion()));
 hand.quaternion.copy(hand.parent.getWorldQuaternion(new THREE.Quaternion()).invert().multiply(world));
 scene.updateMatrixWorld(true);
}
/** CCD uses each model's existing joint lengths and sampled bend, never copies another rig's rotations. */
function reach(scene:THREE.Object3D,side:'Right'|'Left',target:THREE.Vector3,weight=1){
 const hand=scene.getObjectByName(side+'Hand');
 if(!hand)return;
 scene.updateMatrixWorld(true);
 const start=hand.getWorldPosition(new THREE.Vector3());
 const goal=start.clone().lerp(scene.localToWorld(target.clone()),weight);
 const wristOrientation=hand.getWorldQuaternion(new THREE.Quaternion());
 for(let step=0;step<10;step++)for(const key of [side+'ForeArm',side+'Arm']){
  const joint=scene.getObjectByName(key);if(!joint?.parent)continue;
  const jp=joint.getWorldPosition(new THREE.Vector3());
  const toHand=hand.getWorldPosition(new THREE.Vector3()).sub(jp).normalize();
  const toGoal=goal.clone().sub(jp).normalize();
  const delta=new THREE.Quaternion().setFromUnitVectors(toHand,toGoal);
  const next=delta.multiply(joint.getWorldQuaternion(new THREE.Quaternion()));
  joint.quaternion.copy(joint.parent.getWorldQuaternion(new THREE.Quaternion()).invert().multiply(next));
  scene.updateMatrixWorld(true);
 }
 // Keep the sampled wrist's world orientation, so mugs remain upright.
 if(hand.parent)hand.quaternion.copy(hand.parent.getWorldQuaternion(new THREE.Quaternion()).invert().multiply(wristOrientation));
 scene.updateMatrixWorld(true);
}
export function applySkitMotion(scene:THREE.Object3D,motion:SkitMotion,t:number){
 const settle=smooth(t/.45);
 switch(motion){
 case 'Explain':
  rotate(scene,'Head',.025*Math.sin(t*2.6),.12*Math.sin(t*.9),0);
  rotate(scene,'Spine2',0,.045*Math.sin(t*1.3),0);
  reach(scene,'Left',V(.36,1.2+.035*Math.sin(t*3),.32),.55*settle);
  break;
 case 'InspectMug':
  rotate(scene,'Head',.15,.16*Math.sin(t*1.8),-.04);
  reach(scene,'Right',V(-.22,1.37+.035*Math.sin(t*2),.34),settle);
  break;
 case 'SketchMug':
  rotate(scene,'Head',.28,-.1+.035*Math.sin(t*4),0);
  reach(scene,'Left',V(.12,1.09,.32),settle);
  reach(scene,'Right',V(-.04+.035*Math.sin(t*9),1.17+.006*Math.cos(t*9),.43),settle);
  wristTilt(scene,'Left',-1.15*settle,-.8*settle);
  break;
 case 'SniffMug':{
  const lift=pulse(t,0,.65,1.9,2.8);
  rotate(scene,'Head',.1+.10*lift,-.15*lift,-.05*lift);
  rotate(scene,'Spine2',-.018*Math.sin(t*7)*lift);
  reach(scene,'Right',V(-.15,1.45,.35),lift);
  break;}
 case 'ListenFoam':
  rotate(scene,'Head',.02,-.25*settle,-.2*settle);
  reach(scene,'Right',V(-.31,1.49,.22),settle);
  break;
 case 'EmptyHands':
  rotate(scene,'Head',.22*settle,.35*Math.sin(t*2.1)*settle,0);
  rotate(scene,'Spine2',.04*settle);
  reach(scene,'Right',V(-.29,1.13,.39),settle);
  reach(scene,'Left',V(.29,1.13,.39),settle);
  break;
 case 'Conjure':{
  const charge=smooth(t/1.8);
  rotate(scene,'Head',.22*charge,0,0);
  rotate(scene,'Spine2',.09*charge,0,.018*Math.sin(t*19)*charge);
  reach(scene,'Right',V(-.22,1.08,.44),charge);
  reach(scene,'Left',V(.22,1.08,.44),charge);
  break;}
 case 'ProudToast':
  rotate(scene,'Head',-.08*settle,.13*settle,0);
  reach(scene,'Right',V(-.30,1.44,.30),settle);
  reach(scene,'Left',V(.38,1.19,.23),settle*.65);
  break;
 case 'Tsukkomi':{
  const accent=pulse(t,.75,1.05,2.2,2.65);
  rotate(scene,'Head',-.025,-.22*settle,.1*Math.sin(t*5)*settle);
  rotate(scene,'Spine2',.08*accent,0,-.07*accent);
  reach(scene,'Right',V(-.27,.46,.23),Math.max(.45*settle,accent));
  reach(scene,'Left',V(.27,.44,.19),.8*accent);
  break;}
 case 'Wish':
  rotate(scene,'Head',-.07*settle,-.18*settle,.055*Math.sin(t*2));
  reach(scene,'Right',V(-.11,.47,.23),settle);
  reach(scene,'Left',V(.13,.47,.23),settle);
  break;
 case 'DoubleTake':
  rotate(scene,'Head',-.055,-.3*Math.sin(Math.min(t,1.2)*3),-.1*Math.sin(Math.min(t,1.5)*4));
  reach(scene,'Right',V(-.28,.43,.16),.7*settle);
  break;
 case 'Listen':
  rotate(scene,'Head',.035*Math.sin(t*2),-.12,.025*Math.sin(t));
  break;
 }
 scene.updateMatrixWorld(true);
}
