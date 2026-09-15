import bpy, os, json, struct
from pathlib import Path
root=Path(__file__).resolve().parents[1]
source=root/'04_GAME_ASSETS/3d/characters/sobaya/v2_20260915_mask/sobaya_v2.glb'
out=root/'04_GAME_ASSETS/3d/hazard_adopted/v2_20260915_mask/sobaya.glb'
old=root/'04_GAME_ASSETS/3d/hazard_adopted/v2_20260913/sobaya.glb'
bpy.ops.wm.open_mainfile(filepath=str(root/'04_GAME_ASSETS/3d/characters/sobaya/v2_20260915_mask/sobaya_v2.blend'))
rig=bpy.data.objects['SobayaV2Rig']; meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
for obj in bpy.data.objects:
 obj.animation_data_clear()
for a in list(bpy.data.actions):bpy.data.actions.remove(a)
for p in rig.pose.bones:p.matrix_basis.identity()
bpy.context.view_layer.update()
def export(path):
 path.parent.mkdir(parents=True,exist_ok=True)
 bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_frame_range=False,export_anim_slide_to_zero=True,export_anim_single_armature=True,export_skins=True,export_def_bones=False,export_force_sampling=True,export_optimize_animation_size=True,export_extras=True,export_apply=True)
def select(r):
 bpy.ops.object.select_all(action='DESELECT')
 for o in meshes+[r]:o.select_set(True)
 bpy.context.view_layer.objects.active=r
select(rig);export(source)
before=set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(old))
added=set(bpy.data.objects)-before
newrig=next(o for o in added if o.type=='ARMATURE')
for b in rig.data.bones:
 other=newrig.data.bones.get(b.name)
 assert other is not None,b.name
 diff=max(abs(x-y) for row1,row2 in zip(rig.matrix_world@b.matrix_local,newrig.matrix_world@other.matrix_local) for x,y in zip(row1,row2))
 assert diff<1e-4,(b.name,diff)
for o in meshes:
 world=o.matrix_world.copy();o.parent=newrig;o.matrix_world=world
 for m in o.modifiers:
  if m.type=='ARMATURE':m.object=newrig
for o in added:
 if o!=newrig:bpy.data.objects.remove(o,do_unlink=True)
bpy.data.objects.remove(rig,do_unlink=True)
newrig.animation_data_clear()
for p in newrig.pose.bones:p.matrix_basis.identity()
bpy.context.view_layer.update()
select(newrig);export(out)
print('ADOPTION_COMPLETE',source,out)
