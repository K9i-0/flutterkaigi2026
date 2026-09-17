"""Append a reference-matched static mug standing pose to the approved grip GLB."""
import bpy,sys,json,struct,hashlib,math,copy
from pathlib import Path
from mathutils import Vector,Matrix,Quaternion
import numpy as np
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
from replace_glb_animation import read_glb
from build_humanoid_motion import clear_pose
SOURCE=ROOT/'04_GAME_ASSETS/3d/characters/sobaya/grip_v3_20260917/sobaya_grip.glb'
OUT=ROOT/'04_GAME_ASSETS/3d/characters/sobaya/standing_v3_20260917';OUT.mkdir(exist_ok=True)
NAME='CharacterSheet_MugStand'
bpy.ops.wm.open_mainfile(filepath=str(SOURCE.with_suffix('.blend')))
s=bpy.context.scene;r=next(o for o in s.objects if o.type=='ARMATURE')
bpy.context.view_layer.update()
hand=r.pose.bones['RightHand'];socket=r.pose.bones['PropSocket.R']
socket_basis=socket.matrix_basis.copy();relative=hand.matrix.inverted()@socket.matrix
mug=bpy.data.objects['BeerMugRoot'];attachment=mug.matrix_local.copy()
r.animation_data_clear();clear_pose(r);socket.matrix_basis=socket_basis
for o in s.objects:
 if o.type=='MESH' and o.data.shape_keys and 'MugGrip' in o.data.shape_keys.key_blocks:
  o.data.shape_keys.animation_data_clear();o.data.shape_keys.key_blocks['MugGrip'].value=1
bpy.context.view_layer.update()

def aim(name,target):
 b=r.pose.bones[name];delta=(b.tail-b.head).rotation_difference(Vector(target)-b.head)
 b.matrix=Matrix.Translation(b.head)@delta.to_matrix().to_4x4()@Matrix.Translation(-b.head)@b.matrix
 bpy.context.view_layer.update()

def arm(side,target,pole):
 upper=r.pose.bones[side+'Arm'];lower=r.pose.bones[side+'ForeArm']
 shoulder=upper.head.copy();a=upper.length;b=lower.length;v=Vector(target)-shoulder;d=v.length;axis=v.normalized()
 assert abs(a-b)<d<a+b,('unreachable',side,d,a,b)
 along=(a*a-b*b+d*d)/(2*d);h=math.sqrt(max(0,a*a-along*along))
 normal=Vector(pole)-shoulder;normal=(normal-axis*normal.dot(axis)).normalized()
 elbow=shoulder+axis*along+normal*h
 aim(side+'Arm',elbow);aim(side+'ForeArm',target)

# Keep the mug upright, with its handle toward the character's right hand.
desired_mug=Matrix.Translation(Vector((-.015,-.32,1.20)))@Matrix.Rotation(math.pi,4,'Z')
desired_hand=desired_mug@(relative@attachment).inverted()
arm('Right',desired_hand.translation,(-.52,-.07,1.13));r.pose.bones['RightHand'].matrix=desired_hand
# Relax the free arm alongside the hip, with a small natural elbow bend.
arm('Left',(.365,-.055,.935),(.43,.015,1.15))
# Retain the relaxed hand's original world orientation.
r.pose.bones['LeftHand'].matrix=Matrix.Translation(r.pose.bones['LeftHand'].head)@r.data.bones['LeftHand'].matrix_local.to_3x3().to_4x4()
bpy.context.view_layer.update()
# Original lower body is an upright stance; keep its grounded feet and body shape.
# Freeze the pose into an independent Blender action.
a=bpy.data.actions.new(NAME);r.animation_data_create();r.animation_data.action=a
for frame in [0,60]:
 for b in r.pose.bones:
  for path in ['location','rotation_quaternion','scale']:b.keyframe_insert(path,frame=frame,group=b.name)
s.frame_set(0);bpy.context.view_layer.update()
# Convert posed Blender bone matrices into the source glTF node frames. The
# importer may orient display bones differently, so undo each rest matrix.
doc,raw=read_glb(SOURCE);before=copy.deepcopy(doc);binary=bytearray(raw)
parents={c:i for i,n in enumerate(doc['nodes']) for c in n.get('children',[])}
def local(n):
 if 'matrix' in n:return Matrix(np.array(n['matrix']).reshape(4,4).T.tolist())
 q=n.get('rotation',[0,0,0,1]);return Matrix.LocRotScale(Vector(n.get('translation',[0,0,0])),Quaternion((q[3],*q[:3])),Vector(n.get('scale',[1,1,1])))
