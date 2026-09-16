"""Bake a feathered normal repair for the nose material after its color bake."""
def finish_nose_normals(m):
 import bpy
 repair=m.data.materials['YametaroNoseInkRepair'];nodes=repair.node_tree.nodes;links=repair.node_tree.links;shader=nodes.get('Principled BSDF')
 normal=next(n for n in nodes if n.type=='NORMAL_MAP');fall=next(n for n in nodes if n.type=='MAP_RANGE')
 geometry=nodes.new('ShaderNodeNewGeometry');mix=nodes.new('ShaderNodeMixRGB')
 links.new(fall.outputs[0],mix.inputs[0]);links.new(normal.outputs['Normal'],mix.inputs[1]);links.new(geometry.outputs['Normal'],mix.inputs[2]);links.new(mix.outputs[0],shader.inputs['Normal'])
 baked=bpy.data.images.new('YametaroNoseRepairedNormal',width=1024,height=1024);baked.colorspace_settings.name='Non-Color'
 for mat in m.data.materials:
  node=mat.node_tree.nodes.new('ShaderNodeTexImage');node.image=baked;mat.node_tree.nodes.active=node
 bpy.ops.object.select_all(action='DESELECT');m.select_set(True);bpy.context.view_layer.objects.active=m
 bpy.ops.object.bake(type='NORMAL')
 tex=nodes.new('ShaderNodeTexImage');tex.image=baked;normal=nodes.new('ShaderNodeNormalMap');links.new(tex.outputs['Color'],normal.inputs['Color']);links.new(normal.outputs['Normal'],shader.inputs['Normal']);baked.pack()
