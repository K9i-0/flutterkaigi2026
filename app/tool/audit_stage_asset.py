"""Check geometry/texture budgets on the packaged GLB (no Blender required)."""
import json, struct
from pathlib import Path
p = Path(__file__).resolve().parents[2] / 'assets/3d/stages/akasaka/akasaka.glb'
b = p.read_bytes(); n = struct.unpack_from('<I', b, 12)[0]
j = json.loads(b[20:20+n]); binary = b[28+n:]
triangles = sum(j['accessors'][p['indices']]['count']//3 for m in j['meshes'] for p in m['primitives'])
primitives = sum(len(m['primitives']) for m in j['meshes'])
pixels = 0
for image in j['images']:
    v = j['bufferViews'][image['bufferView']]
    d = binary[v.get('byteOffset', 0):][:v['byteLength']]
    assert d[:8] == b'\x89PNG\r\n\x1a\n'
    w, h = struct.unpack_from('>II', d, 16)
    assert max(w, h) <= 1024, (image.get('name'), w, h)
    pixels += w*h
assert triangles <= 50000, triangles
assert primitives <= 41, primitives
heights = {
    m['name']: max(j['accessors'][p['attributes']['POSITION']]['max'][1]
                   for p in m['primitives'])
    for m in j['meshes']
}
# 200m support roof at y=0, ground y=-14; antenna tip is 333m.
assert abs(heights['white'] - (-14 + 333 * 14 / 200)) < .01
assert heights['white'] > max(heights[n] for n in heights if n.startswith('facade') or n == 'skyline')
assert 'lawn' in heights and 'foliage' in heights
assert not any(m.get('name') == 'ad_exam' for m in j['materials'])
assert not any(i.get('name') == 'ad_exam' for i in j['images'])
assert pixels*4 <= 14*1024*1024, 'Run optimize_stage_textures.py after Blender export'
assert not any(m.get('doubleSided', False) for m in j['materials'])
assert sum('normalTexture' in m for m in j['materials']) == 2
assert sum('metallicRoughnessTexture' in m.get('pbrMetallicRoughness', {}) for m in j['materials']) == 8
print(json.dumps({'triangles':triangles,'primitives':primitives,'rgba8BaseMiB':pixels*4/1024/1024,'glbBytes':len(b)},indent=2))
