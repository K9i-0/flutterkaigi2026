"""Visual QA of exported v3 skin, game animations and independent mug socket."""
import bpy,sys,math,json
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
from build_sobaya_v3_rig import OUT
from sobaya_v2_common import studio
from build_humanoid_motion import use_action,clear_pose
bpy.ops.wm.read_factory_settings(use_empty=True);s=bpy.context.scene;s.render.fps=30
bpy.ops.import_scene.gltf(filepath=str(OUT/'sobaya_rig.glb'));rig=next(o for o in s.objects if o.type=='ARMATURE');rig.animation_data_clear();clear_pose(rig);meshes=[o for o in s.objects if o.type=='MESH'];actions={a.name:a for a in bpy.data.actions}
bpy.ops.import_scene.gltf(filepath=str(ROOT/'04_GAME_ASSETS/3d/props/beer_mug/beer_mug.glb'));mug=bpy.data.objects['BeerMug'];grip=bpy.data.objects['Grip'];bpy.context.view_layer.update();attachment=grip.matrix_world.inverted()@mug.matrix_world;mug.parent=None
studio();s.cycles.samples=16;s.render.resolution_x=640;s.render.resolution_y=800
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.006));floor=bpy.context.object;mat=bpy.data.materials.new('Review floor');mat.diffuse_color=(.23,.25,.26,1);floor.data.materials.append(mat)
qa=OUT/'qa';qa.mkdir(exist_ok=True);records=[]
for clip in ['Hybrid_MugHold','Adopted_Library_Walk','Adopted_Candidate_Chase_Run','Hybrid_MugSmash','DanceDisco','DanceVictory']:
 for phase in [.15,.55]:
  use_action(rig,actions[clip]);start,end=actions[clip].frame_range;f=start+(end-start)*phase;s.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
  mug.matrix_world=rig.matrix_world@rig.pose.bones['PropSocket.R'].matrix@attachment;mug.hide_render=False
  target=Vector((0,0,.90));s.camera.location=target+Vector((-2.8,-5,1.3));s.camera.rotation_euler=(target-s.camera.location).to_track_quat('-Z','Y').to_euler();s.camera.data.ortho_scale=2.20
  path=qa/f'{clip}_{phase:.2f}.png';s.render.filepath=str(path);bpy.ops.render.render(write_still=True);records.append({'clip':clip,'phase':phase,'image':path.name})
(qa/'review.json').write_text(json.dumps(records,indent=2));print('V3_ROUNDTRIP_REVIEW_DONE',flush=True)
