"""Add amplitude-driven speech to the approved v3, preserving its input asset.

Blender -b --factory-startup --python tools/build_fukuchan_v3_speech.py
"""
import bpy, sys, json, hashlib, struct, copy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
OUT=ROOT/'04_GAME_ASSETS/3d/hazard_adopted/v3_preview_20260917'
SOURCE=ROOT/'04_GAME_ASSETS/3d/characters/fukuchan/rig_v3_20260917/fukuchan.glb'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps=30
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
head=bpy.data.objects['FukuchanV3']
import fukuchan_head_speech as speech
speech.MOUTH=1.4774
speech.WIDTH=.034
report=speech.add_head_speech(head,jaw_bottom=1.427,jaw_full=1.455,include_teeth=False,
                              jaw_distance=.0054,spread=.055,warm_lining=True)
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True);head.select_set(True);bpy.context.view_layer.objects.active=rig
out=OUT/'fukuchan.glb'
bpy.ops.export_scene.gltf(filepath=str(out),export_format='GLB',use_selection=True,
 export_animations=True,export_animation_mode='ACTIONS',export_frame_range=False,
 export_anim_slide_to_zero=True,export_anim_single_armature=True,export_skins=True,
 export_all_influences=False,export_def_bones=False,export_force_sampling=True,
 export_morph_animation=False,export_extras=True)
b=out.read_bytes();n=struct.unpack_from('<I',b,12)[0];g=json.loads(b[20:20+n])
for source,alias in [('Idle','Adopted_Library_Idle_A'),('Walk','Adopted_Library_Walk'),('Run','Adopted_Candidate_Mixamo_Run')]:
 a=copy.deepcopy(next(a for a in g['animations'] if a['name']==source));a['name']=alias;g['animations'].append(a)
j=json.dumps(g,separators=(',',':')).encode();j+=b' '*((-len(j))%4);tail=b[20+n:]
out.write_bytes(struct.pack('<4sII',b'glTF',2,20+len(j)+len(tail))+struct.pack('<I4s',len(j),b'JSON')+j+tail)
report.update(source=str(SOURCE.relative_to(ROOT)),sourceSha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),sha256=hashlib.sha256(out.read_bytes()).hexdigest(),clips=[a['name'] for a in g['animations']])
(OUT/'speech_build.json').write_text(json.dumps(report,indent=2)+'\n')
print('SPEECH_DONE',report,flush=True)
