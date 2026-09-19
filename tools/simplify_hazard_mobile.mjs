// Attribute-aware reduction with locked face/hand/morph vertices and exact retained data.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import {MeshoptSimplifier as S} from '../.local/vrm-validation/node_modules/three/examples/jsm/libs/meshopt_simplifier.module.js';
await S.ready;
const [character, input, output, reportPath] = process.argv.slice(2);
const bytes = fs.readFileSync(input), size = bytes.readUInt32LE(12);
const doc = JSON.parse(bytes.subarray(20, 20 + size));
let binary = bytes.subarray(28 + size, 28 + size + doc.buffers[0].byteLength);
const widths = {SCALAR: 1, VEC2: 2, VEC3: 3, VEC4: 4, MAT4: 16};
const types = {5121: Uint8Array, 5123: Uint16Array, 5125: Uint32Array, 5126: Float32Array};
function read(id) {
  const a = doc.accessors[id], T = types[a.componentType], w = widths[a.type];
  assert(T && w);
  const out = new T(a.count * w);
  function rows(viewId, count, width, Type, offset = 0) {
    const v = doc.bufferViews[viewId], result = new Type(count * width);
    const start = (v.byteOffset ?? 0) + offset, stride = v.byteStride ?? width * Type.BYTES_PER_ELEMENT;
    for (let i = 0; i < count; i++) {
      const b = Uint8Array.from(binary.subarray(start + i * stride, start + i * stride + width * Type.BYTES_PER_ELEMENT));
      result.set(new Type(b.buffer), i * width);
    }
    return result;
  }
  if (a.bufferView !== undefined) out.set(rows(a.bufferView, a.count, w, T, a.byteOffset ?? 0));
  if (a.sparse) {
    const s = a.sparse, ids = rows(s.indices.bufferView, s.count, 1, types[s.indices.componentType], s.indices.byteOffset ?? 0);
    const values = rows(s.values.bufferView, s.count, w, T, s.values.byteOffset ?? 0);
    ids.forEach((id, i) => out.set(values.subarray(i * w, (i + 1) * w), id * w));
  }
  return out;
}
function append(oldId, values, componentType) {
  const a = structuredClone(doc.accessors[oldId]); delete a.sparse;
  binary = Buffer.concat([binary, Buffer.alloc((4 - binary.length % 4) % 4)]);
  a.bufferView = doc.bufferViews.length; a.byteOffset = 0; a.count = values.length / widths[a.type];
  if (componentType) a.componentType = componentType;
  doc.bufferViews.push({buffer: 0, byteOffset: binary.length, byteLength: values.byteLength, target: a.type === 'SCALAR' ? 34963 : 34962});
  binary = Buffer.concat([binary, Buffer.from(values.buffer, values.byteOffset, values.byteLength)]);
  if (a.min || a.max) {
    a.min = Array(widths[a.type]).fill(Infinity); a.max = a.min.map(() => -Infinity);
    values.forEach((v, i) => {const k = i % a.min.length; a.min[k] = Math.min(a.min[k], v); a.max[k] = Math.max(a.max[k], v);});
  }
  doc.accessors.push(a); return doc.accessors.length - 1;
}
const report = [];
for (const [mi, mesh] of doc.meshes.entries()) for (const [pi, p] of mesh.primitives.entries()) {
  const mat = doc.materials[p.material], name = mat.name ?? '';
  const skinIds = new Set(doc.nodes.filter(n => n.mesh === mi).map(n => n.skin));
  assert.equal(skinIds.size, 1); const skin = doc.skins[[...skinIds][0]];
  const jointNames = skin.joints.map(i => doc.nodes[i].name);
  const pos = read(p.attributes.POSITION), normal = read(p.attributes.NORMAL), count = pos.length / 3;
  const joints = read(p.attributes.JOINTS_0), weights = read(p.attributes.WEIGHTS_0), indices = read(p.indices);
  const lock = new Uint8Array(count);
  const morphs = (p.targets ?? []).map(t => t.POSITION === undefined ? null : read(t.POSITION)).filter(Boolean);
  const preserveMaterial = character === 'sobaya' ? /Mask absolute|Mask reference/.test(name) :
    character === 'fukuchan' ? /skin|sclera|badge|Oral|Imagegen hair/.test(name) : /NoseInk/.test(name);
  const activeJoints = [...new Set([...joints].filter((j, i) => weights[i] > 0))];
  // At most 24 bone-weight attributes; vertices influenced by other bones lock.
  const scored = activeJoints.map(j => [j, weights.reduce((s, w, i) => s + (joints[i] === j ? w : 0), 0)]).sort((a,b) => b[1]-a[1]);
  const selectedJoints = scored.slice(0,24).map(x=>x[0]);
  for (let i = 0; i < count; i++) {
    const x = pos[i*3], y = pos[i*3+1], z = pos[i*3+2];
    if (preserveMaterial || morphs.some(v => v[i*3] !== 0 || v[i*3+1] !== 0 || v[i*3+2] !== 0)) lock[i] = 1;
    if (character === 'sobaya' && name === 'Sobaya_Imagegen_Mask_v1' && y > 1.45) lock[i] = 1;
    if (character === 'yametaro' && y > .62 && z > .11) lock[i] = 1;
    if (character === 'takosan' && y > .78 && z > .07) lock[i] = 1;
    for (let k = 0; k < 4; k++) if (weights[i*4+k] > 0) {
      const j = joints[i*4+k], n = jointNames[j] ?? '';
      if (!selectedJoints.includes(j) || /Hand|Thumb|Index|Middle|Ring|Little/.test(n)) lock[i] = 1;
    }
  }
  const texInfo = mat.pbrMetallicRoughness?.baseColorTexture;
  const uvId = texInfo ? p.attributes['TEXCOORD_' + (texInfo.texCoord ?? 0)] : undefined;
  const uv = uvId === undefined ? null : read(uvId), width = 3 + (uv ? 2 : 0) + selectedJoints.length;
  const attrs = new Float32Array(count * width), attrWeights = [.01, .01, .01, ...(uv ? [.03,.03] : []), ...selectedJoints.map(()=>.1)];
  for (let i = 0; i < count; i++) {
    attrs.set(normal.subarray(i*3,i*3+3), i*width);
    if (uv) attrs.set(uv.subarray(i*2,i*2+2), i*width+3);
    for (let k = 0; k < 4; k++) {const slot = selectedJoints.indexOf(joints[i*4+k]); if (slot >= 0) attrs[i*width+3+(uv?2:0)+slot] += weights[i*4+k];}
  }
  // Changing interpolation of vertex-painted skin can alter the face even
  // with exact retained colors. Keep these primitives intact in this profile.
  const color = p.attributes.COLOR_0 === undefined ? null : read(p.attributes.COLOR_0);
  const colorWidth = color ? widths[doc.accessors[p.attributes.COLOR_0].type] : 0;
  const painted = color && color.some((v,i) => v !== color[i % colorWidth]);
  if (painted) lock.fill(1);
  const ratio = character === 'sobaya' ? .45 : .6;
  const errorLimit = character === 'sobaya' && /Hair/.test(name) ? .0007 : .001;
  const [reduced, error] = preserveMaterial ? [indices, 0] : S.simplifyWithAttributes(indices,pos,3,attrs,width,attrWeights,lock,
    Math.floor(indices.length * ratio / 3)*3,errorLimit,['LockBorder','ErrorAbsolute']);
  const used = [...new Set(reduced)], remap = new Map(used.map((v,i)=>[v,i]));
  const idx = new (used.length < 65536 ? Uint16Array : Uint32Array)(reduced.length);
  reduced.forEach((v,i)=>idx[i]=remap.get(v));
  p.indices = append(p.indices,idx,used.length < 65536 ? 5123 : 5125);
  for (const attributes of [p.attributes,...(p.targets??[])]) for(const [key,id] of Object.entries(attributes)) {
    const old = read(id), w = widths[doc.accessors[id].type], values = new old.constructor(used.length*w);
    used.forEach((v,i)=>values.set(old.subarray(v*w,(v+1)*w),i*w)); attributes[key]=append(id,values);
  }
  report.push({mesh:mi,primitive:pi,material:name,trianglesBefore:indices.length/3,trianglesAfter:reduced.length/3,
    verticesBefore:count,verticesAfter:used.length,protectedVertices:lock.reduce((a,b)=>a+b,0),errorLimit,simplifierAttributeError:error,
    retainedSourceVertices:used});
}
doc.buffers[0].byteLength=binary.length;
let json=Buffer.from(JSON.stringify(doc));json=Buffer.concat([json,Buffer.alloc((4-json.length%4)%4,32)]);
binary=Buffer.concat([binary,Buffer.alloc((4-binary.length%4)%4)]);
const h=Buffer.alloc(20);h.write('glTF');h.writeUInt32LE(2,4);h.writeUInt32LE(28+json.length+binary.length,8);h.writeUInt32LE(json.length,12);h.write('JSON',16);
const bh=Buffer.alloc(8);bh.writeUInt32LE(binary.length);bh.write('BIN\0',4);fs.writeFileSync(output,Buffer.concat([h,json,bh,binary]));
fs.writeFileSync(reportPath,JSON.stringify(report));
console.log(character,JSON.stringify(report.map(({retainedSourceVertices,...r})=>r)));
