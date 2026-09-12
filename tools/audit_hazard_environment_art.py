"""Round-trip environment assets and independently audit traversable apertures.

Run with Blender --background --factory-startup --python this_file.py.
JSON layout hashes are compared with the pre-art-pass baseline recorded here;
update that baseline only when a later task intentionally changes gameplay.
"""
import hashlib
import json
import math
import struct
from pathlib import Path

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parent.parent
BASELINE = {
    'village': {'folder': 'pueblo', 'triangles': 17932, 'primitives': 153,
                'bytes': 12656064, 'images': 12, 'triangleBudget': 30000,
                'primitiveBudget': 170,
                'layoutSha256': 'd6e469fc243628e49d4be6240fa53a553369b5177c36d7c75da05724757ca2fb'},
    'farm': {'folder': 'farm', 'triangles': 13655, 'primitives': 113,
             'bytes': 12658448, 'images': 10, 'triangleBudget': 24000,
             'primitiveBudget': 126,
             'layoutSha256': '884cd3bc01228a4248383485d59ff10da18d135519328e2b4a1f51408bafb875'},
    'mountain': {'folder': 'mountain', 'triangles': 9043, 'primitives': 46,
                 'bytes': 12171680, 'images': 10, 'triangleBudget': 15000,
                 'primitiveBudget': 50,
                 'layoutSha256': 'cc6b8c3e688e14138fbe98f3213090164ea0088e652c4ce8b93b79397bb9567a'},
}
NATIVE_V1_TRIANGLES = {'village': 26115, 'farm': 19869, 'mountain': 12701}
NATIVE_V2_PRIMITIVES = {'village': 167, 'farm': 123, 'mountain': 48}
HOUSE_BATCH_REDUCTION = {'village': 40, 'farm': 30, 'mountain': 0}


def assert_clear(bvh, x, z, height):
    start, end = Vector((x, z - .65, height)), Vector((x, z + .65, height))
    direction = end - start
    hit = bvh.ray_cast(start, direction.normalized(), direction.length)
    assert hit[0] is None, (x, z, height, hit[0])


report = {'date': '2026-09-12', 'description': 'Exported GLB geometry, COLOR_0 and budget audit; not an FPS measurement',
          'iteration': {'number': 2,
                        'reference': 'evidence/graphics-20260912/after-village-v1.png',
                        'finding': 'Bright upright triangular foliage distracted from the buildings',
                        'change': 'Low two-triangle folded leaves, dark muted olive tint, sparse foundation stones',
                        'costConstraint': 'Triangle totals at or below native v1; primitives and images unchanged'},
          'regions': {}}
for region, baseline in BASELINE.items():
    directory = ROOT / '04_GAME_ASSETS/3d/environments' / baseline['folder']
    glb_path, map_path = directory / f'{region}.glb', directory / f'{region}.json'
    raw = glb_path.read_bytes()
    json_length = struct.unpack_from('<I', raw, 12)[0]
    gltf = json.loads(raw[20:20 + json_length])
    primitives = [p for m in gltf['meshes'] for p in m['primitives']]
    triangles = sum(gltf['accessors'][p['indices']]['count'] // 3 for p in primitives)
    layout_hash = hashlib.sha256(map_path.read_bytes()).hexdigest()
    assert layout_hash == baseline['layoutSha256'], (region, 'gameplay layout changed')
    assert triangles <= baseline['triangleBudget'], (region, triangles)
    assert triangles <= NATIVE_V1_TRIANGLES[region], (region, 'foliage pass exceeded native v1 triangle count')
    assert len(primitives) <= baseline['primitiveBudget'], (region, len(primitives))
    assert len(gltf['images']) == baseline['images'], (region, 'texture count increased')
    assert all('COLOR_0' in p['attributes'] for p in primitives), (region, 'lost vertex colour')
    batch_node = next(n for n in gltf['nodes'] if n.get('name') == 'StaticArchitecture')
    batch_report = json.loads(batch_node['extras']['hazardArchitectureBatch'])
    assert batch_report['before'] == batch_report['after'], (region, 'batch payload mismatch')
    assert batch_report['primitiveReduction'] == HOUSE_BATCH_REDUCTION[region]
    assert len(primitives) == NATIVE_V2_PRIMITIVES[region] - HOUSE_BATCH_REDUCTION[region]
    assert len(gltf['meshes'][batch_node['mesh']]['primitives']) == batch_report['primitiveCountAfter']
    world = json.loads(map_path.read_text())
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(glb_path))
    checks = []
    architecture = next(o for o in bpy.context.scene.objects if o.name == 'StaticArchitecture')
    vertices = [architecture.matrix_world @ v.co for v in architecture.data.vertices]
    assert all(math.isfinite(c) for v in vertices for c in v)
    tree = BVHTree.FromPolygons(vertices, [p.vertices[:] for p in architecture.data.polygons])
    for house in world['houses']:
        rays = 0
        for side in [-1, 1]:
            if side > 0 and 'rearDoor' not in house:
                continue
            for dx in [-.60, 0, .60]:
                for height in [.15, 1.15, 2.08]:
                    assert_clear(tree, house['x'] + dx, house['z'] + side * house['d'] / 2, height)
                    rays += 1
        for window in world.get('windows', []):
            if not window['id'].startswith(house['id'] + '_'):
                continue
            for dx in [-.52, 0, .52]:
                for height in [window['sill'] + .12, 1.65, window['top'] - .12]:
                    assert_clear(tree, window['x'] + dx, window['z'], height)
                    rays += 1
        assert any(o.name == 'Roof_' + house['id'] for o in bpy.context.scene.objects)
        checks.append({'house': house['id'], 'apertureRaysPassed': rays, 'roofVisibilityNodeRetained': True})
    report['regions'][region] = {
        'source': str(glb_path.relative_to(ROOT)), 'sha256': hashlib.sha256(raw).hexdigest(),
        'layoutSha256': layout_hash, 'layoutUnchanged': True,
        'before': {k: baseline[k] for k in ['triangles', 'primitives', 'bytes', 'images']},
        'after': {'triangles': triangles, 'primitives': len(primitives), 'bytes': len(raw),
                  'images': len(gltf['images']), 'materials': len(gltf['materials']),
                  'meshes': len(gltf['meshes']), 'vertexColorPrimitives': len(primitives)},
        'budget': {k: baseline[k] for k in ['triangleBudget', 'primitiveBudget']},
        'nativeV1Triangles': NATIVE_V1_TRIANGLES[region],
        'architectureBatch': batch_report,
        'checks': checks, 'passed': True,
    }
output = ROOT / '21_SOBAYA_HAZARD_LAB/qa/environment-art-20260912.json'
output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(report, ensure_ascii=False, indent=2))
