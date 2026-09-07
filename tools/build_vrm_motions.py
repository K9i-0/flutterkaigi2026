"""Blender: bake CC0 performances to avatar-calibrated VRM Animation files."""
import sys,json,struct,hashlib
from pathlib import Path
import bpy
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
import build_humanoid_motion as motion
from export_humanoid_vrm import read_glb
OUT=ROOT/'04_GAME_ASSETS/vrm/motions';OUT.mkdir(parents=True,exist_ok=True)
motion.BASE=[(s,l,'VRM',True,False) for s,l in [('Idle_A','待機'),('Walk','歩行'),('Sprint','ダッシュ'),('Dance_Simple','ダンス：シンプル')]]
motion.ADDON=[(s,l,'VRM',True,False) for s,l in [('Dance Charleston','ダンス：チャールストン'),('Dance Body Roll','ダンス：ボディロール')]]
sources=motion.read_sources(False);catalog={'license':'CC0-1.0','sourceRevision':motion.REVISION,'characters':{}}
for name in ['sobaya','fukuchan']:
 bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.scene.render.fps=30
 bpy.ops.import_scene.gltf(filepath=str(motion.OUT/name/f'{name}.glb'))
 rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
 for obj in bpy.context.scene.objects:
  if obj.animation_data:
   for track in list(obj.animation_data.nla_tracks):obj.animation_data.nla_tracks.remove(track)
 motion.use_action(rig,None);motion.clear_pose(rig)
 for a in list(bpy.data.actions):bpy.data.actions.remove(a)
 body=motion.Body(rig,meshes,name);entries=[]
 for spec in sources.values():entries.append(motion.retarget(body,spec,False))
 motion.use_action(rig,None);motion.clear_pose(rig)
 bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig
 temp=ROOT/'.local/vrm-validation'/f'{name}_motions.glb'
 bpy.ops.export_scene.gltf(filepath=str(temp),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_frame_range=False,export_anim_slide_to_zero=True,export_anim_single_armature=True,export_skins=True,export_def_bones=False,export_force_sampling=True,export_optimize_animation_size=True)
 gltf,binary=read_glb(temp);nodes={n.get('name'):i for i,n in enumerate(gltf['nodes'])}
 manifest=json.loads((ROOT/f'04_GAME_ASSETS/vrm/characters/{name}.manifest.json').read_text())
 gltf['extensionsUsed']=['VRMC_vrm_animation'];gltf['extensions']={'VRMC_vrm_animation':{'specVersion':'1.0','humanoid':{'humanBones':{role:{'node':nodes[bone]} for role,bone in manifest['humanoidBones'].items()}}}}
 animations=gltf['animations'];folder=OUT/name;folder.mkdir(exist_ok=True)
 for entry in entries:
  gltf['animations']=[next(a for a in animations if a['name']==entry['name'])]
  mapped={v['node'] for v in gltf['extensions']['VRMC_vrm_animation']['humanoid']['humanBones'].values()}
  hips=gltf['extensions']['VRMC_vrm_animation']['humanoid']['humanBones']['hips']['node']
  gltf['animations'][0]['channels']=[c for c in gltf['animations'][0]['channels'] if c['target']['node'] in mapped and (c['target']['path']=='rotation' or (c['target']['path']=='translation' and c['target']['node']==hips))]
  payload=json.dumps(gltf,separators=(',',':')).encode();payload+=b' '*(-len(payload)%4)
  data=struct.pack('<III',0x46546c67,2,20+len(payload)+len(binary))+struct.pack('<II',len(payload),0x4e4f534a)+payload+binary
  filename=entry['sourceClip'].replace(' ','_')+'.vrma';(folder/filename).write_bytes(data)
  entry.update(file=f'{name}/{filename}',sha256=hashlib.sha256(data).hexdigest())
 catalog['characters'][name]=entries
(OUT/'catalog.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')
print('VRM_MOTIONS_DONE',flush=True)
