"""Render a repeatable 72-image paused-dance review of the current VRMs."""
import bpy,sys,json,math
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
from build_humanoid_motion import Body,use_action,clear_pose
OUT=ROOT/'.local/dance_deformation/final-review';OUT.mkdir(exist_ok=True,parents=True)
report=[]
for name in ['sobaya','fukuchan']:
 bpy.ops.wm.read_factory_settings(use_empty=True);sc=bpy.context.scene;sc.render.fps=30
 bpy.ops.import_scene.gltf(filepath=str(ROOT/f'04_GAME_ASSETS/vrm/characters/{name}.vrm'))
 rig=next(o for o in sc.objects if o.type=='ARMATURE');meshes=[o for o in sc.objects if o.type=='MESH']
 bpy.ops.import_scene.gltf(filepath=str(ROOT/f'.local/vrm-validation/{name}_motions.glb'))
 for o in list(sc.objects):
  if o.type=='ARMATURE' and o!=rig:bpy.data.objects.remove(o,do_unlink=True)
 for o in sc.objects:
  if o.animation_data:
   for t in list(o.animation_data.nla_tracks):o.animation_data.nla_tracks.remove(t)
 use_action(rig,None);clear_pose(rig);body=Body(rig,meshes,name)
 sc.render.engine='CYCLES';sc.cycles.samples=12;sc.cycles.use_denoising=True;sc.render.resolution_x=600;sc.render.resolution_y=600;sc.render.resolution_percentage=100
 sc.world=bpy.data.worlds.new('World');sc.world.use_nodes=True;sc.world.node_tree.nodes['Background'].inputs[0].default_value=(.22,.25,.28,1)
 def aim(o,p):o.rotation_euler=(Vector(p)-o.location).to_track_quat('-Z','Y').to_euler()
 d=bpy.data.lights.new('Softbox','AREA');d.energy=650;d.size=4;o=bpy.data.objects.new('Softbox',d);sc.collection.objects.link(o);o.location=(-3,-4,5);aim(o,(0,0,1))
 camera=bpy.data.objects.new('Camera',bpy.data.cameras.new('Camera'));sc.collection.objects.link(camera);sc.camera=camera;camera.data.type='ORTHO';camera.data.ortho_scale=1.9;camera.location=(3,-5,3.6);aim(camera,(0,0,1.02))

 for clip in ['Dance_Simple','Dance_Charleston','Dance_Body_Roll']:
  action=bpy.data.actions['Library_'+clip];use_action(rig,action);end=action.frame_range[1]
  for index,phase in enumerate([0,.13,.29,.47,.63,.81]):
   frame=end*phase;sc.frame_set(int(frame),subframe=frame%1)
   for view,location in [('left',(-3,-5,3)),('right',(3,-5,3))]:
    camera.location=location;aim(camera,(0,0,1.02))
    sc.render.filepath=str(OUT/f'{name}_{clip}_{index}_{view}.png');bpy.ops.render.render(write_still=True)
    report.append({'character':name,'clip':clip,'seconds':frame/30,'view':view,'image':sc.render.filepath})
(OUT/'review.json').write_text(json.dumps(report,indent=2)+'\n')
