"""Validate exported GLB skin weights, joints, finite keys and loop seams."""
import hashlib
import json
import math
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DIR = ROOT / ('04_GAME_ASSETS/3d/characters/sobaya/' + (sys.argv[1] if len(sys.argv)>1 else 'rig_v1'))
path = DIR / 'sobaya_rig.glb'
raw = path.read_bytes()
assert raw[:4] == b'glTF'
size = struct.unpack_from('<I', raw, 12)[0]
gltf = json.loads(raw[20:20+size])
binary = raw[28+size:]


def accessor(index):
    a = gltf['accessors'][index]
    view = gltf['bufferViews'][a['bufferView']]
    width = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}[a['type']]
    fmt = {5121: 'B', 5123: 'H', 5125: 'I', 5126: 'f'}[a['componentType']]
    layout = struct.Struct('<'+fmt*width)
    offset = view.get('byteOffset', 0) + a.get('byteOffset', 0)
    stride = view.get('byteStride', layout.size)
    values = [layout.unpack_from(binary, offset+i*stride) for i in range(a['count'])]
    assert all(math.isfinite(v) for row in values for v in row)
    return values


assert len(gltf['skins']) == 1
skin = gltf['skins'][0]
expected_bones = json.loads((DIR/'rig.json').read_text())['bone_count']
assert len(skin['joints']) == expected_bones
assert any(n.get('name') == 'PropSocket.R' for n in gltf['nodes'])
assert len(accessor(skin['inverseBindMatrices'])) == expected_bones
triangles = vertices = 0
max_weight_error = 0.0
for mesh in gltf['meshes']:
    for p in mesh['primitives']:
        attrs = p['attributes']
        for attribute in attrs.values():
            accessor(attribute)  # Positions, UVs, normals and tangents must be finite too.
        weights = accessor(attrs['WEIGHTS_0'])
        joints = accessor(attrs['JOINTS_0'])
        assert 'WEIGHTS_1' not in attrs
        vertices += len(weights)
        for ws, js in zip(weights, joints):
            error = abs(sum(ws)-1)
            max_weight_error = max(max_weight_error, error)
            assert error < 1e-5 and min(ws) >= 0
            assert all(0 <= j < len(skin['joints']) for j in js)
        triangles += len(accessor(p['indices']))//3
specs = {c['name']: c for c in json.loads((DIR/'rig.json').read_text())['clips']}
assert {a['name'] for a in gltf['animations']} == set(specs)
clips = []
for anim in gltf['animations']:
    name = anim['name']
    duration = 0
    seam = 0
    for channel in anim['channels']:
        sampler = anim['samplers'][channel['sampler']]
        times = [x[0] for x in accessor(sampler['input'])]
        assert all(a < b for a, b in zip(times, times[1:]))
        duration = max(duration, times[-1])
        values = accessor(sampler['output'])
        delta = max(abs(a-b) for a, b in zip(values[0], values[-1]))
        if channel['target']['path'] == 'rotation':
            delta = min(delta, max(abs(a+b) for a, b in zip(values[0], values[-1])))
            assert all(abs(sum(x*x for x in q)-1) < 1e-4 for q in values)
        seam = max(seam, delta)
    assert abs(duration-specs[name]['duration']) < 1e-5
    if specs[name]['loop']:
        assert seam < 1e-4, (name, seam)
    clips.append({'name': name, 'seconds': duration, 'loop': specs[name]['loop'],
                  'endpoint_max_delta': seam})
report = {'sha256': hashlib.sha256(raw).hexdigest(), 'bytes': len(raw),
          'skin_joints': len(skin['joints']), 'exported_vertices': vertices,
          'triangles': triangles, 'max_weight_sum_error': max_weight_error,
          'clips': clips, 'result': 'PASS'}
(DIR/'validation.json').write_text(json.dumps(report, indent=2)+'\n')
print(json.dumps(report, indent=2))
