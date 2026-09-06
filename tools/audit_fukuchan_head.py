"""Compare animation payloads and validate a rebuilt GLB, including sparse morphs.

python3 tools/audit_fukuchan_head.py before.glb after.glb report.json
"""
import hashlib
import json
import math
import struct
import sys
from pathlib import Path


class GLB:
    def __init__(self, path):
        self.raw = Path(path).read_bytes()
        size = struct.unpack_from('<I', self.raw, 12)[0]
        self.doc = json.loads(self.raw[20:20 + size])
        self.bin = self.raw[28 + size:]

    def values(self, index):
        accessor = self.doc['accessors'][index]
        width = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}[accessor['type']]
        types = {5120: 'b', 5121: 'B', 5122: 'h', 5123: 'H', 5125: 'I', 5126: 'f'}

        def read(view_index, offset, count, component, columns):
            view = self.doc['bufferViews'][view_index]
            fmt = '<' + types[component] * columns
            size = struct.calcsize(fmt)
            base = view.get('byteOffset', 0) + offset
            stride = view.get('byteStride', size)
            return [struct.unpack_from(fmt, self.bin, base + i * stride) for i in range(count)]

        data = (read(accessor['bufferView'], accessor.get('byteOffset', 0), accessor['count'],
                     accessor['componentType'], width) if 'bufferView' in accessor
                else [(0,) * width for _ in range(accessor['count'])])
        if 'sparse' in accessor:
            sparse = accessor['sparse']
            indices, values = sparse['indices'], sparse['values']
            where = read(indices['bufferView'], indices.get('byteOffset', 0), sparse['count'], indices['componentType'], 1)
            replacements = read(values['bufferView'], values.get('byteOffset', 0), sparse['count'], accessor['componentType'], width)
            for (position,), replacement in zip(where, replacements):
                data[position] = replacement
        return data

    def animations(self):
        result = {}
        for animation in self.doc.get('animations', []):
            channels = {}
            for channel in animation['channels']:
                target = channel['target']
                sampler = animation['samplers'][channel['sampler']]
                key = self.doc['nodes'][target['node']]['name'] + ':' + target['path']
                channels[key] = {'interpolation': sampler.get('interpolation', 'LINEAR'),
                                 'input': self.values(sampler['input']), 'output': self.values(sampler['output'])}
            result[animation['name']] = channels
        return result


before, after = GLB(sys.argv[1]), GLB(sys.argv[2])
assert before.animations() == after.animations(), 'Body animation payload changed'
for index in range(len(after.doc['accessors'])):
    assert all(math.isfinite(value) for row in after.values(index) for value in row)
triangles = 0
for mesh in after.doc['meshes']:
    for primitive in mesh['primitives']:
        triangles += after.doc['accessors'][primitive['indices']]['count'] // 3
        if 'WEIGHTS_0' in primitive['attributes']:
            weights = after.values(primitive['attributes']['WEIGHTS_0'])
            assert all(abs(sum(w) - 1) < .001 for w in weights), 'Unnormalized skin weights'
report = {'beforeSha256': hashlib.sha256(before.raw).hexdigest(),
          'afterSha256': hashlib.sha256(after.raw).hexdigest(),
          'bytesBefore': len(before.raw), 'bytesAfter': len(after.raw),
          'trianglesAfter': triangles, 'materialsAfter': len(after.doc['materials']),
          'animationPayloadIdentical': True, 'clips': sorted(after.animations()),
          'allAccessorsFinite': True, 'skinWeightsNormalized': True,
          'jointCounts': [len(s['joints']) for s in after.doc['skins']]}
Path(sys.argv[3]).write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report))
