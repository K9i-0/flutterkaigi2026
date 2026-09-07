"""Body-aware gaze, evasive roll and Sobaya's canonical mug action layer.

Integrated into build_humanoid_motion; run this file in Blender to update an
existing full library without rebaking the unchanged source retargets.
"""
import json
import math
import sys
from pathlib import Path
import bpy
from mathutils import Matrix, Quaternion, Vector

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tools'))
from build_humanoid_motion import Body, OUT, FPS, use_action, clear_pose, smooth
from build_sobaya_rig_v2 import contact_grip

REVISION = 2


def forward(body):
    head = body.bone('head')
    return (head.matrix.to_3x3() @ body.rest[head.name].to_3x3().inverted()
            @ Vector((0, -1, 0))).normalized()


def stabilize_gaze(body, minimum=-10, maximum=16, heading=None):
    """Preserve horizontal gaze/yaw and intentional small nods, share extension."""
    v = forward(body)
    pitch = math.asin(max(-1, min(1, v.z)))
    desired = max(math.radians(minimum), min(math.radians(maximum), pitch))
    horizontal = Vector((v.x, v.y, 0))
    if heading is not None:horizontal=Vector(heading)
    if horizontal.length < .05:
        horizontal = Vector((0, -1, 0))
    horizontal.normalize()
    target = horizontal*math.cos(desired)+Vector((0, 0, math.sin(desired)))
    correction = v.rotation_difference(target)
    neck = body.bone('neck_01')
    half = Quaternion().slerp(correction, .55)
    neck.matrix = Matrix.Translation(neck.head) @ half.to_matrix().to_4x4() @ neck.matrix.to_3x3().to_4x4()
    bpy.context.view_layer.update()
    head = body.bone('head')
    correction = forward(body).rotation_difference(target)
    head.matrix = Matrix.Translation(head.head) @ correction.to_matrix().to_4x4() @ head.matrix.to_3x3().to_4x4()
    bpy.context.view_layer.update()


def sample_action(body, action):
    use_action(body.rig, None)
    clear_pose(body.rig)
    use_action(body.rig, action)
    start, end = action.frame_range
    frames = round(end-start)
    poses = []
    for i in range(frames+1):
        bpy.context.scene.frame_set(round(start+i))
        poses.append({b.name: b.matrix_basis.copy() for b in body.rig.pose.bones})
    use_action(body.rig, None)
    return poses


def apply_pose(body, pose):
    for b in body.rig.pose.bones:
        b.matrix_basis = pose[b.name]
    bpy.context.view_layer.update()


def gaze_clips(body, profile):
    for spec in profile['clips']:
        if spec['method']=='captured' or spec.get('gazeRevision')==REVISION:
            continue
        # Bows, looking at a picked-up object and tucked rolls have intentional gaze.
        if spec['action'] in ['Bow','PickUp_Table','RollForward']:
            continue
        poses = sample_action(body, bpy.data.actions[spec['name']])
        body.action(spec['name'], len(poses)-1)
        minimum = -25 if spec['action'] in ['Consume','Kneeling_Tired'] else -10
        for i, pose in enumerate(poses):
            bpy.context.scene.frame_set(i)
            apply_pose(body, pose)
            stabilize_gaze(body, minimum)
            body.key(i)
        spec['gazeRevision'] = REVISION
        spec['gazePitchRangeDeg'] = [minimum,16]


def world_rotation(body, role, axis, angle):
    b = body.bone(role)
    b.matrix = Matrix.Translation(b.head) @ Quaternion(axis,angle).to_matrix().to_4x4() @ b.matrix.to_3x3().to_4x4()
    bpy.context.view_layer.update()


def envelope(p, a, peak, b):
    return smooth((p-a)/(peak-a)) if p<peak else 1-smooth((p-peak)/(b-peak))


