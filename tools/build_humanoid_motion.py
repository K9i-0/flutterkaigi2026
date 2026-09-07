"""Retarget CC0 clips and bake body-sized IK on the canonical human GLBs.

blender -b --factory-startup --python tools/build_humanoid_motion.py
Optional: -- --character sobaya|fukuchan --preview (small development subset).
Inputs are versioned GLBs, never an untracked .blend or a paid API.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import statistics
import sys

import bpy
from mathutils import Matrix, Quaternion, Vector

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from fetch_humanoid_motion import FILES, REVISION
from sobaya_garment import animate_hem

OUT = ROOT / '04_GAME_ASSETS/3d/motion_library'
FPS = 30
# source, display name, category, loop, floor IK variant
BASE = [
    ('Idle_A', '自然な待機', '日常', True, True),
    ('Walk', '歩行', '移動', True, True),
    ('Jog', 'ジョギング', '移動', True, True),
    ('Sprint', '全力疾走', '移動', True, True),
    ('Crouch_Idle', 'しゃがみ待機', '移動', True, True),
    ('Crouch_Walk', 'しゃがみ歩き', '移動', True, True),
    ('Walk_Carry', '荷物を運ぶ', '日常', True, False),
    ('Zombie_Walk', 'ゾンビ歩行', '移動', True, True),
    ('Jump_Start', 'ジャンプ踏切', 'アクション', False, False),
    ('Jump_air', 'ジャンプ空中', 'アクション', True, False),
    ('Jump_Land', '着地', 'アクション', False, False),
    ('Punch_Jab', 'ジャブ', '戦闘', False, True),
    ('Punch_Cross', 'ストレート', '戦闘', False, False),
    ('Melee_Hook', 'フック', '戦闘', False, False),
    ('Hit_Chest', '胸への被弾', '戦闘', False, False),
    ('Hit_Head', '頭への被弾', '戦闘', False, False),
    ('Pistol_Aim_Neutral', '拳銃を構える', '戦闘', True, True),
    ('Pistol_Reload', '拳銃リロード', '戦闘', False, False),
    ('Pistol_Shoot', '拳銃発射', '戦闘', False, False),
    ('Sitting_Enter', '椅子に座る', '日常', False, True),
    ('Sitting_Idle', '座って待つ', '日常', True, True),
    ('Sitting_Exit', '椅子から立つ', '日常', False, True),
    ('PickUp_Table', '台の物を取る', '日常', False, False),
    ('Interact', '手を伸ばす', '日常', False, False),
    ('Idle_Talking', '会話', '日常', True, True),
    ('Idle_FoldArms', '腕組み', '日常', True, False),
    ('Consume', '飲む・食べる', '日常', False, False),
    ('Push', '押す', '日常', True, False),
]
ADDON = [
    ('Strafe_left', '左へ横歩き', '移動', True, True),
    ('Strafe_right', '右へ横歩き', '移動', True, True),
    ('Walk_Backwards', '後ろ歩き', '移動', True, True),
    ('Dodge_back', '後方回避', '戦闘', False, False),
    ('Dodge_left', '左へ回避', '戦闘', False, False),
    ('Dodge_right', '右へ回避', '戦闘', False, False),
    ('Greeting', '挨拶', '日常', False, False),
    ('Idle Listening', '話を聞く', '日常', True, False),
    ('Bow', 'お辞儀', '日常', False, True),
    ('Kneeling Tired', '片膝で休む', '日常', True, False),
    ('Victory', '喜ぶ', '日常', False, False),
]
PROCEDURAL = [
    ('Breathing', '呼吸と重心移動', 3.2), ('Walk', '歩幅に合わせた歩行', 1.3),
    ('Jog', '弾みのある走行', .85), ('Crouch', 'しゃがむ・戻る', 3.0),
    ('SideStep', '横へ踏み出す', 1.6), ('Reach', '上の物へ手を伸ばす', 3.0),
    ('LookAround', '周囲を見回す', 4.0), ('StepUp', '段差へ足を上げる', 2.8),
]


def smooth(t):
    t = max(0., min(1., t))
    return t * t * (3 - 2 * t)


def action_id(source):
    return {'Sprint':'Run', 'Breathing':'Idle_A'}.get(source,source.replace(' ','_'))


def mapping(sobaya):
    result = {'Hips': 'pelvis', 'Spine': 'spine_01', 'Neck': 'neck_01', 'Head': 'head'}
    result.update({'Chest': 'spine_03'} if sobaya else {'Spine1': 'spine_02', 'Spine2': 'spine_03'})
    for side, word in [('L', 'Left'), ('R', 'Right')]:
        for a, b, source in [('Shoulder','Shoulder','clavicle'), ('UpperArm','Arm','upperarm'),
                             ('Forearm','ForeArm','lowerarm'), ('Hand','Hand','hand'),
                             ('Thigh','UpLeg','thigh'), ('Shin','Leg','calf'),
                             ('Foot','Foot','foot'), ('Toe','ToeBase','ball')]:
            result[f'{a}.{side}' if sobaya else word+b] = f'{source}_{side.lower()}'
    return result


def use_action(rig, action):
    rig.animation_data_create()
    rig.animation_data.action = action
    if action and action.slots:
        rig.animation_data.action_slot = action.slots[0]


def clear_pose(rig):
    for bone in rig.pose.bones:
        bone.rotation_mode = 'QUATERNION'
        bone.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()


def read_sources(preview):
    sources = {}
    for filename, specs in [('human-base-animations.glb', BASE), ('human-addon-animations.glb', ADDON)]:
        path = OUT / 'source' / filename
        if hashlib.sha256(path.read_bytes()).hexdigest() != FILES[filename]:
            raise ValueError(f'Unexpected source hash: {path}')
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.context.scene.render.fps = FPS
        bpy.ops.import_scene.gltf(filepath=str(path))
        rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
        bind_world = rig.matrix_world.copy()
        for track in list(rig.animation_data.nla_tracks):
            rig.animation_data.nla_tracks.remove(track)
        rest = {b.name: rig.matrix_world @ b.matrix_local for b in rig.data.bones}
        for source, label, category, loop, hybrid in specs:
            if preview and source not in ['Walk', 'Crouch_Walk', 'Punch_Jab', 'Sitting_Enter', 'Strafe_left']:
                continue
            action = bpy.data.actions[source]
            # glTF omits constant channels. Blender otherwise carries an
            # unkeyed root transform over from the preceding clip (e.g. jump).
            use_action(rig, None)
            clear_pose(rig)
            rig.matrix_world = bind_world.copy()
            use_action(rig, action)
            start, end = action.frame_range
            frames = max(1, round(end-start))
            samples = []
            for i in range(frames+1):
                f = start + (end-start)*i/frames
                bpy.context.scene.frame_set(int(f), subframe=f-int(f))
                samples.append({b.name: rig.matrix_world @ b.matrix for b in rig.pose.bones})
            sources[source] = dict(source=source, label=label, category=category, loop=loop,
                hybrid=hybrid, file=filename, rest=rest, samples=samples, duration=frames/FPS)
            if source in ['Idle_A','Pistol_Aim_Neutral','Sitting_Idle','Idle_Talking']:
                lift=min(s['foot_l'].translation.z-rest['foot_l'].translation.z for s in samples)
                if lift>.08:raise ValueError(f'Source lost ground reference: {source} {lift}')
    return sources


class Body:
    def __init__(self, rig, meshes, name):
        self.rig, self.meshes, self.name = rig, meshes, name
        self.sobaya = name == 'sobaya'
        self.map = mapping(self.sobaya)
        self.inverse = {v:k for k,v in self.map.items()}
        missing = set(self.map) - set(rig.pose.bones.keys())
        if missing:
            raise ValueError(f'Missing required bones: {missing}')
        self.rest = {b.name:b.matrix_local.copy() for b in rig.data.bones}
        self.leg = self.length('thigh_l', 'calf_l') + self.length('calf_l', 'foot_l')
        self.arm = self.length('upperarm_l', 'lowerarm_l') + self.length('lowerarm_l', 'hand_l')
        self.width = self.length('upperarm_l', 'upperarm_r')
        # Points in bind-armature space, with all retained skin influences.
        self.soles = {s:[] for s in ['l','r']}
        for mesh in meshes:
            for vertex in mesh.data.vertices:
                p = rig.matrix_world.inverted() @ mesh.matrix_world @ vertex.co
                weights = [(mesh.vertex_groups[g.group].name,g.weight) for g in vertex.groups
                           if mesh.vertex_groups[g.group].name in self.rest and g.weight > 0]
                for side in ['l','r']:
                    feet = {self.inverse[f'foot_{side}'], self.inverse[f'ball_{side}']}
                    if sum(w for n,w in weights if n in feet) > .6 and p.z < .06:
                        self.soles[side].append((p, weights))
        if not all(self.soles.values()):
            raise ValueError('Cannot calibrate actual shoe sole')
        self.previous = {}

    def bone(self, role):
        return self.rig.pose.bones[self.inverse[role]]

    def point(self, role):
        return self.rest[self.inverse[role]].translation.copy()

    def length(self, a, b):
        return (self.point(a)-self.point(b)).length

    def skin_floor(self, side):
        matrices = {n:self.rig.pose.bones[n].matrix @ r.inverted() for n,r in self.rest.items()}
        return min(sum((matrices[n]@p).z*w for n,w in weights) for p,weights in self.soles[side])

    def aim(self, bone, target):
        direction = target-bone.head
        current = bone.tail-bone.head
        if direction.length < 1e-8 or current.length < 1e-8:
            return
        q = current.rotation_difference(direction)
        bone.matrix = Matrix.Translation(bone.head) @ q.to_matrix().to_4x4() @ bone.matrix.to_3x3().to_4x4()
        bpy.context.view_layer.update()

    def ik(self, roles, target, pole):
        a,b,tip = [self.bone(n) for n in roles]
        origin = a.head.copy()
        la = self.length(roles[0],roles[1]); lb = self.length(roles[1],roles[2])
        delta = target-origin
        distance = max(abs(la-lb)+.0005,min(delta.length,la+lb-.0005))
        axis = delta.normalized() if delta.length > 1e-8 else Vector((0,0,-1))
        bend = pole-axis*pole.dot(axis)
        if bend.length < 1e-6:
            bend = axis.cross(Vector((1,0,0)))
        bend.normalize()
        along = (la*la-lb*lb+distance*distance)/(2*distance)
        joint = origin+axis*along+bend*math.sqrt(max(0,la*la-along*along))
        # Aim along actual child-joint vectors; glTF leaf bone lengths are arbitrary.
        for bone, child, goal in [(a,b,joint),(b,tip,origin+axis*distance)]:
            q = (child.head-bone.head).rotation_difference(goal-bone.head)
            bone.matrix = Matrix.Translation(bone.head)@q.to_matrix().to_4x4()@bone.matrix.to_3x3().to_4x4()
            bpy.context.view_layer.update()

    def leg_ik(self, side, ankle, rotation, pole=None):
        self.ik([f'thigh_{side}',f'calf_{side}',f'foot_{side}'], ankle,
                Vector((0,-1,0)) if pole is None else pole)
        foot = self.bone(f'foot_{side}')
        foot.matrix = Matrix.Translation(foot.head)@rotation.to_4x4()
        bpy.context.view_layer.update()

    def ground_leg(self, side, desired_floor=0.003):
        for _ in range(3):
            foot = self.bone(f'foot_{side}')
            floor = self.skin_floor(side)
            if abs(desired_floor-floor) < .0005:
                break
            goal = foot.head.copy(); goal.z += desired_floor-floor
            self.leg_ik(side,goal,foot.matrix.to_3x3())

    def key(self, frame):
        if self.sobaya:
            animate_hem(self.rig)
        for bone in self.rig.pose.bones:
            q = bone.rotation_quaternion
            if bone.name in self.previous and q.dot(self.previous[bone.name]) < 0:
                q.negate()
            self.previous[bone.name] = q.copy()
            bone.keyframe_insert('location',frame=frame,group=bone.name)
            bone.keyframe_insert('rotation_quaternion',frame=frame,group=bone.name)

    def action(self,name,frames):
        old = bpy.data.actions.get(name)
        if old: bpy.data.actions.remove(old)
        a = bpy.data.actions.new(name); a.use_fake_user = True
        a.use_frame_range = True; a.frame_start = 0; a.frame_end = frames
        use_action(self.rig,a)
        self.previous = {}
        return a


def retarget(body, spec, hybrid):
    rig = body.rig; rest = spec['rest']; samples = spec['samples']
    src_leg = (rest['thigh_l'].translation-rest['calf_l'].translation).length + (rest['calf_l'].translation-rest['foot_l'].translation).length
    scale = body.leg/src_leg
    correction = {}
    child_role = {'upperarm':'lowerarm','lowerarm':'hand'}
    for target,role in body.map.items():
        r = body.rest[target].to_3x3(); s = rest[role].to_3x3()
        kind = role.rsplit('_',1)[0]
        if kind in child_role:
            child = child_role[kind]+'_'+role[-1]
            src_axis = rest[child].translation-rest[role].translation
            dst_axis = body.point(child)-body.point(role)
            r = dst_axis.rotation_difference(src_axis).to_matrix()@r
        elif kind == 'hand':
            # Hands inherit the calibrated forearm frame; no arbitrary leaf axis.
            fore = 'lowerarm_'+role[-1]
            src_axis = rest[role].translation-rest[fore].translation
            dst_axis = body.point(role)-body.point(fore)
            r = dst_axis.rotation_difference(src_axis).to_matrix()@r
        correction[target] = s.inverted()@r
    prefix = 'Hybrid' if hybrid else 'Library'
    clip = prefix+'_'+spec['source'].replace(' ','_')
    frames = len(samples)-1
    body.action(clip,frames)
    tracks, contact_weights, ground_velocity = contact_tracks(body, spec, scale)
    lowest=[]; contacts=0; ankle_samples={s:[] for s in ['l','r']};first_pose=None
    for i,sample in enumerate(samples):
        if spec['loop'] and i==frames:
            sample=samples[0]
        bpy.context.scene.frame_set(i); clear_pose(rig)
        root = body.point('pelvis')+(sample['pelvis'].translation-rest['pelvis'].translation)*scale
        for b in rig.pose.bones:
            if b.name not in body.map: continue
            role = body.map[b.name]
            r = sample[role].to_quaternion().to_matrix()@correction[b.name]
            position = root if role == 'pelvis' else b.head.copy()
            b.matrix = Matrix.Translation(position)@r.to_4x4()
            bpy.context.view_layer.update()
        if hybrid:
            for side in ['l','r']:
                role = f'foot_{side}'; toe_role = f'ball_{side}'
                displacement = (sample[role].translation-rest[role].translation)*scale
                ankle = tracks[side][i].copy()
                foot = body.bone(role); foot_rotation = foot.matrix.to_3x3().copy()
                pole = sample[f'calf_{side}'].translation-(sample[f'thigh_{side}'].translation+sample[role].translation)*.5
                body.leg_ik(side,ankle,foot_rotation,pole)
                contact = contact_weights[side][i]
                floor = body.skin_floor(side)
                # Sprint has fast heel rotations; a small clearance also protects
                # the nonlinear skinned sole between 30 Hz rotation keyframes.
                clearance = .014 if spec['source']=='Sprint' else .004
                desired = max(clearance, floor*(1-contact)+clearance*contact)
                body.ground_leg(side,desired)
                contacts += int(contact>.8)
            # A shoulder-relative arm reach preserves short arms and broad bodies.
            for side in ['l','r']:
                upper = body.bone('upperarm_'+side)
                delta = sample['hand_'+side].translation-sample['upperarm_'+side].translation
                src_arm = (rest['upperarm_'+side].translation-rest['lowerarm_'+side].translation).length+(rest['lowerarm_'+side].translation-rest['hand_'+side].translation).length
                wrist = upper.head+delta*(body.arm/src_arm)
                # Only add clearance near the torso, leaving cross-body gestures intact.
                torso = body.bone('spine_01').head
                if abs(wrist.y-torso.y)<.16 and wrist.z<upper.head.z-.14:
                    sign = 1 if side=='l' else -1
                    wrist.x = torso.x+sign*max(abs(wrist.x-torso.x),body.width*.55)
                hand = body.bone('hand_'+side); orientation = hand.matrix.to_3x3().copy()
                elbow = sample['lowerarm_'+side].translation-(sample['upperarm_'+side].translation+sample['hand_'+side].translation)*.5
                body.ik(['upperarm_'+side,'lowerarm_'+side,'hand_'+side],wrist,elbow)
                hand.matrix = Matrix.Translation(hand.head)@orientation.to_4x4()
                bpy.context.view_layer.update()
        if body.sobaya and spec['category']=='戦闘' and spec['source'].startswith(('Punch','Melee')):
            for side in ['L','R']:
                for digit in ['Index','Middle','Ring','Little']:
                    for joint,angle in [(1,.95),(2,1.25)]:
                        rig.pose.bones[f'{digit}{joint}.{side}'].rotation_quaternion = Quaternion((1,0,0),angle)
        if i==0:
            first_pose={b.name:b.matrix_basis.copy() for b in rig.pose.bones}
        if spec['loop'] and i==frames:
            for b in rig.pose.bones:b.matrix_basis=first_pose[b.name]
            bpy.context.view_layer.update()
        body.key(i)
        lowest.append(min(body.skin_floor('l'),body.skin_floor('r')))
        for side in ['l','r']: ankle_samples[side].append(body.bone('foot_'+side).head.copy())
    errors=[]
    for side in ['l','r']:
        for i in range(1,frames):
            if min(contact_weights[side][i-1],contact_weights[side][i])>.95:
                v=(ankle_samples[side][i]-ankle_samples[side][i-1])*FPS-ground_velocity
                errors.append(math.hypot(v.x,v.y))
    return dict(name=clip,action=action_id(spec['source']),label=spec['label'],method=prefix.lower(),
        category=spec['category'],loop=spec['loop'],duration=frames/FPS,source=spec['file'],
        sourceClip=spec['source'],legScale=scale,minSoleM=min(lowest),contactSamples=contacts,
        floor='flat' if hybrid else 'unconstrained',groundSpeedMps=ground_velocity.length,
        contactAnkleSlipRmsMps=math.sqrt(sum(e*e for e in errors)/len(errors)) if errors else None)


def contact_tracks(body, spec, scale):
    """Lock stance to a fitted ground velocity, with cyclic support intervals.

    The returned velocity is the floor moving beneath an in-place character.
    Only locomotion infers moving ground. Gestures have stationary contacts.
    No global body scaling or stretchable bones are used.
    """
    samples=spec['samples'];rest=spec['rest'];count=len(samples)-1
    weights={};tracks={};velocities=[]
    locomotion=spec['source'] in ['Walk','Jog','Sprint','Crouch_Walk','Zombie_Walk','Strafe_left','Strafe_right','Walk_Backwards']
    for side in ['l','r']:
        foot='foot_'+side;toe='ball_'+side
        weights[side]=[1-smooth((min(s[foot].translation.z-rest[foot].translation.z,
            s[toe].translation.z-rest[toe].translation.z)-.012)/.045) for s in samples]
        points=[]
        for sample in samples:
            d=(sample[foot].translation-rest[foot].translation)*scale;d.x*=.7
            points.append(body.point(foot)+d)
        tracks[side]=points
        if locomotion:
            for i in range(1,count):
                if min(weights[side][i-1],weights[side][i])>.95:
                    velocities.append((points[i]-points[i-1])*FPS)
    velocity=Vector((statistics.median(v.x for v in velocities),statistics.median(v.y for v in velocities),0)) if velocities else Vector()
    for side in ['l','r']:
        active=[w>.2 for w in weights[side][:count]]
        starts=[i for i in range(count) if active[i] and (i==0 and not spec['loop'] or not active[(i-1)%count])]
        if all(active): starts=[0]
        for start in starts:
            indices=[]
            for j in range(count):
                index=(start+j)%count
                if (not spec['loop'] and start+j>=count) or not active[index]:break
                indices.append(index)
            if not indices:continue
            anchor=sum((tracks[side][index]-velocity*(j/FPS) for j,index in enumerate(indices)),Vector())/len(indices)
            for j,index in enumerate(indices):
                target=anchor+velocity*(j/FPS);point=tracks[side][index]
                w=weights[side][index]
                point.x=point.x*(1-w)+target.x*w;point.y=point.y*(1-w)+target.y*w
        if spec['loop']:
            tracks[side][-1]=tracks[side][0].copy();weights[side][-1]=weights[side][0]
    return tracks,weights,velocity


def procedural(body, kind, label, duration):
    frames = round(duration*FPS); body.action('Procedural_'+kind,frames)
    rig = body.rig; floors=[]
    for frame in range(frames+1):
        bpy.context.scene.frame_set(frame); clear_pose(rig)
        p = (frame%frames)/frames; wave = math.sin(p*math.tau)
        hips = body.bone('pelvis'); hips_pos = body.point('pelvis')
        gait = kind in ['Walk','Jog','SideStep']
        crouch = math.sin(p*math.pi)**2 if kind=='Crouch' else 0
        compression = body.leg*(.045 + .24*crouch)
        hips_pos.z -= compression
        hips_pos.z += (.012 if gait else .004)*math.cos(2*p*math.tau)
        hips_pos.x += (.018 if gait else .009)*wave
        hips.matrix = Matrix.Translation(hips_pos)@Quaternion((0,0,1),.035*wave).to_matrix().to_4x4()@body.rest[hips.name].to_3x3().to_4x4()
        bpy.context.view_layer.update()
        chest = body.bone('spine_03'); chest.rotation_quaternion = Quaternion((1,0,0),-.10*crouch)
        if kind=='LookAround':
            body.bone('head').rotation_quaternion = Quaternion((0,1,0),.65*wave)
            chest.rotation_quaternion = Quaternion((0,1,0),.12*wave)
        bpy.context.view_layer.update()
        for side,offset,sign in [('l',0,1),('r',.5,-1)]:
            phase = (p+offset)%1
            ankle = body.point('foot_'+side)
            if gait:
                stride = body.leg*(.46 if kind=='Walk' else .68 if kind=='Jog' else .32)
                duty = .60 if kind!='Jog' else .45
                if phase<duty:
                    advance = stride*(phase/duty-.5); lift=0
                else:
                    t=(phase-duty)/(1-duty)
                    advance=stride*(.5-smooth(t)); lift=body.leg*(.08 if kind=='Walk' else .17)*math.sin(math.pi*t)**2
                if kind=='SideStep': ankle.x += advance
                else: ankle.y += advance
                ankle.z += lift
            if kind=='StepUp' and side=='l':
                lift=math.sin(math.pi*p)**2
                ankle.z += .20*lift; ankle.y-=.22*lift
            rotation = body.rest[body.inverse['foot_'+side]].to_3x3()
            body.leg_ik(side,ankle,rotation)
            if not (kind=='StepUp' and side=='l') and (not gait or phase < duty):
                body.ground_leg(side)
            elif body.skin_floor(side)<.003:
                body.ground_leg(side)
            upper = body.bone('upperarm_'+side)
            # Relaxed arms: real shoulder width, measured reach and elbow clearance.
            wrist=upper.head+Vector((sign*body.arm*.20,-.06,-body.arm*.89))
            if gait:
                wrist.y += .14*math.sin(phase*math.tau)
                if kind=='Jog': wrist.z+=body.arm*.30; wrist.y-=.10
            if kind=='Reach' and side=='r':
                amount=math.sin(math.pi*p)**2
                wrist= wrist.lerp(upper.head+Vector((sign*.08,-body.arm*.55,body.arm*.65)),amount)
            wrist.y-=crouch*.22
            body.ik(['upperarm_'+side,'lowerarm_'+side,'hand_'+side],wrist,Vector((sign,.2,-.15)))
        body.key(frame)
        floors.append(min(body.skin_floor('l'),body.skin_floor('r')))
    return dict(name='Procedural_'+kind,action='Run' if kind=='Jog' else action_id(kind),label=label,method='procedural',category='IK生成',
        loop=True,duration=frames/FPS,source='tools/build_humanoid_motion.py',
        minSoleM=min(floors),floor='authored 20cm step' if kind=='StepUp' else 'flat',
        groundSpeedMps=body.leg*({'Walk':.46,'Jog':.68,'SideStep':.32}.get(kind,0))/duration/(.45 if kind=='Jog' else .6))


def optimize_weights(rig, meshes):
    report = dict(vertices=0,changedVertices=0,maxInfluences=0,maxWeightError=0)
    valid=set(rig.data.bones.keys())
    for mesh in meshes:
        for vertex in mesh.data.vertices:
            weights=[(g.group,g.weight) for g in vertex.groups if mesh.vertex_groups[g.group].name in valid and g.weight>0]
            if not weights: raise ValueError(f'Unweighted vertex {mesh.name}:{vertex.index}')
            keep=sorted(weights,key=lambda x:-x[1])[:4];total=sum(w for _,w in keep)
            updated=[(g,w/total) for g,w in keep]
            if len(keep)!=len(weights) or abs(total-1)>1e-5: report['changedVertices']+=1
            for g,_ in weights: mesh.vertex_groups[g].remove([vertex.index])
            for g,w in updated: mesh.vertex_groups[g].add([vertex.index],w,'REPLACE')
            report['vertices']+=1; report['maxInfluences']=max(report['maxInfluences'],len(keep))
            report['maxWeightError']=max(report['maxWeightError'],abs(sum(w for _,w in updated)-1))
    return report


def build_character(name,sources,preview,hybrid_only=False):
    relative = 'sobaya/rig_v3/sobaya_rig.glb' if name=='sobaya' else 'fukuchan/rig_v1/fukuchan.glb'
    canonical=ROOT/'04_GAME_ASSETS/3d/characters'/relative
    source=OUT/name/f'{name}.glb' if hybrid_only else canonical
    bpy.ops.wm.read_factory_settings(use_empty=True); bpy.context.scene.render.fps=FPS
    bpy.ops.import_scene.gltf(filepath=str(source))
    rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' for m in o.modifiers)]
    # Imported glTF NLA tracks must not override newly baked actions.
    for obj in bpy.context.scene.objects:
        if obj.animation_data:
            for track in list(obj.animation_data.nla_tracks): obj.animation_data.nla_tracks.remove(track)
    use_action(rig,None);clear_pose(rig)
    body=Body(rig,meshes,name)
    weights=optimize_weights(rig,meshes)
    profile=dict(id=name,label='そば屋' if name=='sobaya' else '福ちゃん',
        heightM=1.8 if name=='sobaya' else 1.7,legM=body.leg,armM=body.arm,shoulderM=body.width,
        bones=len(rig.data.bones),boneMap={v:k for k,v in body.map.items()},weights=weights,
        source=str(canonical.relative_to(ROOT)),sourceSha256=hashlib.sha256(canonical.read_bytes()).hexdigest(),
        asset=f'assets/models/{name}_motion.glb',clips=[])
    if hybrid_only:
        previous=json.loads((OUT/name/'profile.json').read_text())
        allowed={action_id(s) for s in sources}
        profile['clips']=[c for c in previous['clips'] if c['method']=='library' and c['action'] in allowed]
    for n in ['Walk','Run']:
        a=bpy.data.actions[n]
        profile['clips'].append(dict(name=n,action=n,label='歩行' if n=='Walk' else '走行',
            method='captured',category='収録動作',loop=True,duration=(a.frame_range[1]-a.frame_range[0])/FPS,
            source='existing licensed Mixamo retarget; raw FBX not redistributed'))
    for spec in sources.values():
        for hybrid in [False,True] if spec['hybrid'] else [False]:
            if hybrid_only and not hybrid: continue
            result=retarget(body,spec,hybrid);profile['clips'].append(result)
            print('BAKED',name,result['name'],round(result['minSoleM'],4),flush=True)
    for kind,label,duration in PROCEDURAL:
        result=procedural(body,kind,label,duration);profile['clips'].append(result)
        print('BAKED',name,result['name'],round(result['minSoleM'],4),flush=True)
    use_action(rig,None);clear_pose(rig)
    folder=OUT/name;folder.mkdir(parents=True,exist_ok=True)
    (folder/'.gitignore').write_text('*.blend\n*.blend1\n')
    bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
    for mesh in meshes: mesh.select_set(True)
    bpy.context.view_layer.objects.active=rig
    bpy.ops.wm.save_as_mainfile(filepath=str(folder/f'{name}.blend'))
    bpy.ops.export_scene.gltf(filepath=str(folder/f'{name}.glb'),export_format='GLB',use_selection=True,
        export_animations=True,export_animation_mode='ACTIONS',export_frame_range=False,
        export_anim_slide_to_zero=True,export_anim_single_armature=True,export_skins=True,
        export_all_influences=False,export_def_bones=False,export_force_sampling=True,export_extras=True,
        export_optimize_animation_size=True)
    profile['glbBytes']=(folder/f'{name}.glb').stat().st_size
    (folder/'profile.json').write_text(json.dumps(profile,ensure_ascii=False,indent=2)+'\n')
    return profile


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--character',choices=['sobaya','fukuchan']);parser.add_argument('--preview',action='store_true');parser.add_argument('--hybrid-only',action='store_true')
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    sources=read_sources(args.preview)
    for name in [args.character] if args.character else ['sobaya','fukuchan']:
        build_character(name,sources,args.preview,args.hybrid_only)
    profiles=[json.loads((OUT/n/'profile.json').read_text()) for n in ['sobaya','fukuchan'] if (OUT/n/'profile.json').exists()]
    manifest=dict(schema=1,fps=FPS,sourceRevision=REVISION,preview=args.preview,characters=profiles)
    (OUT/'catalog.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')


if __name__=='__main__': main()
