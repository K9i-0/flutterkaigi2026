"""Keep approved geometry; clean neck with a local material bake and bind anatomical rig."""
import bpy,numpy as np,sys,json,math
from pathlib import Path
from mathutils import Vector,Matrix
P=Path(__file__).resolve().parent;ROOT=P.parents[4];sys.path.insert(0,str(ROOT/'tools'))
bpy.ops.wm.open_mainfile(filepath=str(P.parent/'likeness_finish_20260917/fukuchan_final.blend'))
o=next(o for o in bpy.context.scene.objects if o.type=='MESH');o.data.transform(o.matrix_world);o.matrix_world=Matrix.Identity(4);o.name='FukuchanV3';m=o.data
for a in list(bpy.context.scene.objects):
 if a!=o:bpy.data.objects.remove(a,do_unlink=True)
def smooth(a,b,x):t=max(0,min(1,(x-a)/(b-a)));return t*t*(3-2*t)
sys.path.insert(0,str(P))
from neck import clean_neck
neck_report=clean_neck(o,P)
# Body skeleton: calibrated to this A-pose, not copied local rotations from v2.
arm=bpy.data.armatures.new('FukuchanV3Skeleton');rig=bpy.data.objects.new('FukuchanV3Rig',arm);bpy.context.collection.objects.link(rig);bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
def bone(n,a,b,parent=None,deform=True):
 q=arm.edit_bones.new(n);q.head=a;q.tail=b;q.use_deform=deform
 if parent:q.parent=arm.edit_bones[parent]
 q.align_roll(Vector((0,-1,0)));return q
bone('Root',(0,0,0),(0,0,.1),deform=False)
points=[(.82,'Hips'),(.94,'Spine'),(1.08,'Spine1'),(1.22,'Spine2'),(1.34,'Neck'),(1.46,'Head'),(1.67,None)]
for i,(z,n) in enumerate(points[:-1]):bone(n,(0,.045 if z<1.34 else .015,z),(0,.045 if points[i+1][0]<1.34 else .015,points[i+1][0]),'Root' if i==0 else points[i-1][1])
DIGITS={
 'Index':[(.428,-.061,.778),(.424,-.066,.744),(.407,-.071,.718),(.397,-.073,.706)],
 'Middle':[(.433,-.025,.773),(.427,-.035,.733),(.407,-.045,.704),(.400,-.045,.695)],
 'Ring':[(.431,.008,.776),(.426,-.002,.744),(.410,-.010,.719),(.403,-.012,.705)],
 'Little':[(.425,.035,.787),(.422,.025,.765),(.410,.015,.743),(.403,.008,.733)],
 'Thumb':[(.380,-.040,.821),(.378,-.073,.792),(.373,-.085,.767),(.377,-.087,.746)]}
for side,sign,suffix in [('Left',1,'L'),('Right',-1,'R')]:
 ps=[(sign*.035,.045,1.305),(sign*.183,.055,1.30),(sign*.304,.045,1.065),(sign*.385,-.015,.841),(sign*.415,-.015,.775)]
 for i,n in enumerate(['Shoulder','Arm','ForeArm','Hand']):bone(side+n,ps[i],ps[i+1],'Spine2' if i==0 else side+['Shoulder','Arm','ForeArm'][i-1])
 ps=[(sign*.102,.035,.82),(sign*.119,.025,.445),(sign*.13,.032,.105),(sign*.13,-.095,.045),(sign*.13,-.17,.04)]
 for i,n in enumerate(['UpLeg','Leg','Foot','ToeBase']):bone(side+n,ps[i],ps[i+1],'Hips' if i==0 else side+['UpLeg','Leg','Foot'][i-1])
 for digit,path in DIGITS.items():
  for i in range(3):bone(f'{digit}{i+1}.{suffix}',(sign*path[i][0],*path[i][1:]),(sign*path[i+1][0],*path[i+1][1:]),side+'Hand' if i==0 else f'{digit}{i}.{suffix}')
bone('PropSocket.R',(-.415,-.015,.775),(-.415,-.065,.775),'RightHand',False)
bpy.ops.object.mode_set(mode='OBJECT');o.parent=rig;o.matrix_parent_inverse=Matrix.Identity(4);mod=o.modifiers.new('Skin','ARMATURE');mod.object=rig
for b in arm.bones:
 if b.use_deform:o.vertex_groups.new(name=b.name)
def core(z):
 stops=[(.84,'Hips'),(.98,'Spine'),(1.13,'Spine1'),(1.29,'Spine2'),(1.365,'Neck'),(1.445,'Head')]
 for (a,n),(b,k) in zip(stops,stops[1:]):
  if z<b:t=smooth(a,b,z);return {n:1-t,k:t}
 return {'Head':1}
