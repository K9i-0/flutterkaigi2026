import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {createRequire} from 'node:module';
const root=path.resolve(import.meta.dirname,'..');
const require=createRequire(root+'/.local/vrm-validation/package.json');
const THREE=await import(require.resolve('three'));
const {GLTFLoader}=await import(path.join(path.dirname(require.resolve('three')),'../examples/jsm/loaders/GLTFLoader.js'));
const {validateBytes}=require('gltf-validator');
const folder=root+'/04_GAME_ASSETS/3d/hazard_adopted';
const manifest=JSON.parse(fs.readFileSync(folder+'/manifest.json'));
const sha=b=>createHash('sha256').update(b).digest('hex');
function json(b){return JSON.parse(b.subarray(20,20+b.readUInt32LE(12)).toString());}
async function load(b){
 const loader=new GLTFLoader();
 loader.register(()=>({name:'NoTextures',loadTexture:()=>Promise.resolve(new THREE.Texture())}));
 return loader.parseAsync(b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength),'');
}
const report=[];
for(const name of ['sobaya','fukuchan']){
 const row=manifest[name],buffer=fs.readFileSync(root+'/'+row.file);
 assert.equal(sha(buffer),row.sha256);
 const original=fs.readFileSync(root+'/'+row.source),old=fs.readFileSync(root+'/'+row.motionSource);
 assert.equal(sha(original),row.sourceSha256,'Approved v2 source changed');
 assert.equal(sha(old),row.motionSourceSha256,'V1 motion input changed');
 assert.equal(fs.realpathSync(root+`/21_SOBAYA_HAZARD_LAB/assets/models/${name}.glb`),fs.realpathSync(root+'/'+row.file));
 const format=await validateBytes(buffer,{maxIssues:100});
 assert.equal(format.issues.numErrors,0,JSON.stringify(format.issues));
 const data=json(buffer),sourceData=json(original);
 const game=await load(buffer),source=await load(original);
 const ids=new Set(game.animations.map(a=>a.name));
 for(const a of [...json(old).animations,...(sourceData.animations??[])])assert(ids.has(a.name),'Missing '+name+' '+a.name);
 const meshes=[];game.scene.traverse(o=>{if(o.isMesh)meshes.push(o);});
 const originalMeshes=[];source.scene.traverse(o=>{if(o.isMesh)originalMeshes.push(o);});
 const triangles=ms=>ms.reduce((sum,m)=>sum+(m.geometry.index?.count??m.geometry.attributes.position.count)/3,0);
 assert.equal(triangles(meshes),triangles(originalMeshes),'Approved geometry face count changed');
 game.scene.updateMatrixWorld(true);
 const rest=new THREE.Box3().setFromObject(game.scene,true);
 // V3 subdivision rounds the hair tips by 2.4mm relative to its 1.8m cage.
 assert(Math.abs(rest.max.y-rest.min.y-(name==='sobaya'?1.8:1.7))<(row.version===3?.003:.002), `${name}: height ${rest.max.y-rest.min.y}`);
 const socket=game.scene.getObjectByName(THREE.PropertyBinding.sanitizeNodeName(row.socket));
 const hand=game.scene.getObjectByName('RightHand');
 assert(socket&&hand,'Missing hand attachment');
 let maxWeightError=0;
 for(const mesh of meshes){
  assert(mesh.isSkinnedMesh);
  const w=mesh.geometry.attributes.skinWeight;
  for(let i=0;i<w.count;i++){
   let sum=0;for(let j=0;j<w.itemSize;j++)sum+=w.array[i*w.itemSize+j];
   maxWeightError=Math.max(maxWeightError,Math.abs(sum-1));
  }
 }
 assert(maxWeightError<.0001);
 if(name==='sobaya' && row.version===2){
  const black=data.materials.find(m=>m.name==='MaskBlackBacking');
  assert(black?.extensions?.KHR_materials_unlit);
  assert.deepEqual(black.pbrMetallicRoughness.baseColorFactor,[0,0,0,1]);
 }else if(name==='fukuchan'){
  const morphs=new Set(data.meshes.flatMap(m=>m.extras?.targetNames??[]));
  for(const m of ['SpeechOpen','SpeechNarrow','Smile','Blink','BlinkLeft','BlinkRight'])assert(morphs.has(m));
 }
 if(name==='sobaya' && row.version===3){
  const black=data.materials.find(m=>m.name==='Mask absolute black');
  assert(black, 'Missing black eye material');
  assert.deepEqual(black.pbrMetallicRoughness.baseColorFactor.slice(0,3),[0,0,0]);
  assert(game.scene.getObjectByName('SobayaV3Rig'));
 }
 const mixer=new THREE.AnimationMixer(game.scene),point=new THREE.Vector3();
 let maxAttachmentDistance=0,evaluatedVertices=0;
 for(const clip of game.animations){
  mixer.stopAllAction();meshes[0].skeleton.pose();mixer.clipAction(clip).reset().play();
  for(const phase of [0,.25,.5,.75,.999]){
   mixer.setTime(phase*clip.duration);game.scene.updateMatrixWorld(true);
   const distance=socket.getWorldPosition(new THREE.Vector3()).distanceTo(hand.getWorldPosition(new THREE.Vector3()));
   maxAttachmentDistance=Math.max(maxAttachmentDistance,distance);
   assert(distance<.16,clip.name+' detached socket '+distance);
   for(const mesh of meshes){
    mesh.skeleton.update();
    for(let i=0;i<mesh.geometry.attributes.position.count;i+=23){
     mesh.getVertexPosition(i,point).applyMatrix4(mesh.matrixWorld);
     assert(point.toArray().every(Number.isFinite)&&point.length()<4,clip.name+' exploded skin');
     evaluatedVertices++;
    }
   }
  }
 }
 report.push({name,version:row.version,glbSha256:sha(buffer),gltfErrors:0,gltfWarnings:format.issues.numWarnings,
  triangles:triangles(meshes),renderMeshes:meshes.length,bones:meshes[0].skeleton.bones.length,
  gameClips:ids.size,retainedV1Clips:json(old).animations.length,retainedV2Clips:(sourceData.animations??[]).length,
  heightM:rest.max.y-rest.min.y,maxWeightError,maxAttachmentDistance,evaluatedVertices,
  scope:'Adopted geometry count, expressions/black material, retained clip IDs, five skin samples per clip, socket follows hand. Visual grip quality requires game review.'});
}
fs.writeFileSync(folder+'/validation.json',JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report,null,2));
