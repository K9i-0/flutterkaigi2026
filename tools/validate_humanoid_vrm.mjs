// Dependencies installed under .local/vrm-validation; see VRM characters README.
import fs from 'node:fs';
import {execFileSync} from 'node:child_process';
import path from 'node:path';
import {createRequire} from 'node:module';
const root=path.resolve(import.meta.dirname,'..');
const require=createRequire(root+'/.local/vrm-validation/package.json');
const {default:Ajv}=await import(require.resolve('ajv/dist/2020.js'));
const {validateBytes}=require('gltf-validator');
const {Texture,Vector3}=await import(require.resolve('three'));
const {GLTFLoader}=await import(path.join(path.dirname(require.resolve('three')),'../examples/jsm/loaders/GLTFLoader.js'));
const {VRMLoaderPlugin}=await import(path.join(path.dirname(require.resolve('@pixiv/three-vrm')),'three-vrm.module.js'));
const ajv=new Ajv({strict:false,allErrors:true});
for(const dir of ['.local/vrm-spec','.local/vrm-specification/specification/VRMC_vrm-1.0/schema']) {
 for(const file of fs.readdirSync(root+'/'+dir).filter(x=>x.endsWith('.schema.json'))){
  const schema=JSON.parse(fs.readFileSync(root+'/'+dir+'/'+file));delete schema.$schema;
  if(!ajv.getSchema(file))ajv.addSchema(schema,file);
 }
}
const validate=ajv.getSchema('VRMC_vrm.schema.json');
const results=[];
for(const name of ['sobaya','fukuchan']){
 const bytes=fs.readFileSync(root+`/04_GAME_ASSETS/vrm/characters/${name}.vrm`);
 const json=JSON.parse(bytes.subarray(20,20+bytes.readUInt32LE(12)));
 if(!validate(json.extensions.VRMC_vrm))throw Error(JSON.stringify(validate.errors));
 const bones=json.extensions.VRMC_vrm.humanoid.humanBones;
 const parent=new Map();json.nodes.forEach((n,i)=>(n.children??[]).forEach(c=>parent.set(c,i)));
 const mapped=new Set(Object.values(bones).map(b=>b.node));if(mapped.size!==Object.keys(bones).length)throw Error('duplicate bone');
 const roles={spine:'hips',chest:'spine',upperChest:'chest',neck:'upperChest',head:'neck'};
 for(const side of ['left','right']){
  Object.assign(roles,{[side+'Shoulder']:'upperChest',[side+'UpperArm']:side+'Shoulder',[side+'LowerArm']:side+'UpperArm',[side+'Hand']:side+'LowerArm',[side+'UpperLeg']:'hips',[side+'LowerLeg']:side+'UpperLeg',[side+'Foot']:side+'LowerLeg',[side+'Toes']:side+'Foot'});
  for(const f of ['Index','Middle','Ring','Little','Thumb']){
   const segments=f==='Thumb'?['Metacarpal','Proximal','Distal']:['Proximal','Intermediate','Distal'];
   segments.forEach((s,i)=>roles[side+f+s]=i?side+f+segments[i-1]:side+'Hand');
  }
 }
 for(const [role,b] of Object.entries(bones)){
  let expected=roles[role];while(expected&&!bones[expected])expected=roles[expected];
  let ancestor=parent.get(b.node);while(ancestor!==undefined&&!mapped.has(ancestor))ancestor=parent.get(ancestor);
  if(expected&&ancestor!==bones[expected].node)throw Error('Wrong parent '+role);
  let node=b.node;while(node!==undefined){if((json.nodes[node].scale??[1,1,1]).some(x=>x<=0))throw Error('nonpositive scale');node=parent.get(node);}
 }
 const gltfReport=await validateBytes(new Uint8Array(bytes),{uri:name+'.vrm',maxIssues:10000});
 if(gltfReport.issues.numErrors)throw Error(JSON.stringify(gltfReport.issues));
 // Geometry / skeleton loading test. Browser preview separately verifies actual textures.
 const loader=new GLTFLoader();loader.register(parser=>new VRMLoaderPlugin(parser));
 loader.register(()=>({name:'ValidationTextureStub',loadTexture:()=>Promise.resolve(new Texture())}));
 const asset=await loader.parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'');
 const vrm=asset.userData.vrm;if(!vrm)throw Error('VRM loader did not instantiate');
 for(const role of Object.keys(bones))if(!vrm.humanoid.getRawBoneNode(role))throw Error('missing '+role);
 const head=vrm.humanoid.getNormalizedBoneNode('head');head.rotation.y=.2;vrm.update(1/30);vrm.scene.updateMatrixWorld(true);
 vrm.scene.traverse(n=>{if(n.matrixWorld.elements.some(x=>!Number.isFinite(x)))throw Error('nonfinite matrix');});
 if(name==='fukuchan'){
  vrm.expressionManager.setValue('aa',.7);vrm.update(1/30);
  let active=false;vrm.scene.traverse(n=>{if(n.morphTargetInfluences?.some(v=>v>.6))active=true});if(!active)throw Error('speech bind failed');
 }
 results.push({name,schema:true,hierarchy:true,positiveScale:true,vrmLoader:true,normalizedHeadRotation:true,expressions:(vrm.expressionManager?.expressions??[]).map(e=>e.expressionName),humanBones:Object.keys(bones).length,gltfErrors:gltfReport.issues.numErrors,gltfWarnings:gltfReport.issues.numWarnings,gltfMessages:gltfReport.issues.messages.filter(x=>x.severity<=1)});
}
fs.writeFileSync(root+'/04_GAME_ASSETS/vrm/characters/validation.json',JSON.stringify({passed:true,specCommit:execFileSync('git',['-C',root+'/.local/vrm-specification','rev-parse','HEAD'],{encoding:'utf8'}).trim(),loader:'@pixiv/three-vrm '+JSON.parse(fs.readFileSync(path.join(path.dirname(require.resolve('@pixiv/three-vrm')),'../package.json'))).version,results},null,2)+'\n');
console.log(JSON.stringify(results,null,2));
