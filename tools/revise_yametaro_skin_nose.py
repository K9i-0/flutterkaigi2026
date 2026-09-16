"""Run in Blender with rig_sheet_v2/yametaro.blend open; preserve source."""
import bpy, json, hashlib
from pathlib import Path
from mathutils import Vector, Matrix
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'04_GAME_ASSETS/3d/characters/yametaro/rig_sheet_v2/yametaro.blend'
assert Path(bpy.data.filepath)==SOURCE
OUT=SOURCE.parent.parent/'rig_nose_v3';OUT.mkdir(exist_ok=True)
m=bpy.data.objects['YametaroBody'];rig=bpy.data.objects['YametaroRig']
rig.animation_data.action=None
for b in rig.pose.bones:b.matrix_basis=Matrix.Identity(4)
bpy.context.scene.frame_set(0)
adj=[set() for v in m.data.vertices]
for e in m.data.edges:
 a,b=e.vertices;adj[a].add(b);adj[b].add(a)
seed=next(v.index for v in m.data.vertices if -.034<v.co.x<.001 and v.co.y<-.302 and .734<v.co.z<.762)
part={seed};stack=[seed]
while stack:
 for i in adj[stack.pop()]:
  if i not in part:part.add(i);stack.append(i)
assert len(part)==100
colors=m.data.color_attributes['YametaroSkinColor'];skin=m.data.materials.find('YametaroSkinWithoutInk')
assert skin>=0
samples=[]
image=next(n.image for n in m.data.materials[0].node_tree.nodes if n.type=='TEX_IMAGE' and n.image and any(l.to_socket.name=='Base Color' for l in n.outputs['Color'].links))
pixels=list(image.pixels);w,h=image.size;uv=m.data.uv_layers.active.data
def linear(c):return c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4
for p in m.data.polygons:
 for li in p.loop_indices:
  c=m.data.vertices[m.data.loops[li].vertex_index].co
  if abs(c.x)<.12 and .70<c.z<.79 and c.y<-.23:
   if p.material_index==skin:color=tuple(colors.data[li].color)
   else:
    u,v=uv[li].uv;idx=(min(h-1,max(0,int(v*h)))*w+min(w-1,max(0,int(u*w))))*4
    rgb=pixels[idx:idx+3]
    if not (rgb[0]>.48 and rgb[1]>.26 and rgb[0]>rgb[1]*1.2 and rgb[1]>rgb[2]*1.25):continue
    color=(*map(linear,rgb),1)
   samples.append((c.copy(),color))
assert samples
# Match the neighboring repaired skin, with no black texture or normal-map ink.
for p in m.data.polygons:
 if p.vertices[0] in part:
  p.material_index=skin;p.use_smooth=True
  for li in p.loop_indices:
   c=m.data.vertices[m.data.loops[li].vertex_index].co
   nearest=sorted(samples,key=lambda s:(s[0]-c).length_squared)[:8]
   colors.data[li].color=tuple(sum(s[1][a] for s in nearest)/len(nearest) for a in range(4))
