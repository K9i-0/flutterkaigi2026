"""Append an authored CameraCarry pose without rewriting the original GLB data.

Run with Blender 5.1.2. The camera is a separate asset. Body geometry, skin,
materials, original node rest transforms and all 20 existing clips are copied
verbatim. Only a new animation and its accessors/buffer views are appended.
"""
from __future__ import annotations
import hashlib
import json
import math
from pathlib import Path
import struct
import sys

import bpy
from mathutils import Matrix, Quaternion, Vector

HERE = Path(__file__).resolve().parent
SOURCE = HERE.parent / 'rig_v1_20261014/cto_odatetsu_rig.glb'
OUTPUT = HERE / 'cto_odatetsu_camera.glb'
CAMERA = HERE.parents[2] / 'props/odatetsu_camera/finish_20261014/odatetsu_camera.glb'
QA = HERE / 'qa'
QA.mkdir(parents=True, exist_ok=True)
FPS = 30
C = Matrix(((1, 0, 0, 0), (0, 0, 1, 0), (0, -1, 0, 0), (0, 0, 0, 1)))


def read_glb(path):
    data = path.read_bytes()
    magic, version, total = struct.unpack_from('<4sII', data)
    assert magic == b'glTF' and version == 2 and total == len(data)
    size, kind = struct.unpack_from('<II', data, 12)
    assert kind == 0x4E4F534A
    doc = json.loads(data[20:20 + size])
    offset = 20 + size
    size, kind = struct.unpack_from('<II', data, offset)
    assert kind == 0x004E4942
    return doc, data[offset + 8:offset + 8 + size]


def local_matrix(node):
    if 'matrix' in node:
        return Matrix([node['matrix'][i::4] for i in range(4)])
    x, y, z, w = node.get('rotation', (0, 0, 0, 1))
    return Matrix.LocRotScale(Vector(node.get('translation', (0, 0, 0))),
                              Quaternion((w, x, y, z)), Vector(node.get('scale', (1, 1, 1))))


def matrices(doc):
    parents = {c: i for i, node in enumerate(doc['nodes']) for c in node.get('children', [])}
    memo = {}
    def world(index):
        if index not in memo:
            m = local_matrix(doc['nodes'][index])
            memo[index] = world(parents[index]) @ m if index in parents else m
        return memo[index]
    for i in range(len(doc['nodes'])):
        world(i)
    return memo, parents


def frame(long_axis, palm):
    y = Vector(long_axis).normalized()
    x = Vector(palm) - y * Vector(palm).dot(y)
    x.normalize()
    return Matrix((x, y, x.cross(y))).transposed()


def oriented(rest, old_long, old_palm, new_long, new_palm):
    delta = frame(new_long, new_palm) @ frame(old_long, old_palm).inverted()
    return delta @ rest.to_3x3()


def set_world(rig, name, point, rotation):
    rig.pose.bones[name].matrix = Matrix.LocRotScale(Vector(point), rotation.to_quaternion(), Vector((1, 1, 1)))
    bpy.context.view_layer.update()


def solve_arm(rig, side, wrist, pole, long_axis, palm):
    names = [side + x for x in ('Arm', 'ForeArm', 'Hand')]
    rest = [rig.data.bones[n].matrix_local.copy() for n in names]
    shoulder = rig.pose.bones[names[0]].head.copy()
    wrist, pole = Vector(wrist), Vector(pole)
    l1 = (rest[1].translation - rest[0].translation).length
    l2 = (rest[2].translation - rest[1].translation).length
    d = (wrist - shoulder).length
    assert abs(l1 - l2) < d < l1 + l2, (side, d, l1, l2)
    axis = (wrist - shoulder).normalized()
    t = (l1*l1 - l2*l2 + d*d) / (2*d)
    perpendicular = pole - shoulder - axis * (pole - shoulder).dot(axis)
    perpendicular.normalize()
    elbow = shoulder + axis*t + perpendicular*math.sqrt(max(0, l1*l1-t*t))
    for name, old, old_end, start, end in [
        (names[0], rest[0], rest[1].translation, shoulder, elbow),
        (names[1], rest[1], rest[2].translation, elbow, wrist),
    ]:
        swing = (old_end - old.translation).rotation_difference(end-start)
        rotation = swing.to_matrix() @ old.to_3x3()
        if name.endswith('ForeArm'):
            # Carry the palm roll through the forearm instead of concentrating
            # a half-turn at the wrist when the elbow is deeply flexed.
            sign = 1 if side == 'Left' else -1
            rotation = oriented(old, old_end-old.translation, (-sign, 0, 0), end-start, palm)
        set_world(rig, name, start, rotation)
    # Use anatomical landmarks rather than an importer's guessed bone tail.
    sign = 1 if side == 'Left' else -1
    old_long = Vector((sign * .031, -.005, -.079))
    rotation = oriented(rest[2], old_long, (-sign, 0, 0), long_axis, palm)
    set_world(rig, names[2], wrist, rotation)
    return {'shoulder': list(shoulder), 'elbow': list(elbow), 'wrist': list(wrist),
            'upperArmLengthM': l1, 'forearmLengthM': l2,
            'handLongAxis': list(Vector(long_axis).normalized()), 'palm': list(palm)}


