// Only rigid, untextured head parts. Never simplify the body, mask paint or hands.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import {MeshoptSimplifier} from '../.local/vrm-validation/node_modules/three/examples/jsm/libs/meshopt_simplifier.module.js';

await MeshoptSimplifier.ready;
const [input, output, reportPath] = process.argv.slice(2);
const bytes = fs.readFileSync(input), jsonSize = bytes.readUInt32LE(12);
const doc = JSON.parse(bytes.subarray(20, 20 + jsonSize));
let binary = bytes.subarray(28 + jsonSize, 28 + jsonSize + doc.buffers[0].byteLength);
const sizes = {SCALAR: 1, VEC2: 2, VEC3: 3, VEC4: 4, MAT4: 16};
const types = {5121: Uint8Array, 5123: Uint16Array, 5125: Uint32Array, 5126: Float32Array};
function read(id) {
  const a = doc.accessors[id], v = doc.bufferViews[a.bufferView], T = types[a.componentType];
  assert(!a.sparse && !v.byteStride && T);
  const offset = v.byteOffset + (a.byteOffset ?? 0);
  const b = Uint8Array.from(binary.subarray(offset, offset + a.count * sizes[a.type] * T.BYTES_PER_ELEMENT));
  return new T(b.buffer);
}
function append(oldId, values) {
  const a = structuredClone(doc.accessors[oldId]);
  binary = Buffer.concat([binary, Buffer.alloc((4 - binary.length % 4) % 4)]);
  a.bufferView = doc.bufferViews.length;
  doc.bufferViews.push({buffer: 0, byteOffset: binary.length, byteLength: values.byteLength,
    target: a.type === 'SCALAR' ? 34963 : 34962});
  binary = Buffer.concat([binary, Buffer.from(values.buffer, values.byteOffset, values.byteLength)]);
  a.byteOffset = 0; a.count = values.length / sizes[a.type];
  if (a.min || a.max) {
    a.min = Array(sizes[a.type]).fill(Infinity); a.max = a.min.map(() => -Infinity);
    for (let i = 0; i < values.length; i++) {
      const k = i % sizes[a.type]; a.min[k] = Math.min(a.min[k], values[i]); a.max[k] = Math.max(a.max[k], values[i]);
    }
  }
  doc.accessors.push(a); return doc.accessors.length - 1;
}
const selected = new Set(['Mask porcelain nose', 'Mask medallion black satin', 'Hair clean charcoal']);
const report = [];
for (const mesh of doc.meshes) for (const primitive of mesh.primitives) {
  const material = doc.materials[primitive.material];
  if (!selected.has(material.name)) continue;
  const p = primitive, position = read(p.attributes.POSITION), normal = read(p.attributes.NORMAL);
  const joints = read(p.attributes.JOINTS_0), weights = read(p.attributes.WEIGHTS_0);
  // All affected vertices must move with the exact same bone. No joint-error approximation.
  let bone;
  for (let i = 0; i < weights.length; i++) if (weights[i] !== 0) {
    assert.equal(weights[i], 1); bone ??= joints[i]; assert.equal(joints[i], bone);
  }
  for (const target of p.targets ?? []) for (const id of Object.values(target)) {
    assert(read(id).every(value => value === 0), 'Never simplify a moving morph target');
  }
  const indices = read(p.indices);
  const [reduced, error] = MeshoptSimplifier.simplifyWithAttributes(
    indices, position, 3, normal, 3, [.01, .01, .01], null,
    Math.floor(indices.length * (material.name === 'Mask porcelain nose' ? .05 : .25) / 3) * 3,
    .00015, ['LockBorder', 'ErrorAbsolute'],
  );
  const used = [...new Set(reduced)], remap = new Map(used.map((old, i) => [old, i]));
  const packedIndices = new (used.length < 65536 ? Uint16Array : Uint32Array)(reduced.length);
  for (let i = 0; i < reduced.length; i++) packedIndices[i] = remap.get(reduced[i]);
  p.indices = append(p.indices, packedIndices);
  doc.accessors[p.indices].componentType = used.length < 65536 ? 5123 : 5125;
  for (const attributes of [p.attributes, ...(p.targets ?? [])]) for (const [key, id] of Object.entries(attributes)) {
    const old = read(id), width = sizes[doc.accessors[id].type], packed = new old.constructor(used.length * width);
    used.forEach((v, i) => packed.set(old.subarray(v * width, (v + 1) * width), i * width));
    attributes[key] = append(id, packed);
  }
  report.push({material: material.name, trianglesBefore: indices.length / 3, trianglesAfter: reduced.length / 3,
    verticesBefore: position.length / 3, verticesAfter: used.length, simplifierAttributeError: error,
    targetError: .00015, rigidBone: bone, retainedVertexAttributesExact: true});
}
assert.equal(report.length, selected.size);
doc.buffers[0].byteLength = binary.length;
let json = Buffer.from(JSON.stringify(doc)); json = Buffer.concat([json, Buffer.alloc((4 - json.length % 4) % 4, 32)]);
binary = Buffer.concat([binary, Buffer.alloc((4 - binary.length % 4) % 4)]);
const header = Buffer.alloc(20); header.write('glTF'); header.writeUInt32LE(2, 4);
header.writeUInt32LE(28 + json.length + binary.length, 8); header.writeUInt32LE(json.length, 12); header.write('JSON', 16);
const binHeader = Buffer.alloc(8); binHeader.writeUInt32LE(binary.length); binHeader.write('BIN\0', 4);
fs.writeFileSync(output, Buffer.concat([header, json, binHeader, binary]));
fs.writeFileSync(reportPath, JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify(report));