# Feather the underlying ink repair in object coordinates, preserving glasses.
repair=m.data.materials[0].copy();repair.name='YametaroNoseInkRepair'
nodes=repair.node_tree.nodes;links=repair.node_tree.links;shader=nodes.get('Principled BSDF')
tex=nodes.new('ShaderNodeTexCoord');sub=nodes.new('ShaderNodeVectorMath');sub.operation='SUBTRACT';sub.inputs[1].default_value=(-.016,-.28,.748);links.new(tex.outputs['Object'],sub.inputs[0])
scale=nodes.new('ShaderNodeVectorMath');scale.operation='MULTIPLY';scale.inputs[1].default_value=(1/.047,0,1/.037);links.new(sub.outputs[0],scale.inputs[0])
length=nodes.new('ShaderNodeVectorMath');length.operation='LENGTH';links.new(scale.outputs[0],length.inputs[0])
fall=nodes.new('ShaderNodeMapRange');fall.interpolation_type='SMOOTHERSTEP';fall.inputs['From Min'].default_value=.6;fall.inputs['From Max'].default_value=1;fall.inputs['To Min'].default_value=1;fall.inputs['To Max'].default_value=0;links.new(length.outputs['Value'],fall.inputs['Value'])
# glTF cannot export procedural mixing; bake this material's base color into a copy
# of its existing atlas below, through Blender's material bake.
m.data.materials.append(repair);repair_index=len(m.data.materials)-1
mix=nodes.new('ShaderNodeMixRGB');links.new(fall.outputs[0],mix.inputs[0]);links.new(shader.inputs['Base Color'].links[0].from_socket,mix.inputs[1]);mix.inputs[2].default_value=tuple(sum(v[1][a] for v in samples)/len(samples) for a in range(4));links.new(mix.outputs[0],shader.inputs['Base Color'])
for p in m.data.polygons:
 c=sum((m.data.vertices[i].co for i in p.vertices),Vector())/len(p.vertices)
 if p.material_index==0 and abs(c.x)<.08 and .71<c.z<.79 and c.y>-.295 and c.y<-.23:p.material_index=repair_index
# Bake only repaired faces to an atlas copy; keep original material elsewhere.
baked=image.copy();baked.name='YametaroNoseRepairedColor';baked.pack()
for mat in m.data.materials:
 node=mat.node_tree.nodes.new('ShaderNodeTexImage');node.image=baked;mat.node_tree.nodes.active=node
bpy.ops.object.select_all(action='DESELECT');m.select_set(True);bpy.context.view_layer.objects.active=m
bpy.context.scene.render.engine='CYCLES';bpy.context.scene.cycles.samples=1
bpy.context.scene.render.bake.use_clear=False
bpy.context.scene.render.bake.margin=4
bpy.ops.object.bake(type='DIFFUSE',pass_filter={'COLOR'})
# The whole object was baked, so vertex skin and cloth materials are captured too.
# Keep their shaders; use the baked image for repaired head faces only.
for link in list(shader.inputs['Base Color'].links):links.remove(link)
node=nodes.new('ShaderNodeTexImage');node.image=baked;links.new(node.outputs['Color'],shader.inputs['Base Color'])
for link in list(shader.inputs['Normal'].links):links.remove(link)
baked.pack()
import runpy
runpy.run_path(str(ROOT/'tools/yametaro_nose_normals.py'))['finish_nose_normals'](m)
lo=Vector(tuple(min(m.data.vertices[i].co[a] for i in part) for a in range(3)))
hi=Vector(tuple(max(m.data.vertices[i].co[a] for i in part) for a in range(3)))
center=(lo+hi)/2;radius=(hi-lo)/2
for i in part:
 co=m.data.vertices[i].co
 direction=Vector(tuple((co[a]-center[a])/radius[a] for a in range(3))).normalized()
 target=Vector((direction.x*.017, -.280+direction.y*.026, .748+direction.z*.016))
 delta=target-co
 for key in m.data.shape_keys.key_blocks:key.data[i].co+=delta
m.data.update()
(OUT/'.gitignore').write_text('*.blend\n*.blend1\npreview_*.png\n')
meta={'source':str(SOURCE.relative_to(ROOT)), 'source_sha256':hashlib.sha256(SOURCE.with_suffix('.glb').read_bytes()).hexdigest(),'change':'Replace black nose with centered low rounded skin-colored bulge, matching current character sheet','nose_vertices':len(part),'preserved':['forehead mark','glasses','cheeks','mouth','speech shape keys','rig and animation actions'],'status':'Local review; not adopted by site or game'}
(OUT/'revision.json').write_text(json.dumps(meta,indent=2)+'\n')
bpy.ops.object.select_all(action='DESELECT');m.select_set(True);rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'yametaro.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'yametaro.glb'),export_format='GLB',export_morph_animation=False,use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_frame_range=False,export_anim_slide_to_zero=True,export_anim_single_armature=True,export_skins=True,export_force_sampling=True)
print('SKIN_NOSE_READY')
