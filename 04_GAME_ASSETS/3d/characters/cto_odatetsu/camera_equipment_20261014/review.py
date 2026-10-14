"""Review the exported pose with the actual camera; --placeholder is diagnostic."""
import bpy
import hashlib
import json
import math
from pathlib import Path
import struct
import sys
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from build_pose import read_glb, matrices, C, CAMERA
sys.path.insert(0, str(HERE.parents[4] / 'tools'))
from build_humanoid_motion import use_action, clear_pose
QA = HERE / 'qa'
QA.mkdir(exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = 30
bpy.ops.import_scene.gltf(filepath=str(HERE / 'cto_odatetsu_camera.glb'))
rig = next(o for o in scene.objects if o.type == 'ARMATURE')
rig.animation_data_clear()
clear_pose(rig)
use_action(rig, bpy.data.actions['CameraCarry'])
scene.frame_set(0)
bpy.context.view_layer.update()
doc, binary = read_glb(HERE / 'cto_odatetsu_camera.glb')
clip = next(a for a in doc['animations'] if a['name'] == 'CameraCarry')
for channel in clip['channels']:
    accessor = doc['accessors'][clip['samplers'][channel['sampler']]['output']]
    view = doc['bufferViews'][accessor['bufferView']]
    width = 4 if accessor['type'] == 'VEC4' else 3
    values = struct.unpack_from('<' + 'f' * width, binary, view.get('byteOffset', 0) + accessor.get('byteOffset', 0))
    doc['nodes'][channel['target']['node']][channel['target']['path']] = values
raw, _ = matrices(doc)
socket = next(i for i, n in enumerate(doc['nodes']) if n.get('name') == 'PropSocket.R')
spec = json.loads((HERE / 'attachment.json').read_text())
mount = Matrix([spec['socketToGrip'][i::4] for i in range(4)])
if CAMERA.exists() and '--placeholder' not in sys.argv:
    camera_doc, _ = read_glb(CAMERA)
    camera_matrices, _ = matrices(camera_doc)
    anchor_index = next(i for i, n in enumerate(camera_doc['nodes']) if n.get('name') == 'GripAnchor')
    grip_in_camera = camera_matrices[anchor_index]
else:
    grip_in_camera = Matrix.Translation(Vector(spec['placeholderCamera']['gripInCamera']))
camera_world_gltf = raw[socket] @ mount @ grip_in_camera.inverted()

def material(name, color, roughness=.5):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    bs = m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value = (*color, 1)
    bs.inputs['Roughness'].default_value = roughness
    return m

black = material('Placeholder camera black', (.025, .025, .03))
white = material('Placeholder lens white', (.70, .68, .63))
glass = material('Placeholder lens glass', (.025, .065, .08), .1)
root = bpy.data.objects.new('Equipped camera', None)
scene.collection.objects.link(root)
root.matrix_world = C.inverted() @ camera_world_gltf

def part(name, center, dimensions, mat, cylinder=False):
    if cylinder:
        bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=dimensions[0]/2, depth=dimensions[2])
    else:
        bpy.ops.mesh.primitive_cube_add(size=1)
    obj = bpy.context.object
    obj.name = name
    obj.parent = root
    obj.matrix_parent_inverse = Matrix.Identity(4)
    obj.location = center
    if not cylinder:
        obj.scale = dimensions
        bevel = obj.modifiers.new('Rounded placeholder edges', 'BEVEL')
        bevel.width = .07
        bevel.segments = 3
    for p in obj.data.polygons:
        p.use_smooth = True
    obj.data.materials.append(mat)
    return obj

