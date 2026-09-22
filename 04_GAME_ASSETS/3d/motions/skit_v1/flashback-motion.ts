import * as THREE from 'three';
const v=(x:number,y:number,z:number)=>new THREE.Vector3(x,y,z);
function setWorldRotation(o:THREE.Object3D,q:THREE.Quaternion){
 o.quaternion.copy(o.parent?o.parent.getWorldQuaternion(new THREE.Quaternion()).invert().multiply(q):q);o.updateMatrixWorld(true);
}
function turnToward(bone:THREE.Object3D,child:THREE.Object3D,point:THREE.Vector3){
 const origin=bone.getWorldPosition(new THREE.Vector3());
 const before=child.getWorldPosition(new THREE.Vector3()).sub(origin).normalize();
 const after=point.clone().sub(origin).normalize();
 setWorldRotation(bone,new THREE.Quaternion().setFromUnitVectors(before,after).multiply(bone.getWorldQuaternion(new THREE.Quaternion())));
}
/** Analytic two-link limb pose. Lengths come from the actor, poles keep elbows/knees from flipping. */
function limb(scene:THREE.Object3D,aName:string,bName:string,cName:string,goalLocal:THREE.Vector3,poleLocal:THREE.Vector3){
 const a=scene.getObjectByName(aName)!,b=scene.getObjectByName(bName)!,c=scene.getObjectByName(cName)!;
 const A=a.getWorldPosition(new THREE.Vector3()),B=b.getWorldPosition(new THREE.Vector3()),C=c.getWorldPosition(new THREE.Vector3());
 const l1=A.distanceTo(B),l2=B.distanceTo(C),goal=scene.localToWorld(goalLocal.clone());
 const axis=goal.clone().sub(A),distance=THREE.MathUtils.clamp(axis.length(),Math.abs(l1-l2)+.001,l1+l2-.001);axis.normalize();
 const side=scene.localToWorld(poleLocal.clone()).sub(A);side.addScaledVector(axis,-side.dot(axis)).normalize();
 const along=(l1*l1-l2*l2+distance*distance)/(2*distance);
 const joint=A.clone().addScaledVector(axis,along).addScaledVector(side,Math.sqrt(Math.max(0,l1*l1-along*along)));
 turnToward(a,b,joint);scene.updateMatrixWorld(true);
 turnToward(b,c,A.clone().addScaledVector(axis,distance));scene.updateMatrixWorld(true);
}
/** Evaluate from bind/rest pose, not on top of a walking animation. */
type DogPoseOptions = {sniff?:boolean;paws?:Record<string,THREE.Vector3>};
export function applyDogLapping(scene:THREE.Object3D,t:number,options:DogPoseOptions={}){
 scene.updateWorldMatrix(true,true);
 const space=scene.getWorldQuaternion(new THREE.Quaternion());
 const bind=new Map<string,THREE.Quaternion>();
 for(const name of ['LeftHand','RightHand','LeftFoot','RightFoot'])bind.set(name,space.clone().invert().multiply(scene.getObjectByName(name)!.getWorldQuaternion(new THREE.Quaternion())));
 const hips=scene.getObjectByName('Hips')!;
 const breathe=.008*Math.sin(t*5.5);
 hips.position.set(0,.55+breathe,-.62);
 setWorldRotation(hips,space.clone().multiply(new THREE.Quaternion().setFromAxisAngle(v(1,0,0),1.72)).multiply(space.clone().invert()).multiply(hips.getWorldQuaternion(new THREE.Quaternion())));
 scene.updateMatrixWorld(true);
 const head=scene.getObjectByName('Head')!;
 const delta=space.clone().multiply(new THREE.Quaternion().setFromAxisAngle(v(1,0,0),options.sniff?-.68+.035*Math.sin(t*23):-.55+.07*Math.sin(t*16))).multiply(space.clone().invert());
 setWorldRotation(head,delta.multiply(head.getWorldQuaternion(new THREE.Quaternion())));
 for(const [side,sign] of [['Left',1],['Right',-1]] as const){
  limb(scene,side+'Arm',side+'ForeArm',side+'Hand',options.paws?.[side+'Hand']??v(sign*.36,.075,.17),v(sign*.58,.34,-.05));
  limb(scene,side+'UpLeg',side+'Leg',side+'Foot',options.paws?.[side+'Foot']??v(sign*.23,.13,-1.0),v(sign*.30,.04,-.55));
  const hand=scene.getObjectByName(side+'Hand')!;
  const palm=new THREE.Quaternion().setFromAxisAngle(v(0,0,1),sign*Math.PI/2).multiply(new THREE.Quaternion().setFromAxisAngle(v(1,0,0),-Math.PI/2));
  setWorldRotation(hand,space.clone().multiply(palm).multiply(bind.get(side+'Hand')!));
  setWorldRotation(scene.getObjectByName(side+'Foot')!,space.clone().multiply(new THREE.Quaternion().setFromAxisAngle(v(1,0,0),Math.PI)).multiply(bind.get(side+'Foot')!));
 }
 scene.traverse(o=>{if(o instanceof THREE.Mesh&&o.morphTargetDictionary&&o.morphTargetInfluences){const i=o.morphTargetDictionary.MugGrip;if(i!==undefined)o.morphTargetInfluences[i]=0;}});
 scene.updateMatrixWorld(true);
}


