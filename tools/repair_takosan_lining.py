"""Build v6 from v5: dark reverse cloth, hood edge cleanup, flexible tentacle sockets."""
from pathlib import Path
import bpy, math, json, hashlib
from mathutils import Vector, Matrix
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'04_GAME_ASSETS/3d/characters/takosan/rig_radial_v5_clean/takosan.blend'
OUT=SOURCE.parent.parent/'rig_radial_v6_lined';OUT.mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
body=bpy.data.objects['TakosanBody'];rig=bpy.data.objects['TakosanRig']
rig.animation_data.action=None
for b in rig.pose.bones:b.matrix_basis=Matrix.Identity(4)
bpy.context.scene.frame_set(0)
mat=bpy.data.materials.new('Takosan lightless inner cloth');mat.use_nodes=True
bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(.0003,.0004,.0005,1);bs.inputs['Roughness'].default_value=1;bs.inputs['Specular IOR Level'].default_value=0
mat.use_backface_culling=True
# Original outer cloth keeps its texture, but is no longer visible through its reverse.
for m in body.data.materials:m.use_backface_culling=True
body.data.materials.append(mat);black=len(body.data.materials)-1
edge_mat=mat.copy();edge_mat.name='Takosan clean dark hood rim';edge_mat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.012,.014,.015,1)
body.data.materials.append(edge_mat);edge_index=len(body.data.materials)-1
region=body.data.attributes['RigRegion'];patched=[]
for p in body.data.polygons:
 c=p.center
 if all(region.data[i].value==1 for i in p.vertices) and ((.68<c.z<.86 and c.y<-.20) or (.715<c.z<.86 and c.y<-.10 and abs(c.x)<.17)):
  p.material_index=edge_index;patched.append(p.index)
# Anatomical region 0 is the complete white face/chin: never recolor it.
assert all(p.material_index==0 for p in body.data.polygons if all(region.data[i].value==0 for i in p.vertices))
# Reverse duplicate: same deformation and silhouette, dark on every inside surface.
lining=body.copy();lining.data=body.data.copy();lining.name='TakosanDarkInterior';bpy.context.collection.objects.link(lining)
lining.data.materials.clear();lining.data.materials.append(mat)
for p in lining.data.polygons:p.material_index=0
import bmesh
bm=bmesh.new();bm.from_mesh(lining.data)
# Keep the interior shell only where the robe and hood need it.
labels=bm.verts.layers.int['RigRegion']
bmesh.ops.delete(bm,geom=[v for v in bm.verts if v[labels]!=1 or v.co.z<.32],context='VERTS')
for v in bm.verts:v.co-=v.normal*.0008
bmesh.ops.reverse_faces(bm,faces=list(bm.faces));bm.to_mesh(lining.data);bm.free()
# Hidden closed under-robe volume blocks lines of sight between the six roots.
parts=[body,lining]
bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=16,location=(0,0,.325))
core=bpy.context.object;core.name='TakosanDarkUnderskirt';core.scale=(.205,.205,.075)
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
core.data.materials.append(mat);core.vertex_groups.new(name='Root').add(list(range(len(core.data.vertices))),1,'REPLACE')
mod=core.modifiers.new('Takosan rig','ARMATURE');mod.object=rig;parts.append(core)
# Overlapping sleeves have a fixed top under the robe and a bone-following lower end.
for i in range(1,7):
 label=9+i;head=rig.data.bones[f'Tentacle{i}.Base'].head_local
 verts=[v.co for v in body.data.vertices if region.data[v.index].value==label and .21<v.co.z<.275 and (v.co.xy-head.xy).length<.16]
 center=sum(verts,Vector())/len(verts);center.z=.235
 top=Vector((center.x*.80,center.y*.80,.355))
 points=[];faces=[];rings=7;sides=24
 for r in range(rings):
  t=r/(rings-1);c=top.lerp(center,t);radius=.058 if i<5 else .066
  for k in range(sides):
   a=k*math.tau/sides;points.append(tuple(c+Vector((radius*math.cos(a),radius*math.sin(a),0))))
 for r in range(rings-1):
  for k in range(sides):
   n=(k+1)%sides;faces.append((r*sides+k,(r+1)*sides+k,(r+1)*sides+n,r*sides+n))
 faces.extend([tuple(reversed(range(sides))),tuple((rings-1)*sides+k for k in range(sides))])
 mesh=bpy.data.meshes.new('Flexible socket');mesh.from_pydata(points,[],faces);mesh.update()
 obj=bpy.data.objects.new(f'TakosanSocket{i}',mesh);bpy.context.collection.objects.link(obj);mesh.materials.append(mat)
 root=obj.vertex_groups.new(name='Root');limb=obj.vertex_groups.new(name=f'Tentacle{i}.Base')
 for r in range(rings):
  t=r/(rings-1);weight=t*t*(3-2*t);ids=list(range(r*sides,(r+1)*sides));root.add(ids,1-weight,'REPLACE');limb.add(ids,weight,'REPLACE')
 for p in mesh.polygons:p.use_smooth=True
 mod=obj.modifiers.new('Takosan rig','ARMATURE');mod.object=rig;parts.append(obj)
# Join to canonical body so downstream tools retain one skinned object and all clips.
bpy.ops.object.select_all(action='DESELECT')
for obj in parts:obj.select_set(True)
bpy.context.view_layer.objects.active=body;bpy.ops.object.join()
bpy.ops.object.select_all(action='DESELECT');body.select_set(True);rig.select_set(True);bpy.context.view_layer.objects.active=rig
(OUT/'.gitignore').write_text('*.blend\n*.blend1\npreview_*.png\n')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'takosan.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'takosan.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_frame_range=False,export_anim_slide_to_zero=True,export_anim_single_armature=True,export_skins=True,export_force_sampling=True)
report={'source':str(SOURCE.relative_to(ROOT)),'source_sha256':hashlib.sha256(SOURCE.with_suffix('.glb').read_bytes()).hexdigest(),'hood_darkened_faces':len(patched),'socket_count':6,'bones':len(rig.data.bones),'clips':[a.name for a in bpy.data.actions]}
(OUT/'revision.json').write_text(json.dumps(report,indent=2)+'\n');print('LINING_REPAIR_COMPLETE',report)
