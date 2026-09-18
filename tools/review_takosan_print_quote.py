"""Render repaired STL and quantify source surface coverage."""
import bpy,bmesh,json,sys
from pathlib import Path
from mathutils import Matrix,Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
from sobaya_v2_common import studio
OUT=ROOT/'04_GAME_ASSETS/3d/print/takosan_50_70mm_20260918'
reports=[]
for h,d in [(50,45),(70,60)]:
 bpy.ops.wm.open_mainfile(filepath=str(OUT/f'takosan_{h}mm_base{d}_v1_color_reference.blend'))
 body=bpy.data.objects['Print_TakosanBody'];points=[body.matrix_world@v.co for v in body.data.vertices]
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.ops.wm.stl_import(filepath=str(OUT/f'takosan_{h}mm_base{d}_v2.stl'),forward_axis='Y',up_axis='Z')
 obj=bpy.context.object;bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001)
 tree=BVHTree.FromBMesh(bm);distances=[tree.find_nearest(p)[3] for p in points]
 max_distance=max(distances)
 tips=[d for p,d in zip(points,distances) if p.z<h*.3 and (p.x*p.x+p.y*p.y)**.5>h*.32]
 assert tips and max(tips)<.6,(h,max(tips))
 reports.append({'height_mm':h,'max_source_surface_distance_mm':max_distance,'distance_note':'Includes buried faces behind hood; not an outer-surface error metric','max_outer_tentacle_distance_mm':max(tips),'outer_tentacle_samples':len(tips),'vertices_over_1mm':sum(d>1 for d in distances)})
 bm.free()
 obj.matrix_world=Matrix.Scale(1.8/h,4)@obj.matrix_world
 studio();s=bpy.context.scene;s.cycles.samples=12;s.render.resolution_x=720;s.render.resolution_y=720
 target=Vector((0,0,.9));s.camera.location=target+Vector((-.6,-4,.9));s.camera.rotation_euler=(target-s.camera.location).to_track_quat('-Z','Y').to_euler();s.camera.data.ortho_scale=2.4
 s.render.filepath=str(OUT/f'takosan_{h}mm_base{d}_v2_solid.png');bpy.ops.render.render(write_still=True)
(OUT/'review_v2.json').write_text(json.dumps(reports,indent=2)+'\n');print('REVIEW',reports,flush=True)
