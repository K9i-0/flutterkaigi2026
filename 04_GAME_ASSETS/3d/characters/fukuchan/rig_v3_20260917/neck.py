"""Bake a localized smooth neck material into the existing UV layout using Cycles.

Temporary bake geometry only. Source geometry/UV and unrelated materials stay intact.
"""
import bpy,bmesh,numpy as np
from mathutils import Vector

def clean_neck(o,out):
 def smooth(a,b,x):t=max(0,min(1,(x-a)/(b-a)));return t*t*(3-2*t)
 def linear(c):return np.where(c<=.04045,c/12.92,((c+.055)/1.055)**2.4)
 report={};originals=[a for a in bpy.context.scene.objects];scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=1
 target=np.array([.82,.625,.535])
 def weight(p):
  side=smooth(-.085,-.035,p.y);top=1.438+.047*side
  return smooth(1.30,1.335,p.z)*(1-smooth(top-.025,top,p.z))*(1-smooth(.07,.095,abs(p.x)))
 for f in o.data.polygons:
  if f.material_index==1 and all(o.data.vertices[i].co.z>1.29 for i in f.vertices):f.material_index=10
 for mi in [10]:
  mat=o.data.materials[mi];tex=next(n for n in mat.node_tree.nodes if n.type=='TEX_IMAGE');source=tex.image
  temp=o.copy();temp.data=o.data.copy();bpy.context.collection.objects.link(temp)
  bm=bmesh.new();bm.from_mesh(temp.data);bmesh.ops.delete(bm,geom=[f for f in bm.faces if f.material_index!=mi or not any(weight(v.co)>0 for v in f.verts)],context='FACES');bm.to_mesh(temp.data);bm.free()
  mask=temp.data.color_attributes.new(name='NeckMask',type='FLOAT_COLOR',domain='CORNER');active=0
  for li,loop in enumerate(temp.data.loops):
   p=temp.data.vertices[loop.vertex_index].co;a=weight(p)
   mask.data[li].color=(a,a,a,1);active+=a>0
  bake=bpy.data.materials.new('Neck procedural bake');bake.use_nodes=True;n=bake.node_tree.nodes;n.clear();links=bake.node_tree.links
  src=n.new('ShaderNodeTexImage');src.image=source;vc=n.new('ShaderNodeVertexColor');vc.layer_name='NeckMask';mix=n.new('ShaderNodeMixRGB');mix.blend_type='MIX';mix.inputs[2].default_value=(*linear(target),1);links.new(src.outputs['Color'],mix.inputs[1]);links.new(vc.outputs['Color'],mix.inputs[0]);em=n.new('ShaderNodeEmission');links.new(mix.outputs[0],em.inputs[0]);end=n.new('ShaderNodeOutputMaterial');links.new(em.outputs[0],end.inputs['Surface'])
  image=bpy.data.images.new('Clean neck atlas '+str(mi),width=source.size[0],height=source.size[1],alpha=True);image.pixels.foreach_set(source.pixels[:]);dst=n.new('ShaderNodeTexImage');dst.image=image;n.active=dst
  temp.data.materials.clear();temp.data.materials.append(bake)
  for f in temp.data.polygons:f.material_index=0
  bpy.ops.object.select_all(action='DESELECT');temp.select_set(True);bpy.context.view_layer.objects.active=temp
  bpy.ops.object.bake(type='EMIT',use_clear=False,margin=4)
  print('BAKE_DELTA',mi,float(np.max(np.abs(np.array(image.pixels[:])-np.array(source.pixels[:])))),flush=True)
  image.filepath_raw=str(out/f'neck_atlas_{mi}.png');image.file_format='PNG';image.save();image.pack();tex.image=image
  bpy.data.objects.remove(temp,do_unlink=True);bpy.data.materials.remove(bake);report[mat.name]={'mask_loops':active,'source_image':source.name}
 return report
