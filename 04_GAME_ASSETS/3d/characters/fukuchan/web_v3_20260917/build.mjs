import fs from 'node:fs';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import crypto from 'node:crypto';
const here=path.dirname(fileURLToPath(import.meta.url));
const require=createRequire(path.resolve(here,'../../../../../16_MADOGIWA_STUDIO/package.json'));
const sharp=require('sharp');
const source=fs.readFileSync(path.resolve(here,'../skin_even_20260917/fukuchan.glb'));
const size=source.readUInt32LE(12),g=JSON.parse(source.subarray(20,20+size)),bin=source.subarray(28+size);
const images=new Map(),report=[];
for(const [i,im] of g.images.entries()) {
 const v=g.bufferViews[im.bufferView],original=bin.subarray(v.byteOffset||0,(v.byteOffset||0)+v.byteLength);
 const encoded=await sharp(original).webp({lossless:true,effort:6}).toBuffer();
 const a=await sharp(original).ensureAlpha().raw().toBuffer(),b=await sharp(encoded).ensureAlpha().raw().toBuffer();
 if(!a.equals(b))throw Error('Pixel mismatch '+i);
 images.set(im.bufferView,encoded);im.mimeType='image/webp';report.push({image:i,before:original.length,after:encoded.length,pixelsExact:true});
}
let offset=0;const chunks=[];
for(const [i,v] of g.bufferViews.entries()) {
 const bytes=images.get(i)||bin.subarray(v.byteOffset||0,(v.byteOffset||0)+v.byteLength);
 const pad=Buffer.alloc((4-bytes.length%4)%4);v.byteOffset=offset;v.byteLength=bytes.length;chunks.push(bytes,pad);offset+=bytes.length+pad.length;
}
for(const tex of g.textures){tex.extensions={...tex.extensions,EXT_texture_webp:{source:tex.source}};delete tex.source;}
for(const key of ['extensionsUsed','extensionsRequired'])g[key]=[...new Set([...(g[key]||[]),'EXT_texture_webp'])];
g.buffers[0].byteLength=offset;
let json=Buffer.from(JSON.stringify(g));json=Buffer.concat([json,Buffer.alloc((4-json.length%4)%4,32)]);
const data=Buffer.concat(chunks),header=Buffer.alloc(20),bh=Buffer.alloc(8);
header.write('glTF');header.writeUInt32LE(2,4);header.writeUInt32LE(28+json.length+data.length,8);header.writeUInt32LE(json.length,12);header.write('JSON',16);bh.writeUInt32LE(data.length);bh.write('BIN\0',4);
const result=Buffer.concat([header,json,bh,data]);if(result.length>25*1024*1024)throw Error('Over asset limit: '+result.length);
fs.writeFileSync(path.join(here,'fukuchan.glb'),result);
fs.writeFileSync(path.join(here,'validation.json'),JSON.stringify({sourceSHA256:crypto.createHash('sha256').update(source).digest('hex'),sha256:crypto.createHash('sha256').update(result).digest('hex'),bytes:result.length,images:report,animations:g.animations.length,geometryAndAnimationBuffersExact:true},null,2)+'\n');
console.log(JSON.stringify({bytes:result.length,images:report}));
