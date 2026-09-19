import fs from 'node:fs';
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
const root=process.cwd(),base=pathToFileURL(root+'/.local/vrm-validation/node_modules/three/');
const T=await import(new URL('build/three.module.js',base));
const {GLTFLoader}=await import(new URL('examples/jsm/loaders/GLTFLoader.js',base));
globalThis.ProgressEvent=class {constructor(type,init){Object.assign(this,init);this.type=type;}};
const b=fs.readFileSync('04_GAME_ASSETS/3d/characters/takosan/rig_radial_v6_lined/takosan.glb'),len=b.readUInt32LE(12),json=JSON.parse(b.subarray(20,20+len));
json.buffers[0].uri='data:application/octet-stream;base64,'+b.subarray(28+len).toString('base64');
delete json.images;delete json.textures;delete json.materials;
for(const m of json.meshes)for(const p of m.primitives)delete p.material;
const source=fs.readFileSync('tools/takosan_float_motion.mjs','utf8').replace("'three'",JSON.stringify(new URL('build/three.module.js',base).href));
const {TakosanFloatMotion}=await import('data:text/javascript;base64,'+Buffer.from(source).toString('base64'));
for(const pattern of ['sway','wave','pulse','alternate','curl']){
 const gltf=await new GLTFLoader().parseAsync(JSON.stringify(json),''),pivot=new T.Group();pivot.add(gltf.scene);
 const motion=new TakosanFloatMotion(gltf.scene,pivot);assert.equal(motion.tentacleCount,18);
 const meshes=[];gltf.scene.traverse(o=>{if(o.isSkinnedMesh)meshes.push(o);});
 const sample=()=>{pivot.updateMatrixWorld(true);return meshes.flatMap(mesh=>{mesh.skeleton.update();const pos=mesh.geometry.attributes.position;return Array.from({length:pos.count},(_,i)=>mesh.applyBoneTransform(i,new T.Vector3().fromBufferAttribute(pos,i)));});};
 for(let i=0;i<180;i++)motion.update(1/60,0,'float',pattern,1,false);
 const before=sample(),bones=motion.bones.filter(b=>b.name.startsWith('Tentacle')).map(b=>b.bone.quaternion.clone());
 for(let i=0;i<45;i++)motion.update(1/60,0,'float',pattern,1,false);
 const after=sample(),delta=Math.max(...after.map((v,i)=>v.distanceTo(before[i])));
 assert(delta>.01,pattern+' must deform actual mesh');
 assert(motion.bones.filter(b=>b.name.startsWith('Tentacle')).every((b,i)=>b.bone.quaternion.angleTo(bones[i])>.001));
 assert(after.every(v=>Number.isFinite(v.length())));assert.equal(pivot.rotation.x,0);
 console.log(pattern+': 18 joints moving; max vertex displacement '+delta.toFixed(3)+' m');
}
