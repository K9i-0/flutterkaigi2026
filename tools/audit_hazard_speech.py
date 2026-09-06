"""Blender round-trip and portrait review for the exported speech morphs.

Checks finite posed vertices and localized displacement at eleven open values.
This does not certify phonemes, subjective likeness or natural speech.
"""
import bpy,json,math,hashlib,sys
from pathlib import Path
from mathutils import Vector,Matrix
root=Path(__file__).resolve().parent.parent;out=root/'21_SOBAYA_HAZARD_LAB/evidence';report={}
for name,height,scale in [('fukuchan',1.60,.34),('yametaro',.91,.82)]:
 bpy.ops.wm.read_factory_settings(use_empty=True)
 path=root/f'04_GAME_ASSETS/3d/characters/{name}/rig_v1/{name}.glb';bpy.ops.import_scene.gltf(filepath=str(path))
 rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');rig.animation_data_clear()
 for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.data.shape_keys is not None]
 for mesh in meshes:
  if mesh.data.shape_keys:mesh.data.shape_keys.animation_data_clear()
 scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=16;scene.cycles.use_denoising=True
 scene.render.resolution_x=900;scene.render.resolution_y=900;scene.render.resolution_percentage=100
 scene.world=bpy.data.worlds.new('FaceReview');scene.world.color=(.35,.35,.35)
 for loc,power in [((2,-3,4),450),((-2,-2,2),250)]:
  bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=power;o.data.size=3;o.rotation_euler=(Vector((0,0,height))-o.location).to_track_quat('-Z','Y').to_euler()
 bpy.ops.object.camera_add(location=(0,-3,height));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,height))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=scale;scene.camera=cam
 moved=0;maxdelta=0;minheight=10
 for mesh in meshes:
  keys=mesh.data.shape_keys.key_blocks
  for key in list(keys)[1:]:
   for base,target in zip(keys[0].data,key.data):
    d=(target.co-base.co).length
    if d>1e-6:moved+=1;minheight=min(minheight,base.co.z)
    maxdelta=max(maxdelta,d)
 for sample in range(11):
  amount=sample/10
  for mesh in meshes:
   mesh.data.shape_keys.key_blocks['SpeechOpen'].value=amount
   mesh.data.shape_keys.key_blocks['SpeechNarrow'].value=.2*amount
  bpy.context.view_layer.update()
  for mesh in meshes:
   e=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get());posed=e.to_mesh()
   assert all(math.isfinite(c) for v in posed.vertices for c in v.co)
   e.to_mesh_clear()
 for label,amount in [('neutral',0),('open',.85)]:
  for mesh in meshes:
   mesh.data.shape_keys.key_blocks['SpeechOpen'].value=amount;mesh.data.shape_keys.key_blocks['SpeechNarrow'].value=amount*.2
  scene.render.filepath=str(out/f'{name}-speech-export-{label}.png');bpy.ops.render.render(write_still=True)
 assert minheight>(1.39 if name=='fukuchan' else .57),(name,minheight)
 report[name]={'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'poses':11,'finite':True,'maximumMorphDelta':maxdelta,'minimumChangedHeight':minheight,'changedVertexTargetPairs':moved,'joints':len(rig.data.bones)}
(out/'speech-models.json').write_text(json.dumps(report,indent=2)+'\n');print('SPEECH_AUDIT',json.dumps(report),flush=True)
