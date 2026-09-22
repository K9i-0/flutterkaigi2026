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
export function applyDogLapping(scene:THREE.Object3D,t:number){
 scene.updateMatrixWorld(true);
 const space=scene.getWorldQuaternion(new THREE.Quaternion());
 const bind=new Map<string,THREE.Quaternion>();
 for(const name of ['LeftHand','RightHand','LeftFoot','RightFoot'])bind.set(name,space.clone().invert().multiply(scene.getObjectByName(name)!.getWorldQuaternion(new THREE.Quaternion())));
 const hips=scene.getObjectByName('Hips')!;
 const breathe=.008*Math.sin(t*5.5);
 hips.position.set(0,.55+breathe,-.62);
 setWorldRotation(hips,space.clone().multiply(new THREE.Quaternion().setFromAxisAngle(v(1,0,0),1.72)).multiply(space.clone().invert()).multiply(hips.getWorldQuaternion(new THREE.Quaternion())));
 scene.updateMatrixWorld(true);
 const head=scene.getObjectByName('Head')!;
 const delta=space.clone().multiply(new THREE.Quaternion().setFromAxisAngle(v(1,0,0),-.55+.07*Math.sin(t*16))).multiply(space.clone().invert());
 setWorldRotation(head,delta.multiply(head.getWorldQuaternion(new THREE.Quaternion())));
 for(const [side,sign] of [['Left',1],['Right',-1]] as const){
  limb(scene,side+'Arm',side+'ForeArm',side+'Hand',v(sign*.36,.075,.17),v(sign*.58,.34,-.05));
  limb(scene,side+'UpLeg',side+'Leg',side+'Foot',v(sign*.23,.13,-1.0),v(sign*.30,.04,-.55));
  const hand=scene.getObjectByName(side+'Hand')!;
  const palm=new THREE.Quaternion().setFromAxisAngle(v(0,0,1),sign*Math.PI/2).multiply(new THREE.Quaternion().setFromAxisAngle(v(1,0,0),-Math.PI/2));
  setWorldRotation(hand,space.clone().multiply(palm).multiply(bind.get(side+'Hand')!));
  setWorldRotation(scene.getObjectByName(side+'Foot')!,space.clone().multiply(new THREE.Quaternion().setFromAxisAngle(v(1,0,0),Math.PI)).multiply(bind.get(side+'Foot')!));
 }
 scene.traverse(o=>{if(o instanceof THREE.Mesh&&o.morphTargetDictionary&&o.morphTargetInfluences){const i=o.morphTargetDictionary.MugGrip;if(i!==undefined)o.morphTargetInfluences[i]=0;}});
 scene.updateMatrixWorld(true);
}
