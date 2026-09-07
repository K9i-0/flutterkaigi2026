import fs from 'node:fs';import path from 'node:path';import {createRequire} from 'node:module';
const root=path.resolve(import.meta.dirname,'..');const require=createRequire(root+'/.local/vrm-validation/package.json');
const THREE=await import(require.resolve('three'));
const {GLTFLoader}=await import(path.join(path.dirname(require.resolve('three')),'../examples/jsm/loaders/GLTFLoader.js'));
const {validateBytes}=require('gltf-validator');
async function load(file){const b=fs.readFileSync(root+'/'+file);const l=new GLTFLoader();l.register(()=>({name:'NoTextures',loadTexture:()=>Promise.resolve(new THREE.Texture())}));return l.parseAsync(b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength),'');}
const report=[];
for(const name of ['sobaya','fukuchan']){
 const file=`04_GAME_ASSETS/3d/hazard_adopted/${name}.glb`;const errors=await validateBytes(fs.readFileSync(root+'/'+file),{maxIssues:100});if(errors.issues.numErrors)throw Error(JSON.stringify(errors.issues));
 const game=await load(file);const old=await load(`04_GAME_ASSETS/3d/motion_library/${name}/${name}.glb`);
 for(const a of old.animations)if(!game.animations.some(b=>b.name===a.name))throw Error('Lost game action '+a.name);
 const bones=JSON.parse(fs.readFileSync(root+`/04_GAME_ASSETS/vrm/characters/${name}.manifest.json`)).humanoidBones;
 let maxPositionError=0,maxRotationError=0,samples=0;
 for(const suffix of ['motions','run_candidates']){
  const source=await load(`.local/vrm-validation/${name}_${suffix}.glb`);
  for(const a of source.animations){
   const target=game.animations.find(b=>b.name==='Adopted_'+a.name);if(!target)throw Error('Missing adopted '+a.name);
   const m=new THREE.AnimationMixer(game.scene),n=new THREE.AnimationMixer(source.scene);m.clipAction(target).play();n.clipAction(a).play();
   for(let t=0;t<a.duration;t+=1/30){m.setTime(t);n.setTime(t);game.scene.updateMatrixWorld(true);source.scene.updateMatrixWorld(true);samples++;
    for(const bone of Object.values(bones)){
     const id=THREE.PropertyBinding.sanitizeNodeName(bone),x=game.scene.getObjectByName(id),y=source.scene.getObjectByName(id);
     maxPositionError=Math.max(maxPositionError,x.getWorldPosition(new THREE.Vector3()).distanceTo(y.getWorldPosition(new THREE.Vector3())));
     maxRotationError=Math.max(maxRotationError,x.getWorldQuaternion(new THREE.Quaternion()).angleTo(y.getWorldQuaternion(new THREE.Quaternion())));
    }
   }m.stopAllAction();n.stopAllAction();
  }
 }
 if(maxPositionError>.001||maxRotationError>.005)throw Error(JSON.stringify({name,maxPositionError,maxRotationError}));
 report.push({name,gltfErrors:0,gameClips:game.animations.length,retainedSourceClips:old.animations.length,samples,maxPositionError,maxRotationError});
}
fs.writeFileSync(root+'/04_GAME_ASSETS/3d/hazard_adopted/validation.json',JSON.stringify(report,null,2)+'\n');console.log(report);