worlds={}
def world(i):
 if i not in worlds:worlds[i]=(world(parents[i]) if i in parents else Matrix.Identity(4))@local(doc['nodes'][i])
 return worlds[i]
C=Matrix.Rotation(math.pi/2,4,'X');Ci=C.inverted();posed={}
for i,n in enumerate(doc['nodes']):
 b=r.pose.bones.get(n.get('name',''))
 if b:posed[i]=Ci@r.matrix_world@b.matrix@b.bone.matrix_local.inverted()@C@world(i)
def pw(i):
 if i in posed:return posed[i]
 return (pw(parents[i]) if i in parents else Matrix.Identity(4))@local(doc['nodes'][i])
def append(array,kind):
 x=np.array(array,dtype='<f4').reshape(-1,{'SCALAR':1,'VEC3':3,'VEC4':4}[kind]);binary.extend(b'\0'*(-len(binary)%4));vi=len(doc['bufferViews'])
 doc['bufferViews'].append({'buffer':0,'byteOffset':len(binary),'byteLength':x.nbytes});binary.extend(x.tobytes());ai=len(doc['accessors'])
 doc['accessors'].append({'bufferView':vi,'componentType':5126,'count':len(x),'type':kind,'min':x.min(0).tolist(),'max':x.max(0).tolist()});return ai
animation={'name':NAME,'samplers':[],'channels':[]};times=append([0,2],'SCALAR')
def channel(i,path,value,kind):
 si=len(animation['samplers']);animation['samplers'].append({'input':times,'output':append([value,value],kind),'interpolation':'LINEAR'});animation['channels'].append({'sampler':si,'target':{'node':i,'path':path}})
for i in posed:
 m=(pw(parents[i]).inverted() if i in parents else Matrix.Identity(4))@posed[i];t,q,sc=m.decompose()
 channel(i,'translation',list(t),'VEC3');channel(i,'rotation',[q.x,q.y,q.z,q.w],'VEC4');channel(i,'scale',list(sc),'VEC3')
for i,n in enumerate(doc['nodes']):
 if 'mesh' in n and doc['meshes'][n['mesh']].get('extras',{}).get('targetNames')==['MugGrip']:channel(i,'weights',1,'SCALAR')
doc['animations'].append(animation);doc['buffers'][0]['byteLength']=len(binary)
j=json.dumps(doc,separators=(',',':')).encode();j+=b' '*(-len(j)%4);binary.extend(b'\0'*(-len(binary)%4))
result=struct.pack('<III',0x46546c67,2,28+len(j)+len(binary))+struct.pack('<I4s',len(j),b'JSON')+j+struct.pack('<I4s',len(binary),b'BIN\0')+binary
(OUT/'sobaya_standing.glb').write_bytes(result)
assert bytes(binary[:len(raw)])==raw
for key in ['nodes','meshes','skins','materials','textures','images']:assert before.get(key)==doc.get(key)
assert doc['animations'][:-1]==before['animations']
report={'clip':NAME,'sourceSha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'sha256':hashlib.sha256(result).hexdigest(),'existingClipsUnchanged':len(before['animations']),'geometryGripAndMaterialsUnchanged':True,'originalBinaryPrefixPreserved':True,'rightWrist':list(hand.head),'mugTargetMatrix':[list(row) for row in desired_mug],'boneWorldMatrices':{b.name:[list(row) for row in b.matrix] for b in r.pose.bones}}
(OUT/'report.json').write_text(json.dumps(report,indent=2)+'\n')
s.frame_start=0;s.frame_end=60;s.camera.location=(0,-4,1.05);s.camera.rotation_euler=(Vector((0,0,.9))-s.camera.location).to_track_quat('-Z','Y').to_euler();s.camera.data.ortho_scale=2.02
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'sobaya_standing.blend'))
print('STANDING_DONE',report['rightWrist'],flush=True)
