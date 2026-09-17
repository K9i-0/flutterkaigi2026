import bpy,sys,math,json
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
QA=OUT/'qa';QA.mkdir(exist_ok=True)
MODE='rig'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.context.scene.render.fps=30
bpy.ops.import_scene.gltf(filepath=str(OUT/'fukuchan.glb'));sc=bpy.context.scene
rig=next(o for o in sc.objects if o.type=='ARMATURE')
sys.path.insert(0,str(OUT.parents[4]/'tools'))
from build_humanoid_motion import use_action,clear_pose
rig.animation_data_clear()
sc.render.engine='CYCLES';sc.cycles.samples=24;sc.cycles.use_denoising=True
sc.render.resolution_x=sc.render.resolution_y=900;sc.render.resolution_percentage=100
sc.view_settings.view_transform='Standard'
w=bpy.data.worlds.new('Studio');w.use_nodes=True;w.node_tree.nodes['Background'].inputs[0].default_value=(.42,.45,.48,1);w.node_tree.nodes['Background'].inputs[1].default_value=.49;sc.world=w
cam=bpy.data.objects.new('Calibrated',bpy.data.cameras.new('Calibrated'));sc.collection.objects.link(cam);cam.data.type='ORTHO';cam.data.ortho_scale=180/590;sc.camera=cam
for name,pos,power,size in [('Key',(-1,-5,2.5),280,5),('Fill',(3,-4,2),140,5),('Rim',(1,3,4),105,4)]:
    l=bpy.data.lights.new(name,'AREA');l.energy=power;l.shape='DISK';l.size=size;o=bpy.data.objects.new(name,l);sc.collection.objects.link(o);o.location=pos;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()

def render(name,action,frame,pt,size,d=(0,-1,0)):
 use_action(rig,None);clear_pose(rig)
 if action:use_action(rig,bpy.data.actions[action])
 sc.frame_set(frame);sc.render.resolution_x=800;sc.render.resolution_y=1000
 cam.data.ortho_scale=size;target=Vector(pt);cam.location=target+Vector(d).normalized()*5;cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();sc.render.filepath=str(QA/(name+'.png'));bpy.ops.render.render(write_still=True)
if '--hands' in sys.argv:
 render('gyun_hands','GyunGyunPose',0,(0,-.1,1.40),.65)
 render('GyunGyunPose','GyunGyunPose',0,(0,0,.85),1.94)
 print('HANDS_REVIEW_DONE',flush=True);sys.exit(0)
render('neck_left',None,0,(0,0,1.405),.30,(1,0,0))
render('neck_right',None,0,(0,0,1.405),.30,(-1,0,0))
render('rest_front',None,0,(0,0,.85),1.94)
for name,frame in [('Idle',0),('Walk',12),('Run',7),('GyunGyunPose',0),('Greeting',30)]:
 render(name,name,frame,(0,0,.85),1.94)
render('gyun_oblique','GyunGyunPose',0,(0,0,1.05),1.6,(.7,-1,0))
render('gyun_hands','GyunGyunPose',0,(0,-.1,1.40),.65)
render('gyun_enter','GyunGyun',15,(0,0,.85),1.94,(.5,-1,0))
render('gyun_exit','GyunGyun',105,(0,0,.85),1.94,(.5,-1,0))
print('REVIEW_DONE',flush=True)
