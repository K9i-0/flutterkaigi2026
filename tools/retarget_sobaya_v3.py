"""Rest-aware retarget of the game's adopted v2 clips to Sobaya v3."""
import bpy,math,json,sys,hashlib,statistics,numpy as np
from pathlib import Path
from mathutils import Matrix,Vector
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
from build_humanoid_motion import clear_pose,use_action
from build_sobaya_v3_rig import OUT,render
OLD=ROOT/'04_GAME_ASSETS/3d/hazard_adopted/v2_20260915_mask/sobaya.glb'
bpy.ops.wm.open_mainfile(filepath=str(OUT/'sobaya_rig.blend'));s=bpy.context.scene;s.render.fps=30
rig=bpy.data.objects['SobayaV3Rig'];meshes=[o for o in s.objects if o.type=='MESH'];rest={b.name:b.matrix_local.copy() for b in rig.data.bones};invs={n:m.inverted() for n,m in rest.items()}
for a in list(bpy.data.actions):bpy.data.actions.remove(a)
before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(OLD));added=set(bpy.data.objects)-before;src=next(o for o in added if o.type=='ARMATURE');src.animation_data_clear();clear_pose(src)
sr={b.name:src.matrix_world@b.matrix_local for b in src.data.bones};records={}
for action in list(bpy.data.actions):
 use_action(src,action);start,end=action.frame_range;count=max(1,round(end-start));samples=[]
 for i in range(count+1):
  f=start+(end-start)*i/count;s.frame_set(int(f),subframe=f-int(f));samples.append({b.name:src.matrix_world@b.matrix for b in src.pose.bones})
 records[action.name]=samples
print('SOURCE_CLIPS',len(records),flush=True)
for o in added:bpy.data.objects.remove(o,do_unlink=True)
for a in list(bpy.data.actions):bpy.data.actions.remove(a)
children={side+n:side+c for side in ['Left','Right'] for n,c in [('Shoulder','Arm'),('Arm','ForeArm'),('ForeArm','Hand'),('UpLeg','Leg'),('Leg','Foot')]}
corrections={}
for n in rest:
 if n in ['Root','PropSocket.R']:continue
 target=rest[n].to_3x3()
 if n in children:
  c=children[n];ta=rest[c].translation-rest[n].translation;sa=sr[c].translation-sr[n].translation;target=ta.rotation_difference(sa).to_matrix()@target
 elif n.endswith('Hand'):
  c=n.replace('Hand','ForeArm');target=(rest[n].translation-rest[c].translation).rotation_difference(sr[n].translation-sr[c].translation).to_matrix()@target
 corrections[n]=sr[n].to_quaternion().to_matrix().inverted()@target
leg=lambda r:sum((r[a].translation-r[b].translation).length for a,b in [('LeftUpLeg','LeftLeg'),('LeftLeg','LeftFoot')])
scale=leg(rest)/leg(sr);offset=rest['RightHand'].inverted()@rest['PropSocket.R'].translation
# Fast linear-blend sole sampling; the exported four weights use the same path.
sole=[]
for o in meshes:
 for v in o.data.vertices:
  if v.co.z<.13:
   ws=[(o.vertex_groups[g.group].name,g.weight) for g in v.groups if g.weight>1e-6];sole.append((v.co.copy(),ws))
