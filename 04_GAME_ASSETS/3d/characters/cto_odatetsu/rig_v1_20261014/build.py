"""Bind the approved static GLB to a calibrated 54-bone humanoid skeleton.

No geometry, UV, material, texture, or other character asset is edited.
Run with Blender from any working directory; landmarks are in Blender Z-up metres.
"""
import bpy
import hashlib
import heapq
import json
import sys
import numpy as np
from pathlib import Path
from mathutils import Matrix, Vector

OUT = Path(__file__).resolve().parent
SOURCE = OUT.parent / 'finish_20261014/cto_odatetsu_static.glb'
SPEC = json.loads((OUT / 'landmarks.json').read_text())
sys.path.insert(0, str(OUT))
from arm_weights import arm_surface_masks
from neck_weights import neck_surface_masks
OUT.mkdir(exist_ok=True)
(OUT / 'qa').mkdir(exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = 30
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
mesh = next(o for o in bpy.context.scene.objects if o.type == 'MESH')
mesh.data.transform(mesh.matrix_world)
mesh.matrix_world = Matrix.Identity(4)
mesh.name = 'CTO_Odatetsu'
data = mesh.data
positions = np.array([tuple(v.co) for v in data.vertices])
uv = np.array([tuple(x.uv) for x in data.uv_layers.active.data])
topology = [tuple(f.vertices) for f in data.polygons]
arm = bpy.data.armatures.new('CTO_Odatetsu_Skeleton')
rig = bpy.data.objects.new('CTO_Odatetsu_Rig', arm)
bpy.context.collection.objects.link(rig)
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')

def bone(name, head, tail, parent=None, deform=True):
    b = arm.edit_bones.new(name)
    b.head, b.tail, b.use_deform = head, tail, deform
    if parent:
        b.parent = arm.edit_bones[parent]
    b.align_roll(Vector((0, -1, 0)))
    return b

bone('Root', (0, 0, 0), (0, 0, .1), deform=False)
core_names = ['Hips', 'Spine', 'Spine1', 'Spine2', 'Neck', 'Head']
for i, name in enumerate(core_names):
    bone(name, SPEC['core'][i], SPEC['core'][i + 1],
         'Root' if i == 0 else core_names[i - 1])
digits = SPEC['digits']
for side, suffix, sign in [('Left', 'L', 1), ('Right', 'R', -1)]:
    mirror = lambda p: (sign * p[0], p[1], p[2])
    for section, names, parent in [
            ('arm', ['Shoulder', 'Arm', 'ForeArm', 'Hand'], 'Spine2'),
            ('leg', ['UpLeg', 'Leg', 'Foot', 'ToeBase'], 'Hips')]:
        path = SPEC[section]
        for i, name in enumerate(names):
            bone(side + name, mirror(path[i]), mirror(path[i + 1]),
                 parent if i == 0 else side + names[i - 1])
    for digit, path in digits.items():
        for i in range(3):
            bone(f'{digit}{i + 1}.{suffix}', mirror(path[i]), mirror(path[i + 1]),
                 side + 'Hand' if i == 0 else f'{digit}{i}.{suffix}')
hand_tip = SPEC['arm'][-1]
bone('PropSocket.R', (-hand_tip[0], hand_tip[1], hand_tip[2]),
     (-hand_tip[0], hand_tip[1] - .05, hand_tip[2]), 'RightHand', False)
bpy.ops.object.mode_set(mode='OBJECT')
mesh.parent = rig
mesh.matrix_parent_inverse = Matrix.Identity(4)
modifier = mesh.modifiers.new('Skin', 'ARMATURE')
modifier.object = rig
# glTF uses linear blend skinning; preview the same deformation in Blender.
modifier.use_deform_preserve_volume = False
for b in arm.bones:
    if b.use_deform:
        mesh.vertex_groups.new(name=b.name)

def smooth(a, b, x):
    t = min(1., max(0., (x - a) / (b - a)))
    return t * t * (3 - 2 * t)

def core_weights(z, y, ax):
    stops = [(.84, 'Hips'), (.99, 'Spine'), (1.15, 'Spine1'),
             (1.31, 'Spine2'), (1.405, 'Neck'), (1.465, 'Head')]
    for (a, n), (b, k) in zip(stops, stops[1:]):
        if z < b:
            t = smooth(a, b, z)
            return {n: 1 - t, k: t}
    return {'Head': 1.}

arm_mix, arm_report = arm_surface_masks(data, SPEC['arm'])
hoodie_core, hair_rigid, neck_report = neck_surface_masks(data)
weights = []
for v in data.vertices:
    x, y, z = v.co
    side = 'Left' if x >= 0 else 'Right'
    ax = abs(x)
    if hair_rigid[v.index] or z > 1.465:
        w = {'Head': 1.}
    elif z < .69 or (z < .89 and ax < .265):
        hip = smooth(.70, .88, z)
        knee = smooth(.385, .55, z)
        ankle = smooth(.12, .235, z)
        toe = (1 - smooth(-.15, -.07, y)) * (1 - smooth(.065, .11, z)) * .65
        leg = {side + 'UpLeg': knee * (1 - hip),
               side + 'Leg': (1 - knee) * ankle * (1 - hip),
               side + 'Foot': (1 - knee) * (1 - ankle) * (1 - hip) * (1 - toe),
               side + 'ToeBase': (1 - knee) * (1 - ankle) * (1 - hip) * toe,
               'Hips': hip}
        middle = (1 - smooth(.012, .075, ax)) * smooth(.65, .79, z)
        w = {}
        for n, k in leg.items():
            if n == 'Hips':
                w[n] = k
            else:
                w[n] = k * (1 - .5 * middle)
                w[n.replace(side, 'Right' if side == 'Left' else 'Left')] = k * .5 * middle
    else:
        mix = arm_mix[v.index]
        upper = smooth(1.01, 1.15, z)
        wrist = smooth(.895, .96, z)
        shoulder = smooth(1.265, 1.345, z) * (1 - smooth(.12, .235, ax)) * .35
        aw = {side + 'Shoulder': shoulder,
              side + 'Arm': upper * (1 - shoulder),
              side + 'ForeArm': (1 - upper) * wrist * (1 - shoulder),
              side + 'Hand': (1 - upper) * (1 - wrist) * (1 - shoulder)}
        core = {'Spine2': 1.} if hoodie_core[v.index] else core_weights(z, y, ax)
        w = {n: k * (1 - mix) for n, k in core.items()}
        for n, k in aw.items():
            w[n] = w.get(n, 0) + k * mix
    weights.append(w)

# UV splits must receive identical weights. Surface adjacency keeps nearby
# disconnected fingers/arms from accidentally influencing one another.
groups = {}
for v in data.vertices:
    groups.setdefault(tuple(round(c, 5) for c in v.co), []).append(v.index)
adj = [set() for _ in data.vertices]
for e in data.edges:
    a, b = e.vertices
    adj[a].add(b)
    adj[b].add(a)
for ids in groups.values():
    neighbors = set(ids).union(*(adj[i] for i in ids))
    for i in ids:
        adj[i] = neighbors - {i}

digit_counts = {}
for suffix, side, sign in [('L', 'Left', 1), ('R', 'Right', -1)]:
    active = {v.index for v in data.vertices if sign * v.co.x > .29 and .69 < v.co.z < .91}
    distances = {}
    for digit, path in digits.items():
        tip = Vector((sign * path[-1][0], *path[-1][1:]))
        seed = min(active, key=lambda i: (data.vertices[i].co - tip).length_squared)
        distance, heap = {seed: 0.}, [(0., seed)]
        while heap:
            d, i = heapq.heappop(heap)
            if d > distance[i] + 1e-10:
                continue
            for j in adj[i] & active:
                candidate = d + (data.vertices[i].co - data.vertices[j].co).length
                if candidate < distance.get(j, 1e10):
                    distance[j] = candidate
                    heapq.heappush(heap, (candidate, j))
        distances[digit] = distance
    for i in active:
        p = data.vertices[i].co
        digit = min(digits, key=lambda d: distances[d].get(i, 1e10))
        if distances[digit].get(i, 1e10) == 1e10:
            continue
        path = digits[digit]
        influence = 1 - smooth(path[0][2] - .009, path[0][2] + .012, p.z)
        if influence < 1e-6:
            continue
        second = 1 - smooth(path[1][2] - .009, path[1][2] + .009, p.z)
        third = 1 - smooth(path[2][2] - .007, path[2][2] + .007, p.z)
        weights[i] = {side + 'Hand': 1 - influence,
                      f'{digit}1.{suffix}': influence * (1 - second),
                      f'{digit}2.{suffix}': influence * second * (1 - third),
                      f'{digit}3.{suffix}': influence * second * third}
        digit_counts[digit + '.' + suffix] = digit_counts.get(digit + '.' + suffix, 0) + 1
for iteration in range(3):
    result = []
    for i, v in enumerate(data.vertices):
        w = weights[i].copy()
        if .17 < v.co.z < 1.445 and adj[i]:
            w = {n: k * .75 for n, k in w.items()}
            for j in adj[i]:
                for n, k in weights[j].items():
                    w[n] = w.get(n, 0) + k * .25 / len(adj[i])
        result.append(w)
    weights = result
for ids in groups.values():
    average = {}
    for i in ids:
        for n, k in weights[i].items():
            average[n] = average.get(n, 0) + k / len(ids)
    entries = sorted(((n, k) for n, k in average.items() if k > 1e-7), key=lambda p: -p[1])[:4]
    total = sum(k for _, k in entries)
    assert total > 0
    for name, value in entries:
        mesh.vertex_groups[name].add(ids, value / total, 'REPLACE')
for b in rig.pose.bones:
    b.rotation_mode = 'QUATERNION'
rig.show_in_front = True
assert len(arm.bones) == 54
assert np.array_equal(positions, np.array([tuple(v.co) for v in data.vertices]))
assert np.array_equal(uv, np.array([tuple(x.uv) for x in data.uv_layers.active.data]))
assert topology == [tuple(f.vertices) for f in data.polygons]
assert all(1 <= len(v.groups) <= 4 and abs(sum(g.weight for g in v.groups) - 1) < 1e-5 for v in data.vertices)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'cto_odatetsu_rig.blend'))
report = {'source': str(SOURCE.relative_to(OUT.parents[4])),
          'source_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
          'bones': len(arm.bones), 'vertices': len(data.vertices),
          'shape_uv_topology_preserved': True, 'materials_and_textures_unedited': True,
          'max_influences': 4, 'normalized_weights': True,
          'coincident_vertex_groups': len(groups), 'finger_weight_vertices': digit_counts,
          'rig_coordinates': 'Z up, forward -Y, anatomical left +X, metres',
          'arm_surface_separation': arm_report,
          'neck_surface_separation': neck_report}
(OUT / 'bind_report.json').write_text(json.dumps(report, indent=2) + '\n')
print('ODATETSU_RIG_READY', flush=True)