def curl_digits(rig, side, palm, amounts):
    suffix = 'R' if side == 'Right' else 'L'
    for digit, angles in amounts.items():
        for i, angle in enumerate(angles, 1):
            name = f'{digit}{i}.{suffix}'
            bone = rig.pose.bones[name]
            m = bone.matrix.copy()
            direction = bone.tail - bone.head
            axis = direction.cross(Vector(palm)).normalized()
            rotation = Quaternion(axis, math.radians(angle)).to_matrix() @ m.to_3x3()
            set_world(rig, name, m.translation, rotation)


def append_clip(doc, binary, rows):
    payload = bytearray(binary)
    def accessor(values, kind, width, bounds=False):
        while len(payload) % 4:
            payload.append(0)
        offset = len(payload)
        flat = [v for row in values for v in row]
        data = struct.pack('<' + 'f'*len(flat), *flat)
        payload.extend(data)
        view = len(doc['bufferViews'])
        doc['bufferViews'].append({'buffer': 0, 'byteOffset': offset, 'byteLength': len(data)})
        result = {'bufferView': view, 'componentType': 5126, 'count': len(values), 'type': kind}
        if bounds:
            result['min'] = [min(row[i] for row in values) for i in range(width)]
            result['max'] = [max(row[i] for row in values) for i in range(width)]
        index = len(doc['accessors'])
        doc['accessors'].append(result)
        return index
    time = accessor([[0.], [1.]], 'SCALAR', 1, True)
    clip = {'name': 'CameraCarry', 'samplers': [], 'channels': [],
            'extras': {'authoredFor': 'CTO Odatetsu', 'pose': 'right-hand camera at shoulder; left hand on waist'}}
    for index, matrix in rows.items():
        p, q, s = matrix.decompose()
        for path, kind, row in [('translation', 'VEC3', list(p)),
                                ('rotation', 'VEC4', [q.x, q.y, q.z, q.w]),
                                ('scale', 'VEC3', list(s))]:
            output = accessor([row, row], kind, len(row))
            sampler = len(clip['samplers'])
            clip['samplers'].append({'input': time, 'output': output, 'interpolation': 'LINEAR'})
            clip['channels'].append({'sampler': sampler, 'target': {'node': index, 'path': path}})
    doc['animations'].append(clip)
    doc['buffers'][0]['byteLength'] = len(payload)
    encoded = json.dumps(doc, separators=(',', ':')).encode()
    encoded += b' ' * (-len(encoded) % 4)
    payload.extend(b'\0' * (-len(payload) % 4))
    length = 12 + 8 + len(encoded) + 8 + len(payload)
    OUTPUT.write_bytes(struct.pack('<4sII', b'glTF', 2, length) +
                       struct.pack('<II', len(encoded), 0x4E4F534A) + encoded +
                       struct.pack('<II', len(payload), 0x004E4942) + payload)


