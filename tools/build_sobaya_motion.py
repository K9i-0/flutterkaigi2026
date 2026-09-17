"""Revise selected Sobaya gait/attack clips without touching approved assets."""
import bpy,sys,json,copy,math,hashlib,struct
import numpy as np
from pathlib import Path
from mathutils import Matrix,Vector,Quaternion
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
from replace_glb_animation import read_glb
from build_humanoid_motion import clear_pose
from sobaya_motion_authoring import GAITS,ATTACKS,correct_gait,attack
SOURCE=ROOT/'04_GAME_ASSETS/3d/characters/sobaya/standing_v3_20260917/sobaya_standing.glb'
OUT=ROOT/'04_GAME_ASSETS/3d/characters/sobaya/motion_v3_20260917';OUT.mkdir(exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True);s=bpy.context.scene;s.render.fps=30
bpy.ops.import_scene.gltf(filepath=str(SOURCE));r=next(o for o in s.objects if o.type=='ARMATURE')
actions={a.name:a for a in bpy.data.actions}
def sample_source(name,frame):
 r.animation_data_clear();clear_pose(r);a=actions[name];r.animation_data_create();r.animation_data.action=a;r.animation_data.action_slot=next(sl for sl in a.slots if sl.target_id_type=='OBJECT')
 s.frame_set(int(frame),subframe=frame%1);bpy.context.view_layer.update()
 matrices={b.name:b.matrix_basis.copy() for b in r.pose.bones};r.animation_data_clear()
 for b in r.pose.bones:b.matrix_basis=matrices[b.name]
 bpy.context.view_layer.update()
sample_source('CharacterSheet_MugStand',0);neutral={b.name:b.matrix_basis.copy() for b in r.pose.bones};neutral['_right_hand_world']=[list(row) for row in r.pose.bones['RightHand'].matrix]
doc,raw=read_glb(SOURCE);before=copy.deepcopy(doc);binary=bytearray(raw)
parents={c:i for i,n in enumerate(doc['nodes']) for c in n.get('children',[])}
def local(n):
 q=n.get('rotation',[0,0,0,1]);return Matrix.LocRotScale(Vector(n.get('translation',[0,0,0])),Quaternion((q[3],*q[:3])),Vector(n.get('scale',[1,1,1])))
worlds={}
def world(i):
 if i not in worlds:worlds[i]=(world(parents[i]) if i in parents else Matrix.Identity(4))@local(doc['nodes'][i])
 return worlds[i]
C=Matrix.Rotation(math.pi/2,4,'X');Ci=C.inverted();ids={n.get('name'):i for i,n in enumerate(doc['nodes']) if n.get('name') in r.pose.bones}
restfix={name:r.pose.bones[name].bone.matrix_local.inverted()@C@world(i) for name,i in ids.items()}
def posed_locals(names):
 posed={ids[name]:Ci@r.matrix_world@r.pose.bones[name].matrix@fix for name,fix in restfix.items()}
 def pw(i):
  return posed[i] if i in posed else (pw(parents[i]) if i in parents else Matrix.Identity(4))@local(doc['nodes'][i])
 return {name:(pw(parents[ids[name]]).inverted() if ids[name] in parents else Matrix.Identity(4))@posed[ids[name]] for name in names}
def append(array,kind):
 a=np.array(array,dtype='<f4').reshape(-1,{'SCALAR':1,'VEC3':3,'VEC4':4}[kind]);binary.extend(b'\0'*(-len(binary)%4));vi=len(doc['bufferViews']);doc['bufferViews'].append({'buffer':0,'byteOffset':len(binary),'byteLength':a.nbytes});binary.extend(a.tobytes());ai=len(doc['accessors']);doc['accessors'].append({'bufferView':vi,'componentType':5126,'count':len(a),'type':kind,'min':a.min(0).tolist(),'max':a.max(0).tolist()});return ai
