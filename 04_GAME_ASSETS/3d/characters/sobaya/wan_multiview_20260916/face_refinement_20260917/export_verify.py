import bpy,math,json
from pathlib import Path
from mathutils import Vector
p=Path(__file__).resolve().parent;bpy.ops.wm.open_mainfile(filepath=str(p/'sobaya_front_matched.blend'));s=bpy.context.scene;c=s.camera
main=bpy.data.objects['tripo_node_4861cc5b']
for obj in list(s.objects):
 if obj.type=='MESH' and obj!=main:
  mat=obj.matrix_world.copy();obj.parent=main;obj.matrix_world=mat
bpy.ops.object.select_all(action='DESELECT')
meshes=[obj for obj in s.objects if obj.type=='MESH']
for obj in meshes:obj.select_set(True)
bpy.context.view_layer.objects.active=main
s.cycles.samples=48
bpy.ops.wm.save_as_mainfile(filepath=str(p/'sobaya_front_matched.blend'))
bpy.ops.export_scene.gltf(filepath=str(p/'sobaya_front_matched.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_cameras=False,export_lights=False)
for obj in meshes:bpy.data.objects.remove(obj,do_unlink=True)
bpy.ops.import_scene.gltf(filepath=str(p/'sobaya_front_matched.glb'))
s.render.filepath=str(p/'glb_verified_front.png');bpy.ops.render.render(write_still=True)
s.render.resolution_x=1024;s.render.resolution_y=1024
for yaw,pitch in [(-27,-10),(43,-10),(85,0)]:
 a,b=map(math.radians,(yaw,pitch));target=Vector((-.135,-.70,.995));c.location=target+Vector((3*math.sin(a)*math.cos(b),-3*math.cos(a)*math.cos(b),3*math.sin(b)));c.rotation_euler=(target-c.location).to_track_quat('-Z','Y').to_euler();c.data.ortho_scale=.40;s.render.filepath=str(p/f'glb_verified_{yaw}.png');bpy.ops.render.render(write_still=True)
c.data.ortho_scale=2.15;target=Vector((-.2,-.4,.29));c.location=target+Vector((.15,-4,.05));c.rotation_euler=(target-c.location).to_track_quat('-Z','Y').to_euler();s.render.resolution_x=900;s.render.resolution_y=1100;s.render.filepath=str(p/'glb_verified_wholebody.png');bpy.ops.render.render(write_still=True)
print('EXPORTED AND REIMPORTED',p/'sobaya_front_matched.glb')
