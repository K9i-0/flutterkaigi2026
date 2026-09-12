"""Round-trip the adopted GLBs and verify rear apertures/opaque cover.

Blender --background --factory-startup --python tools/audit_hazard_stealth_map.py
This checks rendered mesh geometry independently of gameplay JSON colliders.
The diagnostic overhead images are not screenshots of the game renderer.
"""
import hashlib
import json
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parent.parent
LAB = ROOT / '21_SOBAYA_HAZARD_LAB'
report = {'description': 'Exported mesh aperture and cover ray audit', 'maps': {}}


def cast(a, b):
    start, end = Vector(a), Vector(b)
    delta = end - start
    hit = bpy.context.scene.ray_cast(
        bpy.context.evaluated_depsgraph_get(), start, delta.normalized(),
        distance=delta.length)
    return hit[4].name if hit[0] else None


for name, folder in [('village', 'pueblo'), ('farm', 'farm')]:
    directory = ROOT / '04_GAME_ASSETS/3d/environments' / folder
    glb, map_file = directory / f'{name}.glb', directory / f'{name}.json'
    world = json.loads(map_file.read_text())
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(glb))
    bpy.context.view_layer.update()
    checks = []
    for house in world['houses']:
        if 'rearDoor' not in house:
            continue
        door = house['rearDoor']
        x, z = door['x'], door['z']
        for dx in [-.42, 0, .42]:
            for height in [.15, 1.15, 1.72]:
                hit = cast((x + dx, z - .7, height),
                           (x + dx, z + .7, height))
                assert hit is None, (name, house['id'], dx, height, hit)
        for dx in [-1.35, 1.35]:
            hit = cast((x + dx, z - .7, 1.15), (x + dx, z + .7, 1.15))
            assert hit and (hit.startswith('House_' + house['id']) or hit == 'StaticArchitecture'), (
                name, house['id'], 'wall beside opening', hit)
        checks.append({'rearDoor': house['id'], 'x': x, 'z': z,
                       'clearBodyWidth': .84, 'clearHeadHeight': 1.72,
                       'raysPassed': 11})
    for solid in world['solids']:
        if not (solid.get('id') or '').startswith('cover_'):
            continue
        x, z = solid['x'], solid['z']
        dx, dz = (.65, 0) if solid['w'] < solid['d'] else (0, .65)
        for height in [.25, 1.15, 1.7, 2.1]:
            hit = cast((x - dx, z - dz, height), (x + dx, z + dz, height))
            expected = 'Cover_' + solid['id'][len('cover_'):]
            assert hit and hit.startswith(expected), (name, solid['id'], height, hit)
        checks.append({'opaqueCover': solid['id'], 'raysPassed': 4})
    if name == 'farm':
        for x, z in [(-11, -16), (-20, 8), (-18, 17), (0, 19), (19, 21), (-21, -3)]:
            hit = cast((x - .5, z, 1.2), (x + .5, z, 1.2))
            assert hit and ('trunk' in hit.lower() or 'tree' in hit.lower()), (x, z, hit)
        checks.append({'playableTrunks': 6, 'raysPassed': 6})
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_WORKBENCH'
    scene.display.shading.light = 'STUDIO'
    scene.display.shading.color_type = 'MATERIAL'
    scene.display.shading.show_shadows = True
    scene.display.shading.show_cavity = True
    scene.display.shading.cavity_type = 'BOTH'
    scene.render.resolution_x = 1000
    scene.render.resolution_y = 1100
    scene.render.resolution_percentage = 100
    camera = bpy.data.cameras.new('Stealth overhead audit')
    camera.type, camera.ortho_scale = 'ORTHO', 62
    obj = bpy.data.objects.new('Stealth overhead audit', camera)
    scene.collection.objects.link(obj)
    obj.location = (0, -5, 65)
    obj.rotation_euler = (Vector((0, 1, 0)) - obj.location).to_track_quat('-Z', 'Y').to_euler()
    scene.camera = obj
    image = LAB / 'evidence' / f'stealth-{name}-overhead.png'
    image.parent.mkdir(exist_ok=True, parents=True)
    scene.render.filepath = str(image)
    bpy.ops.render.render(write_still=True)
    report['maps'][name] = {
        'glb': str(glb.relative_to(ROOT)),
        'glbSha256': hashlib.sha256(glb.read_bytes()).hexdigest(),
        'mapSha256': hashlib.sha256(map_file.read_bytes()).hexdigest(),
        'checks': checks, 'passed': True,
        'diagnosticOverhead': str(image.relative_to(LAB)),
    }

out = LAB / 'qa/stealth-map-geometry-20260908.json'
out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(report, ensure_ascii=False, indent=2))
