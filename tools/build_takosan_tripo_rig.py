"""Rig the sheet-derived P2 Takosan; correct eight generated tentacles to six.

Blender --background --factory-startup --python tools/build_takosan_tripo_rig.py
Keeps P2 textures/geometry; removes surplus rear limbs and authors skin weights.
"""
import bpy,bmesh,math,json,hashlib,sys
from pathlib import Path
from mathutils import Vector,Matrix,Quaternion
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'04_GAME_ASSETS/3d/characters/takosan/rig_sheet_v2';OUT.mkdir(parents=True,exist_ok=True)
src=OUT.parent/'tripo_sheet_p2_20260906/raw/output_model_url.fbx'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False);bpy.ops.import_scene.fbx(filepath=str(src))
body=next(o for o in bpy.context.scene.objects if o.type=='MESH');body.name='TakosanBody'
body.data.transform(Matrix.Scale(1.433/.99951171875,4)@Matrix.Rotation(-math.pi/2,4,'Z')@body.matrix_world);body.matrix_world=Matrix.Identity(4)
body.data.transform(Matrix.Translation((0,0,-min(v.co.z for v in body.data.vertices))))
# P2 produced eight tentacles. Keep the five-leg front silhouette and one
# rear limb; remove the two separate rear-diagonal duplicates without cutting
# the robe or its embroidery.
# Connected components using integer adjacency preserve original vertex identity.
adj=[[] for _ in body.data.vertices]
for e in body.data.edges:
 a,b=e.vertices;adj[a].append(b);adj[b].append(a)
remaining=set(range(len(adj)));groups=[]
while remaining:
 seed=remaining.pop();stack=[seed];g=[seed]
 while stack:
  current=stack.pop()
  for i in adj[current]:
   if i in remaining:remaining.remove(i);stack.append(i);g.append(i)
 groups.append(g)
main=max(groups,key=len)
tentacles=[g for g in groups if len(g)>100 and max(body.data.vertices[i].co.z for i in g)<.28]
assert len(tentacles)==6, len(tentacles)
# Tag anatomical parts before changing topology; Blender preserves point attrs.
part_attr=body.data.attributes.new('RigRegion','INT','POINT')
for i in main:part_attr.data[i].value=1
arms=[]
for g in groups:
 zs=[body.data.vertices[i].co.z for i in g]
 if len(g)>100 and min(zs)>.30 and max(zs)<.81:
  x=sum(body.data.vertices[i].co.x for i in g)/len(g);label=2 if x<0 else 3
  for i in g:part_attr.data[i].value=label
  arms.append(label)
assert sorted(arms)==[2,3]
kept=[];removed=[]
for g in tentacles:
 c=sum((body.data.vertices[i].co for i in g),Vector())/len(g)
 (removed if c.y>.1 and abs(c.x)>.1 else kept).append(g)
assert len(kept)==4 and len(removed)==2
kept.sort(key=lambda g:math.atan2(sum(body.data.vertices[i].co.y for i in g),sum(body.data.vertices[i].co.x for i in g)))
angles=[]
for j,g in enumerate(kept):
 c=sum((body.data.vertices[i].co for i in g),Vector())/len(g);angles.append(math.degrees(math.atan2(c.y,c.x)))
 for i in g:part_attr.data[i].value=10+j
angles.extend([0,180])
for i in main:
 v=body.data.vertices[i]
 if v.co.z<.31 and abs(v.co.x)>.19 and abs(v.co.y)<.16:part_attr.data[i].value=14 if v.co.x>0 else 15
for g in removed:
 for i in g:part_attr.data[i].value=99
bm=bmesh.new();bm.from_mesh(body.data);region=bm.verts.layers.int['RigRegion']
bmesh.ops.delete(bm,geom=[v for v in bm.verts if v[region]==99],context='VERTS')
bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(body.data);bm.free()
# Hidden shoulder underlap prevents the separate sleeve socket showing daylight.
lining=bpy.data.materials.new('Shoulder cloth lining');lining.use_nodes=True
lining.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.022,.025,.028,1)
lining.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.85
for side in [-1,1]:
 bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=12,radius=1,location=(side*.24,-.005,.69));pad=bpy.context.object;pad.scale=(.075,.065,.065);pad.data.materials.append(lining)
 bpy.ops.object.transform_apply(location=True,rotation=True,scale=True);attr=pad.data.attributes.new('RigRegion','INT','POINT')
 for d in attr.data:d.value=4
 bpy.ops.object.select_all(action='DESELECT');body.select_set(True);pad.select_set(True);bpy.context.view_layer.objects.active=body;bpy.ops.object.join()
for p in body.data.polygons:p.use_smooth=True
color_images={m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].links[0].from_node.image
 for m in body.data.materials if m.use_nodes and m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].is_linked}
for im in bpy.data.images:
 if im.name.startswith('tripo_image_'):
  size=2048 if im in color_images else 1024;im.scale(size,size);im.pack()
bpy.ops.object.select_all(action='DESELECT');bpy.ops.object.armature_add();rig=bpy.context.object;rig.name='TakosanRig';bpy.ops.object.mode_set(mode='EDIT');rig.data.edit_bones.remove(rig.data.edit_bones[0])
def bone(name,a,b,parent=None):
 e=rig.data.edit_bones.new(name);e.head=a;e.tail=b
 if parent:e.parent=rig.data.edit_bones[parent]
