import bpy,sys,math
from pathlib import Path
from mathutils import Vector
O=Path(__file__).resolve().parent
source=Path(sys.argv[sys.argv.index('--')+1]);label=sys.argv[-1]
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(source))
for o in bpy.context.scene.objects:
 if o.type=='ARMATURE':
  o.animation_data_clear()
  for p in o.pose.bones:p.matrix_basis.identity()
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=12;s.cycles.use_denoising=True;s.render.resolution_x=480;s.render.resolution_y=540;s.render.resolution_percentage=100;s.view_settings.view_transform='Standard'
w=bpy.data.worlds.new('Studio');w.use_nodes=True;w.node_tree.nodes['Background'].inputs[0].default_value=(.42,.45,.48,1);w.node_tree.nodes['Background'].inputs[1].default_value=.49;s.world=w
for name,pos,power,size in [('Key',(-1,-5,2.5),280,5),('Fill',(3,-4,2),140,5),('Rim',(1,3,4),105,4)]:
 l=bpy.data.lights.new(name,'AREA');l.energy=power;l.shape='DISK';l.size=size;o=bpy.data.objects.new(name,l);s.collection.objects.link(o);o.location=pos;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
c=bpy.data.objects.new('Camera',bpy.data.cameras.new('Camera'));s.collection.objects.link(c);s.camera=c;c.data.type='ORTHO';c.data.ortho_scale=.35
(O/'qa').mkdir(exist_ok=True)
for name,angle in [('front',0),('left45',45),('right45',-45),('left90',90),('right90',-90)]:
 a=math.radians(angle);pt=Vector((0,-.01,1.535));c.location=pt+Vector((math.sin(a),-math.cos(a),0))*5;c.rotation_euler=(pt-c.location).to_track_quat('-Z','Y').to_euler();s.render.filepath=str(O/'qa'/f'{label}_{name}.png');bpy.ops.render.render(write_still=True)
