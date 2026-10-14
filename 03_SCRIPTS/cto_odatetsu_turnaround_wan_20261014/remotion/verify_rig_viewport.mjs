import fs from 'node:fs';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import * as THREE from 'three';
import {GLTFLoader} from 'three/examples/jsm/loaders/GLTFLoader.js';
import {createRigSampler} from './public/riglib/rig-sampler.js';
const project=fileURLToPath(new URL('.',import.meta.url));
const manifest=JSON.parse(fs.readFileSync(project+'/src/rig-manifest.json'));
const bytes=fs.readFileSync(project+'/public/models/cto_odatetsu_rig.glb');
const jsonLen=bytes.readUInt32LE(12), data=JSON.parse(bytes.subarray(20,20+jsonLen));
const bin=bytes.subarray(28+jsonLen);
// Bounds audit uses original mesh/skin/animation bytes, with texture loading removed for Node.
delete data.images;delete data.textures;delete data.samplers;
data.materials=[{name:'BoundsAudit'}];for(const mesh of data.meshes)for(const p of mesh.primitives)p.material=0;
const text=Buffer.from(JSON.stringify(data)),pad=Buffer.alloc((4-text.length%4)%4,32),j=Buffer.concat([text,pad]);
const out=Buffer.alloc(28+j.length+bin.length);out.write('glTF');out.writeUInt32LE(2,4);out.writeUInt32LE(out.length,8);out.writeUInt32LE(j.length,12);out.writeUInt32LE(0x4e4f534a,16);j.copy(out,20);out.writeUInt32LE(bin.length,20+j.length);out.writeUInt32LE(0x004e4942,24+j.length);bin.copy(out,28+j.length);
const gltf=await new GLTFLoader().parseAsync(out.buffer.slice(out.byteOffset,out.byteOffset+out.byteLength),'');
const sampler=createRigSampler(gltf.scene,gltf.animations),meshes=[];gltf.scene.traverse(o=>{if(o.isMesh)meshes.push(o)});
const h=manifest.camera.verticalViewMeters/2,w=h*manifest.composition.width/manifest.composition.height;
const cam=new THREE.OrthographicCamera(-w,w,h,-h,.05,30);cam.position.fromArray(manifest.camera.position);cam.lookAt(new THREE.Vector3().fromArray(manifest.camera.target));cam.updateProjectionMatrix();cam.updateMatrixWorld(true);
const point=new THREE.Vector3(),ranges=[];
for(const segment of manifest.segments){let minX=Infinity,maxX=-Infinity,minY=Infinity,maxY=-Infinity,worstFrame=0;
 for(let frame=0;frame<120;frame++){
  sampler.sample(segment.clip,frame,30);
  for(const mesh of meshes){for(let i=0;i<mesh.geometry.attributes.position.count;i++){
   mesh.getVertexPosition(i,point);point.applyMatrix4(mesh.matrixWorld).project(cam);
   if(point.x<minX)minX=point.x;if(point.x>maxX){maxX=point.x;worstFrame=frame;}
   minY=Math.min(minY,point.y);maxY=Math.max(maxY,point.y);
  }}
 }
 ranges.push({clip:segment.clip,frames:120,minX,maxX,minY,maxY,maxXFrame:segment.startFrame+worstFrame,contained:minX>=-1&&maxX<=1&&minY>=-1&&maxY<=1});
}
const report={modelSha256:createHash('sha256').update(bytes).digest('hex'),camera:manifest.camera,method:'Exact projected bounds of all deformed mesh vertices at every frame of the 720-frame composition; material textures omitted only for headless Node loading.',passed:ranges.every(r=>r.contained),ranges};
fs.writeFileSync(project+'/rig_viewport_validation.json',JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report,null,2));

if (!report.passed) process.exitCode = 1;
