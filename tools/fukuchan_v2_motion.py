"""Rest-aware retargeting and a short authored greeting for the new v2 body."""
import math,hashlib
import bpy
from mathutils import Matrix,Quaternion,Vector
from fukuchan_v2_common import ROOT
from build_humanoid_motion import Body,use_action,clear_pose
from fukuchan_v2_rig import finish_pose

SOURCES={
 'Idle':'Adopted_Library_Idle_A','Walk':'Adopted_Library_Walk','Run':'Adopted_Candidate_Mixamo_Run',
 'Aim':'Aim','AimShotgun':'AimShotgun','ReloadHandgun':'ReloadHandgun','ReloadShotgun':'ReloadShotgun',
 'Hit':'Hit','Evade':'Evade','Kick':'Kick','Climb':'Climb','Vault':'Vault','Struggle':'Struggle','BreakFree':'BreakFree',
 'DanceStep':'DanceStep','DanceDisco':'DanceDisco','DanceVictory':'DanceVictory',
}

def read_motion_sources():
    source=ROOT/'04_GAME_ASSETS/3d/hazard_adopted/fukuchan.glb'
    objects=set(bpy.context.scene.objects);actions=set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=str(source))
    imported=set(bpy.context.scene.objects)-objects
    rig=next(o for o in imported if o.type=='ARMATURE')
    bind=rig.matrix_world.copy()
    for t in list(rig.animation_data.nla_tracks):rig.animation_data.nla_tracks.remove(t)
    use_action(rig,None);clear_pose(rig)
    rest={b.name:bind@b.matrix_local for b in rig.data.bones}
    record={}
    for name,label in SOURCES.items():
        use_action(rig,None);clear_pose(rig);rig.matrix_world=bind.copy()
        action=bpy.data.actions[label];use_action(rig,action)
        start,end=action.frame_range;frames=max(1,round(end-start));samples=[]
        for i in range(frames+1):
            f=start+(end-start)*i/frames;bpy.context.scene.frame_set(int(f),subframe=f-int(f))
            samples.append({b.name:rig.matrix_world@b.matrix for b in rig.pose.bones})
        record[name]={'source':label,'samples':samples,'frames':frames}
    for o in imported:bpy.data.objects.remove(o,do_unlink=True)
    for a in set(bpy.data.actions)-actions:bpy.data.actions.remove(a)
    return rest,record,hashlib.sha256(source.read_bytes()).hexdigest()

