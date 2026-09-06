"""Normalize the Tripo biped and bake captured Mixamo locomotion for Flutter Scene.
Requires the locally downloaded, licensed Mixamo FBX files; these are not redistributed.
Blender --background --factory-startup --python tools/build_fukuchan_game_rig.py
"""
import bpy,sys,math,json,hashlib
from pathlib import Path
from mathutils import Vector,Matrix,Quaternion
ROOT=Path(__file__).resolve().parent.parent
sys.path.insert(0,str(ROOT/'tools'))
import retarget_sobaya_mocap as mocap
mocap.MAP['Spine1']='Spine1'
OUT=ROOT/'04_GAME_ASSETS/3d/characters/fukuchan/rig_v1';OUT.mkdir(parents=True,exist_ok=True)
source=OUT.parent/'rig_source/raw/output_model_url.fbx'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.fbx(filepath=str(source))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');mesh=next(o for o in bpy.context.scene.objects if o.type=='MESH')
mesh.parent=None;mesh.matrix_world=Matrix.Identity(4)
# FBX is one metre tall, +X forward. Bake the common transform into mesh AND rest rig.
transform=Matrix.Scale(1.7/.99951148,4)@Matrix.Rotation(-math.pi/2,4,'Z')
mesh.data.transform(transform@Matrix.Scale(.99951171875,4));rig.data.transform(transform@rig.matrix_world);rig.matrix_world=Matrix.Identity(4)
rig.name='FukuchanRig';mesh.name='FukuchanBody';mesh.parent=rig;mesh.matrix_parent_inverse=Matrix.Identity(4)
for b in rig.data.bones:
 old=b.name;new=old.split(':')[-1]
 if mesh.vertex_groups.get(old):mesh.vertex_groups[old].name=new
 b.name=new
for im in bpy.data.images:
 if im.size[0] and im.name not in ['Viewer Node','Render Result']:
  if im.name!='Color.jpg':im.scale(2048,2048)
  im.pack()
