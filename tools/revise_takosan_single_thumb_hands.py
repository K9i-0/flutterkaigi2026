"""Run in Blender with rig_radial_v3/takosan.blend open.
Replace the generated finger cluster with a smooth round palm and one thumb.
"""
from pathlib import Path
from array import array
import bpy,bmesh,math,json,hashlib
from mathutils import Vector,Matrix
root=Path(bpy.data.filepath).parents[5]
source=root/'04_GAME_ASSETS/3d/characters/takosan/rig_radial_v3/takosan.blend'
assert Path(bpy.data.filepath)==source
out=source.parent.parent/'rig_radial_v4_hands';out.mkdir(exist_ok=True)
(out/'.gitignore').write_text('*.blend\n*.blend1\npreview_*.png\n')
body=bpy.data.objects['TakosanBody'];rig=bpy.data.objects['TakosanRig'];mesh=body.data
if bpy.context.object and bpy.context.object.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
rig.animation_data.action=None
for b in rig.pose.bones:b.matrix_basis=Matrix.Identity(4)
bpy.context.scene.frame_set(0)
labels=mesh.attributes['RigRegion'];original=[v.co.copy() for v in mesh.vertices]
images={}
for j,mat in enumerate(mesh.materials):
 base=mat.node_tree.nodes['Principled BSDF'].inputs['Base Color']
 if base.is_linked:
  im=base.links[0].from_node.image;pixels=array('f',[0])*len(im.pixels);im.pixels.foreach_get(pixels);images[j]=(im.size[0],im.size[1],pixels)
remove=set()
for f in mesh.polygons:
 if not all(labels.data[i].value in (2,3) for i in f.vertices):continue
 if max(mesh.vertices[i].co.z for i in f.vertices)>.45:continue
 if f.material_index not in images:continue
 w,h,pixels=images[f.material_index];values=[]
 for l in f.loop_indices:
  uv=mesh.uv_layers.active.data[l].uv;x=min(w-1,max(0,int(uv.x*w)));y=min(h-1,max(0,int(uv.y*h)));k=(y*w+x)*4;values.append(sum(pixels[k:k+3])/3)
 if sum(values)/len(values)>.32:remove.update(f.vertices)
for v in mesh.vertices:
 if labels.data[v.index].value in (2,3) and (.924*v.co.z-.383*abs(v.co.x)<.225 or (abs(v.co.x)<.315 and v.co.z<.400)):
  remove.add(v.index)
assert 400<len(remove)<1100,len(remove)
bm=bmesh.new();bm.from_mesh(mesh);bm.verts.ensure_lookup_table();bmesh.ops.delete(bm,geom=[bm.verts[i] for i in remove],context='VERTS');bm.to_mesh(mesh);bm.free();mesh.update()
import runpy
cuff_report=runpy.run_path(str(root/'tools/takosan_hand_cuffs.py'))['finish_cuffs'](body)
material=bpy.data.materials.new('Takosan ivory round hands');material.use_nodes=True
shader=material.node_tree.nodes['Principled BSDF'];shader.inputs['Base Color'].default_value=(.76,.68,.54,1);shader.inputs['Roughness'].default_value=.85
hands=[]
for side,suffix,label in [(-1,'L',2),(1,'R',3)]:
 parts=[]
 for name,center,radii in [('Palm',(.373,-.060,.386),(.055,.061,.059)),('Thumb',(.314,-.052,.400),(.024,.026,.025))]:
  bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=20,location=(side*center[0],center[1],center[2]))
  obj=bpy.context.object;obj.name=f'Takosan{name}.{suffix}';obj.scale=radii
  bpy.ops.object.transform_apply(location=True,rotation=True,scale=True);parts.append(obj)
 bpy.ops.object.select_all(action='DESELECT')
 for obj in parts:obj.select_set(True)
 bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();hand=parts[0]
 remesh=hand.modifiers.new('Smooth palm and single thumb','REMESH');remesh.mode='VOXEL';remesh.voxel_size=.0025;remesh.use_smooth_shade=True;bpy.ops.object.modifier_apply(modifier=remesh.name)
 smooth=hand.modifiers.new('Soften thumb junction','SMOOTH');smooth.factor=.65;smooth.iterations=4;bpy.ops.object.modifier_apply(modifier=smooth.name)
 decimate=hand.modifiers.new('Hand web mesh','DECIMATE');decimate.ratio=.08;bpy.ops.object.modifier_apply(modifier=decimate.name)
 hand.data.materials.clear();hand.data.materials.append(material)
 for f in hand.data.polygons:f.use_smooth=True
 region=hand.data.attributes.new('RigRegion','INT','POINT')
 for v in region.data:v.value=label
 hg=hand.vertex_groups.new(name='Hand.'+suffix);fg=hand.vertex_groups.new(name='Forearm.'+suffix)
 for v in hand.data.vertices:
  t=max(0,min(1,(v.co.z-.37)/.05));t=t*t*(3-2*t)
  if t<1:hg.add([v.index],1-t,'REPLACE')
  if t>0:fg.add([v.index],t,'REPLACE')
 hands.append(hand)
bpy.ops.object.select_all(action='DESELECT');body.select_set(True)
for h in hands:h.select_set(True)
bpy.context.view_layer.objects.active=body;bpy.ops.object.join()
body.data.calc_loop_triangles()
report={'source':str(source.relative_to(root)),'source_glb_sha256':hashlib.sha256(source.with_suffix('.glb').read_bytes()).hexdigest(),'change':'Both hands: round ivory palm with one short inward-facing thumb; remove generated multi-finger cluster','removed_vertices':len(remove),'cuff_finish':cuff_report,'triangles':len(body.data.loop_triangles),'bones':len(rig.data.bones),'clips':[a.name for a in bpy.data.actions],'status':'Local revision; not adopted by website or game'}
(out/'revision.json').write_text(json.dumps(report,indent=2)+'\n')
bpy.ops.object.select_all(action='DESELECT');body.select_set(True);rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.wm.save_as_mainfile(filepath=str(out/'takosan.blend'))
bpy.ops.export_scene.gltf(filepath=str(out/'takosan.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_frame_range=False,export_anim_slide_to_zero=True,export_anim_single_armature=True,export_skins=True,export_force_sampling=True)
print('SINGLE_THUMB_HANDS_READY',json.dumps(report))