def make_mug(body, kind, label, base):
    poses = sample_action(body, bpy.data.actions[base])
    duration = {'MugHold':3.2,'MugRun':len(poses[1:])/FPS,
                'MugPunch':1.15,'MugHook':1.35,'MugSmash':1.6}[kind]
    frames = round(duration*FPS)
    body.action('Hybrid_'+kind, frames)
    floors = []
    for i in range(frames+1):
        p=i/frames
        bpy.context.scene.frame_set(i)
        index=round(p*(len(poses)-1)) if kind=='MugRun' else 0
        apply_pose(body,poses[index])
        supports={s:(body.bone('foot_'+s).head.copy(),body.bone('foot_'+s).matrix.to_3x3().copy()) for s in ['l','r']}
        hips=body.bone('pelvis')
        if kind!='MugRun':
            hips.location += body.rest[hips.name].to_3x3().inverted() @ Vector((0,0,.004*math.sin(p*math.tau)))
        hit=envelope(p,.18,.48,.85) if kind in ['MugPunch','MugHook','MugSmash'] else 0
        wind=envelope(p,0,.18,.40) if hit or kind.startswith('Mug') and kind not in ['MugHold','MugRun'] else 0
        twist=(-.22*wind+.40*hit) if kind!='MugHook' else -.30*wind+.62*hit
        if kind not in ['MugHold','MugRun']:
            matrix=hips.matrix.copy()
            matrix.translation+=Vector((.018*hit,-.035*hit,-.012*wind))
            hips.matrix=matrix
            bpy.context.view_layer.update()
            world_rotation(body,'pelvis',(0,0,1),twist*.30)
        world_rotation(body,'spine_03',(0,0,1),twist)
        upper=body.bone('upperarm_r')
        wrist=Vector((-body.width*.36,-.31,upper.head.z-body.arm*.35))
        wrist.z += .012*math.sin(p*math.tau) if kind=='MugHold' else 0
        if kind=='MugRun':
            wrist.z += .018*math.sin(p*math.tau*2)
            wrist.y += .025*math.sin(p*math.tau)
        elif kind=='MugPunch':
            wrist += Vector((-.04*wind+.07*hit,.07*wind-body.arm*.46*hit,.025*hit))
        elif kind=='MugHook':
            wrist += Vector((-.14*wind+.30*hit,.07*wind-.18*hit,.015*hit))
        elif kind=='MugSmash':
            wrist += Vector((-.04*wind,-.08*hit,.37*wind-.12*hit))
        body.ik(['upperarm_r','lowerarm_r','hand_r'],wrist,Vector((-1,.12,-.25)))
        socket=body.rig.pose.bones['PropSocket.R']
        # Upright hold/run; controlled forward follow-through on heavy attacks.
        tilt = .45*hit if kind=='MugSmash' else .14*hit
        socket.matrix=Matrix.Translation(socket.head) @ Quaternion((1,0,0),tilt).to_matrix().to_4x4()
        bpy.context.view_layer.update()
        contact_grip(body.rig)
        if kind not in ['MugHold','MugRun']:
            upper=body.bone('upperarm_l')
            body.ik(['upperarm_l','lowerarm_l','hand_l'],
                    upper.head+Vector((-.04,-.24,-.24)),Vector((1,.1,-.2)))
        stabilize_gaze(body,heading=(0,-1,0))
        for side in ['l','r']:
            if kind not in ['MugHold','MugRun']:
                body.leg_ik(side,*supports[side])
            if body.skin_floor(side)<.004: body.ground_leg(side,.004)
        body.key(i)
        floors.append(min(body.skin_floor('l'),body.skin_floor('r')))
    return dict(name='Hybrid_'+kind,action=kind,label=label,method='hybrid',
                category='ジョッキ',loop=kind in ['MugHold','MugRun'],duration=frames/FPS,
                source='Sobaya.jpg / existing grip IK / '+base,
                prop='beer_mug',gazeRevision=REVISION,gazePitchRangeDeg=[-10,16],
                minSoleM=min(floors),floor='flat',
                support='flight' if kind=='MugRun' else 'feet',
                events={'anticipation':.18,'contact':.48,'recovery':.85} if kind not in ['MugHold','MugRun'] else {})


def skin_points(body):
    points=[]
    for mesh in body.meshes:
        transform=body.rig.matrix_world.inverted() @ mesh.matrix_world
        for v in mesh.data.vertices:
            weights=[(mesh.vertex_groups[g.group].name,g.weight) for g in v.groups
                     if mesh.vertex_groups[g.group].name in body.rest and g.weight>0]
            points.append((transform@v.co,weights))
    return points


def minimum_skin(body, points):
    matrices={n:body.rig.pose.bones[n].matrix@r.inverted() for n,r in body.rest.items()}
    return min(sum((matrices[n]@p).z*w for n,w in weights) for p,weights in points)


