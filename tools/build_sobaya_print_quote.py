"""Freeze the adopted standing sculpt for 150 mm desktop figure quotations.

Quote prototype only: vendor wall-thickness/support review remains required.
Run with Blender in background mode. Never modifies the game source.
"""
import bpy, bmesh, json, sys, zipfile, hashlib, shutil
from pathlib import Path
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / '04_GAME_ASSETS/3d/print/sobaya_150mm_20260918'
OUT.mkdir(parents=True, exist_ok=True)
SOURCE = ROOT / '04_GAME_ASSETS/3d/characters/sobaya/standing_v3_20260917/sobaya_standing.blend'
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
s = bpy.context.scene
s.frame_set(0)
bpy.context.view_layer.update()
dg = bpy.context.evaluated_depsgraph_get()
exclude = {'Icosphere', 'Carbonation', 'BeerVolume', 'LiquidSurface'}
frozen = []
for obj in list(s.objects):
    if obj.type != 'MESH' or obj.name in exclude:
        continue
    mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(dg), depsgraph=dg)
    mesh.transform(obj.matrix_world)
    new = bpy.data.objects.new('Print_' + obj.name, mesh)
    frozen.append(new)
for obj in list(s.objects):
    bpy.data.objects.remove(obj, do_unlink=True)
for obj in frozen:
    s.collection.objects.link(obj)
points = [v.co for obj in frozen for v in obj.data.vertices]
lo = Vector([min(p[i] for p in points) for i in range(3)])
hi = Vector([max(p[i] for p in points) for i in range(3)])
# Embed feet 0.35 mm into the 5 mm base; overall top remains exactly 150 mm.
scale = 145.35 / (hi.z - lo.z)
xf = Matrix.Translation((0, 0, 4.65)) @ Matrix.Scale(scale, 4) @ Matrix.Translation((-(lo.x+hi.x)/2, -(lo.y+hi.y)/2, -lo.z))
for obj in frozen:
    obj.data.transform(xf)
bpy.ops.mesh.primitive_cylinder_add(vertices=128, radius=42.5, depth=5, location=(0,0,2.5))
base = bpy.context.object
base.name = 'Print_Base_85mm'
mat = bpy.data.materials.new('Base dark charcoal')
mat.diffuse_color = (.075,.075,.075,1)
mat.use_nodes = True
mat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value = (.075,.075,.075,1)
base.data.materials.append(mat)
frozen.append(base)
s.unit_settings.system='METRIC'
s.unit_settings.scale_length=.001
for im in bpy.data.images:
    if im.source == 'FILE' and im.size[0]:
        im.filepath_raw=str(OUT/(im.name.replace('/','_')+'.png'))
        im.file_format='PNG'
        im.save()
bpy.ops.object.select_all(action='SELECT')
bpy.context.view_layer.objects.active=base
bpy.ops.wm.obj_export(filepath=str(OUT/'sobaya_150mm_color_quote.obj'), export_selected_objects=True, forward_axis='Y', up_axis='Z', path_mode='COPY', export_triangulated_mesh=True)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'sobaya_150mm_color_quote.blend'))
# Voxel union removes overlapping internal shells for a solid, single-material quote.
for obj in frozen:
    bm=bmesh.new();bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.001)
    bmesh.ops.holes_fill(bm, edges=[e for e in bm.edges if e.is_boundary], sides=0)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(obj.data);bm.free()
bpy.ops.object.join()
solid=bpy.context.object
solid.name='Sobaya_150mm_Solid_Quote'
remesh=solid.modifiers.new('Watertight union 0.15mm','REMESH')
remesh.mode='VOXEL'
remesh.voxel_size=.15
remesh.use_smooth_shade=False
bpy.ops.object.modifier_apply(modifier=remesh.name)
decimate=solid.modifiers.new('Quote upload size','DECIMATE')
decimate.ratio=.25
bpy.ops.object.modifier_apply(modifier=decimate.name)
bm=bmesh.new();bm.from_mesh(solid.data)
unseen=set(bm.verts);components=[]
while unseen:
    seed=unseen.pop();stack=[seed];component=[seed]
    while stack:
        v=stack.pop()
        for edge in v.link_edges:
            other=edge.other_vert(v)
            if other in unseen:
                unseen.remove(other);stack.append(other);component.append(other)
    components.append(component)
components.sort(key=len,reverse=True)
assert all(len(c)<100 for c in components[1:]), 'A substantial part is detached'
bmesh.ops.delete(bm,geom=[v for c in components[1:] for v in c],context='VERTS')
nonmanifold=sum(not e.is_manifold for e in bm.edges)
volume=abs(bm.calc_volume(signed=True))
bm.to_mesh(solid.data);bm.free()
bpy.ops.wm.stl_export(filepath=str(OUT/'sobaya_150mm_solid_quote.stl'),export_selected_objects=True,forward_axis='Y',up_axis='Z')
shutil.copyfile(OUT/'sobaya_150mm_solid_quote.stl',OUT/'sobaya_150mm_base85_v1.stl')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'sobaya_150mm_solid_quote.blend'))
points=[solid.matrix_world@v.co for v in solid.data.vertices]
dims=[max(p[i] for p in points)-min(p[i] for p in points) for i in range(3)]
report={'status':'quote prototype; not approved for manufacture','source':str(SOURCE.relative_to(ROOT)), 'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'dimensions_mm':dims,'base_diameter_mm':85,'base_height_mm':5,'solid_volume_cm3':volume/1000,'nonmanifold_edges':nonmanifold,'vertices':len(solid.data.vertices),'voxel_mm':.15,'excluded_internal_mug_parts':list(exclude),'remaining_checks':['vendor minimum wall thickness and fingers/mug handle review','connected components and physical contact review','full-color texture/material compatibility','support removal and surface finish','no hollowing applied']}
report['connected_components_after_cleanup']=1
report['removed_small_components']=len(components)-1
report['remaining_checks'].remove('connected components and physical contact review')
(OUT/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
with zipfile.ZipFile(OUT/'sobaya_150mm_color_quote.zip','w',zipfile.ZIP_DEFLATED) as z:
    for path in OUT.iterdir():
        if path.name in {'sobaya_150mm_color_quote.obj','sobaya_150mm_color_quote.mtl','sobaya_red_eye_edge.png','sobaya_body_color.png'}:
            z.write(path,path.name)
print('PRINT_QUOTE_REPORT',json.dumps(report),flush=True)
