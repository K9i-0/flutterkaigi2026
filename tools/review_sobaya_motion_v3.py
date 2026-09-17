"""Round-trip motion matrices and render multi-phase inspection sheets."""
import bpy,sys,json,math,hashlib
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
from sobaya_v2_common import studio
from sobaya_motion_authoring import GAITS,ATTACKS,palms
OUT=ROOT/'04_GAME_ASSETS/3d/characters/sobaya/motion_v3_20260917';QA=OUT/'qa';QA.mkdir(exist_ok=True)
report=json.loads((OUT/'report.json').read_text());bpy.ops.wm.read_factory_settings(use_empty=True);s=bpy.context.scene;s.render.fps=30
bpy.ops.import_scene.gltf(filepath=str(OUT/'sobaya_motion.glb'));r=next(o for o in s.objects if o.type=='ARMATURE');actions={a.name:a for a in bpy.data.actions}
keys=[o.data.shape_keys for o in s.objects if o.type=='MESH' and o.data.shape_keys and 'MugGrip' in o.data.shape_keys.key_blocks]
bpy.ops.import_scene.gltf(filepath=str(ROOT/'04_GAME_ASSETS/3d/props/beer_mug_v2/beer_mug.glb'));mug=bpy.data.objects['BeerMugRoot'];grip=bpy.data.objects['Grip'];bpy.context.view_layer.update();attachment=Matrix.Rotation(-math.pi/2,4,'X')@grip.matrix_world.inverted()@mug.matrix_world
originals=[o for o in s.objects if o.type=='MESH' and not o.hide_render];studio();s.cycles.samples=12
# Preview-only liquid shading, matching the browser's nested-transmission approximation.
for o in bpy.data.objects['BeerVolume'].children_recursive+[bpy.data.objects['BeerVolume']]:
 if o.type=='MESH':
  for mat in o.data.materials:
   bsdf=mat.node_tree.nodes.get('Principled BSDF')
   if bsdf:bsdf.inputs['Transmission Weight'].default_value=0;bsdf.inputs['Base Color'].default_value=(.55,.22,.012,1)
def pose(clip,seconds):
 a=actions[clip]
 for obj,kind in [(r,'OBJECT')]+[(k,'KEY') for k in keys]:
  obj.animation_data_create();obj.animation_data.action=a;obj.animation_data.action_slot=next(sl for sl in a.slots if sl.target_id_type==kind)
 s.frame_set(int(seconds*30),subframe=(seconds*30)%1);bpy.context.view_layer.update();mug.matrix_world=r.matrix_world@r.pose.bones['PropSocket.R'].matrix@attachment;bpy.context.view_layer.update()
errors=[];attachment_errors=[];continuity={}
for clip,samples in report['roundTripSamples'].items():
 for time,expected in samples.items():
  pose(clip,float(time))
  errors.extend(max(abs(x-y) for row,other in zip(r.pose.bones[name].matrix,mat) for x,y in zip(row,other)) for name,mat in expected.items())
  attachment_errors.append((grip.matrix_world.translation-(r.matrix_world@r.pose.bones['PropSocket.R'].matrix).translation).length)
 assert max(errors)<3e-5,(clip,max(errors))
for clip in ATTACKS+['Greeting']:
 pose(clip,0);start={b.name:b.matrix.copy() for b in r.pose.bones};pose(clip,report['clips'][clip]['duration'])
 continuity[clip]=max(max(abs(x-y) for row,other in zip(b.matrix,start[b.name]) for x,y in zip(row,other)) for b in r.pose.bones)
 assert continuity[clip]<1e-5
for clip in (['Greeting'] if '--greeting-only' in sys.argv else ['Adopted_Library_Walk','Adopted_Candidate_Chase_Run']+ATTACKS+['Greeting']):
 phases=[0,.25,.5,.75,1] if clip in GAITS or clip=='Greeting' else [0,.28,.48,.60,.9]
 duration=actions[clip].frame_range[1]/30;copies=[]
 for index,phase in enumerate(phases):
  pose(clip,duration*phase);dg=bpy.context.evaluated_depsgraph_get()
  for obj in originals:
   # Carbonation is instanced geometry; copying its seed mesh makes a unit sphere.
   if obj.name in ['Carbonation','Icosphere']:continue
   ev=obj.evaluated_get(dg);mesh=bpy.data.meshes.new_from_object(ev,preserve_all_data_layers=True,depsgraph=dg);copy=bpy.data.objects.new('Review snapshot',mesh);s.collection.objects.link(copy);copy.matrix_world=obj.matrix_world.copy();copy.location.x+=(index-2)*1.12;copies.append(copy)
  curve=bpy.data.curves.new('Phase','FONT');curve.body=f'{phase:.0%}';curve.size=.095;curve.align_x='CENTER';label=bpy.data.objects.new('Phase',curve);s.collection.objects.link(label);label.location=((index-2)*1.12,-.4,1.92);label.rotation_euler=(math.pi/2,0,0);copies.append(label)
 for o in originals:o.hide_render=True
 s.render.resolution_x=2400;s.render.resolution_y=1000;target=Vector((0,0,.95));s.camera.location=target+Vector((0,-7,.15));s.camera.rotation_euler=(target-s.camera.location).to_track_quat('-Z','Y').to_euler();s.camera.data.ortho_scale=5.7;s.render.filepath=str(QA/(clip+'.png'));bpy.ops.render.render(write_still=True)
 for o in copies:bpy.data.objects.remove(o,do_unlink=True)
 for o in originals:o.hide_render=False
# Both wrists at the troublesome middle of walking, from front and rear.
pose('Adopted_Library_Walk',actions['Adopted_Library_Walk'].frame_range[1]/30*.25)
s.render.resolution_x=900;s.render.resolution_y=900
for side in ([] if '--greeting-only' in sys.argv else ['Left','Right']):
 target=r.pose.bones[side+'Hand'].head.copy()+Vector((0,0,-.03));s.camera.location=target+Vector((.55 if side=='Left' else -.55,-1,.1));s.camera.rotation_euler=(target-s.camera.location).to_track_quat('-Z','Y').to_euler();s.camera.data.ortho_scale=.46;s.render.filepath=str(QA/('walk_'+side+'_wrist.png'));bpy.ops.render.render(write_still=True)
proof={'sha256':hashlib.sha256((OUT/'sobaya_motion.glb').read_bytes()).hexdigest(),'maximumBoneRoundTripError':max(errors),'maximumAttachmentErrorM':max(attachment_errors),'attackStartEndMatrixError':continuity}
(QA/'review.json').write_text(json.dumps(proof,indent=2)+'\n');print('MOTION_REVIEW_DONE',proof,flush=True)