def main():
    doc, binary = read_glb(SOURCE)
    original_doc = json.loads(json.dumps(doc))
    assert len(doc['animations']) == 20
    raw_world, parents = matrices(doc)
    index_by_name = {n.get('name'): i for i, n in enumerate(doc['nodes'])}
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.fps = FPS
    bpy.ops.import_scene.gltf(filepath=str(SOURCE))
    rig = next(o for o in scene.objects if o.type == 'ARMATURE')
    rig.animation_data_clear()
    for b in rig.pose.bones:
        b.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    rest = {b.name: rig.matrix_world @ b.matrix_local for b in rig.data.bones}
    # Feet and body retain the original neutral shape. Only the two arms and
    # digits move; the hood therefore follows the unchanged torso.
    right = solve_arm(rig, 'Right', (-.33, -.09, 1.32), (-.42, -.04, 1.08),
                      (0, -.15, 1), (1, 0, 0))
    left = solve_arm(rig, 'Left', (.26, -.16, 1.07), (.48, .00, 1.13),
                     (-.8, 0, -.6), (0, 1, 0))
    curl_digits(rig, 'Right', (1, 0, 0), {
        'Index': (15, 30, 25), 'Middle': (35, 55, 35),
        'Ring': (40, 55, 35), 'Little': (40, 50, 30), 'Thumb': (12, 20, 15),
    })
    curl_digits(rig, 'Left', (0, 1, 0), {
        'Index': (4, 6, 4), 'Middle': (4, 6, 4),
        'Ring': (4, 6, 4), 'Little': (4, 6, 4), 'Thumb': (5, 7, 4),
    })
    bpy.context.view_layer.update()
    posed = {}
    for bone in rig.pose.bones:
        index = index_by_name[bone.name]
        deformation = rig.matrix_world @ bone.matrix @ rest[bone.name].inverted()
        posed[index] = C @ deformation @ C.inverted() @ raw_world[index]
    rows = {i: posed.get(parents.get(i), raw_world.get(parents.get(i), Matrix.Identity(4))).inverted() @ m
            for i, m in posed.items()}
    append_clip(doc, binary, rows)
    result, data = read_glb(OUTPUT)
    assert result['animations'][:20] == original_doc['animations']
    for key in ('meshes', 'skins', 'materials', 'images', 'textures', 'nodes', 'scenes'):
        assert result.get(key) == original_doc.get(key), key
    assert data[:len(binary)] == binary
    # Camera's -X is its grip side, +Y is its top, +Z is the optical axis.
    # In the authored pose the optical axis points upward and slightly back.
    lens = Vector((0, .20, .98)).normalized()
    camera_x = Vector((1, 0, 0))
    camera_top = lens.cross(camera_x)
    # The grip marker is near the shutter-side upper grip, above the middle
    # of the palm when the camera optical axis is upright.
    grip_position = (Vector(right['wrist']) + Vector(right['handLongAxis']) * .045
                     + Vector((.015, 0, 0)) + lens * .065 + Vector((0, 0, -.005)))
    grip_world = Matrix((camera_x, camera_top, lens)).transposed().to_4x4()
    grip_world.translation = grip_position
    raw_socket = posed[index_by_name['PropSocket.R']]
    socket_to_grip = raw_socket.inverted() @ C @ grip_world
    attachment = {
        'schemaVersion': 1, 'units': 'metres',
        'rig': 'cto_odatetsu_camera.glb', 'socket': 'PropSocket.R',
        'threeSocketName': 'PropSocketR', 'cameraGripNode': 'GripAnchor',
        'cameraAxes': '-X grip side (operator right), +Y top, +Z lens optical axis; no reflection',
        'matrixConvention': 'column-major; cameraWorld = socketWorld * socketToGrip * inverse(gripInCamera)',
        'socketToGrip': [socket_to_grip[r][c] for c in range(4) for r in range(4)],
        'authoredPose': 'CameraCarry', 'defaultEquipped': True,
        'contactFitOffsetBlenderMetres': [0, 0, -.005],
        'rightGripPose': [
            {'node': doc['nodes'][i]['name'],
             'quaternion': [m.to_quaternion().x, m.to_quaternion().y, m.to_quaternion().z, m.to_quaternion().w]}
            for i, m in rows.items()
            if doc['nodes'][i]['name'].endswith('.R') and doc['nodes'][i]['name'] != 'PropSocket.R'
        ],
        'gripApplication': 'After sampling an existing clip, apply rightGripPose local quaternions only while equipped; update world matrices and skeleton. Do not override RightHand.',
        'status': 'provisional alignment; final camera geometry must be checked',
        'placeholderCamera': {'bodySize': [.13, .10, .08], 'lensLength': .20, 'hoodLength': .07,
                              'lensDiameter': .09, 'gripInCamera': [-.05, -.005, -.02]},
    }
    if CAMERA.exists():
        attachment['camera'] = '../../../props/odatetsu_camera/finish_20261014/odatetsu_camera.glb'
        attachment['cameraSha256'] = hashlib.sha256(CAMERA.read_bytes()).hexdigest()
        attachment['status'] = 'actual camera alignment; audit hashes are recorded in contact_review.json and pose_review.json'
    (HERE / 'attachment.json').write_text(json.dumps(attachment, indent=2) + '\n')
    report = {'source': str(SOURCE.relative_to(HERE.parents[4])),
              'sourceSha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
              'outputSha256': hashlib.sha256(OUTPUT.read_bytes()).hexdigest(),
              'originalAnimationsUnchanged': True, 'originalBinaryPrefixUnchanged': True,
              'geometrySkinMaterialsRestTransformsUnchanged': True,
              'boneCount': len(rig.pose.bones), 'clipCount': len(result['animations']),
              'addedClip': {'name': 'CameraCarry', 'durationSeconds': 1, 'staticPose': True},
              'landmarksBlenderZUp': {'right': right, 'left': left},
              'cameraGripWorldBlender': list(grip_position),
              'visualReview': 'see pose_review.json for the separately reviewed asset hashes',
              'cameraAlignment': 'actual separate camera GLB' if CAMERA.exists() else 'placeholder only'}
    (HERE / 'pose_report.json').write_text(json.dumps(report, indent=2) + '\n')
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE / 'camera_pose.blend'))
    print('CAMERA_CARRY_BUILT', report, flush=True)


if __name__ == '__main__':
    main()
