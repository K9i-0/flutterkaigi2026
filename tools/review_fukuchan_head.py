"""Render a GLB's head from four angles and audit animation/morph preservation.

Blender -b --factory-startup --python tools/review_fukuchan_head.py -- model.glb output_dir
"""
import bpy, json, math, sys, hashlib, struct
from pathlib import Path
from mathutils import Vector, Matrix

args = sys.argv[sys.argv.index('--') + 1:]
path, out = Path(args[0]).resolve(), Path(args[1]).resolve()
out.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(path))
binary = path.read_bytes()
document = json.loads(binary[20:20 + struct.unpack_from('<I', binary, 12)[0]])
source_mesh_nodes = {n['name'] for n in document['nodes'] if 'mesh' in n}
# The importer creates an Icosphere bone-display helper. It is not asset geometry.
for obj in list(bpy.context.scene.objects):
    if obj.type == 'MESH' and obj.name not in source_mesh_nodes:
        bpy.data.objects.remove(obj, do_unlink=True)
rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
actions = list(bpy.data.actions)
clips = [a.name for a in actions]
rig.animation_data_clear()
for bone in rig.pose.bones:
    bone.matrix_basis = Matrix.Identity(4)
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
report = {'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'bytes': path.stat().st_size,
          'joints': len(rig.data.bones), 'clips': clips, 'meshes': []}
for mesh in meshes:
    mesh.data.calc_loop_triangles()
    keys = mesh.data.shape_keys
    if keys:
        keys.animation_data_clear()
        for key in keys.key_blocks:
            key.value = 0
    report['meshes'].append({'name': mesh.name, 'triangles': len(mesh.data.loop_triangles),
                            'morphs': [k.name for k in keys.key_blocks] if keys else []})
pose_count = 0
largest_head_span = 0.
rig.animation_data_create()
for action in actions:
    rig.animation_data.action = action
    if action.slots:
        rig.animation_data.action_slot = action.slots[0]
    start, end = action.frame_range
    for sample in range(9):
        frame = start + (end - start) * sample / 8
        bpy.context.scene.frame_set(int(frame), subframe=frame % 1)
        for mesh in meshes:
            evaluated = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
            posed = evaluated.to_mesh()
            assert all(math.isfinite(c) for v in posed.vertices for c in v.co)
            if mesh.name == 'FukuchanHead':
                spans = [max(v.co[i] for v in posed.vertices) - min(v.co[i] for v in posed.vertices) for i in range(3)]
                largest_head_span = max(largest_head_span, max(spans))
                assert max(spans) < .5, ('Deformed head bounds', action.name, sample, spans)
            evaluated.to_mesh_clear()
        pose_count += 1
rig.animation_data_clear()
for bone in rig.pose.bones:
    bone.matrix_basis = Matrix.Identity(4)
for sample in range(11):
    for mesh in meshes:
        keys = mesh.data.shape_keys
        if keys:
            keys.key_blocks['SpeechOpen'].value = sample / 10
            keys.key_blocks['SpeechNarrow'].value = sample / 50
            evaluated = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
            posed = evaluated.to_mesh()
            assert all(math.isfinite(c) for v in posed.vertices for c in v.co)
            evaluated.to_mesh_clear()
report['pose_audit'] = {'bodyPoses': pose_count, 'speechPoses': 11,
                        'finite': True, 'maximumHeadAxisSpan': largest_head_span}
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 24
scene.cycles.use_denoising = True
scene.render.resolution_x = scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
scene.world = bpy.data.worlds.new('HeadReview')
scene.world.color = (.35, .35, .35)
target = Vector((0, 0, 1.535))
for location, power in [((2, -3, 4), 450), ((-2, -2, 2), 250), ((0, 3, 3), 180)]:
    bpy.ops.object.light_add(type='AREA', location=location)
    light = bpy.context.object
    light.data.energy, light.data.size = power, 3
    light.rotation_euler = (target - light.location).to_track_quat('-Z', 'Y').to_euler()
bpy.ops.object.camera_add()
camera = bpy.context.object
camera.data.type = 'ORTHO'
camera.data.ortho_scale = .39
scene.camera = camera
for name, position in [('front', (0, -3, 1.535)), ('three-quarter', (2, -3, 1.535)),
                       ('side', (3, 0, 1.535)), ('back', (0, 3, 1.535)),
                       ('speech', (0, -3, 1.535))]:
    for mesh in meshes:
        if mesh.data.shape_keys:
            mesh.data.shape_keys.key_blocks['SpeechOpen'].value = .85 if name == 'speech' else 0
            mesh.data.shape_keys.key_blocks['SpeechNarrow'].value = .17 if name == 'speech' else 0
    camera.location = position
    camera.rotation_euler = (target - camera.location).to_track_quat('-Z', 'Y').to_euler()
    scene.render.filepath = str(out / (name + '.png'))
    bpy.ops.render.render(write_still=True)
report['triangles'] = sum(m['triangles'] for m in report['meshes'])
(out / 'audit.json').write_text(json.dumps(report, indent=2) + '\n')
print('HEAD_REVIEW', json.dumps(report), flush=True)
