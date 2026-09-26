// Reproducible CPU-only adapter for Tidewater (MIT). No browser/GPU required.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath, pathToFileURL} from 'node:url';
import {execFileSync} from 'node:child_process';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const revision = '4811ba48d795197de5621985f404e765c0b7c0ef';
const source = path.resolve(process.argv[2] || path.join(root, '.local/tidewater-source'));
if (!fs.existsSync(path.join(source, '.git'))) {
  fs.mkdirSync(path.dirname(source), {recursive:true});
  execFileSync('git', ['clone', 'https://github.com/dgreenheck/tidewater.git', source], {stdio:'inherit'});
  execFileSync('git', ['-C', source, 'checkout', '--detach', revision], {stdio:'inherit'});
}
if (execFileSync('git', ['-C',source,'rev-parse','HEAD'], {encoding:'utf8'}).trim() !== revision) throw Error('Tidewater revision mismatch');
if (execFileSync('git', ['-C',source,'status','--porcelain','--untracked-files=no'], {encoding:'utf8'}).trim()) throw Error('Tidewater sources must be clean');
const load = p => import(pathToFileURL(path.join(source, 'src', p)));
const {TerrainData} = await load('world/TerrainData.js');
const {Village} = await load('world/Village.js');
const {Colliders} = await load('world/Colliders.js');
const {Scene, Vector3} = await load('engine/index.js');
const {WORLD} = await load('world/WorldLayout.js');
// Retain CPU batches before the upstream assembly creates GPU-only fish instances.
// Signs, animated lanterns, fish/ice props and procedural surface textures are not exported yet.
class ExportVillage extends Village {
  _assemble() {}
  _buildSign() {}
  _buildLanterns() {}
}
const terrain = new TerrainData(7), colliders = new Colliders();
const village = new ExportVillage({scene:new Scene(), terrain, colliders});
const out = path.join(root, '04_GAME_ASSETS/3d/tidewater');
fs.mkdirSync(out, {recursive:true});
const gltf = {asset:{version:'2.0',generator:'Sobaya Tidewater CPU port'},scene:0,scenes:[{nodes:[]}],nodes:[],meshes:[],materials:[],buffers:[{byteLength:0}],bufferViews:[],accessors:[]};
let offset=0; const chunks=[];
function accessor(values, width, indices=false) {
  const array = indices ? new Uint32Array(values) : new Float32Array(values);
  const bytes=Buffer.from(array.buffer); const view=gltf.bufferViews.length;
  gltf.bufferViews.push({buffer:0,byteOffset:offset,byteLength:bytes.length});
  offset+=bytes.length; chunks.push(bytes);
  const a={bufferView:view,componentType:indices?5125:5126,count:array.length/width,type:width===1?'SCALAR':`VEC${width}`};
  if(width===3 && !indices) {
    a.min=Array(width).fill(Infinity); a.max=Array(width).fill(-Infinity);
    for(let i=0;i<array.length;i++) {const k=i%width;a.min[k]=Math.min(a.min[k],array[i]);a.max[k]=Math.max(a.max[k],array[i]);}
  }
  gltf.accessors.push(a); return gltf.accessors.length-1;
}
function mesh(name,p,n,c,idx,roughness=.9) {
  if(!idx.length) return;
  const material=gltf.materials.length;
  gltf.materials.push({name,pbrMetallicRoughness:{baseColorFactor:[1,1,1,1],metallicFactor:0,roughnessFactor:roughness},doubleSided:true});
  const attributes={POSITION:accessor(p,3),NORMAL:accessor(n,3),COLOR_0:accessor(c,3)};
  gltf.meshes.push({name,primitives:[{attributes,indices:accessor(idx,1,true),material}]});
  gltf.scenes[0].nodes.push(gltf.nodes.length);
  gltf.nodes.push({name,mesh:gltf.meshes.length-1});
}
for(const [name,b] of Object.entries(village.B.batches)) {
  // Nets need an alpha shader; emitting their backing quads as solid hides the village.
  if(name==='net') continue;
  mesh(`village_${name}`,b.pos,b.nrm,b.tint,b.idx,name==='glass'?.18:.8);
}
// Uniform 4 m sampling, tiled for culling. Heights retain source geometry; PBR detail is deferred.
const step=4,tile=128,normal=new Vector3();
let triangles=0;
for(let z0=-1024;z0<1024;z0+=tile) for(let x0=-1024;x0<1024;x0+=tile) {
  const p=[],n=[],c=[],idx=[],N=tile/step;
  let max=-Infinity;
  for(let z=0;z<=N;z++) for(let x=0;x<=N;x++) {
    const wx=x0+x*step,wz=z0+z*step,h=terrain.heightAt(wx,wz);
    max=Math.max(max,h);p.push(wx,h,wz);terrain.normalAt(wx,wz,normal);n.push(normal.x,normal.y,normal.z);
    const k=Math.max(0,Math.min(terrain.heights.length-1,Math.floor((wz+1024))*2048+Math.floor(wx+1024)));
    const rock=Math.max(terrain.rock[k],Math.min(1,(1-normal.y)*2));
    const sand=terrain.sand[k]/255;
    const land=h<2?[.55,.46,.29]:[.12,.22,.065];
    const base=land.map((v,i)=>v*(1-sand)+[.62,.52,.33][i]*sand);
    c.push(...base.map((v,i)=>v*(1-rock)+[.21,.22,.20][i]*rock));
  }
  if(max < -8) continue;
  for(let z=0;z<N;z++) for(let x=0;x<N;x++) {const i=z*(N+1)+x,j=i+N+1;idx.push(i,j,i+1,i+1,j,j+1);}
  triangles+=idx.length/3;mesh(`terrain_${x0}_${z0}`,p,n,c,idx);
}
const bin=Buffer.concat(chunks);gltf.buffers[0].byteLength=bin.length;
let json=Buffer.from(JSON.stringify(gltf));json=Buffer.concat([json,Buffer.alloc((4-json.length%4)%4,32)]);
const header=Buffer.alloc(20);header.writeUInt32LE(0x46546c67);header.writeUInt32LE(2,4);header.writeUInt32LE(28+json.length+bin.length,8);header.writeUInt32LE(json.length,12);header.writeUInt32LE(0x4e4f534a,16);
const bh=Buffer.alloc(8);bh.writeUInt32LE(bin.length);bh.writeUInt32LE(0x004e4942,4);
fs.writeFileSync(path.join(out,'island.glb'),Buffer.concat([header,json,bh,bin]));
// Full 1 m source heightfield includes village foundation flattening; little-endian f32.
const heights=Buffer.alloc(terrain.heights.length*4);
terrain.heights.forEach((v,i)=>heights.writeFloatLE(v,i*4));fs.writeFileSync(path.join(out,'heights.bin'),heights);
const manifest={source:'https://github.com/dgreenheck/tidewater',revision,seed:7,heightfield:{resolution:2048,size:2048,origin:-1024,texel:1,encoding:'float32-le',sampleOffset:.5},spawn:WORLD.start,boxes:colliders.boxes,cylinders:colliders.cylinders,buildings:village.buildings,terrainTriangles:triangles,meshes:gltf.meshes.length,omitted:['vegetation','rocks scatter','animated signs and lanterns','fish and scanned vendor props','GPU procedural material textures','FFT ocean','volumetric atmosphere']};
fs.writeFileSync(path.join(out,'world.json'),JSON.stringify(manifest));
fs.copyFileSync(path.join(source,'LICENSE'),path.join(out,'LICENSE-Tidewater'));
console.log(JSON.stringify({meshes:gltf.meshes.length,terrainTriangles:triangles,buildings:village.buildings.length,bytes:bin.length}));
