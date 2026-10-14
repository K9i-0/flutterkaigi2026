import fs from 'node:fs';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import * as THREE from 'three';
import {GLTFLoader} from 'three/examples/jsm/loaders/GLTFLoader.js';
import {createCameraEquipment} from './public/riglib/camera-equipment.js';
import {createRigSampler} from './public/riglib/rig-sampler.js';
const project=fileURLToPath(new URL('.',import.meta.url));
const manifest=JSON.parse(fs.readFileSync(project+'/src/camera-manifest.json'));
const assetFiles=['public/'+manifest.character,'public/'+manifest.cameraProp,'public/'+manifest.attachment];
const hashes=Object.fromEntries(assetFiles.map((name)=>[name,createHash('sha256').update(fs.readFileSync(project+'/'+name)).digest('hex')]));
const loadWithoutTextures=async(name)=>{
  const bytes=fs.readFileSync(project+'/'+name),jsonLen=bytes.readUInt32LE(12);
  const data=JSON.parse(bytes.subarray(20,20+jsonLen)),bin=bytes.subarray(28+jsonLen);
  delete data.images;delete data.textures;delete data.samplers;
  data.materials=[{name:'BoundsAudit'}];for(const mesh of data.meshes)for(const primitive of mesh.primitives)primitive.material=0;
  const text=Buffer.from(JSON.stringify(data)),j=Buffer.concat([text,Buffer.alloc((4-text.length%4)%4,32)]);
  const out=Buffer.alloc(28+j.length+bin.length);out.write('glTF');out.writeUInt32LE(2,4);out.writeUInt32LE(out.length,8);
  out.writeUInt32LE(j.length,12);out.writeUInt32LE(0x4e4f534a,16);j.copy(out,20);
  out.writeUInt32LE(bin.length,20+j.length);out.writeUInt32LE(0x004e4942,24+j.length);bin.copy(out,28+j.length);
  return new GLTFLoader().parseAsync(out.buffer.slice(out.byteOffset,out.byteOffset+out.byteLength),'');
};
const actor=await loadWithoutTextures(assetFiles[0]),prop=await loadWithoutTextures(assetFiles[1]);
const attachment=JSON.parse(fs.readFileSync(project+'/'+assetFiles[2]));
const equipment=createCameraEquipment(actor.scene,actor.animations,prop.scene,attachment);
const baseline=await loadWithoutTextures(assetFiles[0]),baselineSampler=createRigSampler(baseline.scene,baseline.animations);
const matrices=(scene)=>{const bones=[];scene.traverse((node)=>{if(node.isBone)bones.push({name:node.name,matrix:node.matrixWorld.toArray()});});return bones;};
const checks=[];
for(const clip of actor.animations){
  for(const phase of [0,.37,.91]){
    const frame=Math.floor(clip.duration*30*phase);
    baselineSampler.sample(clip.name,frame,30);const expectedOff=JSON.stringify(matrices(baseline.scene));
    equipment.sample(clip.name,frame,30,true,true);const expectedOn=JSON.stringify(equipment.snapshot());
    for(const other of actor.animations)equipment.sample(other.name,Math.floor(other.duration*30*.79),30,true,false);
    equipment.sample(clip.name,0,30,false,true);equipment.sample(clip.name,frame,30,true,true);
    const actual=equipment.snapshot(),strap=equipment.strap.geometry.attributes.position.array;
    equipment.sample(clip.name,frame,30,false,true);
    checks.push({clip:clip.name,frame,repeatable:JSON.stringify(actual)===expectedOn,
      offRestoresOriginalClip:JSON.stringify(equipment.snapshot().bones)===expectedOff,
      gripError:actual.gripError,finite:actual.bones.every((bone)=>bone.matrix.every(Number.isFinite))&&
        actual.cameraMatrix.every(Number.isFinite)&&Array.from(strap).every(Number.isFinite)});
  }
}
const camera=new THREE.OrthographicCamera(),point=new THREE.Vector3(),ranges=[];
const meshes=[];equipment.group.traverse((node)=>{if(node.isMesh)meshes.push(node);});
for(const segment of manifest.segments){
  const settings=manifest.views[segment.view],h=settings.verticalViewMeters/2,w=h*manifest.composition.width/manifest.composition.height;
  Object.assign(camera,{left:-w,right:w,top:h,bottom:-h,near:.05,far:30});
  camera.position.fromArray(settings.position);camera.lookAt(new THREE.Vector3().fromArray(settings.target));camera.updateProjectionMatrix();camera.updateMatrixWorld(true);
  let minX=Infinity,maxX=-Infinity,minY=Infinity,maxY=-Infinity;
  for(let frame=segment.startFrame;frame<segment.endFrameExclusive;frame++){
    equipment.sample(segment.clip,frame-segment.startFrame,30,true,true);
    for(const mesh of meshes)for(let i=0;i<mesh.geometry.attributes.position.count;i++){
      mesh.getVertexPosition(i,point);point.applyMatrix4(mesh.matrixWorld);
      // The detail shot intentionally crops the lower body and the strap loop.
      if(segment.view==='detail'&&(mesh.isSkinnedMesh||mesh===equipment.strap)&&point.y<1.0)continue;
      point.project(camera);minX=Math.min(minX,point.x);maxX=Math.max(maxX,point.x);minY=Math.min(minY,point.y);maxY=Math.max(maxY,point.y);
    }
  }
  ranges.push({clip:segment.clip,view:segment.view,startFrame:segment.startFrame,endFrameExclusive:segment.endFrameExclusive,
    minX,maxX,minY,maxY,contained:minX>=-1&&maxX<=1&&minY>=-1&&maxY<=1});
}
const report={assetSha256:hashes,fps:30,clipCount:actor.animations.length,boneCount:equipment.snapshot().bones.length,
  method:'Shared Three.js equipment sampler: 3 phases of all 21 clips, non-sequential seeks, original-pose comparison after unequip, world-space grip alignment; exact vertex projection of all 480 video frames. Textures omitted only for Node evaluation.',
  passed:checks.every((check)=>check.repeatable&&check.offRestoresOriginalClip&&check.finite&&check.gripError<1e-6)&&ranges.every((range)=>range.contained),checks,ranges};
fs.writeFileSync(project+'/camera_equipment_validation.json',JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({...report,checks:undefined},null,2));
if(!report.passed)process.exitCode=1;
