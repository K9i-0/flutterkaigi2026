"""Close both eye-support holes without changing the approved eye geometry."""
import bpy,bmesh,json,hashlib
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
SRC=OUT.parent/'cleanup_20260919'
bpy.ops.wm.open_mainfile(filepath=str(SRC/'yumemin_clean.blend'))
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
body=max(meshes,key=lambda o:len(o.data.vertices))
eye_before={o.name:[list(v.co) for v in o.data.vertices] for o in meshes if o!=body}
bm=bmesh.new();bm.from_mesh(body.data)
bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-5)
edges=[e for e in bm.edges if e.is_boundary]
assert len(edges)==78,len(edges)
assert all(v.co.y<-.3 and .38<v.co.z<.65 for e in edges for v in e.verts)
# UV-free blue material matches the body's baked blue exactly.
blue=next(i for i,m in enumerate(body.data.materials) if 'Tail_Blue' in m.name)
result=bmesh.ops.holes_fill(bm,edges=edges,sides=0)
faces=result['faces'];assert len(faces)==2,len(faces)
for f in faces:f.material_index=blue;f.smooth=True
new=bmesh.ops.triangulate(bm,faces=faces)['faces']
for f in new:f.material_index=blue;f.smooth=True
bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
assert not any(e.is_boundary for e in bm.edges)
bm.to_mesh(body.data);bm.free();body.data.update()
assert eye_before=={o.name:[list(v.co) for v in o.data.vertices] for o in meshes if o!=body}
bpy.ops.object.select_all(action='DESELECT')
for o in meshes:o.select_set(True)
bpy.context.view_layer.objects.active=body
bpy.ops.export_scene.gltf(filepath=str(OUT/'yumemin_clean_v2.glb'),export_format='GLB',use_selection=True,export_animations=False)
# Audit the exported file, not just Blender's original meshes.
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(OUT/'yumemin_clean_v2.glb'))
report={'body_boundary_edges_before':78,'holes_filled':2,'eye_mesh_coordinates_unchanged':True,'exported_boundaries':{}}
for o in bpy.context.scene.objects:
 if o.type!='MESH':continue
 bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-5)
 count=sum(e.is_boundary for e in bm.edges);report['exported_boundaries'][o.name]=count
 assert count==0,(o.name,count)
 bm.free()
# Reuse the original studio and add white background / mirrored close-ups for seam visibility.
sc=bpy.context.scene;sc.render.engine='CYCLES';sc.cycles.samples=32;sc.cycles.use_denoising=True
sc.view_settings.view_transform='AgX';sc.render.film_transparent=False
world=bpy.data.worlds.new('WhiteReview');world.use_nodes=True
bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs[0].default_value=(1,1,1,1);bg.inputs[1].default_value=.8;sc.world=world
cam=bpy.data.objects.new('ReviewCamera',bpy.data.cameras.new('ReviewCamera'));sc.collection.objects.link(cam);cam.data.type='ORTHO';sc.camera=cam
for name,pos,power,size in [('Key',(-3,-4,5),550,5),('Fill',(4,-1,3),350,4),('Rim',(1,3,4),500,3)]:
 lamp=bpy.data.lights.new(name,'AREA');lamp.energy=power;lamp.size=size
 o=bpy.data.objects.new(name,lamp);sc.collection.objects.link(o);o.location=pos;o.rotation_euler=(Vector((0,0,.5))-o.location).to_track_quat('-Z','Y').to_euler()
qa=OUT/'qa';qa.mkdir(exist_ok=True)
for name,direction,target,scale in [('front',(0,-1,0),(0,0,.5),1.3),('oblique_left',(.8,-1,.1),(0,0,.5),1.3),('oblique_right',(-.8,-1,.1),(0,0,.5),1.3),('eye_left_close',(.8,-1,.2),(.23,-.45,.514),.32),('eye_right_close',(-.8,-1,.2),(-.23,-.45,.514),.32),('low_angle',(0,-1,-.55),(0,0,.5),1.3)]:
 point=Vector(target);cam.location=point+Vector(direction).normalized()*5;cam.rotation_euler=(point-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=scale
 sc.render.resolution_x=800;sc.render.resolution_y=800;sc.render.resolution_percentage=100;sc.render.image_settings.file_format='PNG';sc.render.filepath=str(qa/(name+'.png'));bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'yumemin_clean_v2.blend'))
report['sha256']=hashlib.sha256((OUT/'yumemin_clean_v2.glb').read_bytes()).hexdigest();report['glb_bytes']=(OUT/'yumemin_clean_v2.glb').stat().st_size
(OUT/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print('EYE_SEAMS_FIXED',json.dumps(report),flush=True)