weights=[]
for v in m.vertices:
 x,y,z=v.co;side='Left' if x>0 else 'Right';ax=abs(x)
 if z>1.445:w={'Head':1}
 elif z<.68 or (z<.81 and ax<.30):
  hip=smooth(.70,.85,z);knee=smooth(.36,.53,z);ankle=smooth(.09,.20,z)
  leg={side+'UpLeg':knee*(1-hip),side+'Leg':(1-knee)*ankle*(1-hip),side+'Foot':(1-knee)*(1-ankle)*(1-hip),'Hips':hip}
  middle=(1-smooth(.015,.085,ax))*smooth(.64,.77,z);w={}
  for n,k in leg.items():
   if n=='Hips':w[n]=k
   else:w[n]=k*(1-.5*middle);w[n.replace(side,'Right' if side=='Left' else 'Left')]=k*.5*middle
 else:
  lo=float(np.interp(z,[.7,.9,1.05,1.2,1.33],[.29,.255,.21,.16,.12]));hi=lo+.055;mix=smooth(lo,hi,ax)
  upper=smooth(.985,1.12,z);wrist=smooth(.817,.878,z);aw={side+'Arm':upper,side+'ForeArm':(1-upper)*wrist,side+'Hand':(1-upper)*(1-wrist)}
  w={n:k*(1-mix) for n,k in core(z).items()}
  for n,k in aw.items():w[n]=w.get(n,0)+k*mix
 weights.append(w)
# Weld UV splits and diffuse only locally to avoid seams and abrupt finger assignment.
adj=[set() for _ in m.vertices];groups={}
for v in m.vertices:groups.setdefault(tuple(round(c,5) for c in v.co),[]).append(v.index)
for e in m.edges:a,b=e.vertices;adj[a].add(b);adj[b].add(a)
for ids in groups.values():
 neighbors=set(ids).union(*(adj[i] for i in ids))
 for i in ids:adj[i]=neighbors-{i}
# Surface-distance digit assignment avoids weights jumping between adjacent fingers.
import heapq
for suffix,sign,side in [('L',1,'Left'),('R',-1,'Right')]:
 active={v.index for v in m.vertices if sign*v.co.x>.34 and .68<v.co.z<.835};distances={}
 for digit,path in DIGITS.items():
  tip=Vector((sign*path[-1][0],*path[-1][1:]));seed=min(active,key=lambda i:(m.vertices[i].co-tip).length_squared);dist={seed:0};heap=[(0,seed)]
  while heap:
   d,i=heapq.heappop(heap)
   if d>dist[i]+1e-10:continue
   for j in adj[i]&active:
    nd=d+(m.vertices[i].co-m.vertices[j].co).length
    if nd<dist.get(j,1e10):dist[j]=nd;heapq.heappush(heap,(nd,j))
  distances[digit]=dist
 for i in active:
  p=m.vertices[i].co;allowed=[d for d in DIGITS if d!='Thumb' or (abs(p.x)<.405 and p.y<-.045)];digit=min(allowed,key=lambda d:distances[d].get(i,1e10));path=DIGITS[digit]
  influence=1-smooth(path[0][2]-.008,path[0][2]+.008,p.z)
  if influence<1e-6:continue
  z0,z1,z2,z3=[q[2] for q in path];second=1-smooth(z1-.008,z1+.008,p.z);third=1-smooth(z2-.006,z2+.006,p.z)
  weights[i]={side+'Hand':1-influence,f'{digit}1.{suffix}':influence*(1-second),f'{digit}2.{suffix}':influence*second*(1-third),f'{digit}3.{suffix}':influence*second*third}
for iteration in range(3):
 new=[]
 for i,v in enumerate(m.vertices):
  w=weights[i].copy()
  if v.co.z<1.43 and adj[i]:
   w={n:k*.65 for n,k in w.items()}
   for j in adj[i]:
    for n,k in weights[j].items():w[n]=w.get(n,0)+k*.35/len(adj[i])
  new.append(w)
 weights=new
badgeids={i for f in m.polygons if f.material_index in [5,9] for i in f.vertices}
for i in badgeids:weights[i]={'Spine':1}
for ids in groups.values():
 avg={}
 for i in ids:
  for n,k in weights[i].items():avg[n]=avg.get(n,0)+k/len(ids)
 ent=sorted(avg.items(),key=lambda x:-x[1])[:4];total=sum(k for n,k in ent)
 for n,k in ent:
  if k>1e-7:o.vertex_groups[n].add(ids,k/total,'REPLACE')
for b in rig.pose.bones:b.rotation_mode='QUATERNION'
rig.show_in_front=True;bpy.context.scene.render.fps=30
bpy.ops.wm.save_as_mainfile(filepath=str(P/'fukuchan_rig.blend'))
(P/'bind_report.json').write_text(json.dumps({'bones':len(arm.bones),'vertices':len(m.vertices),'neck_repair':neck_report,'geometry_and_uv_preserved':True,'digits':DIGITS},indent=2)+'\n')
print('RIG_READY',flush=True)
