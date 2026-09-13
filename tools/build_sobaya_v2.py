"""Build the C-reference, two-part Sobaya v2 from recorded Tripo outputs.

No paid requests. Run Blender -b --factory-startup --python tools/build_sobaya_v2.py.
Hair and mask belong to Head. This is a model study, not a character canon update.
"""
import sys,math,json,hashlib
from pathlib import Path
import bpy,bmesh
import numpy as np
from mathutils import Matrix,Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
from sobaya_v2_common import OUT,ROOT,bounds,import_part,prepare_materials,studio
from build_humanoid_motion import use_action,clear_pose

def smooth(a,b,x):
 t=max(0.,min(1.,(x-a)/(b-a)));return t*t*(3-2*t)

def import_body():
 bpy.ops.import_scene.fbx(filepath=str(OUT/'rig_source/raw/output_model_url.fbx'))
 rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
 body=next(o for o in bpy.context.scene.objects if o.type=='MESH')
 mw=body.matrix_world.copy();rw=rig.matrix_world.copy();rot=Matrix.Rotation(-math.pi/2,4,'Z')
 pts=[rot@mw@v.co for v in body.data.vertices]
 lo=Vector([min(p[i] for p in pts) for i in range(3)]);hi=Vector([max(p[i] for p in pts) for i in range(3)])
 transform=Matrix.Scale(1.60/(hi.z-lo.z),4)@Matrix.Translation((-(lo.x+hi.x)/2,-(lo.y+hi.y)/2,-lo.z))@rot
 body.data.transform(transform@mw);body.parent=None;body.matrix_world=Matrix.Identity(4)
 rig.data.transform(transform@rw);rig.matrix_world=Matrix.Identity(4)
 body.parent=rig;body.matrix_parent_inverse=Matrix.Identity(4)
 rig.name='SobayaV2Rig';body.name='Body'
 for bone in rig.data.bones:
  old=bone.name;new=old.split(':')[-1]
  if body.vertex_groups.get(old):body.vertex_groups[old].name=new
  bone.name=new
 rig.animation_data_clear();rig.animation_data_create()
 for a in list(bpy.data.actions):bpy.data.actions.remove(a)
 bpy.context.view_layer.objects.active=rig;bpy.ops.object.mode_set(mode='EDIT')
 neck=rig.data.edit_bones['Neck'];head=rig.data.edit_bones['Head']
 # Headless Tripo rig places these bones inside the stump. Fit them to the
 # assembled neck and skull before any animation is bound.
 neck.head=(0,.028,1.455);neck.tail=(0,.028,1.595)
 head.head=neck.tail;head.tail=(0,.028,1.765)
 for side in ['Left','Right']:
  arm=rig.data.edit_bones[side+'Arm'];shoulder=rig.data.edit_bones[side+'Shoulder']
  shoulder.tail=arm.head
 bpy.ops.object.mode_set(mode='OBJECT')
 for p in rig.pose.bones:p.rotation_mode='QUATERNION'
 for p in body.data.polygons:p.use_smooth=True
 return body,rig

