"""Blender round-trip checks of the actual exported locomotion and shoe soles."""
import bpy
import hashlib
import json
import math
from pathlib import Path

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
for name in ['Walk','Run']:
    action=bpy.data.actions[name]
    rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
    result=[]
    for frame in range(int(action.frame_range[1])+1):
        scene.frame_set(frame)
        evaluated=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get());posed=evaluated.to_mesh()
        assert all(math.isfinite(c) for v in posed.vertices for c in v.co)
        heights={side:min(v.co.z for v,original in zip(posed.vertices,mesh.data.vertices)
                          if original.co.z<.1 and original.co.x*sign>0)
                 for side,sign in [('L',1),('R',-1)]}
        result.append(heights);evaluated.to_mesh_clear()
    minimum=min(min(h.values()) for h in result)
    maximum_support_height=max(min(h.values()) for h in result)
    assert minimum>=-.003,(name,'sole penetration',minimum)
    if name=='Walk':assert maximum_support_height<.012,('walking floats',maximum_support_height)
    rows[name]={'frames':len(result),'minimum_sole_height_m':minimum,
                'maximum_lower_sole_height_m':maximum_support_height}
report={'result':'PASS','sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'clips':rows,
        'checks':['finite deformed vertices','exported shoes do not penetrate floor beyond 3 mm',
                  'walking always has a sole within 12 mm of floor'],
        'limits':'Does not certify all foot sliding, transitions, terrain IK or subjective motion quality.'}
(OUT/'locomotion_validation.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