// Three arcs and three pauses: inspect the same fixed mug from different sides.
// All times below are frames at 24 fps; absolute evaluation supports arbitrary seeking.
const orbitKeys=[{f:0,a:0},{f:16,a:0},{f:52,a:1.9},{f:68,a:1.9},{f:104,a:3.9},{f:120,a:3.9},{f:156,a:5.75},{f:172,a:5.75}];
const smooth=(x:number)=>{x=THREE.MathUtils.clamp(x,0,1);return x*x*(3-2*x);};
const mug={x:.035,z:.17};
export function dogSniffOrbit(t:number){
 const frame=Math.max(0,t*24);let angle=orbitKeys[orbitKeys.length-1].a;
 let moving=false,start=0,end=0;
 for(let i=1;i<orbitKeys.length;i++)if(frame<=orbitKeys[i].f){
  const a=orbitKeys[i-1],b=orbitKeys[i];angle=THREE.MathUtils.lerp(a.a,b.a,smooth((frame-a.f)/(b.f-a.f)));
  moving=a.a!==b.a;start=a.f;end=b.f;break;
 }
 // Keep the head facing inward. A small retreat makes sniffing distinct from licking.
 const c=Math.cos(angle),s=Math.sin(angle);
 return {x:mug.x-(.035*c+.25*s),z:mug.z-(-.035*s+.25*c),yaw:angle,moving,start,end,frame};
}
function pawAtAngle(base:THREE.Vector3,frame:number){
 const p=dogSniffOrbit(frame/24),c=Math.cos(p.yaw),s=Math.sin(p.yaw);
 return v(p.x+base.x*c+base.z*s,base.y,p.z-base.x*s+base.z*c);
}
export function dogSniffPaws(t:number){
 const p=dogSniffOrbit(t),paws:Record<string,THREE.Vector3>={};
 for(const [name,base,offset] of [
  ['LeftHand',v(.36,.075,.17),0],['RightHand',v(-.36,.075,.17),5],
  ['LeftFoot',v(.23,.13,-1),5],['RightFoot',v(-.23,.13,-1),0],
 ] as const){
  if(!p.moving){paws[name]=base;continue;}
  const stride=10,elapsed=p.frame-p.start,cycle=Math.floor((elapsed+offset)/stride),phase=(elapsed+offset)/stride-cycle;
  const touchdown=p.start+cycle*stride-offset;
  const first=THREE.MathUtils.clamp(touchdown+2.5,p.start,p.end);
  const second=THREE.MathUtils.clamp(touchdown+stride+2.5,p.start,p.end);
  const a=pawAtAngle(base,first),b=pawAtAngle(base,second);
  const swing=phase>.5?smooth((phase-.5)*2):0;
  const world=a.lerp(b,swing);
  const lift=Math.sin(Math.PI*swing)*(name.endsWith('Hand')?.065:.055)*smooth(elapsed/3)*smooth((p.end-p.frame)/3);
  const dx=world.x-p.x,dz=world.z-p.z,c=Math.cos(p.yaw),s=Math.sin(p.yaw);
  paws[name]=v(dx*c-dz*s,world.y+lift,dx*s+dz*c);
 }
 return paws;
}
export function applyDogSniff(scene:THREE.Object3D,t:number){
 applyDogLapping(scene,t,{sniff:true,paws:dogSniffPaws(t)});
}
