"""Blender round-trip audit for the forested mountain pass.

Run from the repository root with Blender --background --factory-startup
--python tools/audit_hazard_mountain.py. This checks assets, not frame rate.
"""
import hashlib
import json
import math
import struct
import subprocess
from pathlib import Path

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parent.parent
REL = '04_GAME_ASSETS/3d/environments/mountain/mountain'
raw = (ROOT / (REL + '.glb')).read_bytes()
gltf = json.loads(raw[20:20 + struct.unpack_from('<I', raw, 12)[0]])
world = json.loads((ROOT / (REL + '.json')).read_text())
before = json.loads(subprocess.check_output(
    ['git', 'show', '018ca10:' + REL + '.json'], cwd=ROOT))
old_solids = before.pop('solids')
new_solids = world['solids']
assert {k: v for k, v in world.items() if k != 'solids'} == before
assert new_solids[30:] == old_solids[6:], 'non-terrain collision changed'
for index, old in enumerate(old_solids[:6]):
    layers = new_solids[index * 5:index * 5 + 5]
    assert layers[0] == dict(old, top=1.45), 'walking footprint changed'
    for lower, upper in zip(layers, layers[1:]):
        assert upper['x'] == old['x'] and upper['z'] == old['z']
        assert 0 < upper['w'] <= lower['w'] and 0 < upper['d'] <= lower['d']
        assert math.isclose(upper['bottom'], lower['top'])
        assert lower['top'] < upper['top'] <= old['top'] + .850001
primitives = [p for m in gltf['meshes'] for p in m['primitives']]
triangles = sum(gltf['accessors'][p['indices']]['count'] // 3 for p in primitives)
assert triangles <= 15000
assert len(primitives) <= 50
assert len(gltf['images']) <= 10
assert all('COLOR_0' in p['attributes'] for p in primitives)
assert len([n for n in gltf['nodes'] if n.get('name', '').startswith('MountainPines_')]) == 3
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(ROOT / (REL + '.glb')))
for obj in bpy.context.scene.objects:
    if obj.type == 'MESH':
        assert all(math.isfinite(c) for v in obj.data.vertices for c in v.co)
architecture = bpy.data.objects['StaticArchitecture']
vertices = [architecture.matrix_world @ v.co for v in architecture.data.vertices]
bvh = BVHTree.FromPolygons(vertices, [p.vertices[:] for p in architecture.data.polygons])
rays = 0
house = world['houses'][0]
checks = [(house['x'] + dx, house['z'] - house['d'] / 2, h)
          for dx in [-.6, 0, .6] for h in [.15, 1.15, 2.08]]
for window in world['windows']:
    checks.extend((window['x'] + dx, window['z'], h)
                  for dx in [-.52, 0, .52]
                  for h in [window['sill'] + .12, 1.65, window['top'] - .12])
for x, z, h in checks:
    assert bvh.ray_cast(Vector((x, z - .65, h)), Vector((0, 1, 0)), 1.3)[0] is None
    rays += 1
assert 'Roof_Ruins' in bpy.data.objects
report = {
    'date': '2026-09-13', 'passed': True,
    'sourceSha256': hashlib.sha256(raw).hexdigest(),
    'triangles': triangles, 'primitives': len(primitives),
    'images': len(gltf['images']), 'bytes': len(raw),
    'pineBatches': 3, 'walkingFootprintsUnchanged': True,
    'placementsAndNonTerrainCollisionUnchanged': True,
    'terrainCollision': 'Six footprints, each with a low skirt and four receding upper layers',
    'apertureRaysPassed': rays, 'frameRateMeasured': False,
}
output = ROOT / '21_SOBAYA_HAZARD_LAB/qa/mountain-forest-20260913.json'
output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(report, ensure_ascii=False))
