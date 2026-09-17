import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
const here=path.dirname(fileURLToPath(import.meta.url));
const require=createRequire(path.resolve(here,'../../../../../16_MADOGIWA_STUDIO/package.json'));
const sharp=require('sharp');
function read(file){const d=fs.readFileSync(file),n=d.readUInt32LE(12);return {g:JSON.parse(d.subarray(20,20+n)),bin:d.subarray(28+n)};}
function view(asset,i){const v=asset.g.bufferViews[i];return asset.bin.subarray(v.byteOffset||0,(v.byteOffset||0)+v.byteLength);}
const before=read(path.resolve(here,'../rig_v3_20260917/fukuchan.glb'));
const after=read(path.resolve(here,'../web_v3_20260917/fukuchan.glb'));
for(const key of ['meshes','accessors','skins','animations','nodes','materials'])assert.deepEqual(after.g[key],before.g[key],key);
const imageViews=new Set(before.g.images.map(im=>im.bufferView));
let buffers=0;
for(let i=0;i<before.g.bufferViews.length;i++)if(!imageViews.has(i)){assert(view(before,i).equals(view(after,i)));buffers++;}
const images=[];
for(let i=0;i<before.g.images.length;i++){
 const a=await sharp(view(before,before.g.images[i].bufferView)).ensureAlpha().raw().toBuffer();
 const b=await sharp(view(after,after.g.images[i].bufferView)).ensureAlpha().raw().toBuffer();
 assert.equal(a.length,b.length);let changed=0;
 for(let p=0;p<a.length;p+=4)if(!a.subarray(p,p+4).equals(b.subarray(p,p+4)))changed++;
 if(i!==3)assert.equal(changed,0,'Unrelated image changed');
 images.push({image:i,changedPixels:changed,totalPixels:a.length/4});
}
assert(images[3].changedPixels>0);
const report={result:'PASS',geometryWeightsUVsAnimationsMaterialsExact:true,unchangedNonImageBuffers:buffers,images};
fs.writeFileSync(path.join(here,'web_validation.json'),JSON.stringify(report,null,2)+'\n');console.log(report);
