import bpy,json,math
from pathlib import Path
from mathutils import Vector
root=Path(__file__).resolve().parents[5]
out=root/'04_GAME_ASSETS/3d/characters/cto_odatetsu/finish_20261014';qa=out/'qa'
qa.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(root/'04_GAME_ASSETS/3d/characters/cto_odatetsu/tripo_multiview_20261014/raw/output_model_url.fbx'))
objs=[o for o in bpy.context.scene.objects if o.type=='MESH']
report=[]
for o in objs:
 pts=[o.matrix_world@v.co for v in o.data.vertices]
 report.append({'name':o.name,'vertices':len(o.data.vertices),'polygons':len(o.data.polygons),'bounds':[[min(p[i] for p in pts),max(p[i] for p in pts)] for i in range(3)],'rotation':list(o.rotation_euler),'scale':list(o.scale),'materials':[m.name for m in o.data.materials]})
for im in bpy.data.images:
 if im.type=='IMAGE':
  im.filepath_raw=str(qa/(im.name.replace('/','_')+'.png'));im.file_format='PNG';im.save()
print(json.dumps(report),flush=True)
print([(m.name,[(n.type,n.image.name if n.type=='TEX_IMAGE' and n.image else '') for n in m.node_tree.nodes]) for m in bpy.data.materials],flush=True)
(out/'inspection.json').write_text(json.dumps(report,indent=2))
# normalize model coordinates and height, keeping proportions
for o in objs:
 bpy.context.view_layer.objects.active=o;o.select_set(True)
 bpy.ops.object.transform_apply(location=False,rotation=True,scale=True);o.select_set(False)
pts=[o.matrix_world@v.co for o in objs for v in o.data.vertices]
lo=Vector(tuple(min(p[i] for p in pts) for i in range(3)));hi=Vector(tuple(max(p[i] for p in pts) for i in range(3)))
print('normalized import bounds',list(lo),list(hi),flush=True)
sc=1.75/(hi.z-lo.z);center=Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z))
for o in objs:
 for v in o.data.vertices:v.co=(v.co-center)*sc
 for p in o.data.polygons:p.use_smooth=True
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=24;s.cycles.use_denoising=True
s.world=bpy.data.worlds.new('Studio');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.75,.75,.75,1);s.world.node_tree.nodes['Background'].inputs[1].default_value=.7
s.view_settings.view_transform='Standard'
for name,loc,power,size in [('Key',(2,-3,4),160,4),('Fill',(-3,-2,2),100,3),('Rim',(1,3,3),140,3)]:
 d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size;o=bpy.data.objects.new(name,d);s.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,.9))-o.location).to_track_quat('-Z','Y').to_euler()
d=bpy.data.cameras.new('AuditCamera');c=bpy.data.objects.new('AuditCamera',d);s.collection.objects.link(c);s.camera=c;d.type='ORTHO'
s.render.image_settings.file_format='PNG';s.render.film_transparent=False
for name,loc in [('front',(0,-4,.9)),('back',(0,4,.9)),('side',(4,0,.9)),('opposite',(-4,0,.9))]:
 c.location=loc;c.rotation_euler=(Vector((0,0,.9))-c.location).to_track_quat('-Z','Y').to_euler();d.ortho_scale=1.95;s.render.resolution_x=720;s.render.resolution_y=900;s.render.resolution_percentage=100;s.render.filepath=str(qa/('before_'+name+'.png'));bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(out/'working_base.blend'))
print('AUDIT_DONE',flush=True)
