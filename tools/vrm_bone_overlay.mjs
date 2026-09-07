import * as THREE from 'three';
// Project raw deformation joints, not the normalized VRM control skeleton.
export function createBoneOverlay(canvas){
 const ctx=canvas.getContext('2d');
 const chains=[['hips','spine','chest','upperChest','neck','head']];
 for(const side of ['left','right']){chains.push([side+'Shoulder',side+'UpperArm',side+'LowerArm',side+'Hand']);chains.push(['hips',side+'UpperLeg',side+'LowerLeg',side+'Foot',side+'Toes']);}
 const names={leftUpperArm:'左肩関節',rightUpperArm:'右肩関節',leftLowerArm:'左肘',rightLowerArm:'右肘',leftHand:'左手首',rightHand:'右手首'};
 function project(v,camera){v.project(camera);return [(v.x+1)*canvas.width/2,(1-v.y)*canvas.height/2];}
 return function draw(actors,camera,enabled,axes){
  if(canvas.width!==innerWidth||canvas.height!==innerHeight){canvas.width=innerWidth;canvas.height=innerHeight;}
  ctx.clearRect(0,0,canvas.width,canvas.height);if(!enabled)return;
  for(const actor of actors){if(!actor.vrm.scene.visible)continue;
   const human=actor.vrm.humanoid;const get=role=>human.getRawBoneNode(role);
   const color=role=>role.startsWith('left')?'#63f4ec':role.startsWith('right')?'#ff81cf':'#ffe27a';
   const all=new Set();const segments=chains.filter(x=>x.length).map(c=>c.filter(get));
   const chest=['upperChest','chest','spine'].find(get);
   for(const side of ['left','right'])segments.push([chest,side+'Shoulder'].filter(get));
   for(const chain of segments){for(let i=0;i<chain.length;i++){const role=chain[i];all.add(role);if(!i)continue;const a=project(get(chain[i-1]).getWorldPosition(new THREE.Vector3()),camera),b=project(get(role).getWorldPosition(new THREE.Vector3()),camera);ctx.strokeStyle=color(role);ctx.lineWidth=3;ctx.beginPath();ctx.moveTo(...a);ctx.lineTo(...b);ctx.stroke();}}
   for(const role of all){const joint=get(role),world=joint.getWorldPosition(new THREE.Vector3());const p=project(world.clone(),camera);ctx.fillStyle=color(role);ctx.beginPath();ctx.arc(...p,role.includes('UpperArm')?6:4,0,Math.PI*2);ctx.fill();
    if(names[role]){ctx.font='12px system-ui';ctx.lineWidth=3;ctx.strokeStyle='#102029';ctx.strokeText(names[role],p[0]+9,p[1]-7);ctx.fillText(names[role],p[0]+9,p[1]-7);}
    if(axes&&names[role]){const q=joint.getWorldQuaternion(new THREE.Quaternion());for(const [axis,c]of [[new THREE.Vector3(.09,0,0),'#ff5555'],[new THREE.Vector3(0,.09,0),'#66ff77'],[new THREE.Vector3(0,0,.09),'#669dff']]){const end=project(axis.applyQuaternion(q).add(world),camera);ctx.strokeStyle=c;ctx.lineWidth=2;ctx.beginPath();ctx.moveTo(...p);ctx.lineTo(...end);ctx.stroke();}}
   }
  }
 };
}
