"""Round-trip the exported Vault clips and sample window clearance at 60 Hz.
Run with Blender --background --factory-startup --python tools/audit_hazard_window_clearance.py.
The report records sampled vertices and contact drift, not a swept-mesh or
subjective animation-quality pass. The frame surface is x=+/-0.775 metres.
"""
import hashlib
import json
import math
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / '21_SOBAYA_HAZARD_LAB/evidence/window-clearance.json'
result = {'sampleHz': 60, 'wallHalfDepth': .175, 'apertureHalfWidth': .78,
          'sill': .82, 'lintel': 2.42, 'tolerance': .02, 'models': {}}
for name, relative in [('fukuchan', 'fukuchan/rig_v1/fukuchan.glb'),
                       ('sobaya', 'sobaya/rig_v3/sobaya_rig.glb')]:
    path = ROOT / '04_GAME_ASSETS/3d/characters' / relative
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)
    bpy.context.scene.render.fps = 30
    bpy.ops.import_scene.gltf(filepath=str(path))
    rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
    mesh = next(o for o in bpy.context.scene.objects if o.type == 'MESH')
    action = bpy.data.actions['Vault']
    rig.animation_data.action = action
    rig.animation_data.action_slot = action.slots[0]
    hand_name = 'Hand.L' if name == 'sobaya' else 'LeftHand'
    hand_group = mesh.vertex_groups[hand_name].index
    hand_indices = [v.index for v in mesh.data.vertices
                    if any(g.group == hand_group and g.weight > .5 for g in v.groups)]
    rows = []
    for sample in range(97):
        frame = sample / 2
        bpy.context.scene.frame_set(int(frame), subframe=frame % 1)
        bpy.context.view_layer.update()
        t = frame / 48
        root_y = .95 - 1.9 * t * t * (3 - 2 * t)
        root_z = .55 * math.sin(math.pi * t) ** 2
        evaluated = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
        posed = evaluated.to_mesh()
        coords = [mesh.matrix_world @ v.co for v in posed.vertices]
        assert all(math.isfinite(c) for v in coords for c in v)
        slab = [v for v in coords if abs(v.y + root_y) < .175]
        violations = [v for v in slab if v.z + root_z < .80 or
                      v.z + root_z > 2.44 or abs(v.x) > .80]
        hand = rig.matrix_world @ rig.pose.bones[hand_name].head
        surface = [coords[i] for i in hand_indices
                   if abs(coords[i].y + root_y) < .175]
        rows.append({'frame': frame, 'slabVertices': len(slab),
                     'violatingVertices': len(violations),
                     'minimumHeight': min((v.z + root_z for v in slab), default=None),
                     'maximumHalfWidth': max((abs(v.x) for v in slab), default=None),
                     'supportWrist': [hand.x, hand.y + root_y, hand.z + root_z],
                     'supportOuterSkinX': max((v.x for v in surface), default=None)})
        evaluated.to_mesh_clear()
    planted = [r for r in rows if .32 <= r['frame'] / 48 <= .48]
    wrist_ranges = [[min(r['supportWrist'][axis] for r in planted),
                     max(r['supportWrist'][axis] for r in planted)] for axis in range(3)]
    result['models'][name] = {
        'source': str(path.relative_to(ROOT)),
        'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
        'samples': len(rows), 'violatingVertexSamples': sum(r['violatingVertices'] for r in rows),
        'supportWristRanges': wrist_ranges,
        'maximumSupportWristAxisDrift': max(hi - lo for lo, hi in wrist_ranges),
        'supportSkinGapToFrame': [.775 - max(r['supportOuterSkinX'] for r in planted),
                                  .775 - min(r['supportOuterSkinX'] for r in planted)],
        'rows': rows,
    }
OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({n: {k: v for k, v in m.items() if k != 'rows'}
                  for n, m in result['models'].items()}, indent=2))
