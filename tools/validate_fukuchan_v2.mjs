import fs from 'node:fs';
import {createHash} from 'node:crypto';
import path from 'node:path';
import {createRequire} from 'node:module';
import assert from 'node:assert/strict';
const root=path.resolve(import.meta.dirname,'..');
const require=createRequire(root+'/.local/vrm-validation/package.json');
const THREE=await import(require.resolve('three'));
const {GLTFLoader}=await import(path.join(path.dirname(require.resolve('three')),'../examples/jsm/loaders/GLTFLoader.js'));
const {validateBytes}=require('gltf-validator');
const folder=root+'/04_GAME_ASSETS/3d/characters/fukuchan/v2_20260913';
const buffer=fs.readFileSync(folder+'/fukuchan_v2.glb');
const format=await validateBytes(buffer,{maxIssues:100});
assert.equal(format.issues.numErrors,0,JSON.stringify(format.issues));
const loader=new GLTFLoader();
loader.register(()=>({name:'NoTextures',loadTexture:()=>Promise.resolve(new THREE.Texture())}));
const gltf=await loader.parseAsync(buffer.buffer.slice(buffer.byteOffset,buffer.byteOffset+buffer.byteLength),'');
const expected=['Idle','Walk','Run','Aim','AimShotgun','ReloadHandgun','ReloadShotgun','Hit','Evade','Kick','Climb','Vault','Struggle','BreakFree','DanceStep','DanceDisco','DanceVictory','Greeting','Test_HeadTurn','Test_ArmRaise','Test_ElbowBend','Test_KneeBend'];
expected.push('Test_Grip');
assert.deepEqual(gltf.animations.map(a=>a.name).sort(),expected.sort());
for(const name of ['Body','Head','Hair','Eyelids'])assert(gltf.scene.getObjectByName(name),'Missing separate part '+name);
const meshes=[];gltf.scene.traverse(o=>{if(o.isMesh)meshes.push(o);});
const baselinePath=root+'/.local/fukuchan-v2-rig/before.glb';
let unchangedRestGeometry=null;
if(fs.existsSync(baselinePath)){
 const b=fs.readFileSync(baselinePath),old=await loader.parseAsync(b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength),'');
 function restPoints(scene){const points=new Set();scene.traverse(o=>{if(!o.isMesh)return;
  const p=o.geometry.attributes.position;for(let i=0;i<p.count;i++)points.add([p.getX(i),p.getY(i),p.getZ(i)].map(n=>n.toFixed(6)).join(','));
 });return [...points].sort();}
 assert.deepEqual(restPoints(gltf.scene),restPoints(old.scene),'Rig repair changed the rest mesh');
 unchangedRestGeometry=true;
}
gltf.scene.updateMatrixWorld(true);
const restBox=new THREE.Box3().setFromObject(gltf.scene,true);
assert(Math.abs(restBox.max.y-restBox.min.y-1.7)<.002,JSON.stringify(restBox));
let maxWeightError=0,triangles=0;
const morphs={};
for(const mesh of meshes){
 assert(mesh.isSkinnedMesh,'Not skinned '+mesh.name);
 const geometry=mesh.geometry,w=geometry.attributes.skinWeight;
 assert(w&&w.itemSize===4);
 for(let i=0;i<w.count;i++){let sum=0;for(let j=0;j<4;j++)sum+=w.array[i*4+j];maxWeightError=Math.max(maxWeightError,Math.abs(1-sum));}
 for(const attr of Object.values(geometry.attributes))for(const n of attr.array)assert(Number.isFinite(n));
 triangles+=(geometry.index?.count??geometry.attributes.position.count)/3;
 for(const [name,index] of Object.entries(mesh.morphTargetDictionary??{})){
  assert.equal(mesh.morphTargetInfluences[index],0,'Non-neutral default '+name);
  const values=geometry.morphAttributes.position[index].array;
  let displacement=0;for(let i=0;i<values.length;i+=3)displacement=Math.max(displacement,Math.hypot(values[i],values[i+1],values[i+2]));
  morphs[name]=Math.max(morphs[name]??0,displacement);
 }
}
assert(maxWeightError<.0001);
const fingerBones=[];
for(const side of ['L','R'])for(const digit of ['Thumb','Index','Middle','Ring','Little'])for(let joint=1;joint<=3;joint++){
 const name=`${digit}${joint}.${side}`,bone=gltf.scene.getObjectByName(THREE.PropertyBinding.sanitizeNodeName(name));assert(bone?.isBone,'Missing finger bone '+name);
 let influenced=0;for(const m of meshes){const index=m.skeleton.bones.indexOf(bone);if(index<0)continue;
  const ids=m.geometry.attributes.skinIndex,w=m.geometry.attributes.skinWeight;
  for(let i=0;i<ids.count*4;i++)if(ids.array[i]===index&&w.array[i]>.01)influenced++;
 }
 assert(influenced>5,'Unweighted finger '+name);fingerBones.push({name,influences:influenced});
}
for(const name of ['SpeechOpen','SpeechNarrow','Smile','Blink','BlinkLeft','BlinkRight'])assert(morphs[name]>.0001,'Empty morph '+name);
const mixer=new THREE.AnimationMixer(gltf.scene),position=new THREE.Vector3();
const samples=[];
for(const clip of gltf.animations){
 mixer.stopAllAction();meshes[0].skeleton.pose();
 mixer.clipAction(clip).reset().play();
 const box=new THREE.Box3();let evaluatedVertices=0;
 for(const t of [0,.25,.5,.75,.999]){
  mixer.setTime(t*clip.duration);gltf.scene.updateMatrixWorld(true);
  for(const m of meshes){
   m.skeleton.update();
   for(let i=0;i<m.geometry.attributes.position.count;i+=13){
    m.getVertexPosition(i,position).applyMatrix4(m.matrixWorld);
    assert(position.toArray().every(Number.isFinite),clip.name+' nonfinite skin');
    assert(position.length()<4,clip.name+' exploded skin '+position.toArray());
    box.expandByPoint(position);evaluatedVertices++;
   }
  }
 }
 samples.push({clip:clip.name,duration:clip.duration,evaluatedVertices,bounds:{min:box.min.toArray(),max:box.max.toArray()}});
}
const report={unchangedRestGeometry,glbSha256:createHash('sha256').update(buffer).digest('hex'),gltfErrors:format.issues.numErrors,gltfWarnings:format.issues.numWarnings,formatMessages:format.issues.messages,triangles,renderMeshes:meshes.length,bones:meshes[0].skeleton.bones.length,fingerBones,restHeightM:restBox.max.y-restBox.min.y,maxWeightError,morphMaxDisplacementsM:morphs,animations:samples,scope:'Format, separated parts, 170cm rest height, normalized skin weights, six nonempty neutral morphs, 23 clips sampled at five times. Naturalness and intersections require the accompanying rendered/UI review.'};
fs.writeFileSync(folder+'/validation.json',JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({...report,formatMessages:undefined,animations:report.animations.map(a=>a.clip)},null,2));