def fit_neck(body,head):
 # Delete only the gray neck skin of the body; retain the shirt collar.
 im=next(n.image for n in body.data.materials[0].node_tree.nodes if n.type=='TEX_IMAGE' and n.image and Path(n.image.filepath).stem.lower()=='color')
 pixels=np.empty(len(im.pixels),np.float32);im.pixels.foreach_get(pixels);pixels=pixels.reshape((im.size[1],im.size[0],4))
 uv=body.data.uv_layers.active.data;remove=[]
 for p in body.data.polygons:
  co=[body.data.vertices[i].co for i in p.vertices]
  if min(v.z for v in co)<1.455 or max(abs(v.x) for v in co)>.14:continue
  t=sum((uv[i].uv for i in p.loop_indices),Vector((0,0)))/len(p.loop_indices)
  rgb=pixels[int(t.y*im.size[1])%im.size[1],int(t.x*im.size[0])%im.size[0],:3]
  if max(rgb)<.73 or min(v.z for v in co)>1.577:remove.append(p.index)
 bm=bmesh.new();bm.from_mesh(body.data);bm.faces.ensure_lookup_table()
 bmesh.ops.delete(bm,geom=[bm.faces[i] for i in remove],context='FACES')
 # The generated shirt has an open inner edge. Smooth its collar contour,
 # add a turned-in fabric rim, and preserve the existing skin weights.
 rim=[e for e in bm.edges if e.is_boundary and all(v.co.z>1.40 and abs(v.co.x)<.17 for v in e.verts)]
 rimverts={v for e in rim for v in e.verts};deform=bm.verts.layers.deform.verify()
 collar=bpy.data.materials.new('CollarFabric');collar.use_nodes=True
 bs=collar.node_tree.nodes['Principled BSDF'];bs.inputs['Base Color'].default_value=(.78,.78,.78,1);bs.inputs['Roughness'].default_value=.85
 matidx=len(body.data.materials);body.data.materials.append(collar)
 inside={}
 for v in rimverts:
  angle=math.atan2((v.co.y-.027)/.095,v.co.x/.11)
  target=Vector((.11*math.cos(angle),.027+.095*math.sin(angle),1.495+.058*math.sin(angle)))
  v.co=v.co.lerp(target,.80)
  point=v.co.copy();point.x*=.87;point.y=.027+(point.y-.027)*.87;point.z+=.005
  n=bm.verts.new(point)
  for g,w in v[deform].items():n[deform][g]=w
  inside[v]=n
 for e in rim:
  f=bm.faces.new((e.verts[0],e.verts[1],inside[e.verts[1]],inside[e.verts[0]]));f.material_index=matidx
 bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
 bm.to_mesh(body.data);bm.free()
 # Taper the lower neck within the shirt, leaving mask and ears untouched.
 changed=0
 for v in head.data.vertices:
  if v.co.z>=1.61:continue
  if v.co.y<-.06 and v.co.z>1.485:continue
  t=1-smooth(1.515,1.61,v.co.z)
  d=Vector((v.co.x,v.co.y-.022,0))
  if d.length<1e-8:continue
  u=d.normalized();radius=1/math.sqrt((u.x/.080)**2+(u.y/.072)**2)
  if d.length<=radius:continue
  q=Vector((0,.022,v.co.z))+u*radius
  v.co=v.co.lerp(q,t)
  changed+=1
 # Close the concealed neck volume under the mask and collar. This stays in
 # Head and receives the same chest/neck/head transition as its outer neck.
 verts=[];faces=[];steps=64
 for j in range(9):
  t=j/8;z=1.40+.20*t;rx=.098-.024*t;ry=.090-.018*t
  for i in range(steps):
   a=i*math.tau/steps;verts.append((rx*math.cos(a),.025+ry*math.sin(a),z))
 for j in range(8):
  for i in range(steps):
   a=j*steps+i;b=j*steps+(i+1)%steps;faces.append((a,b,b+steps,a+steps))
 faces.append(tuple(range(steps-1,-1,-1)));faces.append(tuple(8*steps+i for i in range(steps)))
 mesh=bpy.data.meshes.new('NeckInterior');mesh.from_pydata(verts,[],faces);mesh.update()
 inner=bpy.data.objects.new('NeckInterior',mesh);bpy.context.collection.objects.link(inner)
 mat=bpy.data.materials.new('NeckInteriorSkin');mat.use_nodes=True
 bs=mat.node_tree.nodes['Principled BSDF'];bs.inputs['Base Color'].default_value=(.23,.235,.235,1);bs.inputs['Roughness'].default_value=.72
 inner.data.materials.append(mat)
 bpy.ops.object.select_all(action='DESELECT');head.select_set(True);inner.select_set(True);bpy.context.view_layer.objects.active=head;bpy.ops.object.join()
 for p in head.data.polygons:p.use_smooth=True
 return {'removedBodyStumpFaces':len(remove),'taperedNeckVertices':changed,'collarRimEdges':len(rim),'neckInteriorFaces':len(faces),'masterHeightM':1.8}

