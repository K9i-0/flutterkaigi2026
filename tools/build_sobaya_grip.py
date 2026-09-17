"""Blender CLI: build an additive grip morph and rigid mug attachment.

Original geometry, UVs, skin weights, materials, rest bones and body motion
buffers are copied verbatim. Only the right-hand morph and PropSocket.R
channels are added/replaced. Does not publish or adopt the candidate.
"""
import bpy,sys,json,struct,hashlib,copy,math
from pathlib import Path
from mathutils import Vector,Matrix,Quaternion
import numpy as np
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
from replace_glb_animation import read_glb
from sobaya_grip_shape import deform,jacobian,REVISION,GRIP_CENTER,MUG_ROTATION
SOURCE=ROOT/'04_GAME_ASSETS/3d/hazard_adopted/v3_20260917/sobaya.glb'
OUT=ROOT/'04_GAME_ASSETS/3d/characters/sobaya/grip_v3_20260917'
OUT.mkdir(exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
doc,raw=read_glb(SOURCE);original=copy.deepcopy(doc);binary=bytearray(raw)

def values(index):
 a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']]
 assert 'sparse' not in a
 size={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
 dtype={5126:'<f4',5123:'<u2',5125:'<u4',5121:'u1'}[a['componentType']]
 return np.ndarray((a['count'],size),dtype=dtype,buffer=raw,
   offset=v.get('byteOffset',0)+a.get('byteOffset',0),
   strides=(v.get('byteStride',np.dtype(dtype).itemsize*size),np.dtype(dtype).itemsize)).copy()

def append(array,kind):
 array=np.array(array,dtype='<f4');array=array.reshape((-1,{'SCALAR':1,'VEC3':3,'VEC4':4}[kind]))
 binary.extend(b'\0'*(-len(binary)%4));view=len(doc['bufferViews'])
 doc['bufferViews'].append({'buffer':0,'byteOffset':len(binary),'byteLength':array.nbytes})
 binary.extend(array.tobytes());idx=len(doc['accessors'])
 doc['accessors'].append({'bufferView':view,'componentType':5126,'count':len(array),'type':kind,
  'min':array.min(0).tolist(),'max':array.max(0).tolist()})
 return idx

parents={c:i for i,n in enumerate(doc['nodes']) for c in n.get('children',[])}
def world(i):
 n=doc['nodes'][i];q=n.get('rotation',[0,0,0,1]);q=Quaternion((q[3],*q[:3]));m=Matrix.LocRotScale(Vector(n.get('translation',[0,0,0])),q,Vector(n.get('scale',[1,1,1])))
 return world(parents[i])@m if i in parents else m
hand_id=next(i for i,n in enumerate(doc['nodes']) if n.get('name')=='RightHand')
socket_id=next(i for i,n in enumerate(doc['nodes']) if n.get('name')=='PropSocket.R')
body_id=next(i for i,n in enumerate(doc['nodes']) if n.get('name')=='SobayaV3Body')
hand=world(hand_id);inv=hand.inverted();rotation=hand.to_3x3();inverse_rotation=rotation.inverted()
mesh=doc['meshes'][doc['nodes'][body_id]['mesh']]
assert 'weights' not in mesh
from sobaya_grip_contact import fit_contact
contact,contact_report=fit_contact(doc,values,mesh,hand,ROOT)
changed=0;determinants=[];max_move=0;minimum_hand_weight=1.
hand_joint=doc['skins'][doc['nodes'][body_id]['skin']]['joints'].index(hand_id)
for primitive in mesh['primitives']:
 assert 'targets' not in primitive
 positions=values(primitive['attributes']['POSITION']);normals=values(primitive['attributes']['NORMAL'])
 deltas=np.zeros_like(positions);ndeltas=np.zeros_like(normals)
 joints=values(primitive['attributes']['JOINTS_0']);weights=values(primitive['attributes']['WEIGHTS_0'])
 for i,position in enumerate(positions):
  # glTF is Y up; Blender's right hand occupies this bounded region.
  if position[0]>-.30 or not .68<position[1]<.99:continue
  p=inv@Vector(position);q=deform(p)
  correction=contact.get(tuple(round(float(x),6) for x in p))
  if correction:q+=correction[0]
  if (q-p).length<1e-7:continue
  hand_weight=float(sum(w for j,w in zip(joints[i],weights[i]) if j==hand_joint))
  assert hand_weight>.9,('Grip reached outside right hand',tuple(position),hand_weight)
  minimum_hand_weight=min(minimum_hand_weight,hand_weight)
  j=jacobian(p);det=j.determinant();determinants.append(det)
  assert det>.1,('Folded grip field',tuple(p),det)
  delta=rotation@(q-p);deltas[i]=delta
  normal=(rotation@j.inverted().transposed()@inverse_rotation@Vector(normals[i])).normalized()
  if correction:normal=(rotation@correction[1].to_matrix()@inverse_rotation@normal).normalized()
  ndeltas[i]=normal-Vector(normals[i]);changed+=1;max_move=max(max_move,delta.length)
 primitive['targets']=[{'POSITION':append(deltas,'VEC3'),'NORMAL':append(ndeltas,'VEC3')}]
 for accessor in primitive['targets'][0].values():doc['bufferViews'][doc['accessors'][accessor]['bufferView']]['target']=34962
mesh['weights']=[0.];mesh.setdefault('extras',{})['targetNames']=['MugGrip']
# Grip's axes in a glTF prop are X=handle, Y=up, Z=depth. Convert them
# to the hand's unchanged local bone frame (which retains Blender axes).
convert=Matrix(((1,0,0),(0,0,-1),(0,1,0)))
q=(MUG_ROTATION@convert).to_quaternion();socket_q=[q.x,q.y,q.z,q.w]
held=[]
for animation in doc['animations']:
 name=animation['name']
 # All game-held clips, plus the old mug clips. Open-hand preview/library
 # clips remain open; locomotion is intentionally equipped in this asset.
 hold=(name.startswith('Hybrid_Mug') or name.startswith('Adopted_') or
       name in ['Idle','Walk','Run','ZombieWalk','MugAttack','MugPunch','MugHook','Toast',
                'DanceStep','DanceDisco','DanceVictory','Grab','Hold','Release','Climb','Vault'])
 if hold:held.append(name)
 end=max(float(values(s['input'])[-1,0]) for s in animation['samplers'])
 time=append([[0],[end]],'SCALAR')
 def channel(path,node,array,kind):
  output=append(array,kind);sampler=len(animation['samplers'])
  animation['samplers'].append({'input':time,'output':output,'interpolation':'LINEAR'})
  animation['channels'].append({'sampler':sampler,'target':{'node':node,'path':path}})
 channel('weights',body_id,[[int(hold)],[int(hold)]],'SCALAR')
 if hold:
  animation['channels']=[c for c in animation['channels'] if c['target']['node']!=socket_id]
  channel('translation',socket_id,[GRIP_CENTER,GRIP_CENTER],'VEC3')
  channel('rotation',socket_id,[socket_q,socket_q],'VEC4')
  channel('scale',socket_id,[[1,1,1],[1,1,1]],'VEC3')
# Append-only guarantees original accessors, normal maps and motions remain exact.
assert bytes(binary[:len(raw)])==raw
for key in ['nodes','skins','materials','textures','images']:
 assert doc.get(key)==original.get(key),key
for before,after in zip(original['animations'],doc['animations']):
 remaining=[c for c in after['channels'] if c['target']['node'] not in [body_id,socket_id]]
 expected=[c for c in before['channels'] if c['target']['node'] not in [body_id,socket_id]]
 assert remaining==expected
 assert after['samplers'][:len(before['samplers'])]==before['samplers']
doc['buffers'][0]['byteLength']=len(binary)
j=json.dumps(doc,separators=(',',':')).encode();j+=b' '*(-len(j)%4);binary.extend(b'\0'*(-len(binary)%4))
result=struct.pack('<III',0x46546c67,2,28+len(j)+len(binary))+struct.pack('<I4s',len(j),b'JSON')+j+struct.pack('<I4s',len(binary),b'BIN\0')+binary
path=OUT/'sobaya_grip.glb';path.write_bytes(result)
report={'revision':REVISION,'source':str(SOURCE.relative_to(ROOT)),'sourceSha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
 'sha256':hashlib.sha256(result).hexdigest(),'contact':contact_report,'morph':'MugGrip','changedExportVertices':changed,'maxDisplacementM':max_move,'minimumRightHandSkinWeight':minimum_hand_weight,
 'localJacobianDeterminant':[min(determinants),max(determinants)],'curveFieldFoldedSamples':0,
 'originalBinaryPreserved':True,'unchangedRestBonesSkinMaterials':True,'unchangedBodyMotionClips':len(doc['animations']),
 'heldClips':held,'socketHandLocalPosition':GRIP_CENTER,'socketHandLocalRotation':socket_q,
 'note':'Attachment follows the existing wrist. Gait wrist orientation and attack choreography are not revised.'}
(OUT/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
# Round-trip editor source is generated from the exact review GLB, avoiding
# a subtly different Blender-only shape or socket transform.
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.scene.render.fps=30
bpy.ops.import_scene.gltf(filepath=str(path))
from build_humanoid_motion import use_action,clear_pose
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');rig.animation_data_clear();clear_pose(rig)
# All action slots (body shape keys as well as skeleton) stay in the file.
for action in bpy.data.actions:action.use_fake_user=True
action=bpy.data.actions['Hybrid_MugHold']
keys=next(o.data.shape_keys for o in bpy.context.scene.objects if o.type=='MESH' and o.data.shape_keys)
for target,kind in [(rig,'OBJECT'),(keys,'KEY')]:
 target.animation_data_create();target.animation_data.action=action
 target.animation_data.action_slot=next(slot for slot in action.slots if slot.target_id_type==kind)
bpy.context.scene.frame_set(0)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'04_GAME_ASSETS/3d/props/beer_mug_v2/beer_mug.glb'))
mug=bpy.data.objects['BeerMugRoot'];grip=bpy.data.objects['Grip'];bpy.context.view_layer.update()
attachment=Matrix.Rotation(-math.pi/2,4,'X')@grip.matrix_world.inverted()@mug.matrix_world
helper=bpy.data.objects.new('Grip preview attachment',None);bpy.context.collection.objects.link(helper)
constraint=helper.constraints.new('COPY_TRANSFORMS');constraint.target=rig;constraint.subtarget='PropSocket.R'
mug.parent=helper;mug.matrix_local=attachment
from sobaya_v2_common import studio
studio();scene=bpy.context.scene;target=Vector((-.12,0,1.05))
scene.camera.location=target+Vector((-2,-4,.8));scene.camera.rotation_euler=(target-scene.camera.location).to_track_quat('-Z','Y').to_euler();scene.camera.data.ortho_scale=2.1
bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'sobaya_grip.blend'))
print('SOBAYA_GRIP_DONE',json.dumps(report),flush=True)