sole=sole[::max(1,len(sole)//160)]
parents={b.name:b.parent.name if b.parent else None for b in rig.data.bones}
local={n:(rest[parents[n]].inverted()@r if parents[n] else r) for n,r in rest.items()}
ordered=list(rest);speed_samples={};floor_report={}
for label,samples in sorted(records.items()):
 action=bpy.data.actions.new(label);action.use_fake_user=True;slot=action.slots.new(id_type='OBJECT',name=rig.name);layer=action.layers.new('Retarget');strip=layer.strips.new(type='KEYFRAME');bag=strip.channelbag(slot,ensure=True)
 values={n:[] for n in ordered};feet={n:[] for n in ['LeftFoot','RightFoot']};floor_deltas=[];prev={}
 for i,sample in enumerate(samples):
  posed={}
  for n in ordered:
   parent=parents[n]
   if n=='Root':posed[n]=rest[n].copy();continue
   loc=posed[parent]@local[n].translation if parent else rest[n].translation.copy()
   if n=='Hips':loc=rest[n].translation+(sample[n].translation-sr[n].translation)*scale
   if n=='PropSocket.R':loc=posed['RightHand']@offset;rotation=sample[n].to_quaternion().to_matrix()
   else:rotation=sample[n].to_quaternion().to_matrix()@corrections[n]
   posed[n]=Matrix.Translation(loc)@rotation.to_4x4()
  grounded=not any(k in label for k in ['Jump','Climb','Vault','RollForward','StepUp'])
  if grounded:
   skin={n:posed[n]@invs[n] for n in ordered};floor=min(sum((skin[n]@v).z*w for n,w in ws) for v,ws in sole);floor_deltas.append(-floor)
   for n in ordered:
    if n!='Root':posed[n].translation.z-=floor
  for n in feet:feet[n].append((posed[n].translation.copy(),sample[n].translation.z))
  for n in ordered:
   parent=parents[n];basis=local[n].inverted()@(posed[parent].inverted()@posed[n] if parent else posed[n]);loc,q,sc=basis.decompose()
   if n in prev and q.dot(prev[n])<0:q.negate()
   prev[n]=q.copy();values[n].append([*loc,*q,*sc])
 frames=np.arange(len(samples),dtype=float)
 for n,rows in values.items():
  a=np.array(rows)
  for attr,start,size in [('location',0,3),('rotation_quaternion',3,4),('scale',7,3)]:
   for j in range(size):
    fc=bag.fcurves.new(data_path=f'pose.bones["{n}"].{attr}',index=j);fc.keyframe_points.add(len(frames));fc.keyframe_points.foreach_set('co',np.c_[frames,a[:,start+j]].ravel())
    for k in fc.keyframe_points:k.interpolation='LINEAR'
 action.use_frame_range=True;action.frame_start=0;action.frame_end=len(samples)-1
 if label in ['Adopted_Library_Walk','Adopted_Candidate_Chase_Run']:
  vals=[]
  for points in feet.values():
   # Preserve the source clip's stance phases. Target floor correction
   # must not classify the slow swing turnaround as a planted foot.
   low=min(h for p,h in points);vals.extend((b[0].y-a[0].y)*30 for a,b in zip(points,points[1:]) if max(a[1],b[1])<low+.035 and b[0].y>a[0].y)
  speed_samples[label]=statistics.median(vals)
 floor_report[label]=[min(floor_deltas,default=0),max(floor_deltas,default=0)]
 print('RETARGETED',label,len(samples),flush=True)
if '--measure-only' in sys.argv:
 report=json.loads((OUT/'rig_report.json').read_text());report['groundSpeedMps']={'Walk':speed_samples['Adopted_Library_Walk'],'Run':speed_samples['Adopted_Candidate_Chase_Run']};report['speedMethod']='Target backward foot velocity in original clip stance phases; target floor correction excluded from phase classification.'
 (OUT/'rig_report.json').write_text(json.dumps(report,indent=2));print('SPEED_MEASURED',report['groundSpeedMps'],flush=True);raise SystemExit(0)
use_action(rig,None);clear_pose(rig);s.frame_set(0)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'sobaya_animated.blend'))
if '--preview-only' in sys.argv:
 for clip,phase in [('Hybrid_MugHold',.0),('Adopted_Library_Walk',.25),('Adopted_Candidate_Chase_Run',.25),('Hybrid_MugSmash',.48),('DanceDisco',.33)]:
  use_action(rig,bpy.data.actions[clip]);end=bpy.data.actions[clip].frame_range[1];s.frame_set(int(end*phase));render('motion_'+clip,False)
 print('PREVIEW_DONE',flush=True)
 raise SystemExit(0)
bpy.ops.object.select_all(action='DESELECT')
for o in meshes+[rig]:o.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(OUT/'sobaya_rig.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=True,export_animation_mode='ACTIONS',export_frame_range=False,export_anim_slide_to_zero=True,export_anim_single_armature=True,export_skins=True,export_def_bones=False,export_force_sampling=True,export_optimize_animation_size=True,export_extras=True)
report={'version':3,'clips':sorted(records),'clipCount':len(records),'bones':ordered,'legScale':scale,'groundSpeedMps':{'Walk':speed_samples['Adopted_Library_Walk'],'Run':speed_samples['Adopted_Candidate_Chase_Run']},'floorCorrectionM':floor_report,'animationSource':str(OLD.relative_to(ROOT)),'animationSourceSha256':hashlib.sha256(OLD.read_bytes()).hexdigest(),'sha256':hashlib.sha256((OUT/'sobaya_rig.glb').read_bytes()).hexdigest()}
report['speedMethod']='Target backward foot velocity in original clip stance phases; target floor correction excluded from phase classification.'
(OUT/'rig_report.json').write_text(json.dumps(report,indent=2));print('V3_RETARGET_DONE',report['clipCount'],report['groundSpeedMps'],flush=True)
for clip,phase in [('Hybrid_MugHold',.0),('Adopted_Library_Walk',.25),('Adopted_Candidate_Chase_Run',.25),('Hybrid_MugSmash',.48),('DanceDisco',.33)]:
 use_action(rig,bpy.data.actions[clip]);end=bpy.data.actions[clip].frame_range[1];s.frame_set(int(end*phase));render('motion_'+clip,False)
