"""Blender round-trip checks of the actual exported locomotion and shoe soles."""
import bpy
import hashlib
import json
import math
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parent.parent
OUT=ROOT/'04_GAME_ASSETS/3d/characters/sobaya/rig_v3'
path=OUT/'sobaya_rig.glb'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.context.scene.render.fps=30
bpy.ops.import_scene.gltf(filepath=str(path))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
mesh=next(o for o in bpy.context.scene.objects if o.type=='MESH')
scene=bpy.context.scene;scene.render.fps=30
rows={}
rest_width=(rig.data.bones['UpperArm.L'].head_local-rig.data.bones['UpperArm.R'].head_local).length
for name in ['Walk','Run']:
    action=bpy.data.actions[name]
    rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
    result=[];posture=[]
    for frame in range(int(action.frame_range[1])+1):
        scene.frame_set(frame)
        evaluated=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get());posed=evaluated.to_mesh()
        assert all(math.isfinite(c) for v in posed.vertices for c in v.co)
        heights={side:min(v.co.z for v,original in zip(posed.vertices,mesh.data.vertices)
                          if original.co.z<.1 and original.co.x*sign>0)
                 for side,sign in [('L',1),('R',-1)]}
        result.append(heights);evaluated.to_mesh_clear()
        head=rig.pose.bones['Head']
        forward=(head.matrix.to_quaternion()@head.bone.matrix_local.to_quaternion().inverted())@Vector((0,-1,0))
        pitch=math.degrees(math.asin(max(-1,min(1,forward.z))))
        yaw=math.degrees(math.atan2(forward.x,-forward.y))
        inv=rig.pose.bones['Chest'].matrix.inverted()
        width=abs((inv@rig.pose.bones['UpperArm.L'].head).x-(inv@rig.pose.bones['UpperArm.R'].head).x)
        assert abs(pitch)<2,(name,frame,'gaze elevation',pitch)
        assert abs(yaw)<2,(name,frame,'gaze direction',yaw)
        assert .995<width/rest_width<1.005,(name,frame,'shoulder width',width)
        posture.append({'face_pitch_degrees':pitch,'face_yaw_degrees':yaw,'shoulder_width_m':width})
    minimum=min(min(h.values()) for h in result)
    maximum_support_height=max(min(h.values()) for h in result)
    assert minimum>=-.003,(name,'sole penetration',minimum)
    if name=='Walk':assert maximum_support_height<.012,('walking floats',maximum_support_height)
    rows[name]={'frames':len(result),'minimum_sole_height_m':minimum,
                'maximum_lower_sole_height_m':maximum_support_height,
                'posture_ranges':{k:[min(p[k] for p in posture),max(p[k] for p in posture)] for k in posture[0]}}
report={'result':'PASS','sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'clips':rows,
        'rest_shoulder_width_m':rest_width,
        'checks':['finite deformed vertices','exported shoes do not penetrate floor beyond 3 mm',
                  'walking always has a sole within 12 mm of floor',
                  'face elevation and yaw within 2 degrees of forward',
                  'chest-local shoulder width within 0.5 percent of authored rest width'],
        'limits':'Does not certify all foot sliding, transitions, terrain IK or subjective motion quality.'}
(OUT/'locomotion_validation.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
