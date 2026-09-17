import bpy,sys,json,struct
from pathlib import Path
P=Path(__file__).resolve().parent;ROOT=P.parents[4];sys.path[:0]=[str(P),str(ROOT/'tools')]
bpy.ops.wm.open_mainfile(filepath=str(P/'fukuchan_rig.blend'));bpy.context.scene.render.fps=30
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');mesh=next(o for o in bpy.context.scene.objects if o.type=='MESH')
from retarget import retarget
from poses import author
report=retarget(rig,[mesh]);print('RETARGET_DONE',flush=True);report+=author(rig,mesh)
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);mesh.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.wm.save_as_mainfile(filepath=str(P/'fukuchan_animated.blend'))
bpy.ops.export_scene.gltf(filepath=str(P/'fukuchan.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_frame_range=False,export_anim_slide_to_zero=True,export_anim_single_armature=True,export_skins=True,export_all_influences=False,export_def_bones=False,export_force_sampling=True,export_morph_animation=False)
p=P/'fukuchan.glb';data=p.read_bytes();n=struct.unpack_from('<I',data,12)[0];g=json.loads(data[20:20+n]);tail=data[20+n:]
for mat in g['materials']:
 if mat['name'] in ['Front faithful skin','Natural sclera','Balanced forehead skin']:mat['pbrMetallicRoughness']['baseColorFactor']=[.36,.36,.36,1]
j=json.dumps(g,separators=(',',':')).encode();j+=b' '*((-len(j))%4);p.write_bytes(struct.pack('<4sII',b'glTF',2,20+len(j)+len(tail))+struct.pack('<II',len(j),0x4e4f534a)+j+tail)
(P/'motions.json').write_text(json.dumps(report,indent=2)+'\n');print('ANIMATED_DONE',len(g['animations']),flush=True)
