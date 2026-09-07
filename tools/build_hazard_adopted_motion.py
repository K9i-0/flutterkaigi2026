"""Bake reviewed VRM performances into game GLBs without altering library inputs.
Prerequisites: build_vrm_motions.py and build_vrm_run_candidates.py.
"""
import bpy,sys,json,hashlib,statistics
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
from build_humanoid_motion import Body,use_action,clear_pose
from humanoid_deformation import smooth_shoulders
OUT=ROOT/'04_GAME_ASSETS/3d/hazard_adopted';OUT.mkdir(parents=True,exist_ok=True)
report={}
for name in ['sobaya','fukuchan']:
 bpy.ops.wm.read_factory_settings(use_empty=True);sc=bpy.context.scene;sc.render.fps=30
 source=ROOT/f'04_GAME_ASSETS/3d/motion_library/{name}/{name}.glb'
 bpy.ops.import_scene.gltf(filepath=str(source));rig=next(o for o in sc.objects if o.type=='ARMATURE');meshes=[o for o in sc.objects if o.type=='MESH']
 for o in sc.objects:
  if o.animation_data:o.animation_data_clear()
 clear_pose(rig);changed=sum(smooth_shoulders(m,rig) for m in meshes)
 old={a:a.name for a in bpy.data.actions}
 for a,n in old.items():a.name='Existing_'+n
 for suffix in ['motions','run_candidates']:
  before=set(bpy.data.actions)
  bpy.ops.import_scene.gltf(filepath=str(ROOT/f'.local/vrm-validation/{name}_{suffix}.glb'))
  for a in set(bpy.data.actions)-before:a.name='Adopted_'+a.name
  for o in list(sc.objects):
   if o.type=='ARMATURE' and o!=rig:bpy.data.objects.remove(o,do_unlink=True)
 for a,n in old.items():a.name=n
 # Preserve public gameplay identifiers while replacing reviewed generic dances.
 for dst,src in [('DanceStep','Adopted_Library_Dance_Simple'),('DanceDisco','Adopted_Library_Dance_Charleston'),('DanceVictory','Adopted_Library_Dance_Body_Roll')]:
  if dst in bpy.data.actions:bpy.data.actions[dst].name='Legacy_'+dst
  a=bpy.data.actions[src].copy();a.name=dst;a.use_fake_user=True
 body=Body(rig,meshes,name);speeds={}
 chosen={'Walk':'Adopted_Library_Walk','Run':'Adopted_Candidate_Chase_Run' if name=='sobaya' else 'Adopted_Candidate_Mixamo_Run'}
 for role,clip in chosen.items():
  use_action(rig,None);clear_pose(rig);a=bpy.data.actions[clip];use_action(rig,a);start,end=a.frame_range;tracks={s:[] for s in ['l','r']}
  for i in range(round(end-start)+1):
   sc.frame_set(round(start+i))
   for s in tracks:tracks[s].append(body.bone('foot_'+s).head.copy())
  values=[]
  for pts in tracks.values():
   low=min(p.z for p in pts)
   values.extend((b.y-a.y)*30 for a,b in zip(pts,pts[1:]) if max(a.z,b.z)<low+.035 and b.y>a.y)
  assert values,('No stance samples',name,clip)
  speeds[role]=statistics.median(values)
 use_action(rig,None);clear_pose(rig)
 target=OUT/f'{name}.glb'
 bpy.ops.export_scene.gltf(filepath=str(target),export_format='GLB',export_animations=True,export_animation_mode='ACTIONS',export_frame_range=False,export_anim_slide_to_zero=True,export_anim_single_armature=True,export_skins=True,export_def_bones=False,export_force_sampling=True,export_optimize_animation_size=True,export_extras=True)
 report[name]={'source':str(source.relative_to(ROOT)),'sourceSha256':hashlib.sha256(source.read_bytes()).hexdigest(),'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'changedWeightVertices':changed,'sources':chosen,'groundSpeedMps':speeds,'clips':[a.name for a in bpy.data.actions]}
(OUT/'manifest.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print('HAZARD_ADOPTED_DONE',flush=True)
