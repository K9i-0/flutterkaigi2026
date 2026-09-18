"""Freeze base-free character bodies and add an eyelet for geometry-only quotes."""
import bpy,bmesh,sys
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'04_GAME_ASSETS/3d/print/keychains_20260918'; OUT.mkdir(parents=True,exist_ok=True)
for name,height,source in [('takosan',30,'takosan_50_70mm_20260918/takosan_50mm_base45_v1_color_reference.blend'),('sobaya',40,'sobaya_150mm_20260918/sobaya_150mm_color_quote.blend')]:
 bpy.ops.wm.open_mainfile(filepath=str(ROOT/'04_GAME_ASSETS/3d/print'/source))
 for o in list(bpy.context.scene.objects):
  if o.type!='MESH' or 'base' in o.name.lower(): bpy.data.objects.remove(o,do_unlink=True)
 objs=list(bpy.context.scene.objects)
 pts=[o.matrix_world@v.co for o in objs for v in o.data.vertices]
 lo=Vector([min(p[i] for p in pts) for i in range(3)]); hi=Vector([max(p[i] for p in pts) for i in range(3)])
 xf=Matrix.Scale(height/(hi.z-lo.z),4)@Matrix.Translation((-(lo.x+hi.x)/2,-(lo.y+hi.y)/2,-lo.z))
 for o in objs:
  o.data.transform(xf@o.matrix_world);o.matrix_world=Matrix.Identity(4)
 # Vertical eyelet, 3mm clear hole, 2mm radial wall; lower 2mm embedded in head.
 bpy.ops.mesh.primitive_torus_add(major_radius=2.5,minor_radius=1,major_segments=64,minor_segments=16,location=(0,0,height+1.5),rotation=(1.57079632679,0,0))
 bpy.context.object.name='Keychain_eyelet_3mm_hole'
 for o in bpy.context.scene.objects:
  bm=bmesh.new();bm.from_mesh(o.data)
  bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.001)
  bmesh.ops.holes_fill(bm,edges=[e for e in bm.edges if e.is_boundary],sides=0)
  bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
 bpy.ops.object.select_all(action='SELECT')
 bpy.ops.wm.stl_export(filepath=str(OUT/f'{name}_{height}mm_surface.stl'),export_selected_objects=True,forward_axis='Y',up_axis='Z')
 bpy.ops.wm.save_as_mainfile(filepath=str(OUT/f'{name}_{height}mm_reference.blend'))