bone('Root',(0,0,0),(0,0,.3));bone('Spine',(0,0,.3),(0,0,.78),'Root');bone('Head',(0,0,.78),(0,0,1.18),'Spine')
for side,suffix in [(-1,'L'),(1,'R')]:
 bone('UpperArm.'+suffix,(side*.22,-.025,.75),(side*.315,-.055,.54),'Spine')
 bone('Forearm.'+suffix,(side*.315,-.055,.54),(side*.375,-.06,.395),'UpperArm.'+suffix)
 bone('Hand.'+suffix,(side*.375,-.06,.395),(side*.38,-.065,.34),'Forearm.'+suffix)
for j,angle in enumerate(angles):
 d=Vector((math.cos(math.radians(angle)),math.sin(math.radians(angle)),0))
 points=[d*r+Vector((0,0,z)) for r,z in ([ (.12,.26),(.29,.10),(.46,.12),(.57,.22)] if j>=4 else [(.11,.255),(.25,.115),(.37,.08),(.45,.19)])]
 for k,part in enumerate(['Base','Mid','Tip']):bone(f'Tentacle{j+1}.{part}',points[k],points[k+1],'Root' if k==0 else f'Tentacle{j+1}.'+['Base','Mid'][k-1])
bpy.ops.object.mode_set(mode='OBJECT');body.vertex_groups.clear()
for b in rig.data.bones:body.vertex_groups.new(name=b.name)
def smooth(a,b,v):
 t=max(0,min(1,(v-a)/(b-a)));return t*t*(3-2*t)
def put(v,w):
 for n,x in w.items():
  if x>1e-7:body.vertex_groups[n].add([v.index],x,'REPLACE')
for v in body.data.vertices:
 region=body.data.attributes['RigRegion'].data[v.index].value
 if region>=10:
  j=region-10;r=math.hypot(v.co.x,v.co.y);f=smooth(.23,.49,r)*2 if j>=4 else smooth(.18,.38,r)*2;k=min(1,int(f));t=f-k;names=['Base','Mid','Tip'];put(v,{f'Tentacle{j+1}.{names[k]}':1-t,f'Tentacle{j+1}.{names[k+1]}':t})
 elif region in (2,3):
  suffix='L' if region==2 else 'R';fore=1-smooth(.49,.60,v.co.z);hand=1-smooth(.37,.42,v.co.z);put(v,{'UpperArm.'+suffix:1-fore,'Forearm.'+suffix:fore*(1-hand),'Hand.'+suffix:fore*hand})
 elif region==4:put(v,{'Spine':1})
 else:
  head=smooth(.76,.86,v.co.z);spine=smooth(.30,.43,v.co.z);put(v,{'Head':head,'Spine':(1-head)*spine,'Root':(1-head)*(1-spine)})
# The canonical sheet is matte plush/cloth, including the ivory face.
for material in body.data.materials:
 shader=material.node_tree.nodes.get('Principled BSDF')
 for input_name,value in [('Roughness',.85),('Metallic',0.)]:
  socket=shader.inputs[input_name]
  for link in list(socket.links):material.node_tree.links.remove(link)
  socket.default_value=value
body.parent=rig;body.modifiers.new('Skin','ARMATURE').object=rig
rig.animation_data_create();bpy.context.scene.render.fps=30
for b in rig.pose.bones:b.rotation_mode='QUATERNION'
def turn(name,axis,angle):
 b=rig.pose.bones[name];b.rotation_quaternion=Quaternion(b.bone.matrix_local.to_3x3().inverted()@Vector(axis),angle)
for name in ['Idle','Talk','Wave']:
 act=bpy.data.actions.new(name);act.use_fake_user=True;act.use_frame_range=True;act.frame_start=0;act.frame_end=90;rig.animation_data.action=act
 for frame in range(91):
  t=frame/90*math.tau
  for b in rig.pose.bones:b.matrix_basis=Matrix.Identity(4)
  turn('Head',(0,1,0),.018*math.sin(t))
  for j in range(6):
   turn(f'Tentacle{j+1}.Mid',(0,0,1),.022*math.sin(t+j*math.tau/6));turn(f'Tentacle{j+1}.Tip',(0,0,1),.055*math.sin(t+j*math.tau/6))
  if name=='Talk':
   turn('UpperArm.R',(1,0,0),-.15);turn('Forearm.R',(1,0,0),-.28-.08*math.sin(t*2));turn('Head',(0,0,1),.035*math.sin(t))
  if name=='Wave':
   turn('UpperArm.R',(0,1,0),-.75);turn('Forearm.R',(0,1,0),-1.05+.1*math.sin(t*2))
  for b in rig.pose.bones:
   b.keyframe_insert('location',frame=frame,group=b.name);b.keyframe_insert('rotation_quaternion',frame=frame,group=b.name)
rig.animation_data.action=None
for b in rig.pose.bones:b.matrix_basis=Matrix.Identity(4)
bpy.context.scene.frame_set(0);bpy.context.view_layer.update()
body.data.calc_loop_triangles()
report={'source':'Tripo P2 detailed multiview / canonical sheet','source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'height_m':1.433,'triangles':len(body.data.loop_triangles),'bone_count':len(rig.data.bones),'tentacles':6,'arms':2,'correction':'Removed two separate rear-diagonal duplicate tentacles; retained original closed robe and five-front/one-back six-limb silhouette.','clips':['Idle','Talk','Wave'],'texture':'albedo 2048 / normal 1024 / roughness 0.85 / metallic 0'}
(OUT/'rig.json').write_text(json.dumps(report,indent=2)+'\n');(OUT/'.gitignore').write_text('*.blend\n*.blend1\n')
bpy.ops.object.select_all(action='DESELECT');body.select_set(True);rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'takosan.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'takosan.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_frame_range=False,export_anim_slide_to_zero=True,export_anim_single_armature=True,export_skins=True,export_force_sampling=True)
print('TAKOSAN',json.dumps(report))
