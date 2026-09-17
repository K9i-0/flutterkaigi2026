import bpy,sys,math,json
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
MODE='baseline' if '--baseline' in sys.argv else 'candidate'
path=OUT.parent/'finish_C_20260917/fukuchan_finished.glb' if MODE=='baseline' else OUT/'fukuchan_front_faithful.glb'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(path));sc=bpy.context.scene
sc.render.engine='CYCLES';sc.cycles.samples=24;sc.cycles.use_denoising=True
sc.render.resolution_x=sc.render.resolution_y=900;sc.render.resolution_percentage=100
sc.view_settings.view_transform='Standard'
w=bpy.data.worlds.new('Studio');w.use_nodes=True;w.node_tree.nodes['Background'].inputs[0].default_value=(.42,.45,.48,1);w.node_tree.nodes['Background'].inputs[1].default_value=.49;sc.world=w
cam=bpy.data.objects.new('Calibrated',bpy.data.cameras.new('Calibrated'));sc.collection.objects.link(cam);cam.data.type='ORTHO';cam.data.ortho_scale=180/590;sc.camera=cam
for name,pos,power,size in [('Key',(-1,-5,2.5),280,5),('Fill',(3,-4,2),140,5),('Rim',(1,3,4),105,4)]:
    l=bpy.data.lights.new(name,'AREA');l.energy=power;l.shape='DISK';l.size=size;o=bpy.data.objects.new(name,l);sc.collection.objects.link(o);o.location=pos;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
if '--albedo' in sys.argv:
    sc.view_settings.view_transform='Standard'
    for mat in bpy.data.materials:
        if not mat.use_nodes:continue
        bs=next((n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
        if not bs:continue
        out=next(n for n in mat.node_tree.nodes if n.type=='OUTPUT_MATERIAL')
        em=mat.node_tree.nodes.new('ShaderNodeEmission')
        if bs.inputs['Base Color'].links:mat.node_tree.links.new(bs.inputs['Base Color'].links[0].from_socket,em.inputs['Color'])
        else:em.inputs['Color'].default_value=bs.inputs['Base Color'].default_value
        mat.node_tree.links.new(em.outputs[0],out.inputs['Surface'])
    MODE+='albedo'
target=Vector(((414-411)/590,0,1.7-(110-24.5)/590))
for name,d in [('front',(0,-1,0)),('oblique',(.6,-1,0)),('profile',(1,0,0))]:
    if (MODE=='baseline' or '--albedo' in sys.argv) and name!='front':continue
    cam.location=target+Vector(d).normalized()*5;cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();sc.render.filepath=str(OUT/(MODE+'_'+name+'.png'));bpy.ops.render.render(write_still=True)
print('COMPARE_DONE',flush=True)
if '--full' in sys.argv:
    sc.render.resolution_x=900;sc.render.resolution_y=1000
    for name,d in [('full_front',(0,-1,0)),('full_oblique',(.6,-1,0)),('full_back',(0,1,0)),('right_profile',(-1,0,0)),('badge',(0,-1,0))]:
        pt=Vector((0,0,.85));size=1.94
        if name=='right_profile':pt=target;size=180/590
        if name=='badge':pt=Vector((-.004,0,1.032));size=.18
        cam.data.ortho_scale=size;cam.location=pt+Vector(d).normalized()*5;cam.rotation_euler=(pt-cam.location).to_track_quat('-Z','Y').to_euler()
        sc.render.filepath=str(OUT/(MODE+'_'+name+'.png'));bpy.ops.render.render(write_still=True)
    print('FULL_QA_DONE',flush=True)