def skin_head(rig,head):
 head.vertex_groups.clear()
 for name in ['Head','Neck','Spine2']:head.vertex_groups.new(name=name)
 black_vertices={i for p in head.data.polygons if head.data.materials[p.material_index].name=='MaskBlackBacking' for i in p.vertices}
 for v in head.data.vertices:
  # Mask, hair, ears and skull stay rigid. Only the neck can bend.
  rigid=v.index in black_vertices or v.co.z>1.585 or (v.co.y<-.065 and v.co.z>1.49)
  h=1. if rigid else smooth(1.535,1.59,v.co.z)
  neck=(1-h)*smooth(1.455,1.53,v.co.z);chest=1-h-neck
  for name,w in [('Head',h),('Neck',neck),('Spine2',chest)]:
   if w>1e-7:head.vertex_groups[name].add([v.index],w,'REPLACE')
 head.parent=rig;head.matrix_parent_inverse=Matrix.Identity(4)
 mod=head.modifiers.new('Skin','ARMATURE');mod.object=rig

def materials():
 report=prepare_materials()
 for im in bpy.data.images:
  if im.size[0]>2048 and Path(im.filepath).stem.lower() in ['roughness','metallic','normal']:
   im.scale(2048,2048);im.pack()
 return report

def normalize_weights(mesh,rig):
 changed=0
 for v in mesh.data.vertices:
  groups=[(g.group,g.weight) for g in v.groups if mesh.vertex_groups[g.group].name in rig.data.bones and g.weight>1e-7]
  groups=sorted(groups,key=lambda x:-x[1])[:4];total=sum(w for _,w in groups)
  if not groups:raise ValueError('Unbound vertex '+str(v.index))
  if len(v.groups)>4 or abs(total-1)>1e-6:changed+=1
  for g in list(v.groups):mesh.vertex_groups[g.group].remove([v.index])
  for idx,w in groups:mesh.vertex_groups[idx].add([v.index],w/total,'REPLACE')
 return changed

def main():
 bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.scene.name='Sobaya_v2_Review_20260913'
 body,rig=import_body();head=import_part('head',.365,1.435)
 report={'neck':fit_neck(body,head)}
 from sobaya_v2_mask import add_black_backing
 report['maskBacking']=add_black_backing(head)
 skin_head(rig,head)
 report['materials']=materials()
 from humanoid_deformation import smooth_shoulders
 report['smoothedShoulderVertices']=smooth_shoulders(body,rig)
 report['normalizedVertices']={o.name:normalize_weights(o,rig) for o in [body,head]}
 from sobaya_v2_motion import retarget
 bpy.context.scene.render.fps=30
 report['animations']=retarget(rig,[body,head])
 use_action(rig,None);clear_pose(rig)
 rig['character']='Sobaya';rig['version']='v2_20260913';rig['reference']='reference/master_front.png'
 rig['scope']='C-reference Tripo model study only; not canonical design for other works'
 rig['workflow']='https://www.tripo3d.ai/blog/gpt-6-astra-3d-character-workflow'
 head['includes']='head, hair, mask, neck';head['mask']='rigid; no facial morphs'
 report['heightM']=max(bounds(o)[1][2] for o in [body,head])
 report['meshStats']={o.name:{'vertices':len(o.data.vertices),'triangles':sum(len(p.vertices)-2 for p in o.data.polygons)} for o in [body,head]}
 report['bones']=list(rig.data.bones.keys())
 studio();bpy.context.scene.frame_start=0;bpy.context.scene.frame_end=90
 bpy.ops.object.select_all(action='DESELECT')
 for o in [rig,body,head]:o.select_set(True)
 bpy.context.view_layer.objects.active=rig
 bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'sobaya_v2.blend'))
 target=OUT/'sobaya_v2.glb'
 bpy.ops.export_scene.gltf(filepath=str(target),export_format='GLB',use_selection=True,export_animations=True,
  export_animation_mode='ACTIONS',export_frame_range=False,export_anim_slide_to_zero=True,export_anim_single_armature=True,
  export_skins=True,export_all_influences=False,export_def_bones=False,export_force_sampling=True,export_extras=True)
 report['glb']={'bytes':target.stat().st_size,'sha256':hashlib.sha256(target.read_bytes()).hexdigest()}
 (OUT/'assembly_report.json').write_text(json.dumps(report,indent=2)+'\n')
 print('SOBAYA_V2_BUILD_DONE',report['glb'],flush=True)

if __name__=='__main__':main()
