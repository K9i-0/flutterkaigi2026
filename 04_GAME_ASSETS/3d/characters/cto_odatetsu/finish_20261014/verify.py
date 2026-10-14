"""Re-import the exported GLB and render review views under identical studio light."""
import bpy,json,math,sys
from pathlib import Path
from mathutils import Vector
O=Path(__file__).resolve().parent;Q=O/'qa'
bpy.ops.wm.open_mainfile(filepath=str(O/'normalized_base.blend'))
s=bpy.context.scene
for o in list(s.objects):
 if o.type=='MESH':bpy.data.objects.remove(o,do_unlink=True)
bpy.ops.import_scene.gltf(filepath=str(O/'cto_odatetsu_static.glb'))
meshes=[o for o in s.objects if o.type=='MESH'];s.cycles.samples=16
report={'meshes':len(meshes),'materials':len(set(m.name for o in meshes for m in o.data.materials)),'vertices_after_gltf_uv_splits':sum(len(o.data.vertices) for o in meshes),'polygons':sum(len(o.data.polygons) for o in meshes),'armatures':sum(o.type=='ARMATURE' for o in s.objects)}
pts=[o.matrix_world@v.co for o in meshes for v in o.data.vertices];report['bounds']=[[min(p[i] for p in pts),max(p[i] for p in pts)] for i in range(3)]
for o in meshes:
 for m in o.data.materials:
  b=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED');assert b.inputs['Metallic'].default_value==0
  assert b.inputs['Base Color'].is_linked
(O/'export_validation.json').write_text(json.dumps(report,indent=2)+'\n')
c=s.camera
views=[('front',(0,-1,0),(0,0,.88),1.95,720,900),('back',(0,1,0),(0,0,.88),1.95,720,900),('left',(1,0,0),(0,0,.88),1.95,720,900),('right',(-1,0,0),(0,0,.88),1.95,720,900),('hero',(.5,-1,.05),(0,0,.88),1.95,900,1080),('head',(0,-1,0),(0,0,1.55),.42,960,960),('chest',(0,-1,0),(0,0,1.25),.48,960,960),('hands',(.25,-1,0),(0,0,.88),.90,960,960),('shoes',(0,-1,.35),(0,0,.09),.55,960,960),('shoe_left',(1,0,.15),(.22,0,.09),.37,960,960),('shoe_right',(-1,0,.15),(-.22,0,.09),.37,960,960)]
for name,di,pt,sc,w,h in views:
 if '--shoes-only' in sys.argv and name not in ['front','hero','shoes','shoe_left','shoe_right']:continue
 c.location=Vector(pt)+Vector(di).normalized()*5;c.rotation_euler=(Vector(pt)-c.location).to_track_quat('-Z','Y').to_euler();c.data.ortho_scale=sc;s.render.resolution_x=w;s.render.resolution_y=h;s.render.filepath=str(Q/('after_'+name+'.png'));bpy.ops.render.render(write_still=True)
print('VERIFY_DONE',flush=True)
