import bpy,math
from mathutils import Matrix,Vector
from build_humanoid_motion import Body,use_action,clear_pose
from fukuchan_v2_motion import read_motion_sources
from poses import curl

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
            curl(rig,.15 if name in ['Idle','Walk'] else .35)
            body.key(i)
        report.append({'name':name,'source':spec['source'],'seconds':frames/30,'loop':loop,'sourceGlbSha256':digest,'retargetLegScale':scale})
    use_action(rig,None);clear_pose(rig)
    return report
