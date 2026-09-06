"""Retarget locally downloaded Mixamo locomotion onto the repaired Sobaya rig.

Blender --background --python tools/retarget_sobaya_mocap.py
Raw FBX stays in .local/mixamo_sobaya/source; never download through a private API.
"""
import bpy
import json
import math
import sys
import hashlib
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'tools'))
from sobaya_garment import animate_hem, relax_hem_weights

OUT = ROOT / '04_GAME_ASSETS/3d/characters/sobaya/rig_v3'
INPUT = ROOT / '.local/mixamo_sobaya/source'
MAP = {'Hips':'Hips', 'Spine':'Spine', 'Chest':'Spine2', 'Neck':'Neck', 'Head':'Head'}
for side, word in [('L','Left'),('R','Right')]:
    for target, source in [('Shoulder','Shoulder'),('UpperArm','Arm'),('Forearm','ForeArm'),('Hand','Hand'),
                           ('Thigh','UpLeg'),('Shin','Leg'),('Foot','Foot'),('Toe','ToeBase')]:
        MAP[target+'.'+side] = word+source


def add_toes(rig, mesh):
    bpy.context.view_layer.objects.active=rig
    bpy.ops.object.mode_set(mode='EDIT')
    for side in ['L','R']:
        foot=rig.data.edit_bones['Foot.'+side]
        toe=rig.data.edit_bones.new('Toe.'+side);toe.head=foot.tail
        toe.tail=toe.head+Vector((0,-.12,0));toe.parent=foot
        toe.align_roll(Vector((0,0,1)))
    bpy.ops.object.mode_set(mode='OBJECT')
    for side in ['L','R']:
        foot=mesh.vertex_groups['Foot.'+side];toe=mesh.vertex_groups.new(name='Toe.'+side)
        for v in mesh.data.vertices:
            weight=next((g.weight for g in v.groups if g.group==foot.index),0)
            if not weight:continue
            t=max(0,min(1,(-v.co.y-.10)/.075));t=t*t*(3-2*t)
            if t:
                foot.add([v.index],weight*(1-t),'REPLACE');toe.add([v.index],weight*t,'REPLACE')
    bpy.context.view_layer.objects.active=mesh
    bpy.ops.object.vertex_group_limit_total(limit=4)
    bpy.ops.object.vertex_group_normalize_all(lock_active=False)


def import_motion(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=str(path))
    objects = set(bpy.data.objects)-before
    arm = next(o for o in objects if o.type=='ARMATURE')
    action = arm.animation_data.action
    start, end = map(int, action.frame_range)
    def name(short):
        return next(b.name for b in arm.data.bones if b.name.split(':')[-1]==short)
    names = {short:name(short) for short in set(MAP.values()) | {'LeftToeBase','RightToeBase'}}
    rest = {short:arm.matrix_world @ arm.data.bones[full].matrix_local for short,full in names.items()}
    samples=[]
    for frame in range(start,end+1):
        bpy.context.scene.frame_set(frame)
        samples.append({short:arm.matrix_world @ arm.pose.bones[full].matrix for short,full in names.items()})
    for obj in objects: bpy.data.objects.remove(obj,do_unlink=True)
    bpy.data.actions.remove(action)
    return rest,samples


def rotation(matrix):
    return matrix.to_quaternion().to_matrix()


def average_rotation(rotations):
    reference=rotations[0].to_quaternion()
    components=[0.0]*4
    for matrix in rotations:
        q=matrix.to_quaternion()
        if q.dot(reference)<0:q.negate()
        for i in range(4):components[i]+=q[i]
    return Quaternion(components).normalized()


def posture_reference(rest, samples):
    # Neutralize the performer's habitual clavicle pose, not the character's
    # broad authored shoulders. Retain the changing motion around that mean.
    shoulders={side:[] for side in ['L','R']};gaze=[]
    for sample in samples[:-1]:
        chest=rotation(sample['Spine2'])@rotation(rest['Spine2']).inverted()
        for side,word in [('L','Left'),('R','Right')]:
            skin=rotation(sample[word+'Shoulder'])@rotation(rest[word+'Shoulder']).inverted()
            shoulders[side].append(chest.inverted()@skin)
        forward=(rotation(sample['Head'])@rotation(rest['Head']).inverted())@Vector((0,-1,0))
        gaze.append((math.asin(max(-1,min(1,forward.z))),math.atan2(forward.x,-forward.y)))
    return {s:average_rotation(v) for s,v in shoulders.items()}, tuple(sum(p[i] for p in gaze)/len(gaze) for i in range(2))


