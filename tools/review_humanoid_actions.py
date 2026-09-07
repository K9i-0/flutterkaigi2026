"""Render a repeatable inspection of gaze, roll contacts and mug poses.
blender -b --factory-startup --python tools/review_humanoid_actions.py
"""
from pathlib import Path
import sys,math
sys.path.insert(0,str(Path(__file__).resolve().parent))
from build_humanoid_motion import *
from humanoid_action_refinement import minimum_skin,skin_points
folder=ROOT/'22_HUMANOID_MOTION_LAB/evidence/action-refinement';folder.mkdir(parents=True,exist_ok=True)
for name in ['sobaya','fukuchan']:
 bpy.ops.wm.read_factory_settings(use_empty=True);sc=bpy.context.scene;sc.render.fps=30
 bpy.ops.import_scene.gltf(filepath=str(OUT/name/f'{name}.glb'))
 rig=next(o for o in sc.objects if o.type=='ARMATURE')
 for t in list(rig.animation_data.nla_tracks):rig.animation_data.nla_tracks.remove(t)
 use_action(rig,None);clear_pose(rig)
 before=set(sc.objects)
 bpy.ops.import_scene.gltf(filepath=str(ROOT/'04_GAME_ASSETS/3d/props/beer_mug_v2/beer_mug.glb'))
 props=list(set(sc.objects)-before);grip=next(o for o in props if o.name=='Grip')
 matrices={o:grip.matrix_world.inverted()@o.matrix_world for o in props if o.type=='MESH'}
 for o in props:o.parent=None
 sc.render.engine='CYCLES';sc.cycles.samples=8;sc.cycles.use_denoising=True
 sc.render.resolution_x=640;sc.render.resolution_y=640;sc.render.resolution_percentage=100
 world=bpy.data.worlds.new('World');sc.world=world;world.use_nodes=True
 world.node_tree.nodes['Background'].inputs[0].default_value=(.15,.18,.20,1)
 world.node_tree.nodes['Background'].inputs[1].default_value=.65
 def aim(obj,target):obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()
 for pos,power in [((-3,-4,5),650),((3,-1,3),350)]:
  d=bpy.data.lights.new('Softbox','AREA');d.energy=power;d.shape='DISK';d.size=4
  o=bpy.data.objects.new('Softbox',d);sc.collection.objects.link(o);o.location=pos;aim(o,(0,0,1))
 bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.006))
 m=bpy.data.materials.new('Floor');m.diffuse_color=(.1,.13,.15,1);bpy.context.object.data.materials.append(m)
 camera=bpy.data.objects.new('Camera',bpy.data.cameras.new('Camera'));sc.collection.objects.link(camera);sc.camera=camera
 camera.data.type='ORTHO';camera.data.ortho_scale=2.3
 cases=[('Hybrid_Crouch_Idle',.4),('Procedural_RollForward',.25),('Procedural_RollForward',.46),('Procedural_RollForward',.72)]
 if name=='sobaya':cases += [('Hybrid_MugHold',0),('Hybrid_MugRun',.3),('Hybrid_MugPunch',.48),('Hybrid_MugHook',.48),('Hybrid_MugSmash',.18),('Hybrid_MugSmash',.48)]
 for clip,phase in cases:
  a=bpy.data.actions[clip];use_action(rig,None);clear_pose(rig);use_action(rig,a)
  f=a.frame_range[0]+phase*(a.frame_range[1]-a.frame_range[0]);sc.frame_set(int(f),subframe=f-int(f))
  camera.location=(-3,-5,2.2) if 'Roll' not in clip else (-5,-.8,1.8);aim(camera,(0,-.04,.87))
  for o,mat in matrices.items():
   o.hide_render='Mug' not in clip
   if not o.hide_render:o.matrix_world=rig.matrix_world@rig.pose.bones['PropSocket.R'].matrix@mat
  sc.render.filepath=str(folder/f'{name}_{clip}_{phase:.2f}.png');bpy.ops.render.render(write_still=True)
