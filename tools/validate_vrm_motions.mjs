import fs from 'node:fs';import path from 'node:path';import {createRequire} from 'node:module';
const root=path.resolve(import.meta.dirname,'..');const require=createRequire(root+'/.local/vrm-validation/package.json');
const {default:Ajv}=await import(require.resolve('ajv/dist/2020.js'));const {validateBytes}=require('gltf-validator');
const THREE=await import(require.resolve('three'));
const {GLTFLoader}=await import(path.join(path.dirname(require.resolve('three')),'../examples/jsm/loaders/GLTFLoader.js'));
const {VRMLoaderPlugin}=await import(path.join(path.dirname(require.resolve('@pixiv/three-vrm')),'three-vrm.module.js'));
const {VRMAnimationLoaderPlugin,createVRMAnimationClip}=await import(path.join(path.dirname(require.resolve('@pixiv/three-vrm-animation')),'three-vrm-animation.module.js'));
const ajv=new Ajv({strict:false,allErrors:true});for(const dir of ['.local/vrm-spec','.local/vrm-specification/specification/VRMC_vrm_animation-1.0/schema'])for(const f of fs.readdirSync(root+'/'+dir).filter(x=>x.endsWith('.schema.json'))){const s=JSON.parse(fs.readFileSync(root+'/'+dir+'/'+f));delete s.$schema;if(!ajv.getSchema(f))ajv.addSchema(s,f);}
const schema=ajv.getSchema('VRMC_vrm_animation.schema.json');
function buffer(file){const b=fs.readFileSync(root+'/'+file);return b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength)}
const catalog=JSON.parse(fs.readFileSync(root+'/04_GAME_ASSETS/vrm/motions/catalog.json'));const results=[];
for(const name of ['sobaya','fukuchan']){
 const loader=new GLTFLoader();loader.register(p=>new VRMLoaderPlugin(p));loader.register(()=>({name:'TestTextures',loadTexture:()=>Promise.resolve(new THREE.Texture())}));
 const {userData:{vrm}}=await loader.parseAsync(buffer(`04_GAME_ASSETS/vrm/characters/${name}.vrm`),'');
 const source=await new GLTFLoader().parseAsync(buffer(`.local/vrm-validation/${name}_motions.glb`),'');
 const manifest=JSON.parse(fs.readFileSync(root+`/04_GAME_ASSETS/vrm/characters/${name}.manifest.json`));
 for(const entry of catalog.characters[name]){
  const b=buffer('04_GAME_ASSETS/vrm/motions/'+entry.file);const json=JSON.parse(Buffer.from(b).subarray(20,20+new DataView(b).getUint32(12,true)));
  if(!schema(json.extensions.VRMC_vrm_animation))throw Error(JSON.stringify(schema.errors));
  const report=await validateBytes(new Uint8Array(b),{maxIssues:1000});if(report.issues.numErrors)throw Error(JSON.stringify(report.issues));
  const l=new GLTFLoader();l.register(p=>new VRMAnimationLoaderPlugin(p));const data=await l.parseAsync(b,'');const clip=createVRMAnimationClip(data.userData.vrmAnimations[0],vrm);
  const baselinePath='.local/dance_deformation/baseline/motions/'+entry.file;
  let unchangedLocomotion=null;
  if(!entry.sourceClip.startsWith('Dance')&&fs.existsSync(root+'/'+baselinePath)){
   const baseline=await l.parseAsync(buffer(baselinePath),'');const before=createVRMAnimationClip(baseline.userData.vrmAnimations[0],vrm);
   unchangedLocomotion=before.tracks.length===clip.tracks.length&&before.tracks.every((t,i)=>t.name===clip.tracks[i].name&&['times','values'].every(k=>t[k].length===clip.tracks[i][k].length&&t[k].every((v,j)=>Math.abs(v-clip.tracks[i][k][j])<2e-5)));
   if(!unchangedLocomotion)throw Error('Non-dance performance changed: '+entry.file);
  }
  vrm.humanoid.resetNormalizedPose();const mixer=new THREE.AnimationMixer(vrm.scene);mixer.clipAction(clip).play();
  const sm=new THREE.AnimationMixer(source.scene);sm.clipAction(source.animations.find(a=>a.name===entry.name)).play();let maxPositionError=0,maxRotationError=0;
  const samples=Math.ceil(clip.duration*30)+1;
  for(let sample=0;sample<samples;sample++){const phase=sample/(samples-1)*.999999;
   mixer.setTime(clip.duration*phase);vrm.update(0);vrm.scene.updateMatrixWorld(true);sm.setTime(clip.duration*phase);source.scene.updateMatrixWorld(true);
   for(const [role,bone]of Object.entries(manifest.humanoidBones)){
    const a=vrm.humanoid.getRawBoneNode(role),s=source.scene.getObjectByName(THREE.PropertyBinding.sanitizeNodeName(bone));
    const p=a.getWorldPosition(new THREE.Vector3()),q=a.getWorldQuaternion(new THREE.Quaternion());
    if(![...p.toArray(),...q.toArray()].every(Number.isFinite))throw Error('Nonfinite '+role);
    maxPositionError=Math.max(maxPositionError,p.distanceTo(s.getWorldPosition(new THREE.Vector3())));
    maxRotationError=Math.max(maxRotationError,q.angleTo(s.getWorldQuaternion(new THREE.Quaternion())));
   }
  }
  mixer.stopAllAction();sm.stopAllAction();
  results.push({character:name,motion:entry.sourceClip,duration:clip.duration,sampledPoses:samples,unchangedLocomotion,tracks:clip.tracks.length,gltfErrors:report.issues.numErrors,maxPositionError,maxRotationError});
 }
}
const passed=results.every(r=>r.maxPositionError<.025&&r.maxRotationError<.025);
fs.writeFileSync(root+'/04_GAME_ASSETS/vrm/motions/validation.json',JSON.stringify({passed,sampleRateHz:30,results},null,2)+'\n');console.log(JSON.stringify(results,null,2));
if(!passed)throw Error('VRMA differs from baked performance');
