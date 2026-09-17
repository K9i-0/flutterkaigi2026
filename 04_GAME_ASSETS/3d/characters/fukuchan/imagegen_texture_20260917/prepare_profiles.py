import bpy,json
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(OUT.parent/'front_fidelity_20260917/fukuchan_front_faithful.blend'))
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=16;s.cycles.use_denoising=True
s.render.resolution_x=s.render.resolution_y=1024;s.render.resolution_percentage=100;s.view_settings.view_transform='Standard';s.render.film_transparent=False
for o in list(s.objects):
 if o.type in ['LIGHT','CAMERA']:bpy.data.objects.remove(o,do_unlink=True)
w=bpy.data.worlds.new('Gray');w.use_nodes=True;w.node_tree.nodes['Background'].inputs[0].default_value=(.32,.32,.32,1);w.node_tree.nodes['Background'].inputs[1].default_value=.7;s.world=w
cam=bpy.data.objects.new('Projection',bpy.data.cameras.new('Projection'));s.collection.objects.link(cam);cam.data.type='ORTHO';cam.data.ortho_scale=.38;s.camera=cam
views=[('profile_left',(1,0,0)),('profile_right',(-1,0,0))]
for mat in bpy.data.materials:
 if not mat.use_nodes:continue
 bs=next((n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
 if not bs:continue
 out=next(n for n in mat.node_tree.nodes if n.type=='OUTPUT_MATERIAL');em=mat.node_tree.nodes.new('ShaderNodeEmission')
 if bs.inputs['Base Color'].links:mat.node_tree.links.new(bs.inputs['Base Color'].links[0].from_socket,em.inputs['Color'])
 else:em.inputs['Color'].default_value=bs.inputs['Base Color'].default_value
 mat.node_tree.links.new(em.outputs[0],out.inputs['Surface'])
for name,d in views:
 pt=Vector((0,0,1.54));cam.location=pt+Vector(d).normalized()*5;cam.rotation_euler=(pt-cam.location).to_track_quat('-Z','Y').to_euler();s.render.filepath=str(OUT/('albedo_'+name+'.png'));bpy.ops.render.render(write_still=True)
(OUT/'projection_profiles.json').write_text(json.dumps({'target':[0,0,1.54],'scale':.38,'views':views,'panel_size':1024},indent=2)+'\n')
print('PREPARED')
