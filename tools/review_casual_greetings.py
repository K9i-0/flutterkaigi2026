"""Review both exported Greeting clips, including the entire lowering phase."""
import bpy,sys
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
from build_humanoid_motion import use_action,clear_pose
from sobaya_v2_common import studio
D=ROOT/'04_GAME_ASSETS/3d/motions/casual_greeting_20260917/qa';D.mkdir(parents=True,exist_ok=True)
for name,path in [('sobaya','v3_20260917/sobaya.glb'),('fukuchan','v2_20260913/fukuchan.glb')]:
 bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.scene.render.fps=30;bpy.ops.import_scene.gltf(filepath=str(ROOT/'04_GAME_ASSETS/3d/hazard_adopted'/path));rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');rig.animation_data_clear();clear_pose(rig);use_action(rig,bpy.data.actions['Greeting']);s=bpy.context.scene;s.render.fps=30;studio();s.cycles.samples=8;s.render.resolution_x=480;s.render.resolution_y=600
 for angle,frames in [('front',[0,8,14,20,27,34,40,46,52,58,66]),('side',[20,40,46,52])]:
  for frame in frames:
   s.frame_set(frame);target=Vector((-.10,-.01,1.23 if name=='sobaya' else 1.15));s.camera.location=target+Vector((0,-3,.05) if angle=='front' else (-2,-3,.10));s.camera.rotation_euler=(target-s.camera.location).to_track_quat('-Z','Y').to_euler();s.camera.data.ortho_scale=1.4;s.render.filepath=str(D/f'{name}_{angle}_{frame:02}.png');bpy.ops.render.render(write_still=True)
 print('REVIEWED',name,flush=True)
