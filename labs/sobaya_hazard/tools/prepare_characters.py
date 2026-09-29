"""Export only body geometry and independently authored locomotion clips.
Run in Blender with -- INPUT_DIRECTORY OUTPUT_DIRECTORY. Canonical inputs stay unchanged.
"""
import sys,json,hashlib
from pathlib import Path
import bpy
source,out=map(Path,sys.argv[sys.argv.index('--')+1:]);out.mkdir(parents=True,exist_ok=True)
report={}
for actor in ['fukuchan','sobaya']:
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.context.scene.render.fps=60
 path=source/f'{actor}.glb'
 bpy.ops.import_scene.gltf(filepath=str(path.resolve()))
 rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
 for obj in list(bpy.context.scene.objects):
  if obj.type=='MESH' and obj.name in ['CarriedEggShell','FishingRod','NetBag','NetHandle','NetHoop','PickaxeHandle','PickaxeHead']:
   bpy.data.objects.remove(obj,do_unlink=True)
 if rig.animation_data:rig.animation_data_clear()
 for action in list(bpy.data.actions):
  label=action.name.split('_')[-1]
  if label not in ['Idle','Walk','Run']:bpy.data.actions.remove(action)
  else:action.name=label;action.use_fake_user=True
 rig.animation_data_create()
 rig.animation_data.action=next(a for a in bpy.data.actions if a.name=='Idle')
 rig.animation_data.action_slot=rig.animation_data.action.slots[0]
 for bone in rig.pose.bones:bone.matrix_basis.identity()
 target=out/f'{actor}.glb'
 bpy.ops.export_scene.gltf(filepath=str(target.resolve()),export_format='GLB',export_animations=True,export_animation_mode='ACTIONS',export_frame_range=False,export_anim_slide_to_zero=True,export_anim_single_armature=True,export_skins=True,export_def_bones=False,export_force_sampling=True,export_optimize_animation_size=False,export_extras=False)
 report[actor]={'inputSha256':hashlib.sha256(path.read_bytes()).hexdigest(),'outputSha256':hashlib.sha256(target.read_bytes()).hexdigest(),'clips':['Idle','Walk','Run'],'geometry':'Existing approved character body; no vertex edits','motion':'Independently authored locomotion; previous game walking clips not reused'}
(out/'characters.json').write_text(json.dumps(report,indent=2)+'\n')
