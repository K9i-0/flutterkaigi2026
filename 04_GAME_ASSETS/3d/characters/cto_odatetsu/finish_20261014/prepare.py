"""Prepare normalized source and closeup/albedo inspections; run with Blender."""
import bpy, json, math, bmesh
from pathlib import Path
from mathutils import Vector,Matrix
O=Path(__file__).resolve().parent;Q=O/'qa';Q.mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(O/'working_base.blend'))
s=bpy.context.scene;o=next(o for o in s.objects if o.type=='MESH');o.name='CTO_Odatetsu_Body'
for v in o.data.vertices:v.co=Matrix.Rotation(-math.pi/2,3,'Z')@v.co
# Model front is now -Y, Z up, 1.75m assumed display height.
report={'height_note':'1.75 m presentation normalization; not a measured personal height','materials':[]}
for m in o.data.materials:
 b=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
 report['materials'].append({'name':m.name,'inputs':{i.name:(i.links[0].from_node.name if i.is_linked else str(i.default_value)) for i in b.inputs if i.name in ['Base Color','Metallic','Roughness','Normal']}})
bm=bmesh.new();bm.from_mesh(o.data)
report['mesh']={'vertices':len(bm.verts),'faces':len(bm.faces),'boundary_edges':sum(e.is_boundary for e in bm.edges),'nonmanifold_edges':sum(not e.is_manifold for e in bm.edges),'degenerate_faces':sum(f.calc_area()<1e-12 for f in bm.faces)}
bm.free()
(O/'mesh_audit.json').write_text(json.dumps(report,indent=2))
c=s.camera;s.cycles.samples=32
views=[('head',(0,-1,0),(0,0,1.55),.42),('chest',(0,-1,0),(0,0,1.25),.48),('hands',(.25,-1,0),(0,0,.88),.90),('shoes',(0,-1,.35),(0,0,.09),.55),('shoe_left',(1,0,.15),(.22,0,.09),.37),('shoe_right',(-1,0,.15),(-.22,0,.09),.37)]
for name,di,pt,sc in views:
 c.location=Vector(pt)+Vector(di).normalized()*5;c.rotation_euler=(Vector(pt)-c.location).to_track_quat('-Z','Y').to_euler();c.data.ortho_scale=sc;s.render.resolution_x=s.render.resolution_y=960;s.render.filepath=str(Q/('before_'+name+'.png'));bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(O/'normalized_base.blend'))
# Base-color plates for localized Imagegen repair.
for m in o.data.materials:
 b=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED');out=next(n for n in m.node_tree.nodes if n.type=='OUTPUT_MATERIAL');e=m.node_tree.nodes.new('ShaderNodeEmission');m.node_tree.links.new(b.inputs['Base Color'].links[0].from_socket,e.inputs['Color']);m.node_tree.links.new(e.outputs[0],out.inputs['Surface'])
for name,di,pt,sc in [('chest',(0,-1,0),(0,0,1.25),.48),('shoe_left',(1,0,0),(.22,0,.09),.37),('shoe_right',(-1,0,0),(-.22,0,.09),.37)]:
 c.location=Vector(pt)+Vector(di)*5;c.rotation_euler=(Vector(pt)-c.location).to_track_quat('-Z','Y').to_euler();c.data.ortho_scale=sc;s.render.resolution_x=s.render.resolution_y=1024;s.render.filepath=str(Q/('albedo_'+name+'.png'));bpy.ops.render.render(write_still=True)
print('PREPARE_DONE',flush=True)
