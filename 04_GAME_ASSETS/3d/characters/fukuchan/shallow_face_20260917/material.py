"""Retain reference texture detail while reducing doubled lighting contrast."""
import bpy,json
from pathlib import Path
O=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(O/'fukuchan_shallow.blend'))
o=next(o for o in bpy.context.scene.objects if o.type=='MESH')
for mat in o.data.materials:
 if not any(k in mat.name for k in ['Front faithful skin','Natural sclera']):continue
 bs=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');nt=mat.node_tree
 color=bs.inputs['Base Color'].links[0].from_socket
 mix=nt.nodes.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1;mix.inputs[2].default_value=(.45,.45,.45,1);nt.links.new(color,mix.inputs[1]);nt.links.new(mix.outputs[0],bs.inputs['Base Color'])
 nt.links.new(color,bs.inputs['Emission Color']);bs.inputs['Emission Strength'].default_value=.55
 bs.inputs['Specular IOR Level'].default_value=0
# Correct legacy forehead polygons still assigned to the hair shading model.
skin=next(m for m in o.data.materials if 'Front faithful skin' in m.name)
hair=next(m for m in o.data.materials if 'sculpted black hair' in m.name)
hb=next(n for n in hair.node_tree.nodes if n.type=='BSDF_PRINCIPLED');hi=hb.inputs['Base Color'].links[0].from_node.image
fore=skin.copy();fore.name='Balanced forehead skin'
for node in fore.node_tree.nodes:
 if node.type=='TEX_IMAGE':node.image=hi
o.data.materials.append(fore);fi=len(o.data.materials)-1
for face in o.data.polygons:
 if o.data.materials[face.material_index]!=hair:continue
 c=sum((o.matrix_world@o.data.vertices[i].co for i in face.vertices),__import__('mathutils').Vector())/len(face.vertices)
 x,y,z=c
 if abs(x)<max(.018,min(.063,.063-.5*(z-1.55))) and 1.555<z<1.63 and -.105<y<0:face.material_index=fi
bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
bpy.ops.export_scene.gltf(filepath=str(O/'fukuchan_balanced.glb'),export_format='GLB',use_selection=True,export_animations=False)
bpy.ops.wm.save_as_mainfile(filepath=str(O/'fukuchan_balanced.blend'))
print('MATERIAL_DONE')
# Blender's exporter omits the linked Multiply node's color factor; preserve it explicitly.
import struct
p=O/'fukuchan_balanced.glb';data=p.read_bytes();n=struct.unpack_from('<I',data,12)[0];g=json.loads(data[20:20+n]);tail=data[20+n:]
for mat in g['materials']:
 if any(k in mat['name'] for k in ['Front faithful skin','Natural sclera','Balanced forehead skin']):mat['pbrMetallicRoughness']['baseColorFactor']=[.45,.45,.45,1]
j=json.dumps(g,separators=(',',':')).encode();j+=b' '*((-len(j))%4);p.write_bytes(struct.pack('<4sII',b'glTF',2,20+len(j)+len(tail))+struct.pack('<II',len(j),0x4e4f534a)+j+tail)