if CAMERA.exists() and '--placeholder' not in sys.argv:
    before = set(scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(CAMERA))
    imported = set(scene.objects) - before
    root.matrix_world = C.inverted() @ camera_world_gltf @ C
    for obj in imported:
        if obj.parent not in imported:
            local = obj.matrix_world.copy()
            obj.parent = root
            obj.matrix_parent_inverse = Matrix.Identity(4)
            obj.matrix_basis = local
    bpy.context.view_layer.update()
    grip_obj = next(o for o in imported if o.name == 'GripAnchor')
    desired_grip = (C.inverted() @ raw[socket] @ mount).translation
    grip_error = (grip_obj.matrix_world.translation - desired_grip).length
    assert grip_error < 1e-5, grip_error
    print('ACTUAL_CAMERA_ATTACHED', CAMERA, 'grip_error_m', grip_error, flush=True)
    # Check head/hood clearance against the actual camera triangles. The grip
    # region is excluded from the broad body intersection check intentionally.
    dg = bpy.context.evaluated_depsgraph_get()
    camera_points, camera_faces = [], []
    for obj in imported:
        if obj.type != 'MESH':
            continue
        ev = obj.evaluated_get(dg)
        offset = len(camera_points)
        camera_points.extend(ev.matrix_world @ v.co for v in ev.data.vertices)
        camera_faces.extend(tuple(offset+i for i in p.vertices) for p in ev.data.polygons)
    camera_bvh = BVHTree.FromPolygons(camera_points, camera_faces)
    body = next(o for o in scene.objects if o.type == 'MESH' and any(m.type == 'ARMATURE' for m in o.modifiers))
    evaluated = body.evaluated_get(dg)
    points = [evaluated.matrix_world @ v.co for v in evaluated.data.vertices]
    assert len(points) == len(body.data.vertices)
    weight_names = {g.index: g.name for g in body.vertex_groups}
    head_ids, hood_ids, non_grip_ids, grip_ids = set(), set(), set(), set()
    for v in body.data.vertices:
        weights = {weight_names[g.group]: g.weight for g in v.groups}
        if weights.get('Head', 0) > .8:
            head_ids.add(v.index)
        if .02 < v.co.y and 1.18 < v.co.z < 1.46 and abs(v.co.x) < .24:
            hood_ids.add(v.index)
        hand = sum(value for name, value in weights.items() if name == 'RightHand' or name.endswith('.R'))
        if hand < .2:
            non_grip_ids.add(v.index)
        else:
            grip_ids.add(v.index)
    clearances = {}
    for name, ids in [('head_and_hair', head_ids), ('back_hood', hood_ids), ('body_excluding_right_grip', non_grip_ids), ('right_grip', grip_ids)]:
        faces = [tuple(p.vertices) for p in body.data.polygons if all(i in ids for i in p.vertices)]
        bvh = BVHTree.FromPolygons(points, faces)
        overlaps = camera_bvh.overlap(bvh)
        distances = [camera_bvh.find_nearest(points[i])[3] for i in ids]
        clearances[name] = {'sampledVertices': len(ids), 'surfaceIntersectionPairs': len(overlaps),
                            'minimumBodyVertexToCameraDistanceM': min(distances),
                            'bodyVerticesWithin2mm': sum(d < .002 for d in distances)}
        if name == 'right_grip':
            signed = []
            for i in ids:
                point, normal, _, distance = camera_bvh.find_nearest(points[i])
                signed.append((points[i]-point).dot(normal))
            clearances[name]['maximumSignedNearestSurfacePenetrationM'] = max(0, -min(signed))
            clearances[name]['verticesBeyond2mmInsideNearestSurface'] = sum(d < -.002 for d in signed)
    report = {'cameraSha256': hashlib.sha256(CAMERA.read_bytes()).hexdigest(),
              'rigSha256': hashlib.sha256((HERE / 'cto_odatetsu_camera.glb').read_bytes()).hexdigest(),
              'attachmentSha256': hashlib.sha256((HERE / 'attachment.json').read_bytes()).hexdigest(),
              'gripAnchorErrorM': grip_error, 'clearances': clearances,
              'notes': 'Triangle intersection check plus one-way vertex-to-surface distances. Generated meshes are not guaranteed watertight: signed nearest-normal statistics are diagnostics, not closed-volume penetration depths. Does not certify physical hand contact or cloth simulation.'}
    (HERE / 'contact_review.json').write_text(json.dumps(report, indent=2) + '\n')
    print('CAMERA_CONTACT_CHECK', clearances, flush=True)
    if '--fit' in sys.argv:
        candidates = []
        for dx in [-.01, 0, .01, .02]:
            for dy in [-.01, 0, .01]:
                for dz in [-.01, 0, .01]:
                    delta = Vector((dx, dy, dz))
                    signed, distances = [], []
                    for i in grip_ids:
                        point, normal, _, distance = camera_bvh.find_nearest(points[i]-delta)
                        signed.append((points[i]-delta-point).dot(normal))
                        distances.append(distance)
                    penetration = max(0, -min(signed))
                    contact = sum(d < .002 for d in distances)
                    penalty = sum(max(0, -d-.002)**2 for d in signed)
                    candidates.append({'deltaWorldBlender': list(delta), 'maximumSignedDepthM': penetration,
                                       'verticesInsideBeyond2mm': sum(d < -.002 for d in signed),
                                       'verticesWithin2mm': contact, 'penalty': penalty})
        candidates.sort(key=lambda row: row['penalty'] if row['verticesWithin2mm'] >= 50 else 1e3)
        (QA / 'grip_fit_candidates.json').write_text(json.dumps(candidates, indent=2) + '\n')
        print('GRIP_FIT_CANDIDATES', candidates[:8], flush=True)
