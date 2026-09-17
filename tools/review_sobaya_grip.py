"""Round-trip images and attachment checks for the Sobaya grip asset."""
import bpy,sys,json,math,hashlib
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
from sobaya_v2_common import studio
from build_humanoid_motion import clear_pose
OUT=ROOT/'04_GAME_ASSETS/3d/characters/sobaya/grip_v3_20260917';QA=OUT/'qa';QA.mkdir(exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True);s=bpy.context.scene;s.render.fps=30
bpy.ops.import_scene.gltf(filepath=str(OUT/'sobaya_grip.glb'))
rig=next(o for o in s.objects if o.type=='ARMATURE');rig.animation_data_clear();clear_pose(rig)
body=next(o for o in s.objects if o.type=='MESH' and o.data.shape_keys);keys=body.data.shape_keys;keys.animation_data_clear()
print('SHAPE_OBJECT',body.name,flush=True)
print('SLOTS',[(a.name,[(sl.identifier,sl.target_id_type) for sl in a.slots]) for a in bpy.data.actions if a.name=='Hybrid_MugHold'],flush=True)
actions={a.name:a for a in bpy.data.actions}
bpy.ops.import_scene.gltf(filepath=str(ROOT/'04_GAME_ASSETS/3d/props/beer_mug_v2/beer_mug.glb'))
root=bpy.data.objects['BeerMugRoot'];grip=bpy.data.objects['Grip'];bpy.context.view_layer.update();attachment=Matrix.Rotation(-math.pi/2,4,'X')@grip.matrix_world.inverted()@root.matrix_world
studio();s.cycles.samples=16;s.render.resolution_x=960;s.render.resolution_y=960
records=[]
def pose(clip,phase):
 action=actions[clip]
 for obj,kind in [(rig,'OBJECT'),(keys,'KEY')]:
  obj.animation_data_create();obj.animation_data.action=action
  obj.animation_data.action_slot=next(sl for sl in action.slots if sl.target_id_type==kind)
 start,end=action.frame_range;frame=start+(end-start)*phase;s.frame_set(int(frame),subframe=frame%1);bpy.context.view_layer.update()
 root.matrix_world=rig.matrix_world@rig.pose.bones['PropSocket.R'].matrix@attachment
 bpy.context.view_layer.update()
 return root.matrix_world.copy()
def render(name,target,direction,up,scale):
 if '--audit-only' in sys.argv:return
 s.camera.location=target+direction.normalized()*2
 forward=(target-s.camera.location).normalized();right=forward.cross(up).normalized();up=right.cross(forward)
 s.camera.rotation_euler=Matrix((right,up,-forward)).transposed().to_euler();s.camera.data.ortho_scale=scale
 s.render.filepath=str(QA/(name+'.png'));bpy.ops.render.render(write_still=True)
for clip,phase in [('Hybrid_MugHold',0),('Adopted_Library_Walk',.25),('Adopted_Candidate_Chase_Run',.25),('Hybrid_MugSmash',.48),('Greeting',.45)]:
 m=pose(clip,phase);root.hide_render=clip=='Greeting'
 for o in root.children_recursive:o.hide_render=clip=='Greeting'
 p=rig.matrix_world@rig.pose.bones['RightHand'].matrix.translation
 render(clip+'_full',Vector((0,0,.90)),Vector((-2,-4,1)),Vector((0,0,1)),2.15)
 if clip=='Hybrid_MugHold':
  for label,d in [('front',(.4,1,.25)),('outer',(.9,.7,.15)),('palm',(.4,-1,.25))]:
   # Mug-oriented closeups, so contact is readable independent of wrist roll.
   target=m@Vector((.12,0,.12));direction=m.to_3x3()@Vector(d);up=m.to_3x3()@Vector((0,0,1))
   render('grip_'+label,target,direction,up,.34)
 error=(grip.matrix_world.translation-(rig.matrix_world@rig.pose.bones['PropSocket.R'].matrix).translation).length
 records.append({'clip':clip,'phase':phase,'morphWeight':keys.key_blocks['MugGrip'].value,'attachmentErrorM':error})
# Check a complete cycle independently of the selected render frames.
cycle=[]
for clip in ['Hybrid_MugHold','Adopted_Library_Walk','Adopted_Candidate_Chase_Run','Hybrid_MugSmash','Hybrid_MugPunch','Hybrid_MugHook']:
 for phase in [0,.15,.3,.5,.7,.85,1]:
  pose(clip,phase)
  error=(grip.matrix_world.translation-(rig.matrix_world@rig.pose.bones['PropSocket.R'].matrix).translation).length
  assert error<1e-5 and abs(keys.key_blocks['MugGrip'].value-1)<1e-6
  cycle.append(error)
# Inspect the exported, skinned hand against the actual imported glass.
from mathutils.bvhtree import BVHTree
pose('Hybrid_MugHold',0);dg=bpy.context.evaluated_depsgraph_get();evaluated=body.evaluated_get(dg);evaluated_mesh=evaluated.to_mesh()
assert len(evaluated_mesh.vertices)==len(body.data.vertices)
points=[evaluated.matrix_world@v.co for v,base in zip(evaluated_mesh.vertices,body.data.vertices)
        if base.co.x<-.30 and .68<base.co.z<.99]
evaluated.to_mesh_clear();contacts={}
for name in ['Handle','GlassBody']:
 obj=bpy.data.objects[name].evaluated_get(dg);data=obj.to_mesh()
 bvh=BVHTree.FromPolygons([obj.matrix_world@v.co for v in data.vertices],[tuple(p.vertices) for p in data.polygons])
 depths=[];near=0
 for point in points:
  co,normal,index,distance=bvh.find_nearest(point);signed=(point-co).dot(normal)
  if signed<0:depths.append(-signed)
  if distance<.005:near+=1
 contacts[name]={'penetratingVertices':len(depths),'maxDepthM':max(depths,default=0),'verticesWithin5mm':near}
 assert max(depths,default=0)<1e-5,contacts[name]
 obj.to_mesh_clear()
proof={'sha256':hashlib.sha256((OUT/'sobaya_grip.glb').read_bytes()).hexdigest(),
       'renderSamples':records,'cycleSamples':len(cycle),'maxAttachmentErrorM':max(cycle),
       'bodyMotionAndWristOrientationChanged':False,'contactVertexSamples':len(points),'contact':contacts}
(QA/'review.json').write_text(json.dumps(proof,indent=2)+'\n');print('GRIP_REVIEW_DONE',proof,flush=True)
