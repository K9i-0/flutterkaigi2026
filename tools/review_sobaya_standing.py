"""Inspect the exported standing pose, including its attachment and bone frames."""
import bpy,sys,json,math,hashlib
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
from sobaya_v2_common import studio
OUT=ROOT/'04_GAME_ASSETS/3d/characters/sobaya/standing_v3_20260917';QA=OUT/'qa';QA.mkdir(exist_ok=True)
report=json.loads((OUT/'report.json').read_text());bpy.ops.wm.read_factory_settings(use_empty=True);s=bpy.context.scene;s.render.fps=30
bpy.ops.import_scene.gltf(filepath=str(OUT/'sobaya_standing.glb'))
r=next(o for o in s.objects if o.type=='ARMATURE');a=bpy.data.actions[report['clip']]
r.animation_data_create();r.animation_data.action=a;r.animation_data.action_slot=next(slot for slot in a.slots if slot.target_id_type=='OBJECT')
for o in s.objects:
 if o.type=='MESH' and o.data.shape_keys and 'MugGrip' in o.data.shape_keys.key_blocks:
  k=o.data.shape_keys;k.animation_data_create();k.animation_data.action=a;k.animation_data.action_slot=next(slot for slot in a.slots if slot.target_id_type=='KEY')
s.frame_set(0);bpy.context.view_layer.update()
errors=[max(abs(x-y) for row,other in zip(r.pose.bones[name].matrix,mat) for x,y in zip(row,other)) for name,mat in report['boneWorldMatrices'].items()]
assert max(errors)<1e-5,max(errors)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'04_GAME_ASSETS/3d/props/beer_mug_v2/beer_mug.glb'))
mug=bpy.data.objects['BeerMugRoot'];grip=bpy.data.objects['Grip'];bpy.context.view_layer.update();attach=Matrix.Rotation(-math.pi/2,4,'X')@grip.matrix_world.inverted()@mug.matrix_world
mug.matrix_world=r.matrix_world@r.pose.bones['PropSocket.R'].matrix@attach;bpy.context.view_layer.update()
up=mug.matrix_world.to_3x3()@Vector((0,0,1));assert up.normalized().dot(Vector((0,0,1)))>.9999
studio();s.cycles.samples=20;s.render.resolution_x=1024;s.render.resolution_y=1024
# Grounded studio view; no changes to the character materials.
for name,direction in [('front',(0,-4,.12)),('three_quarter',(-2,-4,.15)),('side',(-4,0,.12)),('back',(0,4,.12))]:
 target=Vector((0,-.025,.90));s.camera.location=target+Vector(direction);s.camera.rotation_euler=(target-s.camera.location).to_track_quat('-Z','Y').to_euler();s.camera.data.ortho_scale=2.04
 s.render.filepath=str(QA/(name+'.png'));bpy.ops.render.render(write_still=True)
proof={'sha256':hashlib.sha256((OUT/'sobaya_standing.glb').read_bytes()).hexdigest(),'maxRoundTripBoneMatrixError':max(errors),'mugUprightDot':up.normalized().z,'clip':report['clip']}
(QA/'review.json').write_text(json.dumps(proof,indent=2)+'\n');print('STANDING_REVIEW_DONE',proof,flush=True)
