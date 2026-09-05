"""Normalize the accepted P2 biped and add NPC idle, talk, wave and captured walk."""
import bpy,sys,math,json,hashlib
from pathlib import Path
from mathutils import Vector,Matrix,Quaternion
ROOT=Path(__file__).resolve().parent.parent;sys.path.insert(0,str(ROOT/'tools'))
import retarget_sobaya_mocap as mocap
mocap.MAP['Spine1']='Spine1'
OUT=ROOT/'04_GAME_ASSETS/3d/characters/yametaro/rig_v1';OUT.mkdir(parents=True,exist_ok=True)
source=OUT.parent/'rig_source/raw/output_model_url.fbx'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False);bpy.ops.import_scene.fbx(filepath=str(source))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');mesh=next(o for o in bpy.context.scene.objects if o.type=='MESH')
mesh.parent=None;mesh.matrix_world=Matrix.Identity(4)
transform=Matrix.Scale(1.3/.99951178,4)@Matrix.Rotation(-math.pi/2,4,'Z')
mesh.data.transform(transform@Matrix.Scale(.99951171875,4));rig.data.transform(transform@rig.matrix_world);rig.matrix_world=Matrix.Identity(4)
rig.name='YametaroRig';mesh.name='YametaroBody';mesh.parent=rig;mesh.matrix_parent_inverse=Matrix.Identity(4)
for b in rig.data.bones:b.name=b.name.split(':')[-1]
for im in bpy.data.images:
 if im.size[0] and im.name not in ['Render Result','Viewer Node']:
  im.scale(2048 if im.name=='Color.jpg' else 1024,2048 if im.name=='Color.jpg' else 1024);im.pack()
rig.animation_data_clear();rig.animation_data_create();bpy.context.scene.render.fps=30
for b in rig.pose.bones:b.rotation_mode='QUATERNION'
rest={b.name:b.matrix_local.copy() for b in rig.data.bones}
def reset():
 for b in rig.pose.bones:b.matrix_basis=Matrix.Identity(4)
 bpy.context.view_layer.update()
def action(name,end):
 a=bpy.data.actions.new(name);a.use_fake_user=True;a.use_frame_range=True;a.frame_start=0;a.frame_end=end;rig.animation_data.action=a

def key(frame):
 for b in rig.pose.bones:b.keyframe_insert('location',frame=frame,group=b.name);b.keyframe_insert('rotation_quaternion',frame=frame,group=b.name)
def point(name,tail):
 b=rig.pose.bones[name];q=(b.tail-b.head).rotation_difference(tail-b.head);b.matrix=Matrix.Translation(b.head)@q.to_matrix().to_4x4()@b.matrix.to_3x3().to_4x4();bpy.context.view_layer.update()
clips=[]
for name in ['Idle','Talk','Wave']:
 action(name,90)
 for i in range(91):
  bpy.context.scene.frame_set(i);reset();t=i/90*math.tau
  rig.pose.bones['Spine1'].rotation_quaternion=Quaternion((1,0,0),math.sin(t)*.012)
  rig.pose.bones['Head'].rotation_quaternion=Quaternion((0,1,0),math.sin(t)*(.065 if name!='Idle' else .01));bpy.context.view_layer.update()
  if name=='Talk':
   point('LeftArm',rig.pose.bones['LeftArm'].head+Vector((.08,-.04,-.12)))
   point('LeftForeArm',rig.pose.bones['LeftForeArm'].head+Vector((.03,-.12,.02+math.sin(t*2)*.025)))
  elif name=='Wave':
   point('RightArm',rig.pose.bones['RightArm'].head+Vector((-.2,0,.03)))
   point('RightForeArm',rig.pose.bones['RightForeArm'].head+Vector((-.12+math.sin(t*2)*.025,-.015,.09)))
  key(i)
 clips.append({'name':name,'duration':3,'source':'authored NPC gesture'})
source_motion=ROOT/'.local/mixamo_sobaya/source/walk_standard.fbx';sr,samples=mocap.import_motion(source_motion);reset();frames=len(samples)-1;action('Walk',frames)
correction={}
for name in sr:
 rt=rest[name].to_3x3();rs=mocap.rotation(sr[name])
 if name.endswith(('Arm','ForeArm','Hand')):rt=rt.col[1].rotation_difference(rs.col[1]).to_matrix()@rt
 correction[name]=rs.inverted()@rt
scale=(rig.data.bones['LeftUpLeg'].length+rig.data.bones['LeftLeg'].length)/((sr['LeftUpLeg'].translation-sr['LeftLeg'].translation).length+(sr['LeftLeg'].translation-sr['LeftFoot'].translation).length)
travel=samples[-1]['Hips'].translation-samples[0]['Hips'].translation;travel.z=0
for i,sample in enumerate(samples):
 bpy.context.scene.frame_set(i);reset()
 if i==frames:sample=samples[0]
 for b in rig.pose.bones:
  if b.name not in correction:continue
  loc=b.parent.matrix@b.parent.bone.matrix_local.inverted()@b.bone.head_local if b.parent else b.bone.head_local.copy()
  if b.name=='Hips':
   delta=sample['Hips'].translation-samples[0]['Hips'].translation-(travel*(i/frames) if i<frames else Vector());loc=rest['Hips'].translation+delta*scale
  b.matrix=Matrix.Translation(loc)@(mocap.rotation(sample[b.name])@correction[b.name]).to_4x4();bpy.context.view_layer.update()
 evaluated=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get());low=min(v.co.z for v in evaluated.data.vertices)
 rig.pose.bones['Hips'].location+=rest['Hips'].to_3x3().inverted()@Vector((0,0,.003-low));key(i)
clips.append({'name':'Walk','duration':frames/30,'ground_speed_mps':travel.length*scale/(frames/30),'source':'walk_standard.fbx','sha256':hashlib.sha256(source_motion.read_bytes()).hexdigest()})
rig.animation_data.action=None;reset();bpy.context.scene.frame_set(0)
(OUT/'.gitignore').write_text('*.blend\n*.blend1\n');(OUT/'rig.json').write_text(json.dumps({'height_m':1.3,'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'clips':clips},indent=2)+'\n')
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);mesh.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'yametaro.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'yametaro.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_frame_range=False,export_anim_slide_to_zero=True,export_anim_single_armature=True,export_skins=True,export_force_sampling=True)
print('YAMETARO',clips)
