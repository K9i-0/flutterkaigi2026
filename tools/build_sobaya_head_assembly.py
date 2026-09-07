"""Fit the Tripo head to Sobaya's muscular body and replace the lower neck surface.

Blender --background --factory-startup --python tools/build_sobaya_head_assembly.py
The mesh-only export is merged with the original animation payload separately.
"""
import bpy, bmesh, math, json, argparse, sys
import numpy as np
from pathlib import Path
from mathutils import Matrix, Vector

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'04_GAME_ASSETS/3d/characters/sobaya/head_sheet_p2_20260907'
parser=argparse.ArgumentParser()
parser.add_argument('--source',type=Path,default=ROOT/'04_GAME_ASSETS/3d/characters/sobaya/rig_v3/sobaya_rig.glb')
parser.add_argument('--skip-preview',action='store_true')
parser.add_argument('--work',type=Path,default=ROOT/'.local/sobaya-fitted')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
WORK=args.work;WORK.mkdir(parents=True,exist_ok=True)
SOURCE=args.source
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
body=bpy.data.objects['SobayaBody'];rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
rig.animation_data_clear()
for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
for o in list(bpy.context.scene.objects):
 if o.type=='MESH' and o!=body:bpy.data.objects.remove(o,do_unlink=True)
bpy.context.view_layer.update()
assert all(abs(body.matrix_world[i][j]-(i==j))<1e-5 for i in range(4) for j in range(4))

# Preserve the shirt and trapezius silhouette; the new neck continues inside
# the collar, as in the existing separate-head Fukuchan pipeline.
uv=body.data.uv_layers.active.data
im=next(n.image for n in body.data.materials[0].node_tree.nodes if n.type=='TEX_IMAGE' and n.image and any(l.to_socket.name=='Base Color' for l in n.outputs['Color'].links))
w,h=im.size
body_pixels=np.empty(w*h*4,dtype=np.float32);im.pixels.foreach_get(body_pixels)
remove=[]
for p in body.data.polygons:
 c=p.center
 if c.z>1.60 or p.material_index in (2,3):remove.append(p.index);continue
 if c.z>1.510 and c.y<-.090 and abs(c.x)<.14:remove.append(p.index);continue
 if c.z<1.425 or abs(c.x)>.21:continue
 co=sum((uv[i].uv for i in p.loop_indices),Vector((0,0)))/len(p.loop_indices)
 x=min(w-1,max(0,int(co.x*w)));y=min(h-1,max(0,int(co.y*h)))
 rgb=body_pixels[(y*w+x)*4:(y*w+x)*4+3]
 if max(rgb)<.72 and max(rgb)-min(rgb)<.14:remove.append(p.index)