def make_roll(body):
    # In-place root; application/game applies rootTravelM on its navigation plane.
    frames=42;body.action('Procedural_RollForward',frames)
    points=skin_points(body); floors=[];bounds=[]
    for i in range(frames+1):
        p=i/frames
        bpy.context.scene.frame_set(i);clear_pose(body.rig)
        tuck=smooth(p/.20)*(1-smooth((p-.78)/.22))
        rotation=math.tau*smooth((p-.13)/.67)
        hips=body.bone('pelvis');pos=body.point('pelvis')
        pos.z-=body.leg*.35*tuck
        hips.matrix=Matrix.Translation(pos) @ Quaternion((1,0,0),rotation).to_matrix().to_4x4() @ body.rest[hips.name].to_3x3().to_4x4()
        bpy.context.view_layer.update()
        world_rotation(body,'spine_01',(1,0,0),.35*tuck)
        world_rotation(body,'spine_03',(1,0,0),.70*tuck)
        local=Quaternion((1,0,0),rotation).to_matrix()
        for side,sign in [('l',1),('r',-1)]:
            # Feet fold beside the hips; knees tuck FORWARD toward the chest.
            # Anatomical IK avoids assuming opposite rigs share flexion axes.
            rest_offset=body.point('foot_'+side)-body.point('pelvis')
            folded=Vector((sign*body.width*.24,-body.leg*.12,body.leg*.07))
            ankle=pos+local@rest_offset.lerp(folded,tuck)
            foot_rotation=local@body.rest[body.inverse['foot_'+side]].to_3x3()
            body.leg_ik(side,ankle,foot_rotation,local@Vector((0,-1,.15)))
            upper=body.bone('upperarm_'+side)
            target=upper.head+local@Vector((-sign*.07,-body.arm*.39,-body.arm*.20))
            body.ik(['upperarm_'+side,'lowerarm_'+side,'hand_'+side],target,local@Vector((sign,0,-1)))
        # Tuck the chin while rolling; look forward again during recovery.
        world_rotation(body,'neck_01',(1,0,0),.25*tuck)
        body.bone('head').rotation_quaternion=Quaternion((1,0,0),.55*tuck)
        bpy.context.view_layer.update()
        low=minimum_skin(body,points)
        matrix=hips.matrix.copy()
        matrix.translation += Vector((0,0,.012-low))
        hips.matrix=matrix
        bpy.context.view_layer.update()
        body.key(i)
        floors.append(min(body.skin_floor('l'),body.skin_floor('r')))
        bounds.append(minimum_skin(body,points))
    return dict(name='Procedural_RollForward',action='RollForward',label='前方ローリング回避',
                method='procedural',category='回避',loop=False,duration=frames/FPS,
                source='authored tuck / shoulder roll / recovery; body-sized',
                minSoleM=min(floors),minBodyM=min(bounds),floor='body contact',
                support='body',rootTravelM=body.leg*2.0,gazeRevision=REVISION,
                events={'tuck':.13,'rollEnd':.80,'recovered':1.0})


def refine(body, profile):
    gaze_clips(body,profile)
    added=[make_roll(body)]
    if body.sobaya:
        for kind,label,base in [
            ('MugHold','正典のジョッキ構え','Hybrid_Idle_A'),
            ('MugRun','ジョッキを持って走る','Hybrid_Jog'),
            ('MugPunch','ジョッキ・正面パンチ','Hybrid_Idle_A'),
            ('MugHook','ジョッキ・横フック','Hybrid_Idle_A'),
            ('MugSmash','ジョッキ・重い打ち下ろし','Hybrid_Idle_A')]:
            if base not in bpy.data.actions:base='Run' if kind=='MugRun' else 'Idle'
            added.append(make_mug(body,kind,label,base))
    names={s['name'] for s in added}
    profile['clips']=[s for s in profile['clips'] if s['name'] not in names]+added
    profile['actionRefinementRevision']=REVISION


def main():
    for name in ['sobaya','fukuchan']:
        profile=json.loads((OUT/name/'profile.json').read_text())
        bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.scene.render.fps=FPS
        bpy.ops.import_scene.gltf(filepath=str(OUT/name/f'{name}.glb'))
        rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
        meshes=[o for o in bpy.context.scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' for m in o.modifiers)]
        for track in list(rig.animation_data.nla_tracks):rig.animation_data.nla_tracks.remove(track)
        use_action(rig,None);clear_pose(rig)
        refine(Body(rig,meshes,name),profile)
        use_action(rig,None);clear_pose(rig)
        bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
        for mesh in meshes:mesh.select_set(True)
        bpy.ops.export_scene.gltf(filepath=str(OUT/name/f'{name}.glb'),export_format='GLB',use_selection=True,
            export_animations=True,export_animation_mode='ACTIONS',export_frame_range=False,
            export_anim_slide_to_zero=True,export_anim_single_armature=True,export_skins=True,
            export_all_influences=False,export_def_bones=False,export_force_sampling=True,
            export_extras=True,export_optimize_animation_size=True)
        profile['glbBytes']=(OUT/name/f'{name}.glb').stat().st_size
        (OUT/name/'profile.json').write_text(json.dumps(profile,ensure_ascii=False,indent=2)+'\n')
        print('REFINED',name,len(profile['clips']),flush=True)
    catalog=json.loads((OUT/'catalog.json').read_text())
    catalog['characters']=[json.loads((OUT/n/'profile.json').read_text()) for n in ['sobaya','fukuchan']]
    (OUT/'catalog.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')

if __name__=='__main__':main()
