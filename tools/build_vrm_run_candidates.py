"""Blender: build Jog, licensed existing Run, and authored chase candidates."""
import sys,json,struct,hashlib,copy
from pathlib import Path
import bpy
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
import build_humanoid_motion as motion
from export_humanoid_vrm import read_glb
OUT=ROOT/'04_GAME_ASSETS/vrm/motions';OUT.mkdir(parents=True,exist_ok=True)
motion.BASE=[('Jog','Jog（公開ライブラリ）','VRM',True,False)]
motion.ADDON=[]
sources=motion.read_sources(False);catalog={'license':'Per-entry; CC0 or existing licensed Mixamo' ,'sourceRevision':motion.REVISION,'characters':{}}
for name in ['sobaya','fukuchan']:
 bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.scene.render.fps=30
 bpy.ops.import_scene.gltf(filepath=str(motion.OUT/name/f'{name}.glb'))
 rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
 for obj in bpy.context.scene.objects:
  if obj.animation_data:
   for track in list(obj.animation_data.nla_tracks):obj.animation_data.nla_tracks.remove(track)
 motion.use_action(rig,None);motion.clear_pose(rig)
 for a in list(bpy.data.actions):
  if a.name!='Run':bpy.data.actions.remove(a)
 body=motion.Body(rig,meshes,name);entries=[]
 for spec in sources.values():
  entry=motion.retarget(body,spec,False)
  entry['license']='CC0-1.0';entries.append(entry)
 # Keep the existing retargeted Mixamo performance, without distributing raw FBX.
 captured=bpy.data.actions['Run'];captured.name='Candidate_Mixamo_Run'
 entries.append(dict(name=captured.name,sourceClip='Candidate_Mixamo_Run',label='Run（既存Mixamo）',license='Existing licensed Mixamo; not CC0',source='Shared game GLB Run',duration=(captured.frame_range[1]-captured.frame_range[0])/30))
 # A distinct authored variation of Jog, preserving its leg cycle.
 original=bpy.data.actions['Library_Jog'];end=round(original.frame_range[1]);poses=[]
 motion.use_action(rig,original)
 for frame in range(end+1):
  bpy.context.scene.frame_set(frame);poses.append({b.name:(b.location.copy(),b.rotation_quaternion.copy()) for b in rig.pose.bones})
 variant=body.action('Candidate_Chase_Run',end)
 from mathutils import Quaternion
 for frame,pose in enumerate(poses):
  for b in rig.pose.bones:
   b.location,b.rotation_quaternion=pose[b.name]
   role=body.map.get(b.name,'')
   if role.startswith('upperarm_'):
    b.rotation_quaternion=Quaternion().slerp(b.rotation_quaternion,.72 if name=='sobaya' else .88)
   if role=='spine_01':b.rotation_quaternion=Quaternion((1,0,0),.10 if name=='sobaya' else .15)@b.rotation_quaternion
  bpy.context.view_layer.update();body.key(frame/1.2)
 variant.frame_end=end/1.2
 entries.append(dict(name=variant.name,sourceClip='Candidate_Chase_Run',label='逃走・追跡（調整版）',license='CC0-1.0',source='Jog with authored torso lean, arm amplitude and 1.2x cadence',duration=end/30/1.2,characterDirection='重さのある追跡' if name=='sobaya' else '前傾して逃走'))
 motion.use_action(rig,None);motion.clear_pose(rig)
 bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig
 temp=ROOT/'.local/vrm-validation'/f'{name}_run_candidates.glb'
 bpy.ops.export_scene.gltf(filepath=str(temp),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_frame_range=False,export_anim_slide_to_zero=True,export_anim_single_armature=True,export_skins=True,export_def_bones=False,export_force_sampling=True,export_optimize_animation_size=True)
 gltf,binary=read_glb(temp);nodes={n.get('name'):i for i,n in enumerate(gltf['nodes'])}
 manifest=json.loads((ROOT/f'04_GAME_ASSETS/vrm/characters/{name}.manifest.json').read_text())
 gltf['extensionsUsed']=['VRMC_vrm_animation'];gltf['extensions']={'VRMC_vrm_animation':{'specVersion':'1.0','humanoid':{'humanBones':{role:{'node':nodes[bone]} for role,bone in manifest['humanoidBones'].items()}}}}
 template=copy.deepcopy(gltf);animations=gltf['animations'];folder=OUT/name;folder.mkdir(exist_ok=True)
 for entry in entries:
  gltf=copy.deepcopy(template)
  gltf['animations']=[copy.deepcopy(next(a for a in animations if a['name']==entry['name']))]
  mapped={v['node'] for v in gltf['extensions']['VRMC_vrm_animation']['humanoid']['humanBones'].values()}
  hips=gltf['extensions']['VRMC_vrm_animation']['humanoid']['humanBones']['hips']['node']
  gltf['animations'][0]['channels']=[c for c in gltf['animations'][0]['channels'] if c['target']['node'] in mapped and (c['target']['path']=='rotation' or (c['target']['path']=='translation' and c['target']['node']==hips))]
  # Keep only this performance's referenced buffers (licenses differ by clip).
  animation=gltf['animations'][0]
  ids=sorted({c['sampler'] for c in animation['channels']});remap={v:i for i,v in enumerate(ids)}
  animation['samplers']=[animation['samplers'][i] for i in ids]
  for c in animation['channels']:c['sampler']=remap[c['sampler']]
  ids=sorted({a[k] for a in animation['samplers'] for k in ['input','output']});remap={v:i for i,v in enumerate(ids)}
  gltf['accessors']=[gltf['accessors'][i] for i in ids]
  for a in animation['samplers']:
   for k in ['input','output']:a[k]=remap[a[k]]
  raw=binary[8:];packed=bytearray();views=[]
  for a in gltf['accessors']:
   v=copy.deepcopy(gltf['bufferViews'][a['bufferView']]);offset=v.get('byteOffset',0)+a.pop('byteOffset',0)
   assert a['componentType']==5126 and 'byteStride' not in v and 'sparse' not in a
   v['byteLength']=a['count']*{'SCALAR':1,'VEC3':3,'VEC4':4}[a['type']]*4
   packed.extend(b'\0'*(-len(packed)%4));v['byteOffset']=len(packed)
   packed.extend(raw[offset:offset+v['byteLength']]);a['bufferView']=len(views);views.append(v)
  packed.extend(b'\0'*(-len(packed)%4));gltf['bufferViews']=views;gltf['buffers']=[{'byteLength':len(packed)}]
  clip_binary=struct.pack('<II',len(packed),0x004e4942)+packed
  payload=json.dumps(gltf,separators=(',',':')).encode();payload+=b' '*(-len(payload)%4)
  data=struct.pack('<III',0x46546c67,2,20+len(payload)+len(clip_binary))+struct.pack('<II',len(payload),0x4e4f534a)+payload+clip_binary
  filename=entry['sourceClip'].replace(' ','_')+'.vrma';(folder/filename).write_bytes(data)
  entry.update(validationSource=f'.local/vrm-validation/{name}_run_candidates.glb',file=f'{name}/{filename}',sha256=hashlib.sha256(data).hexdigest())
 catalog['characters'][name]=entries
(OUT/'run_candidates.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')
print('RUN_CANDIDATES_DONE',flush=True)