del body_pixels
bm=bmesh.new();bm.from_mesh(body.data);bm.faces.ensure_lookup_table()
bmesh.ops.delete(bm,geom=[bm.faces[i] for i in remove],context='FACES')
bm.to_mesh(body.data);bm.free()
before=set(bpy.context.scene.objects)
bpy.ops.import_scene.gltf(filepath=str(OUT/'head.glb'))
head=next(o for o in set(bpy.context.scene.objects)-before if o.type=='MESH')
head.data.transform(Matrix.Diagonal((1.15,1.05,1.02,1)) @ head.matrix_world)
head.parent=None;head.matrix_world=Matrix.Identity(4)
head.data.transform(Matrix.Translation((0,-.020,1.4634)))
head.name='SobayaNewHead'
# Retopologize only the neck: Tripo's diagonal end cap is unsuitable for
# widening. Keep the mask, hair and ears, and replace the gray lower neck.
head_im=next(n.image for n in head.data.materials[0].node_tree.nodes if n.type=='TEX_IMAGE' and n.image and any(l.to_socket.name=='Base Color' for l in n.outputs['Color'].links))
w,h=head_im.size
head_pixels=np.empty(w*h*4,dtype=np.float32);head_im.pixels.foreach_get(head_pixels)
bm=bmesh.new();bm.from_mesh(head.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
uvl=bm.loops.layers.uv.active;deleted=[]
neck_mat=bpy.data.materials.new('SobayaNeckSkin');neck_mat.use_nodes=True;neck_mat.diffuse_color=(.26,.26,.26,1)
bs=neck_mat.node_tree.nodes['Principled BSDF'];bs.inputs['Base Color'].default_value=neck_mat.diffuse_color;bs.inputs['Roughness'].default_value=.88
skin_index=len(head.data.materials);head.data.materials.append(neck_mat)
for f in bm.faces:
 c=f.calc_center_median()
 if c.z>1.67:continue
 co=sum((l[uvl].uv for l in f.loops),Vector((0,0)))/len(f.loops)
 x=min(w-1,max(0,int(co.x*w)));y=min(h-1,max(0,int(co.y*h)))
 rgb=head_pixels[(y*w+x)*4:(y*w+x)*4+3]
 gray=max(rgb)<.68 and max(rgb)-min(rgb)<.12 and min(rgb)>.10
 if c.z<1.515 or (c.z<1.610 and c.y>-.090 and gray and not(abs(c.x)>.095 and c.z>1.60)):
  deleted.append(f)
 elif gray and c.y>-.09:f.material_index=skin_index
del head_pixels
bmesh.ops.delete(bm,geom=deleted,context='FACES');bm.to_mesh(head.data);bm.free()
for p in head.data.polygons:p.use_smooth=True
head.data.normals_split_custom_set([(0,0,0)]*len(head.data.loops));head.data.update()
# A smooth neck surface follows the original trapezius at the collar and
# narrows continuously into the new head, with its lower end inside the shirt.
verts=[];faces=[];rings=24;segments=64
for j in range(rings):
 z=1.405+(1.660-1.405)*j/(rings-1)
 t=max(0,min(1,(z-1.535)/.110));t=t*t*(3-2*t)
 for i in range(segments):
  a=2*math.pi*i/segments;direction=Vector((math.cos(a),math.sin(a),0));origin=Vector((0,.025,z))
  lower=1/math.sqrt((direction.x/.115)**2+(direction.y/.078)**2)
  upper=1/math.sqrt((direction.x/.107)**2+(direction.y/.089)**2)
  r=lower*(1-t)+upper*t
  if z>1.635:r*=1-.10*(z-1.635)/.025
  verts.append(tuple(origin+direction*r))
for j in range(rings-1):
 for i in range(segments):
  a=j*segments+i;b=j*segments+(i+1)%segments
  faces.append((a,b,b+segments,a+segments))
mesh=bpy.data.meshes.new('SobayaFittedNeck');mesh.from_pydata(verts,[],faces);mesh.materials.append(neck_mat)
neck_obj=bpy.data.objects.new('SobayaFittedNeck',mesh);bpy.context.collection.objects.link(neck_obj)
for p in mesh.polygons:p.use_smooth=True
bpy.ops.object.select_all(action='DESELECT');head.select_set(True);neck_obj.select_set(True);bpy.context.view_layer.objects.active=head;bpy.ops.object.join()
fitted=len(verts)
head.vertex_groups.clear();ng=head.vertex_groups.new(name='Neck');hg=head.vertex_groups.new(name='Head')
for v in head.data.vertices:
 t=max(0,min(1,(v.co.z-1.500)/.110));t=t*t*(3-2*t)
 if v.co.y<-.090 and v.co.z>1.515:t=1
 ng.add([v.index],1-t,'REPLACE');hg.add([v.index],t,'REPLACE')
head.parent=rig;head.matrix_parent_inverse=Matrix.Identity(4)
mod=head.modifiers.new('HeadSkin','ARMATURE');mod.object=rig
bpy.ops.object.select_all(action='DESELECT');body.select_set(True);head.select_set(True);bpy.context.view_layer.objects.active=body
bpy.ops.object.join()
body.data.calc_loop_triangles()
report={'head_width_scale':1.15,'head_depth_scale':1.05,'head_height_scale':1.02,'neck_connection':'smooth replacement neck ending inside the original shirt collar','fitted_neck_vertices':fitted,'removed_old_head_faces':len(remove),'triangles':len(body.data.loop_triangles)}
(WORK/'fit.json').write_text(json.dumps(report,indent=2)+'\n')
bpy.ops.object.select_all(action='DESELECT');body.select_set(True);rig.select_set(True);bpy.context.view_layer.objects.active=body
bpy.ops.export_scene.gltf(filepath=str(WORK/'mesh.glb'),export_format='GLB',use_selection=True,export_animations=False,export_skins=True,export_def_bones=False,export_image_format='AUTO')
if args.skip_preview:
 print("FIT",json.dumps(report),flush=True)
 sys.exit(0)
# Fast body-connected previews first.
scene=bpy.context.scene;scene.render.engine='BLENDER_WORKBENCH';scene.render.resolution_x=700;scene.render.resolution_y=800;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Preview');scene.world.color=(.16,.18,.19)
sh=scene.display.shading;sh.color_type='TEXTURE';sh.show_cavity=False;sh.show_object_outline=False;sh.background_type='WORLD'
for mat in bpy.data.materials:
 if mat.use_nodes:
  for n in mat.node_tree.nodes:
   if n.type=='TEX_IMAGE' and n.image and any(l.to_socket.name=='Base Color' for l in n.outputs['Color'].links):mat.node_tree.nodes.active=n
bpy.ops.object.camera_add();camera=bpy.context.object;scene.camera=camera;camera.data.type='ORTHO'
for name,pos,target,scale in [('front',(0,-5,1),(0,0,.92),2.05),('side',(5,0,1),(0,0,.92),2.05),('three-quarter',(3,-5,1.5),(0,0,1),2.05),('neck-front',(0,-4,1.55),(0,0,1.55),.72),('neck-side',(4,0,1.55),(0,0,1.55),.72),('neck-back',(0,4,1.55),(0,0,1.55),.72)]:
 camera.location=pos;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.ortho_scale=scale
 scene.render.filepath=str(WORK/(name+'.png'));bpy.ops.render.render(write_still=True)
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':
   s=area.spaces.active;s.shading.type='SOLID';s.shading.color_type='TEXTURE';s.overlay.show_overlays=False
   s.region_3d.view_location=(0,0,1);s.region_3d.view_distance=3;s.region_3d.view_rotation=(Vector((0,0,1))-Vector((3,-5,1.5))).to_track_quat('-Z','Y')
bpy.ops.wm.save_as_mainfile(filepath=str(WORK/'connected.blend'))
print('FIT',json.dumps(report),flush=True)