def retarget(rig,meshes):
    sr,records,digest=read_motion_sources()
    body=Body(rig,meshes,'fukuchan')
    rest=body.rest;corrections={}
    children={}
    for side in ['Left','Right']:
        children.update({side+'Arm':side+'ForeArm',side+'ForeArm':side+'Hand',side+'Shoulder':side+'Arm'})
    for b in rig.data.bones:
        name=b.name
        if name not in sr or name=='Root':continue
        tr=rest[name].to_3x3();ss=sr[name].to_quaternion().to_matrix()
        if name in children:
            child=children[name]
            sa=sr[child].translation-sr[name].translation;ta=rest[child].translation-rest[name].translation
            tr=ta.rotation_difference(sa).to_matrix()@tr
        elif name.endswith('Hand'):
            fore=name.replace('Hand','ForeArm')
            sa=sr[name].translation-sr[fore].translation;ta=rest[name].translation-rest[fore].translation
            tr=ta.rotation_difference(sa).to_matrix()@tr
        corrections[name]=ss.inverted()@tr
    srcleg=(sr['LeftUpLeg'].translation-sr['LeftLeg'].translation).length+(sr['LeftLeg'].translation-sr['LeftFoot'].translation).length
    scale=body.leg/srcleg
    report=[]
    for name,spec in records.items():
        frames=spec['frames'];body.action(name,frames)
        loop=name in ['Idle','Walk','Run','Aim','AimShotgun','DanceStep','DanceDisco','DanceVictory']
        for i,sample in enumerate(spec['samples']):
            if loop and i==frames:sample=spec['samples'][0]
            bpy.context.scene.frame_set(i);clear_pose(rig)
            for b in rig.pose.bones:
                if b.name not in corrections:continue
                loc=b.head.copy()
                if b.name=='Hips':loc=rest['Hips'].translation+(sample['Hips'].translation-sr['Hips'].translation)*scale
                b.matrix=Matrix.Translation(loc)@(sample[b.name].to_quaternion().to_matrix()@corrections[b.name]).to_4x4()
                bpy.context.view_layer.update()
            if name in ['Idle','Walk','Run','Aim','AimShotgun']:
                floor=min(body.skin_floor('l'),body.skin_floor('r'))
                h=rig.pose.bones['Hips'];m=h.matrix.copy();m.translation.z+=.003-floor;h.matrix=m
                bpy.context.view_layer.update()
            if name in ['Idle','Walk','Run','Hit','Evade']:
                # Calibrate the new open palms with anatomical axes.
                for side,sign in [('Left',1),('Right',-1)]:
                    h=rig.pose.bones[side+'Hand'];fore=rig.pose.bones[side+'ForeArm']
                    u0=(h.bone.tail_local-h.bone.head_local).normalized()
                    n0=Vector((0,-1,0));n0=(n0-u0*n0.dot(u0)).normalized()
                    u1=(h.head-fore.head).normalized()
                    n1=Vector((-sign,0,0));n1=(n1-u1*n1.dot(u1)).normalized()
                    a=Matrix((u0,n0,u0.cross(n0))).transposed()
                    b=Matrix((u1,n1,u1.cross(n1))).transposed()
                    h.matrix=Matrix.Translation(h.head)@(b@a.transposed()@rest[h.name].to_3x3()).to_4x4()
                    bpy.context.view_layer.update()
            finish_pose(body,name,i/frames)
            body.key(i)
        report.append({'name':name,'source':spec['source'],'seconds':frames/30,'loop':loop,'sourceGlbSha256':digest,'retargetLegScale':scale})
    use_action(rig,bpy.data.actions['Idle']);bpy.context.scene.frame_set(0)
    neutral={b.name:b.matrix_basis.copy() for b in rig.pose.bones}
    use_action(rig,None)
    def baseline():
        for b in rig.pose.bones:b.matrix_basis=neutral[b.name]
        bpy.context.view_layer.update()
    for name in ['Greeting','Test_HeadTurn','Test_ArmRaise','Test_ElbowBend','Test_KneeBend','Test_Grip']:
        frames=90;body.action(name,frames)
        for i in range(frames+1):
            bpy.context.scene.frame_set(i);baseline();t=i/frames
            envelope=math.sin(math.pi*t)**2
            if name=='Greeting':
                a=rig.pose.bones['RightArm'];h=rig.pose.bones['RightHand']
                goal=h.head.lerp(Vector((-.38,-.16,1.54)),envelope)
                body.ik(['upperarm_r','lowerarm_r','hand_r'],goal,Vector((-1,-.1,0)))
                # A small wrist wave, with open palm held clear of the sleeve.
                direction=(h.tail-h.head).normalized().lerp(Vector((.12*math.sin(t*math.tau*3),-.10,1)).normalized(),envelope).normalized()
                u0=(h.bone.tail_local-h.bone.head_local).normalized();n0=Vector((0,-1,0))
                n0=(n0-u0*n0.dot(u0)).normalized()
                n1=Vector((0,-1,0));n1=(n1-direction*n1.dot(direction)).normalized()
                a=Matrix((u0,n0,u0.cross(n0))).transposed()
                b=Matrix((direction,n1,direction.cross(n1))).transposed()
                target=(b@a.transposed()@rest[h.name].to_3x3()).to_quaternion()
                rotation=h.matrix.to_quaternion().slerp(target,envelope)
                h.matrix=Matrix.Translation(h.head)@rotation.to_matrix().to_4x4()
                head=rig.pose.bones['Head'];rot=Quaternion((0,0,1),.10*envelope).to_matrix()
                head.matrix=Matrix.Translation(head.head)@rot.to_4x4()@head.matrix.to_3x3().to_4x4()
            elif name=='Test_HeadTurn':
                head=rig.pose.bones['Head'];angle=math.radians(35)*math.sin(t*math.tau)
                head.matrix=Matrix.Translation(head.head)@Quaternion((0,0,1),angle).to_matrix().to_4x4()@head.matrix.to_3x3().to_4x4()
            elif name=='Test_ArmRaise':
                for side,sign in [('l',1),('r',-1)]:
                    a=body.bone('upperarm_'+side);angle=math.radians(160)*envelope
                    length=body.length('upperarm_'+side,'lowerarm_'+side)+body.length('lowerarm_'+side,'hand_'+side)
                    goal=a.head+Vector((sign*math.sin(angle),-.08,-math.cos(angle))).normalized()*(length-.004)
                    body.ik(['upperarm_'+side,'lowerarm_'+side,'hand_'+side],goal,Vector((0,-1,0)))
            elif name=='Test_ElbowBend':
                for side,sign in [('l',1),('r',-1)]:
                    h=body.bone('hand_'+side);goal=h.head.lerp(Vector((sign*.24,-.30,1.37)),envelope)
                    body.ik(['upperarm_'+side,'lowerarm_'+side,'hand_'+side],goal,Vector((sign*.3,-1,0)))
            elif name=='Test_KneeBend':
                foot=body.bone('foot_r');goal=foot.head+Vector((0,.20,.25))*envelope
                body.leg_ik('r',goal,foot.matrix.to_3x3(),Vector((0,-1,0)))
            finish_pose(body,name,t)
            bpy.context.view_layer.update();body.key(i)
        report.append({'name':name,'source':'authored in Blender on the v2 rig','seconds':3,'loop':False})
    use_action(rig,None);clear_pose(rig)
    return report
