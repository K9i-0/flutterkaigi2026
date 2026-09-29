"""Blockout geometry from the same layout consumed by collision and gameplay."""
import json,sys
from pathlib import Path
import bpy
root=Path(__file__).resolve().parents[1]
x=json.loads((root/'assets/yard.json').read_text())
bpy.ops.wm.read_factory_settings(use_empty=True)
def material(name,color):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(*color,1)
 m.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.85
 return m
floor=material('Wet concrete',(.08,.12,.15));wall=material('Boundary',(.15,.2,.22));crate=material('Cargo blue',(.09,.24,.29));trim=material('Safety amber',(.9,.48,.08));green=material('Control teal',(.1,.75,.52))
def box(name,x,z,w,d,h,mat,y=0):
 bpy.ops.mesh.primitive_cube_add(size=1,location=(x,-z,y+h/2));o=bpy.context.object;o.name=name;o.scale=(w,d,h);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(mat)
box('Ground',0,0,24,36,.2,floor,-.2)
for a in [(-12,0,.4,36),(12,0,.4,36),(0,-18,24,.4),(0,18,24,.4)]:box('Perimeter',*a,3,wall)
for i,(a,b,w,d,h) in enumerate(x['cover']):
 box(f'Cargo {i}',a,b,w,d,h,crate)
 box('Cargo stripe',a,b,w+.02,d+.02,.12,trim,h*.7)
for a in [-10,10]:
 for b in [-14,0,14]:box('Lamp post',a,b,.12,.12,4,wall);box('Lamp',a,b,.7,.4,.15,trim,4)
box('Control cabinet',*x['terminal'],.7,.5,1.2,green)
box('Extraction marker',*x['exit'],3,1,.04,green)
bpy.ops.export_scene.gltf(filepath=str(root/'assets/models/yard.glb'),export_format='GLB',export_animations=False)