def solve_leg(rig, side, ankle, pole, foot_rotation):
    thigh=rig.pose.bones['Thigh.'+side];shin=rig.pose.bones['Shin.'+side]
    hip=thigh.head.copy();a=thigh.bone.length;b=shin.bone.length
    delta=ankle-hip;distance=min(delta.length,a+b-.0005);axis=delta.normalized()
    bend=pole-axis*pole.dot(axis)
    if bend.length<.0001: bend=Vector((0,-1,0))
    bend.normalize();along=(a*a-b*b+distance*distance)/(2*distance)
    knee=hip+axis*along+bend*math.sqrt(max(0,a*a-along*along))
    ankle=hip+axis*distance
    for bone,head,tail in [(thigh,hip,knee),(shin,knee,ankle)]:
        q=(bone.tail-bone.head).rotation_difference(tail-head)
        bone.matrix=Matrix.Translation(head)@q.to_matrix().to_4x4()@bone.matrix.to_3x3().to_4x4()
        bpy.context.view_layer.update()
    rig.pose.bones['Foot.'+side].matrix=Matrix.Translation(ankle)@foot_rotation.to_4x4()
    bpy.context.view_layer.update()


def bake(rig, mesh, name, source):
    rest,samples=import_motion(source)
    shoulder_neutral,gaze_neutral=posture_reference(rest,samples)
    rig.animation_data.action=None
    for b in rig.pose.bones:
        b.location=(0,0,0);b.rotation_mode='QUATERNION';b.rotation_quaternion=Quaternion();b.scale=(1,1,1)
    bpy.context.view_layer.update()
    # Source and target both use Blender Z-up / -Y-forward. Match each bone's
    # anatomical axis in a common T pose, including the target's authored A pose.
    correction={}
    for target,short in MAP.items():
        rt=rig.data.bones[target].matrix_local.to_3x3()
        rs=rotation(rest[short])
        if target.startswith(('UpperArm','Forearm','Hand')):
            rt=(rt.col[1].rotation_difference(rs.col[1])).to_matrix()@rt
        correction[target]=rs.inverted()@rt
    src_leg=(rest['LeftUpLeg'].translation-rest['LeftLeg'].translation).length+(rest['LeftLeg'].translation-rest['LeftFoot'].translation).length
    scale=(rig.data.bones['Thigh.L'].length+rig.data.bones['Shin.L'].length)/src_leg
    travel=samples[-1]['Hips'].translation-samples[0]['Hips'].translation
    travel.z=0
    frames=len(samples)-1;duration=frames/30
    center=sum((m['Hips'].translation for m in samples),Vector())/len(samples)
    center.z=rest['Hips'].translation.z
    # Use the first root-forward position but the mean lateral position.
    center.y=samples[0]['Hips'].translation.y
    old=bpy.data.actions.get(name)
    if old: bpy.data.actions.remove(old)
    action=bpy.data.actions.new(name);action.use_fake_user=True;rig.animation_data.action=action
    foot_points={}
    sole_vertices={}
    for side in ['L','R']:
        fg=mesh.vertex_groups['Foot.'+side].index;tg=mesh.vertex_groups['Toe.'+side].index
        points=[]
        for v in mesh.data.vertices:
            weights={g.group:g.weight for g in v.groups};f=weights.get(fg,0);t=weights.get(tg,0)
            if v.co.z<.055 and f+t>.9:points.append((v.co.copy(),t/(f+t)))
        foot_points[side]=points
        sign=1 if side=='L' else -1
        sole_vertices[side]=[(v.co.copy(),[(mesh.vertex_groups[g.group].name,g.weight) for g in v.groups])
                             for v in mesh.data.vertices if v.co.z<.055 and v.co.x*sign>0]
    first_pose=None;diagnostics=[]
    for frame,sample in enumerate(samples):
        bpy.context.scene.frame_set(frame)
        for b in rig.pose.bones:
            b.location=(0,0,0);b.rotation_quaternion=Quaternion()
        displacement=(sample['Hips'].translation-center-travel*(frame/frames))*scale
        # Keep recorded vertical compression, lateral weight transfer and yaw.
        root=rig.data.bones['Hips'].head_local+displacement
        chest_skin=rotation(sample['Spine2'])@rotation(rest['Spine2']).inverted()
        head_skin=rotation(sample['Head'])@rotation(rest['Head']).inverted()
        forward=head_skin@Vector((0,-1,0))
        pitch=.2*(math.asin(max(-1,min(1,forward.z)))-gaze_neutral[0])
        yaw=.35*(math.atan2(forward.x,-forward.y)-gaze_neutral[1])
        gaze=Vector((math.sin(yaw)*math.cos(pitch),-math.cos(yaw)*math.cos(pitch),math.sin(pitch)))
        head_skin=forward.rotation_difference(gaze).to_matrix()@head_skin
        for target,short in MAP.items():
            b=rig.pose.bones[target]
            r=rotation(sample[short])@correction[target]
            if target=='Head':
                r=head_skin@b.bone.matrix_local.to_3x3()
            elif target=='Neck':
                neck_skin=rotation(sample[short])@rotation(rest[short]).inverted()
                r=neck_skin.to_quaternion().slerp(head_skin.to_quaternion(),.35).to_matrix()@b.bone.matrix_local.to_3x3()
            elif target.startswith('Shoulder.'):
                side=target[-1]
                skin=rotation(sample[short])@rotation(rest[short]).inverted()
                delta=(chest_skin.inverted()@skin).to_quaternion()@shoulder_neutral[side].inverted()
                r=chest_skin@Quaternion().slerp(delta,.5).to_matrix()@b.bone.matrix_local.to_3x3()
            elif target.startswith(('UpperArm.','Forearm.','Hand.')):
                # Carry the complete arm chain outward together: elbow flexion
                # and captured swing stay intact while clearing the broad torso.
                side=target[-1];upper=rig.data.bones['UpperArm.'+side]
                axis=(upper.tail_local-upper.head_local).normalized()
                authored_open=math.atan2(abs(axis.x),-axis.z)
                angle=authored_open*(.65 if name=='Walk' else .45)*(1 if side=='L' else -1)
                r=Quaternion(chest_skin@Vector((0,-1,0)),angle).to_matrix()@r
            b.matrix=Matrix.Translation(root if target=='Hips' else b.head)@r.to_4x4()
            bpy.context.view_layer.update()
        for side,word,sign in [('L','Left',1),('R','Right',-1)]:
            short=word+'Foot';b=rig.pose.bones['Foot.'+side]
            r=rotation(sample[short])@correction[b.name]
            delta=(sample[short].translation-rest[short].translation-travel*(frame/frames))*scale
            ankle=rig.data.bones[b.name].head_local+delta
            ankle.x+=sign*(-.045)-center.x*scale
            ankle.y-= (center.y-rest['Hips'].translation.y)*scale
            # The new shoe's sole differs from X Bot. Solve its actual skinned
            # sole against the floor, instead of adding a fixed ankle offset.
            skin=Matrix.Translation(ankle)@r.to_4x4()@b.bone.matrix_local.inverted()
            toe=rig.pose.bones['Toe.'+side]
            tr=rotation(sample[word+'ToeBase'])@correction[toe.name]
            def toe_matrix(foot_skin):
                return Matrix.Translation(foot_skin@toe.bone.head_local)@tr.to_4x4()
            ts=toe_matrix(skin)@toe.bone.matrix_local.inverted()
            lowest=min(((skin@p)*(1-w)+(ts@p)*w).z for p,w in foot_points[side])
            source_toe=sample[word+'ToeBase'].translation.z
            contact=max(0,min(1,(.045-source_toe)/.025))
            desired_toe=toe.bone.head_local+(sample[word+'ToeBase'].translation-rest[word+'ToeBase'].translation-travel*(frame/frames))*scale
            desired_toe.x+=sign*(-.045)-center.x*scale
            desired_toe.y-=(center.y-rest['Hips'].translation.y)*scale
            toe_delta=desired_toe-(skin@toe.bone.head_local)
            # During toe support use its captured world-space track as anchor.
            ankle.x+=toe_delta.x*contact;ankle.y+=toe_delta.y*contact
            ankle.z+=max(0,.004-lowest)+min(0,.004-lowest)*contact
            pole=sample[word+'Leg'].translation-(sample[word+'UpLeg'].translation+sample[short].translation)*.5
            solve_leg(rig,side,ankle,pole,r)
            toe.matrix=toe_matrix(b.matrix@b.bone.matrix_local.inverted())
            bpy.context.view_layer.update()
            for _ in range(2):
                matrices={bone.name:bone.matrix@bone.bone.matrix_local.inverted() for bone in rig.pose.bones}
                actual=min(
                    sum(((matrices[n]@p)*w for n,w in weights),Vector()).z for p,weights in sole_vertices[side])
                if actual>=.002:break
                ankle.z+=.003-actual
                solve_leg(rig,side,ankle,pole,r)
                toe.matrix=toe_matrix(b.matrix@b.bone.matrix_local.inverted())
                bpy.context.view_layer.update()
        animate_hem(rig)
        pose={b.name:(b.location.copy(),b.rotation_quaternion.copy()) for b in rig.pose.bones}
        if frame==0:first_pose=pose
        # The source is already a full loop. Keep its captured timing and
        # only close the tiny FBX endpoint mismatch on the duplicate last key.
        if frame==frames:
            for b in rig.pose.bones:
                b.location=first_pose[b.name][0]
                b.rotation_quaternion=first_pose[b.name][1]
        for b in rig.pose.bones:
            b.keyframe_insert('location',frame=frame,group=b.name)
            b.keyframe_insert('rotation_quaternion',frame=frame,group=b.name)
        diagnostics.append({'frame':frame,'hips':list(root),'left_ankle':list(rig.pose.bones['Foot.L'].head),'right_ankle':list(rig.pose.bones['Foot.R'].head)})
    action.use_frame_range=True;action.frame_start=0;action.frame_end=frames
    return {'name':name,'duration':duration,'fps':30,'loop':True,'ground_speed_mps':travel.length*scale/duration,
            'source_file':source.name,'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'source_scale':scale,
            'posture':'forward gaze; authored shoulder width with 50% captured clavicle variation; body-sized arm clearance',
            'samples':diagnostics}


