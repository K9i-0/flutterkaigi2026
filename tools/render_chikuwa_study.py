"""Render the actual v3 rigged GLB in Cycles; no generated-photo substitution."""
from pathlib import Path
import bpy,math,hashlib,json
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'04_GAME_ASSETS/3d/props/chikuwa/v3'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(OUT/'chikuwa.glb'))
for o in list(bpy.context.scene.objects):
    if o.type=='ARMATURE':
        o.animation_data_clear();o.data.pose_position='REST'
roots=[o for o in bpy.context.scene.objects if o.type=='ARMATURE']
bpy.context.view_layer.update()
def bounds():
    coords=[o.matrix_world@Vector(c) for o in bpy.context.scene.objects if o.type=='MESH' and o.data.name.startswith('ContinuousFishPaste') for c in o.bound_box]
    lo=Vector([min(c[i] for c in coords) for i in range(3)]);hi=Vector([max(c[i] for c in coords) for i in range(3)])
    return lo,hi
lo,hi=bounds();axis=max(range(3),key=lambda i:hi[i]-lo[i])
rot=Matrix.Rotation(-math.pi/2,4,'Z') if axis==1 else Matrix.Rotation(math.pi/2,4,'Y') if axis==2 else Matrix.Identity(4)
for o in roots:o.matrix_world=rot@o.matrix_world
bpy.context.view_layer.update();lo,hi=bounds();center=(lo+hi)/2
for o in roots:o.location-=center
bpy.context.view_layer.update();lo,hi=bounds();print('Model bounds',list(lo),list(hi),flush=True)
mat=bpy.data.materials.new('Warm grey studio');mat.use_nodes=True
p=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');p.inputs['Base Color'].default_value=(.52,.50,.47,1);p.inputs['Roughness'].default_value=.9
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,lo.z+.003));floor=bpy.context.object;floor.data.materials.append(mat)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=48;scene.cycles.use_denoising=True
scene.world.use_nodes=True
bg=next(n for n in scene.world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs['Color'].default_value=(.80,.85,.92,1);bg.inputs['Strength'].default_value=.35
bpy.ops.object.light_add(type='AREA',location=(-1.7,-3.7,5));key=bpy.context.object;key.data.energy=440;key.data.shape='DISK';key.data.size=3.5;key.rotation_euler=(Vector((0,0,0))-key.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.light_add(type='AREA',location=(1.5,2,3));fill=bpy.context.object;fill.data.energy=100;fill.data.size=3;fill.rotation_euler=(-fill.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(3.1,-9,3));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,0))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=3.35;scene.camera=cam
scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast';scene.view_settings.exposure=0
scene.render.resolution_x=1600;scene.render.resolution_y=700;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.filepath=str(OUT/'beauty.png')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'study.blend'))
bpy.ops.render.render(write_still=True)

(OUT/'render_manifest.json').write_text(json.dumps({'source':'chikuwa.glb','sha256':hashlib.sha256((OUT/'chikuwa.glb').read_bytes()).hexdigest(),'output':'beauty.png','renderer':'Blender 5.1.2 Cycles','samples':48,'resolution':[1600,700],'pose':'rest','camera':'orthographic','imagegen':False},indent=2)+'\n')
