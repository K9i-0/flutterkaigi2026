"""Adopt the approved v2 meshes, retaining the v1 game's motion identifiers.

The root hazard_adopted GLBs remain immutable v1 motion inputs. New game
derivatives live in v2_20260913; the game follows them through relative links.
No generation API is called.
"""
import hashlib
import json
import os
import re
import statistics
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from build_humanoid_motion import Body, clear_pose, use_action
from sobaya_v2_motion import adapt_matrices
from fukuchan_v2_rig import finish_pose

BASE = ROOT / '04_GAME_ASSETS/3d/hazard_adopted'
OUT = BASE / 'v2_20260913'
ALIASES = {
    'Adopted_Library_Idle_A': 'Idle',
    'Adopted_Library_Walk': 'Walk',
    'Adopted_Library_Dance_Simple': 'DanceStep',
    'Adopted_Library_Dance_Charleston': 'DanceDisco',
    'Adopted_Library_Dance_Body_Roll': 'DanceVictory',
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_sources(name):
    before_objects, before_actions = set(bpy.data.objects), set(bpy.data.actions)
    names = {a: a.name for a in before_actions}
    for a in before_actions:
        a.name = 'V2Input_' + a.name
    source = BASE / f'{name}.glb'
    bpy.ops.import_scene.gltf(filepath=str(source))
    imported = set(bpy.data.objects) - before_objects
    rig = next(o for o in imported if o.type == 'ARMATURE')
    bind = rig.matrix_world.copy()
    for track in list(rig.animation_data.nla_tracks):
        rig.animation_data.nla_tracks.remove(track)
    use_action(rig, None)
    clear_pose(rig)
    raw_rest = {b.name: bind @ b.matrix_local for b in rig.data.bones}
    convert = adapt_matrices if name == 'sobaya' else lambda m: m
    records = {}
    for a in set(bpy.data.actions) - before_actions:
        use_action(rig, None)
        clear_pose(rig)
        rig.matrix_world = bind.copy()
        use_action(rig, a)
        start, end = a.frame_range
        frames = max(1, round(end - start))
        samples, sockets = [], []
        for i in range(frames + 1):
            f = start + (end - start) * i / frames
            bpy.context.scene.frame_set(int(f), subframe=f-int(f))
            raw = {b.name: rig.matrix_world @ b.matrix for b in rig.pose.bones}
            samples.append(convert(raw))
            if name == 'sobaya':
                sockets.append(raw['PropSocket.R'].copy())
        records[a.name] = {'frames': frames, 'samples': samples, 'sockets': sockets}
    for o in imported:
        bpy.data.objects.remove(o, do_unlink=True)
    for a in set(bpy.data.actions) - before_actions:
        bpy.data.actions.remove(a)
    for a, label in names.items():
        a.name = label
    return convert(raw_rest), records


def add_socket(rig, name):
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.select_all(action='DESELECT')
    rig.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    hand = rig.data.edit_bones['RightHand']
    b = rig.data.edit_bones.new(name)
    b.head = hand.head + (hand.tail-hand.head).normalized() * .065
    b.tail = b.head + Vector((0, 0, .05))
    b.parent = hand
    b.use_deform = False
    bpy.ops.object.mode_set(mode='OBJECT')


def build(name):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = 30
    source = ROOT / f'04_GAME_ASSETS/3d/characters/{name}/v2_20260913/{name}_v2.glb'
    bpy.ops.import_scene.gltf(filepath=str(source))
    rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    for o in bpy.context.scene.objects:
        if o.animation_data:
            o.animation_data_clear()
    clear_pose(rig)
    # Work in Blender's existing Z-up armature space, exactly as the v2 builder.
    assert rig.matrix_world.translation.length < 1e-5
    assert rig.matrix_world.to_quaternion().angle < 1e-5
    assert max(rig.scale)-min(rig.scale) < 1e-5, 'Non-uniform rig scale'
    sr, records = read_sources(name)
    aliases = dict(ALIASES)
    aliases['Adopted_Candidate_Chase_Run' if name == 'sobaya' else
            'Adopted_Candidate_Mixamo_Run'] = 'Run'
    for target, original in aliases.items():
        if target not in bpy.data.actions:
            a = bpy.data.actions[original].copy()
            a.name = target
            a.use_fake_user = True
    body = Body(rig, meshes, 'fukuchan')
    rest = body.rest
    corrections = {}
    children = {s+n: s+c for s in ['Left', 'Right'] for n,c in
                [('Shoulder','Arm'),('Arm','ForeArm'),('ForeArm','Hand')]}
    for b in rig.data.bones:
        n = b.name
        if n not in sr or n == 'Root':
            continue
        target = rest[n].to_3x3()
        if n in children:
            c = children[n]
            a = sr[c].translation - sr[n].translation
            z = rest[c].translation - rest[n].translation
            target = z.rotation_difference(a).to_matrix() @ target
        elif n.endswith('Hand'):
            c = n.replace('Hand', 'ForeArm')
            a = sr[n].translation - sr[c].translation
            z = rest[n].translation - rest[c].translation
            target = z.rotation_difference(a).to_matrix() @ target
        corrections[n] = sr[n].to_quaternion().to_matrix().inverted() @ target
    scale = body.leg / ((sr['LeftUpLeg'].translation-sr['LeftLeg'].translation).length +
                        (sr['LeftLeg'].translation-sr['LeftFoot'].translation).length)
    retained = set(bpy.data.actions.keys())
    for label, spec in sorted(records.items()):
        if label in retained:
            continue
        body.action(label, spec['frames'])
        for i, sample in enumerate(spec['samples']):
            bpy.context.scene.frame_set(i)
            clear_pose(rig)
            for b in rig.pose.bones:
                if b.name not in corrections:
                    continue
                loc = b.head.copy()
                if b.name == 'Hips':
                    loc = rest['Hips'].translation + (sample['Hips'].translation-sr['Hips'].translation)*scale
                b.matrix = Matrix.Translation(loc) @ (sample[b.name].to_quaternion().to_matrix() @ corrections[b.name]).to_4x4()
                bpy.context.view_layer.update()
            if name == 'fukuchan':
                finish_pose(body, label, i/spec['frames'])
            body.key(i)
        print(name, 'retargeted', label, flush=True)
    use_action(rig, None)
    clear_pose(rig)
    socket_name = 'PropSocket.R' if name == 'sobaya' else 'GunSocket'
    add_socket(rig, socket_name)
    socket = rig.pose.bones[socket_name]
    hand = rig.pose.bones['RightHand']
    local_offset = hand.bone.matrix_local.inverted() @ socket.bone.head_local
    use_action(rig, bpy.data.actions['Hybrid_MugHold' if name == 'sobaya' else 'Aim'])
    bpy.context.scene.frame_set(0)
    aim_hand = hand.matrix.to_quaternion().to_matrix()
    if name == 'fukuchan':
        # Same grip placement reviewed with the actual weapon in the web page.
        offset=Vector((.025,-.065,.035))/rig.scale.x
        local_offset=hand.matrix.inverted()@(hand.head+offset)
    # Blender export changes Z-up to Y-up; Rx(90deg) gives the weapon's game axes.
    gun_axes = Matrix.Rotation(1.5707963267948966, 3, 'X')
    for a in list(bpy.data.actions):
        use_action(rig, None)
        clear_pose(rig)
        use_action(rig, a)
        start, end = a.frame_range
        spec = records.get(a.name)
        for i in range(round(end-start)+1):
            bpy.context.scene.frame_set(round(start+i))
            location = hand.matrix @ local_offset
            if name == 'sobaya' and spec and spec['sockets']:
                k = min(i, len(spec['sockets'])-1)
                rotation = spec['sockets'][k].to_quaternion().to_matrix()
            else:
                rotation = hand.matrix.to_3x3() @ aim_hand.inverted() @ gun_axes
            socket.matrix = Matrix.Translation(location) @ rotation.to_4x4()
            socket.rotation_mode = 'QUATERNION'
            for attr in ['location','rotation_quaternion','scale']:
                socket.keyframe_insert(attr, frame=round(start+i), group=socket_name)
    speeds = {}
    chosen = {'Walk':'Adopted_Library_Walk', 'Run':
              'Adopted_Candidate_Chase_Run' if name == 'sobaya' else 'Adopted_Candidate_Mixamo_Run'}
    for role, clip in chosen.items():
        use_action(rig, None)
        clear_pose(rig)
        use_action(rig, bpy.data.actions[clip])
        start, end = bpy.data.actions[clip].frame_range
        feet = {s:[] for s in ['LeftFoot','RightFoot']}
        for i in range(round(end-start)+1):
            bpy.context.scene.frame_set(round(start+i))
            for s in feet:
                feet[s].append(rig.matrix_world @ rig.pose.bones[s].head)
        values=[]
        for points in feet.values():
            low=min(p.z for p in points)
            values += [(b.y-a.y)*30 for a,b in zip(points,points[1:])
                       if max(a.z,b.z)<low+.035 and b.y>a.y]
        assert values, (name,role)
        speeds[role]=statistics.median(values)
    use_action(rig, None)
    clear_pose(rig)
    for o in meshes:
        if o.data.shape_keys:
            for key in o.data.shape_keys.key_blocks:
                key.value=0
    target=OUT/f'{name}.glb'
    bpy.ops.export_scene.gltf(filepath=str(target), export_format='GLB',
        export_animations=True, export_animation_mode='ACTIONS', export_frame_range=False,
        export_anim_slide_to_zero=True, export_anim_single_armature=True, export_skins=True,
        export_def_bones=False, export_force_sampling=True, export_optimize_animation_size=True,
        export_extras=True)
    return {'version':2,'file':str(target.relative_to(ROOT)),
        'source':str(source.relative_to(ROOT)), 'sourceSha256':digest(source),
        'motionSource':str((BASE/f'{name}.glb').relative_to(ROOT)),
        'motionSourceSha256':digest(BASE/f'{name}.glb'), 'sha256':digest(target),
        'sources':chosen,'groundSpeedMps':speeds,'clips':sorted(bpy.data.actions.keys()),
        'socket':socket_name,'individualFingerRig':name=='fukuchan',
        'retainedV1ClipCount':len(records),'retainedV2ClipCount':len(retained)-len(aliases)}


OUT.mkdir(parents=True, exist_ok=True)
report=json.loads((OUT/'manifest.json').read_text()) if '--fukuchan-only' in sys.argv else {}
characters=['fukuchan'] if '--fukuchan-only' in sys.argv else ['sobaya','fukuchan']
if '--fukuchan-only' in sys.argv:
    assert digest(OUT/'sobaya.glb')==report['sobaya']['sha256']
    assert digest(ROOT/report['sobaya']['source'])==report['sobaya']['sourceSha256']
for name in characters:
    report[name]=build(name)
    (OUT/'manifest.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
old_manifest=BASE/'v1_manifest.json'
if not old_manifest.exists():
    old_manifest.write_bytes((BASE/'manifest.json').read_bytes())
(BASE/'manifest.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
for name in report:
    link=ROOT/f'21_SOBAYA_HAZARD_LAB/assets/models/{name}.glb'
    link.unlink()
    link.symlink_to(os.path.relpath(OUT/f'{name}.glb',link.parent))
motion=ROOT/'21_SOBAYA_HAZARD_LAB/lib/game/game_motion_blend.dart'
code=motion.read_text()
for name,role,const in [('fukuchan','Walk','fukuchanWalkSpeed'),('fukuchan','Run','fukuchanRunSpeed'),
                        ('sobaya','Walk','sobayaWalkSpeed'),('sobaya','Run','sobayaMugRunSpeed')]:
    code=re.sub(r'const '+const+r' = [\d.]+;',f'const {const} = {report[name]["groundSpeedMps"][role]};',code)
motion.write_text(code)
print('HAZARD_V2_BUILD_DONE', flush=True)
