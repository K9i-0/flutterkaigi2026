"""Sample the exported paired clips at 60 Hz; optionally render with --render.

Blender --background --factory-startup --python tools/audit_hazard_grapple.py
Finite vertices, loop seams and surface proximity are measured, not full cloth
collision or the subjective naturalness of a human grip.
"""
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / '21_SOBAYA_HAZARD_LAB/evidence'
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = 30
actors = {}
report = {'sampleHz': 60, 'separation': .70, 'models': {}}

for name, rel, clips in [
    ('sobaya', 'sobaya/rig_v3/sobaya_rig.glb', ['Grab', 'Hold', 'Release']),
    ('fukuchan', 'fukuchan/rig_v1/fukuchan.glb', ['Struggle', 'BreakFree']),
]:
    before = set(bpy.data.objects)
    path = ROOT / '04_GAME_ASSETS/3d/characters' / rel
    bpy.ops.import_scene.gltf(filepath=str(path))
    objects = set(bpy.data.objects) - before
    rig = next(o for o in objects if o.type == 'ARMATURE')
    mesh = max((o for o in objects if o.type == 'MESH'), key=lambda o: len(o.data.vertices))
    # Imported actions may animate the armature object's own transform.
    # Apply gameplay placement above the animated hierarchy, as Scene nodes do.
    placement = bpy.data.objects.new(name + 'Placement', None)
    scene.collection.objects.link(placement)
    for obj in objects:
        if obj.parent is None:
            obj.parent = placement
    for track in rig.animation_data.nla_tracks:
        track.mute = True
    actions = {n: bpy.data.actions[n] for n in clips}
    actors[name] = (rig, mesh, actions)
    results = {}
    for clip, action in actions.items():
        rig.animation_data.action = action
        rig.animation_data.action_slot = action.slots[0]
        end = int(round(action.frame_range[1]))
        first = last = None
        low = np.full(3, np.inf)
        high = np.full(3, -np.inf)
        for sample in range(end * 2 + 1):
            frame = sample / 2
            scene.frame_set(int(frame), subframe=frame % 1)
            evaluated = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
            posed = evaluated.to_mesh()
            coords = np.array([v.co[:] for v in posed.vertices])
            assert np.isfinite(coords).all()
            low = np.minimum(low, coords.min(axis=0))
            high = np.maximum(high, coords.max(axis=0))
            if first is None:
                first = coords.copy()
            last = coords.copy()
            evaluated.to_mesh_clear()
        seam = float(np.linalg.norm(last - first, axis=1).max())
        if clip in ['Hold', 'Struggle']:
            assert seam < .0001, (name, clip, seam)
        results[clip] = {'poses': end * 2 + 1, 'finite': True,
                         'endpointMaxVertexDelta': seam,
                         'boundsMin': low.tolist(), 'boundsMax': high.tolist()}
    report['models'][name] = {'source': str(path.relative_to(ROOT)),
                              'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                              'clips': results}

for name, (rig, mesh, actions) in actors.items():
    action = actions['Hold' if name == 'sobaya' else 'Struggle']
    rig.animation_data.action = action
    rig.animation_data.action_slot = action.slots[0]
    if name == 'fukuchan':
        placement = bpy.data.objects['fukuchanPlacement']
        placement.location.y = -.70
        placement.rotation_euler.z = math.pi

# Closest Sobaya hand-skin point to Fukuchan's skin in the shared loop.
# A small distance is proximity evidence, not a proof of a closed finger grip.
rows = []
for sample in range(61):
    scene.frame_set(sample // 2, subframe=(sample % 2) / 2)
    bpy.context.view_layer.update()
    surfaces = {}
    for name, (_, mesh, _) in actors.items():
        evaluated = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
        posed = evaluated.to_mesh()
        coords = [mesh.matrix_world @ v.co for v in posed.vertices]
        polygons = [tuple(p.vertices) for p in posed.polygons]
        surfaces[name] = (coords, BVHTree.FromPolygons(coords, polygons))
        evaluated.to_mesh_clear()
    mesh = actors['sobaya'][1]
    distances = {}
    for side in ['L', 'R']:
        group = mesh.vertex_groups['Hand.' + side].index
        indices = [v.index for v in mesh.data.vertices
                   if any(g.group == group and g.weight > .5 for g in v.groups)]
        distances[side] = min(surfaces['fukuchan'][1].find_nearest(
            surfaces['sobaya'][0][i])[3] for i in indices)
    rows.append(distances)
report['holdHandSurfaceGap'] = {
    side: [min(r[side] for r in rows), max(r[side] for r in rows)]
    for side in ['L', 'R']}
report['limits'] = 'Surface proximity only; no signed penetration, finger closure, swept collision or subjective motion pass.'
OUT.mkdir(parents=True, exist_ok=True)
(OUT / 'grapple-models.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2), flush=True)

if '--render' in sys.argv:
    scene.frame_set(9)
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 24
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = 1000, 850
    scene.render.resolution_percentage = 100
    scene.world = bpy.data.worlds.new('ReviewWorld')
    scene.world.color = (.3, .3, .3)
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -.012))
    for loc, power, size in [((2, -3, 5), 550, 4), ((-3, -1, 3), 400, 3), ((0, 3, 4), 350, 3)]:
        bpy.ops.object.light_add(type='AREA', location=loc)
        light = bpy.context.object
        light.data.energy, light.data.size = power, size
        light.rotation_euler = (Vector((0, -.3, 1)) - light.location).to_track_quat('-Z', 'Y').to_euler()
    bpy.ops.object.camera_add(location=(3, -2.5, 2.2))
    camera = bpy.context.object
    camera.rotation_euler = (Vector((0, -.35, 1)) - camera.location).to_track_quat('-Z', 'Y').to_euler()
    camera.data.type, camera.data.ortho_scale = 'ORTHO', 2.7
    scene.camera = camera
    scene.render.filepath = str(OUT / 'grapple-pair-exported.png')
    bpy.ops.render.render(write_still=True)