rig.animation_data_create();rig.animation_data_clear();rig.animation_data_create()
for b in rig.pose.bones:b.rotation_mode='QUATERNION'
bpy.context.scene.render.fps=30
rest={b.name:b.matrix_local.copy() for b in rig.data.bones}
report={'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'height_m':1.7,'bones':len(rig.data.bones),'clips':[]}
def reset():
 for b in rig.pose.bones:b.matrix_basis=Matrix.Identity(4)
 bpy.context.view_layer.update()
def key(frame):
 for b in rig.pose.bones:
  b.keyframe_insert('location',frame=frame,group=b.name);b.keyframe_insert('rotation_quaternion',frame=frame,group=b.name)
def action(name,frames):
 a=bpy.data.actions.new(name);a.use_fake_user=True;a.use_frame_range=True;a.frame_start=0;a.frame_end=frames;rig.animation_data.action=a;return a
def minimum_z():
 deps=bpy.context.evaluated_depsgraph_get();o=mesh.evaluated_get(deps);return min(v.co.z for v in o.data.vertices)
def ground():
 bpy.context.view_layer.update();rig.pose.bones['Hips'].location+=rest['Hips'].to_3x3().inverted()@Vector((0,0,.003-minimum_z()));bpy.context.view_layer.update()
for clip,file in [('Walk','walk_standard.fbx'),('Run','run_weighted.fbx')]:
 src=ROOT/'.local/mixamo_sobaya/source'/file
 sr,samples=mocap.import_motion(src);reset();frames=len(samples)-1;action(clip,frames)
 correction={}
 for name in sr:
  r=rest[name].to_3x3();s=mocap.rotation(sr[name])
  if name.endswith(('Arm','ForeArm','Hand')):r=r.col[1].rotation_difference(s.col[1]).to_matrix()@r
  correction[name]=s.inverted()@r
 scale=(rig.data.bones['LeftUpLeg'].length+rig.data.bones['LeftLeg'].length)/((sr['LeftUpLeg'].translation-sr['LeftLeg'].translation).length+(sr['LeftLeg'].translation-sr['LeftFoot'].translation).length)
 travel=samples[-1]['Hips'].translation-samples[0]['Hips'].translation;travel.z=0
 center=sum((s['Hips'].translation for s in samples),Vector())/len(samples);center.y=samples[0]['Hips'].translation.y;center.z=sr['Hips'].translation.z
 for i,sample in enumerate(samples):
  bpy.context.scene.frame_set(i);reset()
  if i==frames:sample=samples[0]
  for b in rig.pose.bones:
   if b.name not in correction:continue
   loc=(b.parent.matrix@b.parent.bone.matrix_local.inverted()@b.bone.head_local) if b.parent else b.bone.head_local.copy()
   if b.name=='Hips':loc=rest['Hips'].translation+(sample['Hips'].translation-center-(travel*(i/frames) if i<frames else Vector()))*scale
   r=mocap.rotation(sample[b.name])@correction[b.name]
   if b.name=='Head':
    skin=mocap.rotation(sample['Head'])@mocap.rotation(sr['Head']).inverted();f=skin@Vector((0,-1,0));r=f.rotation_difference(Vector((0,-1,0))).to_matrix()@r
   b.matrix=Matrix.Translation(loc)@r.to_4x4();bpy.context.view_layer.update()
  ground();key(i)
 report['clips'].append({'name':clip,'duration':frames/30,'ground_speed_mps':travel.length*scale/(frames/30),'source':file,'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest()})

def point_bone(name,tail):
 b=rig.pose.bones[name];q=(b.tail-b.head).rotation_difference(tail-b.head);b.matrix=Matrix.Translation(b.head)@q.to_matrix().to_4x4()@b.matrix.to_3x3().to_4x4();bpy.context.view_layer.update()
def arm_ik(side,wrist,pole):
 a=rig.pose.bones[side+'Arm'];b=rig.pose.bones[side+'ForeArm'];hip=a.head.copy();la=(b.head-hip).length;lb=(rig.pose.bones[side+'Hand'].head-b.head).length
 v=wrist-hip;d=min(v.length,la+lb-.002);axis=v.normalized();bend=pole-axis*pole.dot(axis);bend.normalize();along=(la*la-lb*lb+d*d)/(2*d);elbow=hip+axis*along+bend*math.sqrt(max(0,la*la-along*along));point_bone(a.name,elbow);point_bone(b.name,hip+axis*d)
for name in ['Idle','Aim','AimShotgun']:
 action(name,60)
 for i in range(61):
  bpy.context.scene.frame_set(i);reset();breath=math.sin(i/60*math.tau)
  rig.pose.bones['Spine1'].rotation_quaternion=Quaternion((1,0,0),breath*.005);bpy.context.view_layer.update()
  if name.startswith('Aim'):
   arm_ik('Right',Vector((-.12,-.46,1.27)),Vector((-.8,.2,-1)))
   arm_ik('Left',(Vector((.015,-.65,1.2)) if name=='AimShotgun' else Vector((-.075,-.48,1.235))),Vector((.7,.25,-1)))
   point_bone('RightHand',rig.pose.bones['RightHand'].head+Vector((0,-.13,-.07)))
   point_bone('LeftHand',rig.pose.bones['LeftHand'].head+Vector((-.04,-.10,.03)))
  ground();key(i)
 report['clips'].append({'name':name,'duration':2,'source':'authored breathing / two-hand IK pose'})
# Short authored actions supplement captured locomotion. Hit clocks in Dart
# match these frame counts; the upper-body aim pose remains the common baseline.
for name,frames in [('ReloadHandgun',39),('ReloadShotgun',60),('Hit',14),('Evade',13),('Kick',24)]:
 action(name,frames)
 for i in range(frames+1):
  bpy.context.scene.frame_set(i);reset();t=i/frames;arc=math.sin(math.pi*t)**2
  if name.startswith('Reload'):
   long=name=='ReloadShotgun';arm_ik('Right',Vector((-.15,-.37,1.22)),Vector((-.8,.2,-1)))
   # Supporting hand reaches the magazine/belt, then seats the reload.
   support=Vector((.015,-.65,1.2)) if long else Vector((-.075,-.48,1.235))
   hand=support.lerp(Vector((.12,-.14,.89)),arc)
   arm_ik('Left',hand,Vector((.7,.25,-1)))
   point_bone('RightHand',rig.pose.bones['RightHand'].head+Vector((-.035*arc,-.13,-.07+.055*arc)))
   point_bone('LeftHand',rig.pose.bones['LeftHand'].head+Vector((-.04,-.08,.035)))
  elif name=='Kick':
   rig.pose.bones['Spine1'].rotation_quaternion=Quaternion((1,0,0),-.10*arc)
   bpy.context.view_layer.update()
   thigh=rig.pose.bones['RightUpLeg'];shin=rig.pose.bones['RightLeg']
   a=1.35*arc;point_bone(thigh.name,thigh.head+Vector((-.05,-math.sin(a),-math.cos(a)))*thigh.bone.length)
   a=1.65*arc;point_bone(shin.name,shin.head+Vector((0,-math.sin(a),-math.cos(a)))*shin.bone.length)
   arm_ik('Right',Vector((-.29,-.10,1.03)),Vector((-.8,.2,-1)))
   arm_ik('Left',Vector((.30,-.11,1.10)),Vector((.7,.25,-1)))
  elif name=='Evade':
   rig.pose.bones['Spine1'].rotation_quaternion=Quaternion((1,0,0),.16*arc)
   for side,sign in [('Left',1),('Right',-1)]:
    thigh=rig.pose.bones[side+'UpLeg'];a=sign*.35*math.sin(t*math.pi)
    point_bone(thigh.name,thigh.head+Vector((0,-math.sin(a),-math.cos(a)))*thigh.bone.length)
   arm_ik('Right',Vector((-.28,-.12,1.07)),Vector((-.8,.2,-1)))
   arm_ik('Left',Vector((.28,-.12,1.07)),Vector((.8,.2,-1)))
  else:
   rig.pose.bones['Spine1'].rotation_quaternion=Quaternion((1,0,0),-.19*arc)
   rig.pose.bones['Head'].rotation_quaternion=Quaternion((1,0,0),-.06*arc)
  ground();key(i)
 report['clips'].append({'name':name,'duration':frames/30,'source':'authored action; no new motion capture claimed'})
from hazard_climb_motion import bake_climb
report['clips'].append(bake_climb(rig))
from hazard_vault_motion import bake_vault
report['clips'].append(bake_vault(rig))
from hazard_grapple_motion import bake_grapple
report['clips'].extend(bake_grapple(rig))
# Mount the gun at the hand grip in the aiming pose. Bone parent handles all clip blending.
rig.animation_data.action=bpy.data.actions['Aim']
bpy.context.scene.frame_set(0);bpy.context.view_layer.update()
socket=bpy.data.objects.new('GunSocket',None);bpy.context.collection.objects.link(socket);socket.parent=rig;socket.parent_type='BONE';socket.parent_bone='RightHand'
bpy.context.view_layer.update();desired=Matrix.Translation(rig.pose.bones['RightHand'].head+Vector((0,-.075,-.035)))
socket.matrix_world=desired;bpy.context.view_layer.update()
rig.animation_data.action=None;reset();bpy.context.scene.frame_set(0)
from hazard_face_shapes import add_speech_shapes
report['speech_shapes'] = add_speech_shapes(mesh, 'fukuchan')
(OUT/'.gitignore').write_text('*.blend\n*.blend1\n')
(OUT/'rig.json').write_text(json.dumps(report,indent=2)+'\n')
bpy.ops.object.select_all(action='DESELECT')
for o in [rig,mesh,socket]:o.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'fukuchan.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'fukuchan.glb'),export_format='GLB',export_morph_animation=False,use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_frame_range=False,export_anim_slide_to_zero=True,export_anim_single_armature=True,export_skins=True,export_all_influences=False,export_def_bones=False,export_force_sampling=True)
print('FUKUCHAN',json.dumps(report),flush=True)