def build():
    for file in ['walk_standard.fbx','run_weighted.fbx']:
        if not (INPUT/file).exists():raise FileNotFoundError(INPUT/file)
    source=ROOT/'04_GAME_ASSETS/3d/characters/sobaya/rig_v2/sobaya_rig.blend'
    if not source.exists():raise RuntimeError('Build rig_v2 first to create the editable baseline')
    bpy.ops.wm.open_mainfile(filepath=str(source))
    rig=bpy.data.objects['SobayaRig'];mesh=bpy.data.objects['SobayaBody']
    garment = relax_hem_weights(mesh)
    add_toes(rig,mesh)
    report=json.loads((source.parent/'rig.json').read_text());report['rig_version']=3;report['mocap']=[]
    report['garment'] = garment
    report['bone_count']=len(rig.data.bones);report['deform_bones']=sum(b.use_deform for b in rig.data.bones)
    for name,file in [('Walk','walk_standard.fbx'),('Run','run_weighted.fbx')]:
        path=INPUT/file
        if path.exists():
            data=bake(rig,mesh,name,path);report['mocap'].append({k:v for k,v in data.items() if k!='samples'})
            (INPUT.parent/(name.lower()+'_retarget_samples.json')).write_text(json.dumps(data['samples'],indent=2))
            for clip in report['clips']:
                if clip['name']==name:clip.update({k:v for k,v in data.items() if k!='samples'})
    from hazard_climb_motion import bake_climb
    report['clips'].append({**bake_climb(rig, sobaya=True), 'loop': True, 'fps': 30})
    from hazard_vault_motion import bake_vault
    report['clips'].append({**bake_vault(rig, sobaya=True), 'loop': False, 'fps': 30})
    from hazard_grapple_motion import bake_grapple
    report['clips'].extend(bake_grapple(rig, sobaya=True))
    rig.animation_data.action=None
    for b in rig.pose.bones:b.location=(0,0,0);b.rotation_quaternion=Quaternion()
    bpy.context.scene.frame_set(0)
    OUT.mkdir(parents=True,exist_ok=True)
    (OUT/'.gitignore').write_text('*.blend\n*.blend1\n')
    (OUT/'rig.json').write_text(json.dumps(report,indent=2)+'\n')
    bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);mesh.select_set(True);bpy.context.view_layer.objects.active=rig
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'sobaya_rig.blend'))
    bpy.ops.export_scene.gltf(filepath=str(OUT/'sobaya_rig.glb'),export_format='GLB',use_selection=True,
        export_animations=True,export_animation_mode='ACTIONS',export_frame_range=False,
        export_anim_slide_to_zero=True,export_anim_single_armature=True,export_skins=True,
        export_all_influences=False,export_def_bones=False,export_force_sampling=True,export_extras=True)
    print('MOCAP',[(c['name'],c['duration'],c['ground_speed_mps']) for c in report['mocap']],flush=True)

if __name__=='__main__':build()
