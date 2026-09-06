"""Sample skinned Vault vertices in the central window-wall slab.
Run with Blender --background --factory-startup --python tools/audit_hazard_window_clearance.py.
This records penetrations rather than declaring a broad collision pass.
"""
import bpy,json,math
from pathlib import Path
root=Path(__file__).resolve().parent.parent
result={}
for name,path in [('fukuchan','fukuchan/rig_v1/fukuchan.blend'),('sobaya','sobaya/rig_v3/sobaya_rig.blend')]:
 bpy.ops.wm.open_mainfile(filepath=str(root/'04_GAME_ASSETS/3d/characters'/path))
 rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
 mesh=next(o for o in bpy.context.scene.objects if o.type=='MESH')
 rig.animation_data.action=bpy.data.actions['Vault'];rows=[]
 for f in range(0,49):
  bpy.context.scene.frame_set(f);bpy.context.view_layer.update()
  t=f/48;ry=.95-1.9*t*t*(3-2*t);rz=.55*math.sin(math.pi*t)**2
  evaluated=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
  vs=[v.co for v in evaluated.data.vertices if abs(v.co.y+ry)<.175 and abs(v.co.x)<.78]
  bad=[v for v in vs if v.z+rz<.82-.02 or v.z+rz>2.42+.02]
  rows.append({'frame':f,'wallVertices':len(vs),'penetrating':len(bad),'worstGroups':[(v.index,[(mesh.vertex_groups[g.group].name,round(g.weight,2)) for g in mesh.data.vertices[v.index].groups]) for v in evaluated.data.vertices if v.co in bad][:3],'lowest':min((v.z+rz for v in vs),default=None),'highest':max((v.z+rz for v in vs),default=None)})
 result[name]=rows
(root/'21_SOBAYA_HAZARD_LAB/evidence/window-clearance.json').write_text(json.dumps(result,indent=2))
print(json.dumps({name:{'poses':len(rows),'violatingVertices':sum(r['penetrating'] for r in rows)} for name,rows in result.items()}))