proof={};snapshots={}
for clip in GAITS+ATTACKS:
 animation=next(a for a in doc['animations'] if a['name']==clip);frames=round(actions[clip].frame_range[1]);names=['RightForeArm','RightHand','LeftForeArm','LeftHand'] if clip in GAITS else list(ids)
 times=sorted(set([i/30 for i in range(frames+1)]+([frames/30*.48] if clip in ATTACKS else [])))
 samples={name:[] for name in names};rows=[];snapshots[clip]={}
 for time in times:
  phase=time/(frames/30)
  if clip in GAITS:sample_source(clip,time*30);row=correct_gait(r)
  else:row=attack(r,clip,phase,neutral)
  rows.append(row);poses=posed_locals(names)
  for name in names:samples[name].append(poses[name])
  if time in [times[0],times[len(times)//2],times[-1]]:snapshots[clip][str(time)]={name:[list(row) for row in r.pose.bones[name].matrix] for name in names}
 targets={ids[n] for n in names};oldchannels=animation['channels'];animation['channels']=[c for c in oldchannels if c['target']['node'] not in targets]
 input_id=append(times,'SCALAR')
 for name,matrices in samples.items():
  arrays={'translation':[],'rotation':[],'scale':[]};previous=None
  for m in matrices:
   t,q,sc=m.decompose()
   if previous and previous.dot(q)<0:q.negate()
   previous=q.copy();arrays['translation'].append(list(t));arrays['rotation'].append([q.x,q.y,q.z,q.w]);arrays['scale'].append(list(sc))
  for path,array in arrays.items():
   sampler=len(animation['samplers']);animation['samplers'].append({'input':input_id,'output':append(array,'VEC4' if path=='rotation' else 'VEC3'),'interpolation':'LINEAR'});animation['channels'].append({'sampler':sampler,'target':{'node':ids[name],'path':path}})
 if clip in GAITS:
  proof[clip]={'frames':len(times),'changedBones':names,'minimumInwardDot':{side:min(row[side]['inwardDot'] for row in rows) for side in ['Right','Left']},'maximumWristRollDeg':max(abs(row[side]['wristRollDeg']) for row in rows for side in ['Right','Left']),'unchangedOtherChannels':True}
  assert all(v>.65 for v in proof[clip]['minimumInwardDot'].values()),proof[clip]
 else:proof[clip]={'frames':len(times),'duration':frames/30,'contactPhase':.48,'maxReachClampM':max(row['rightHandReachClampM'] for row in rows),'startEndPose':'CharacterSheet_MugStand'}
 print('CLIP_DONE',clip,proof[clip],flush=True)
assert bytes(binary[:len(raw)])==raw
for key in ['nodes','meshes','skins','materials','textures','images']:assert doc.get(key)==before.get(key)
for a,b in zip(before['animations'],doc['animations']):
 if a['name'] not in GAITS+ATTACKS:assert a==b
 elif a['name'] in GAITS:
  changed={ids[n] for n in ['RightForeArm','RightHand','LeftForeArm','LeftHand']}
  assert [c for c in a['channels'] if c['target']['node'] not in changed]==[c for c in b['channels'] if c['target']['node'] not in changed]
doc['buffers'][0]['byteLength']=len(binary);j=json.dumps(doc,separators=(',',':')).encode();j+=b' '*(-len(j)%4);binary.extend(b'\0'*(-len(binary)%4));result=struct.pack('<III',0x46546c67,2,28+len(j)+len(binary))+struct.pack('<I4s',len(j),b'JSON')+j+struct.pack('<I4s',len(binary),b'BIN\0')+binary
path=OUT/'sobaya_motion.glb';path.write_bytes(result)
report={'source':str(SOURCE.relative_to(ROOT)),'sourceSha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'sha256':hashlib.sha256(result).hexdigest(),'unchangedGeometryGripSkinMaterials':True,'unchangedStandingPose':True,'originalBinaryPrefixPreserved':True,'clips':proof,'roundTripSamples':snapshots}
(OUT/'report.json').write_text(json.dumps(report,indent=2)+'\n')
# Store the exact exported result as the editable inspection asset.
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.scene.render.fps=30;bpy.ops.import_scene.gltf(filepath=str(path))
r=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');a=bpy.data.actions['CharacterSheet_MugStand']
for obj,kind in [(r,'OBJECT')]+[(o.data.shape_keys,'KEY') for o in bpy.context.scene.objects if o.type=='MESH' and o.data.shape_keys and 'MugGrip' in o.data.shape_keys.key_blocks]:
 obj.animation_data_create();obj.animation_data.action=a;obj.animation_data.action_slot=next(sl for sl in a.slots if sl.target_id_type==kind)
for a in bpy.data.actions:a.use_fake_user=True
bpy.context.scene.frame_set(0)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'04_GAME_ASSETS/3d/props/beer_mug_v2/beer_mug.glb'))
mug=bpy.data.objects['BeerMugRoot'];grip=bpy.data.objects['Grip'];bpy.context.view_layer.update()
attachment=Matrix.Rotation(-math.pi/2,4,'X')@grip.matrix_world.inverted()@mug.matrix_world
helper=bpy.data.objects.new('Motion mug attachment',None);bpy.context.collection.objects.link(helper)
constraint=helper.constraints.new('COPY_TRANSFORMS');constraint.target=r;constraint.subtarget='PropSocket.R'
mug.parent=helper;mug.matrix_local=attachment
from sobaya_v2_common import studio
studio();bpy.context.scene.camera.data.ortho_scale=2.05
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'sobaya_motion.blend'));print('MOTION_DONE',report['sha256'],flush=True)
