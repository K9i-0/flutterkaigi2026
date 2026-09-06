"""Check exported NPC GLB skinning, morph targets, textures and loop endpoints.

Usage: python3 tools/validate_hazard_npc.py path/to/character.glb
"""
import hashlib
import json
import math
import struct
import sys
from pathlib import Path


def validate(path):
    raw = path.read_bytes()
    magic, version, length = struct.unpack_from('<4sII', raw)
    assert magic == b'glTF' and version == 2 and length == len(raw)
    size = struct.unpack_from('<I', raw, 12)[0]
    gltf = json.loads(raw[20:20 + size])
    binary = raw[28 + size:]

    def accessor(index):
        a = gltf['accessors'][index]
        width = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}[a['type']]
        formats = {5120: 'b', 5121: 'B', 5122: 'h', 5123: 'H', 5125: 'I', 5126: 'f'}
        layout = struct.Struct('<' + formats[a['componentType']] * width)
        def read(view_index, offset, count, fmt):
            v = gltf['bufferViews'][view_index]
            start = v.get('byteOffset', 0) + offset
            stride = v.get('byteStride', fmt.size)
            return [fmt.unpack_from(binary, start + i * stride) for i in range(count)]
        rows = read(a['bufferView'], a.get('byteOffset', 0), a['count'], layout) if 'bufferView' in a else [(0,) * width for _ in range(a['count'])]
        if 'sparse' in a:
            sparse = a['sparse']; ix = sparse['indices']; vals = sparse['values']
            indices = read(ix['bufferView'], ix.get('byteOffset', 0), sparse['count'], struct.Struct('<' + formats[ix['componentType']]))
            values = read(vals['bufferView'], vals.get('byteOffset', 0), sparse['count'], layout)
            for (i,), value in zip(indices, values):
                assert 0 <= i < a['count']
                rows[i] = value
        assert all(math.isfinite(x) for row in rows for x in row), index
        return rows

    assert len(gltf['skins']) == 1
    joints = len(gltf['skins'][0]['joints'])
    assert len(accessor(gltf['skins'][0]['inverseBindMatrices'])) == joints
    triangles = vertices = 0
    error = 0
    for mesh in gltf['meshes']:
        for p in mesh['primitives']:
            attrs = p['attributes']
            for index in attrs.values():
                accessor(index)
            assert 'WEIGHTS_1' not in attrs
            ws, js = accessor(attrs['WEIGHTS_0']), accessor(attrs['JOINTS_0'])
            for w, j in zip(ws, js):
                error = max(error, abs(sum(w) - 1))
                assert min(w) >= 0 and abs(sum(w) - 1) < 1e-5
                assert all(0 <= x < joints for x in j)
            vertices += len(ws)
            triangles += len(accessor(p['indices'])) // 3
            for target in p.get('targets', []):
                for index in target.values():
                    assert len(accessor(index)) == len(ws)
    names = {a['name'] for a in gltf['animations']}
    assert {'Idle', 'Talk', 'Wave'} <= names
    if path.stem == 'yametaro':
        assert 'Walk' in names
        assert any({'SpeechOpen', 'SpeechNarrow'} <= set(m.get('extras', {}).get('targetNames', [])) for m in gltf['meshes'])
    clips = []
    for anim in gltf['animations']:
        duration = seam = 0
        for channel in anim['channels']:
            sampler = anim['samplers'][channel['sampler']]
            times = [t[0] for t in accessor(sampler['input'])]
            assert all(a < b for a, b in zip(times, times[1:]))
            rows = accessor(sampler['output'])
            assert len(rows) == len(times)
            delta = max(abs(a - b) for a, b in zip(rows[0], rows[-1]))
            if channel['target']['path'] == 'rotation':
                delta = min(delta, max(abs(a + b) for a, b in zip(rows[0], rows[-1])))
                assert all(abs(sum(v * v for v in q) - 1) < 1e-4 for q in rows)
            duration, seam = max(duration, times[-1]), max(seam, delta)
        assert seam < 1e-4, (anim['name'], seam)
        clips.append({'name': anim['name'], 'seconds': duration, 'loopSeam': seam})
    assert all('bufferView' in im for im in gltf.get('images', [])), 'Textures must be embedded'
    report = {'result': 'PASS', 'sha256': hashlib.sha256(raw).hexdigest(), 'bytes': len(raw),
              'triangles': triangles, 'vertices': vertices, 'joints': joints,
              'materials': len(gltf.get('materials', [])), 'maxWeightError': error, 'clips': clips,
              'scope': 'GLB structural checks; visual deformation review is separate'}
    path.with_name('validation.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    validate(Path(sys.argv[1]))
