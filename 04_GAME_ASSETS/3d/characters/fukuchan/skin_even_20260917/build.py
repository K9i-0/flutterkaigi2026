"""Bake a local cheek material; patch only its embedded atlas in the original GLB."""
import bpy,bmesh,numpy as np,json,struct,hashlib
from pathlib import Path
O=Path(__file__).resolve().parent;SOURCE=O.parent/'rig_v3_20260917'
bpy.ops.wm.open_mainfile(filepath=str(SOURCE/'fukuchan_animated.blend'))
o=next(o for o in bpy.context.scene.objects if o.type=='MESH');mi=next(i for i,m in enumerate(o.data.materials) if m.name=='Front faithful skin');mat=o.data.materials[mi];tex=next(n for n in mat.node_tree.nodes if n.type=='TEX_IMAGE');source=tex.image
# Measured upper-quartile of the approved front cheek, excluding eyes/lips.
target=np.array([.84313732,.65098041,.59607846])
def smooth(a,b,x):t=np.clip((x-a)/(b-a),0,1);return t*t*(3-2*t)
def weight(p):
 x,y,z=p;side=max(smooth(.031,.066,abs(x)),smooth(-.073,-.025,y))
 return float(.78*side*smooth(1.427,1.46,z)*(1-smooth(1.532,1.567,z))*(1-smooth(.078,.100,abs(x)))*(1-smooth(.015,.045,y)))
temp=o.copy();temp.data=o.data.copy();temp.modifiers.clear();bpy.context.collection.objects.link(temp)
bm=bmesh.new();bm.from_mesh(temp.data);bmesh.ops.delete(bm,geom=[f for f in bm.faces if f.material_index!=mi or not any(weight(v.co)>0 for v in f.verts)],context='FACES');bm.to_mesh(temp.data);bm.free()
mask=temp.data.color_attributes.new(name='CheekMask',type='FLOAT_COLOR',domain='CORNER')
for li,loop in enumerate(temp.data.loops):
 a=weight(temp.data.vertices[loop.vertex_index].co);mask.data[li].color=(a,a,a,1)
bake=bpy.data.materials.new('Local even cheek material');bake.use_nodes=True;n=bake.node_tree.nodes;n.clear();links=bake.node_tree.links
src=n.new('ShaderNodeTexImage');src.image=source;vc=n.new('ShaderNodeVertexColor');vc.layer_name='CheekMask'
# Preserve dark hair pixels that share the facial UV atlas.
bw=n.new('ShaderNodeRGBToBW');links.new(src.outputs['Color'],bw.inputs[0]);r=n.new('ShaderNodeMapRange');r.clamp=True;r.inputs['From Min'].default_value=.08;r.inputs['From Max'].default_value=.18;links.new(bw.outputs[0],r.inputs['Value'])
mul=n.new('ShaderNodeMath');mul.operation='MULTIPLY';links.new(vc.outputs['Color'],mul.inputs[0]);links.new(r.outputs[0],mul.inputs[1])
mix=n.new('ShaderNodeMixRGB');mix.inputs[2].default_value=(*np.where(target<=.04045,target/12.92,((target+.055)/1.055)**2.4),1);links.new(src.outputs[0],mix.inputs[1]);links.new(mul.outputs[0],mix.inputs[0]);em=n.new('ShaderNodeEmission');links.new(mix.outputs[0],em.inputs[0]);end=n.new('ShaderNodeOutputMaterial');links.new(em.outputs[0],end.inputs[0])
im=bpy.data.images.new('Even cheek atlas',width=source.size[0],height=source.size[1],alpha=True);im.pixels.foreach_set(source.pixels[:]);dst=n.new('ShaderNodeTexImage');dst.image=im;n.active=dst
temp.data.materials.clear();temp.data.materials.append(bake)
for f in temp.data.polygons:f.material_index=0
bpy.ops.object.select_all(action='DESELECT');temp.select_set(True);bpy.context.view_layer.objects.active=temp
sc=bpy.context.scene;sc.render.engine='CYCLES';sc.cycles.samples=1;bpy.ops.object.bake(type='EMIT',use_clear=False,margin=4)
im.filepath_raw=str(O/'cheek_atlas.png');im.file_format='PNG';im.save();im.pack();tex.image=im;bpy.data.objects.remove(temp,do_unlink=True)
bpy.ops.wm.save_as_mainfile(filepath=str(O/'fukuchan_skin.blend'))
# Preserve every non-image buffer byte, all materials, animation, weights, morphs and UVs.
data=(SOURCE/'fukuchan.glb').read_bytes();size=struct.unpack_from('<I',data,12)[0];g=json.loads(data[20:20+size]);binary=data[28+size:]
m=next(m for m in g['materials'] if m['name']=='Front faithful skin');ti=m['pbrMetallicRoughness']['baseColorTexture']['index'];ii=g['textures'][ti]['source'];vi=g['images'][ii]['bufferView'];oldview=g['bufferViews'][vi];offset=len(binary);pad=b'\0'*((-offset)%4);offset+=len(pad);atlas=(O/'cheek_atlas.png').read_bytes();g['bufferViews'][vi]={'buffer':0,'byteOffset':offset,'byteLength':len(atlas)};binary+=pad+atlas;binary+=b'\0'*((-len(binary))%4);g['buffers'][0]['byteLength']=len(binary)
j=json.dumps(g,separators=(',',':')).encode();j+=b' '*((-len(j))%4);out=struct.pack('<4sII',b'glTF',2,28+len(j)+len(binary))+struct.pack('<I4s',len(j),b'JSON')+j+struct.pack('<I4s',len(binary),b'BIN\0')+binary;(O/'fukuchan.glb').write_bytes(out)
report={'sourceSha256':hashlib.sha256(data).hexdigest(),'sha256':hashlib.sha256(out).hexdigest(),'targetFrontSRGB':target.tolist(),'replacedImage':ii,'originalBinaryPrefixExact':binary[:len(data[28+size:])]==data[28+size:],'animations':len(g['animations']),'joints':len(g['skins'][0]['joints'])};(O/'validation.json').write_text(json.dumps(report,indent=2)+'\n');print(report,flush=True)