else:
    part('Camera body placeholder', (0, 0, -.04), (.13, .10, .08), black)
    part('Lens barrel placeholder', (0, 0, .10), (.089, .089, .20), white, True)
    part('Focus ring placeholder', (0, 0, .065), (.091, .091, .030), black, True)
    part('Zoom ring placeholder', (0, 0, .145), (.091, .091, .032), black, True)
    part('Lens hood placeholder', (0, 0, .235), (.103, .103, .07), white, True)
    part('Lens glass placeholder', (0, 0, .272), (.094, .094, .004), glass, True)
    part('Tripod foot placeholder', (0, -.066, .09), (.035, .032, .075), white)

scene.render.engine = 'CYCLES'
scene.cycles.samples = 12
scene.cycles.use_denoising = True
scene.render.resolution_percentage = 100
scene.view_settings.view_transform = 'Standard'
world = bpy.data.worlds.new('Camera pose review studio')
world.use_nodes = True
world.node_tree.nodes['Background'].inputs[0].default_value = (.75, .75, .75, 1)
world.node_tree.nodes['Background'].inputs[1].default_value = .7
scene.world = world
camera = bpy.data.objects.new('Review Camera', bpy.data.cameras.new('Review Camera'))
scene.collection.objects.link(camera)
camera.data.type = 'ORTHO'
scene.camera = camera
for name, location, power, size in [('Key', (2, -3, 4), 160, 4),
                                   ('Fill', (-3, -2, 2), 100, 3),
                                   ('Rim', (1, 3, 3), 140, 3)]:
    light = bpy.data.lights.new(name, 'AREA')
    light.energy, light.shape, light.size = power, 'DISK', size
    obj = bpy.data.objects.new(name, light)
    scene.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (Vector((0, 0, .9)) - obj.location).to_track_quat('-Z', 'Y').to_euler()

def render(name, direction, center, size, resolution=(720, 900)):
    target = Vector(center)
    camera.location = target + Vector(direction).normalized() * 5
    camera.rotation_euler = (target - camera.location).to_track_quat('-Z', 'Y').to_euler()
    camera.data.ortho_scale = size
    scene.render.resolution_x, scene.render.resolution_y = resolution
    scene.render.filepath = str(QA / (name + '.png'))
    bpy.ops.render.render(write_still=True)

if '--audit-only' in sys.argv or '--fit' in sys.argv:
    pass
elif '--quick' in sys.argv:
    render('camera_carry_front', (0, -1, .02), (0, 0, .91), 2.02)
else:
    render('camera_carry_front', (0, -1, .02), (0, 0, .91), 2.02)
    render('camera_carry_three_quarter', (.55, -1, .10), (0, 0, .91), 2.02)
    render('camera_carry_back', (.25, 1, .05), (0, 0, .91), 2.02)
    render('camera_grip_close', (-.6, -1, .05), (-.31, -.08, 1.36), .48, (900, 900))
    render('waist_hand_close', (.3, -1, .08), (.25, -.08, 1.08), .53, (900, 900))
print('CAMERA_CARRY_REVIEW_DONE', flush=True)
