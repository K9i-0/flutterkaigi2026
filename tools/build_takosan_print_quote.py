"""Create 50/70 mm Takosan quote prototypes; no manufacturing approval implied."""
import bpy,bmesh,json,hashlib,sys
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from sobaya_v2_common import studio
SOURCE=ROOT/'04_GAME_ASSETS/3d/characters/takosan/rig_radial_v5_clean/takosan.glb'
OUT=ROOT/'04_GAME_ASSETS/3d/print/takosan_50_70mm_20260918'
OUT.mkdir(parents=True,exist_ok=True)
reports=[]
for height,diameter in [(50,45),(70,60)]:
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.ops.import_scene.gltf(filepath=str(SOURCE))
 s=bpy.context.scene;s.frame_set(0);bpy.context.view_layer.update()
 dg=bpy.context.evaluated_depsgraph_get();parts=[]
 for obj in list(s.objects):
  if obj.type!='MESH' or obj.name!='TakosanBody':continue
  mesh=bpy.data.meshes.new_from_object(obj.evaluated_get(dg),depsgraph=dg)
  mesh.transform(obj.matrix_world)
  parts.append(bpy.data.objects.new('Print_'+obj.name,mesh))
 for obj in list(s.objects):bpy.data.objects.remove(obj,do_unlink=True)
 for obj in parts:s.collection.objects.link(obj)
 pts=[v.co for obj in parts for v in obj.data.vertices]
 lo=Vector([min(p[i] for p in pts) for i in range(3)]);hi=Vector([max(p[i] for p in pts) for i in range(3)])
 xf=Matrix.Translation((0,0,2.15))@Matrix.Scale((height-2.15)/(hi.z-lo.z),4)@Matrix.Translation((-(lo.x+hi.x)/2,-(lo.y+hi.y)/2,-lo.z))
 for obj in parts:obj.data.transform(xf)
 bpy.ops.mesh.primitive_cylinder_add(vertices=96,radius=diameter/2,depth=2.5,location=(0,0,1.25))
 base=bpy.context.object;base.name='Base';parts.append(base)
 mat=bpy.data.materials.new('Charcoal base');mat.diffuse_color=(.06,.06,.06,1);base.data.materials.append(mat)
 s.unit_settings.system='METRIC';s.unit_settings.scale_length=.001
 prefix=f'takosan_{height}mm_base{diameter}_v1'
 bpy.ops.wm.save_as_mainfile(filepath=str(OUT/(prefix+'_color_reference.blend')))
 # Weld glTF seams before closing openings and voxel union.
 for obj in parts:
  bm=bmesh.new();bm.from_mesh(obj.data)
  bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.001)
  bmesh.ops.holes_fill(bm,edges=[e for e in bm.edges if e.is_boundary],sides=0)
  bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(obj.data);bm.free()
 bpy.ops.object.select_all(action='SELECT');bpy.context.view_layer.objects.active=base;bpy.ops.object.join()
 obj=bpy.context.object
 mod=obj.modifiers.new('Union','REMESH');mod.mode='VOXEL';mod.voxel_size=.1
 bpy.ops.object.modifier_apply(modifier=mod.name)
 mod=obj.modifiers.new('Upload size','DECIMATE');mod.ratio=.25;bpy.ops.object.modifier_apply(modifier=mod.name)
 bm=bmesh.new();bm.from_mesh(obj.data);unseen=set(bm.verts);comps=[]
 while unseen:
  seed=unseen.pop();stack=[seed];comp=[seed]
  while stack:
   v=stack.pop()
   for e in v.link_edges:
    u=e.other_vert(v)
    if u in unseen:unseen.remove(u);stack.append(u);comp.append(u)
  comps.append(comp)
 comps.sort(key=len,reverse=True)
 print('COMPONENTS',height,[len(c) for c in comps],flush=True)
 assert all(len(c)<100 for c in comps[1:]),'Substantial disconnected part'
 bmesh.ops.delete(bm,geom=[v for c in comps[1:] for v in c],context='VERTS')
 nonmanifold=sum(not e.is_manifold for e in bm.edges);assert nonmanifold==0
 volume=abs(bm.calc_volume(signed=True))/1000
 bm.to_mesh(obj.data);bm.free()
 bpy.ops.wm.stl_export(filepath=str(OUT/(prefix+'.stl')),export_selected_objects=True,forward_axis='Y',up_axis='Z')
 bpy.ops.wm.save_as_mainfile(filepath=str(OUT/(prefix+'_solid.blend')))
 pts=[obj.matrix_world@v.co for v in obj.data.vertices]
 reports.append({'file':prefix+'.stl','target_height_mm':height,'base_diameter_mm':diameter,'base_height_mm':2.5,'dimensions_mm':[max(p[i] for p in pts)-min(p[i] for p in pts) for i in range(3)],'volume_cm3':volume,'nonmanifold_edges':nonmanifold,'components':1,'sha256':hashlib.sha256((OUT/(prefix+'.stl')).read_bytes()).hexdigest()})
 for variant in ['color_reference','solid']:
  bpy.ops.wm.open_mainfile(filepath=str(OUT/(prefix+'_'+variant+'.blend')))
  for o in list(bpy.context.scene.objects):o.matrix_world=Matrix.Scale(1.8/height,4)@o.matrix_world
  studio();s=bpy.context.scene;s.cycles.samples=12;s.render.resolution_x=720;s.render.resolution_y=720
  target=Vector((0,0,.9));s.camera.location=target+Vector((-.6,-4,.9));s.camera.rotation_euler=(target-s.camera.location).to_track_quat('-Z','Y').to_euler();s.camera.data.ortho_scale=2.4
  s.render.filepath=str(OUT/(prefix+'_'+variant+'.png'));bpy.ops.render.render(write_still=True)
(OUT/'report.json').write_text(json.dumps({'source':str(SOURCE.relative_to(ROOT)),'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'status':'quote only; vendor thin-feature/support/color review pending','models':reports},ensure_ascii=False,indent=2)+'\n')
print('QUOTE_REPORT',json.dumps(reports),flush=True)
