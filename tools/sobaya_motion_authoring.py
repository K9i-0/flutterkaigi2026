"""Sobaya-specific palm calibration and authored mug attack trajectories."""
import math
import bpy
from mathutils import Vector,Matrix,Quaternion
from casual_greeting import PALM_NORMAL

GAITS=['Adopted_Library_Walk','Adopted_Candidate_Chase_Run','Walk','Run']
ATTACKS=['Hybrid_MugPunch','Hybrid_MugHook','Hybrid_MugSmash']

def update():bpy.context.view_layer.update()
def rotate(b,axis,angle):
 b.matrix=Matrix.Translation(b.head)@Quaternion(axis,angle).to_matrix().to_4x4()@b.matrix.to_3x3().to_4x4();update()
def palms(r):
 nr=Vector(PALM_NORMAL['sobaya']);world=r.data.bones['RightHand'].matrix_local.to_3x3()@nr
 nl=r.data.bones['LeftHand'].matrix_local.to_3x3().inverted()@Vector((-world.x,world.y,world.z))
 return {'Right':nr,'Left':nl}
def correct_gait(r):
 proof={}
 for side,normal in palms(r).items():
  fore=r.pose.bones[side+'ForeArm'];hand=r.pose.bones[side+'Hand'];point=hand.head.copy()
  # Discard the retargeted wrist roll. Preserve the rest relationship between
  # the forearm and hand, including the model's small relaxed wrist bend.
  natural=(fore.matrix@fore.bone.matrix_local.inverted()@hand.bone.matrix_local).to_3x3()
  axis=(point-fore.head).normalized();palm=natural@normal
  inward=r.pose.bones['Hips'].matrix.to_3x3()@Vector((1 if side=='Right' else -1,0,0))
  a=(palm-axis*palm.dot(axis)).normalized();b=(inward-axis*inward.dot(axis)).normalized()
  angle=math.atan2(axis.dot(a.cross(b)),a.dot(b))
  rotate(fore,axis,angle*.9)
  hand.matrix=Matrix.Translation(point)@(Quaternion(axis,angle).to_matrix()@natural).to_4x4();update()
  result=(hand.matrix.to_3x3()@normal).normalized()
  proof[side]={'inwardDot':result.dot(inward.normalized()),'forearmRollDeg':math.degrees(angle*.9),'wristRollDeg':math.degrees(angle*.1)}
 return proof

def aim(r,name,child,goal):
 b=r.pose.bones[name];direction=r.pose.bones[child].head-b.head
 q=direction.rotation_difference(Vector(goal)-b.head)
 b.matrix=Matrix.Translation(b.head)@q.to_matrix().to_4x4()@b.matrix.to_3x3().to_4x4();update()
def ik(r,names,goal,pole,margin=.009):
 upper,lower,end=[r.pose.bones[n] for n in names];origin=upper.head.copy()
 a=(lower.head-origin).length;b=(end.head-lower.head).length;v=Vector(goal)-origin;distance=v.length
 # Keep a slight bend at extension, avoiding an IK singularity.
 d=min(max(distance,abs(a-b)+.006),a+b-margin);axis=v.normalized();goal=origin+axis*d
 along=(a*a-b*b+d*d)/(2*d);bend=Vector(pole)-origin;bend=(bend-axis*bend.dot(axis)).normalized()
 elbow=origin+axis*along+bend*math.sqrt(max(0,a*a-along*along))
 aim(r,names[0],names[1],elbow);aim(r,names[1],names[2],goal)
 return (goal-Vector(origin+v)).length

def smooth(x):return x*x*(3-2*x)
def track(p,keys):
 for (a,x),(b,y) in zip(keys,keys[1:]):
  if p<=b:
   t=smooth(max(0,(p-a)/(b-a)));return x*(1-t)+y*t
 return keys[-1][1]
def vtrack(p,keys):
 keys=[(t,Vector(v)) for t,v in keys]
 for i,((a,x),(b,y)) in enumerate(zip(keys,keys[1:])):
  if p<=b:
   u=max(0,(p-a)/(b-a))
   def tangent(k):
    if abs(keys[k][0]-.48)<1e-6 and 0<k<len(keys)-1:
     return (keys[k+1][1]-keys[k-1][1])/(keys[k+1][0]-keys[k-1][0])
    return Vector()
   return x*(2*u**3-3*u*u+1)+y*(-2*u**3+3*u*u)+tangent(i)*(u**3-2*u*u+u)*(b-a)+tangent(i+1)*(u**3-u*u)*(b-a)
 return keys[-1][1]

def attack(r,kind,p,neutral):
 for b in r.pose.bones:b.matrix_basis=neutral[b.name].copy()
 update()
 # Contact remains 48% to match the existing game animation clock.
 wind=track(p,[(0,0),(.28,1),(.43,0),(1,0)])
 strike=track(p,[(0,0),(.30,0),(.48,1),(.60,.85),(.92,0),(1,0)])
 settle=track(p,[(0,0),(.28,0),(.48,1),(.63,1),(.94,0),(1,0)])
 yaw=(-22*wind+30*strike) if kind=='Hybrid_MugHook' else (-14*wind+19*strike)
 lean=(-4*wind+13*strike) if kind=='Hybrid_MugSmash' else (-2*wind+7*strike)
 hips=r.pose.bones['Hips'];m=hips.matrix.copy();m.translation+=Vector((.018*strike,-.055*settle,-.028*wind-.024*strike));hips.matrix=m;update()
 rotate(hips,(0,0,1),math.radians(yaw*.35))
 for name,weight in [('Spine',.15),('Spine1',.3),('Spine2',.55)]:
  rotate(r.pose.bones[name],(0,0,1),math.radians(yaw*.65*weight));rotate(r.pose.bones[name],(1,0,0),math.radians(lean*weight))
 if kind=='Hybrid_MugSmash':rotate(r.pose.bones['RightShoulder'],(0,1,0),math.radians(3*wind))
 # Gaze stays on the opponent rather than rolling with the torso.
 head=r.pose.bones['Head'];neutral_head=head.bone.matrix_local.to_3x3()
 head.matrix=Matrix.Translation(head.head)@Matrix.Rotation(math.radians(2*strike),4,'X')@neutral_head.to_4x4();update()
 # Plant the rear foot; lift/advance and recover the lead foot with the hips.
 for side in ['Right','Left']:
  foot=r.pose.bones[side+'Foot'];rest=foot.bone.matrix_local
  advance=track(p,[(0,0),(.18,0),(.40,1),(.66,1),(.96,0),(1,0)])
  lift=track(p,[(0,0),(.18,0),(.29,1),(.40,0),(.68,0),(.81,.8),(.96,0),(1,0)])
  goal=rest.translation+Vector((0,-.15*advance if side=='Left' else 0,.035*lift if side=='Left' else 0))
  ik(r,[side+'UpLeg',side+'Leg',side+'Foot'],goal,(goal.x,-1,.48),margin=.0005)
  foot.matrix=Matrix.Translation(goal)@rest.to_3x3().to_4x4();update()
 # Distinct hand paths: a straight drive, a cross-body arc, and an overhead drop.
 start=Vector((-.2533,-.3387,1.2986))
 if kind=='Hybrid_MugPunch':
  path=[(0,start),(.28,(-.34,-.19,1.28)),(.48,(-.13,-.60,1.30)),(.57,(-.09,-.62,1.27)),(.88,start),(1,start)]
  roll=track(p,[(0,0),(.28,-8),(.48,16),(.57,20),(.88,0),(1,0)])
  tilt=track(p,[(0,0),(.28,-5),(.48,10),(.57,15),(.88,0),(1,0)])
 elif kind=='Hybrid_MugHook':
  path=[(0,start),(.28,(-.52,-.16,1.36)),(.39,(-.45,-.43,1.38)),(.48,(-.04,-.58,1.32)),(.60,(.17,-.42,1.23)),(.90,start),(1,start)]
  roll=track(p,[(0,0),(.28,-35),(.48,42),(.60,62),(.90,0),(1,0)])
  tilt=track(p,[(0,0),(.28,-8),(.48,15),(.60,24),(.90,0),(1,0)])
 else:
  path=[(0,start),(.28,(-.40,-.20,1.51)),(.36,(-.37,-.23,1.54)),(.48,(-.17,-.56,1.24)),(.59,(-.15,-.47,.99)),(.91,start),(1,start)]
  roll=track(p,[(0,0),(.28,-12),(.48,8),(.59,14),(.91,0),(1,0)])
  tilt=track(p,[(0,0),(.28,-32),(.36,-28),(.48,42),(.59,60),(.91,0),(1,0)])
 target=vtrack(p,path);error=ik(r,['RightArm','RightForeArm','RightHand'],target,(-.65,-.06,1.12 if kind!='Hybrid_MugSmash' else 1.08))
 # Preserve the exact grip/socket relationship; orient the complete hand.
 base=Matrix(neutral['_right_hand_world']).to_3x3()
 hand=r.pose.bones['RightHand'];desired=Matrix.Rotation(math.radians(roll),3,'Z')@Matrix.Rotation(math.radians(tilt),3,'X')@base
 fore=r.pose.bones['RightForeArm'];axis=(hand.head-fore.head).normalized();normal=palms(r)['Right']
 natural=(fore.matrix@fore.bone.matrix_local.inverted()@hand.bone.matrix_local).to_3x3()@normal;goal=desired@normal
 x=(natural-axis*natural.dot(axis)).normalized();y=(goal-axis*goal.dot(axis)).normalized();angle=math.atan2(axis.dot(x.cross(y)),x.dot(y))
 rotate(fore,axis,angle*.85)
 hand.matrix=Matrix.Translation(hand.head)@desired.to_4x4();update()
 # The free arm counters the strike without flaring away from the torso.
 left_start=Vector((.365,-.055,.935));guard=Vector((.28,-.27,1.18));amount=track(p,[(0,0),(.24,.75),(.48,1),(.65,.7),(.92,0),(1,0)])
 ik(r,['LeftArm','LeftForeArm','LeftHand'],left_start.lerp(guard,amount),(.55,.06,1.15))
 lh=r.pose.bones['LeftHand'];fore=r.pose.bones['LeftForeArm'];rot=(fore.matrix@fore.bone.matrix_local.inverted()@lh.bone.matrix_local).to_3x3();lh.matrix=Matrix.Translation(lh.head)@rot.to_4x4();update()
 if p in [0,1]:
  for b in r.pose.bones:b.matrix_basis=neutral[b.name].copy()
  update()
 return {'rightHandReachClampM':error}


def greeting(r,p,neutral):
 # Keep the approved body and mug arm fixed; lift only the free left arm.
 from casual_greeting import ease
 for b in r.pose.bones:b.matrix_basis=neutral[b.name].copy()
 update()
 amount=ease((p-.055)/.24)*(1-ease((p-.51)/.37))
 ik(r,['LeftArm','LeftForeArm','LeftHand'],(.43,-.29,1.53),(.59,.03,1.16))
 hand=r.pose.bones['LeftHand'];fore=r.pose.bones['LeftForeArm']
 finger=Vector((.18,-.04,1)).normalized();normal=Vector((0,-1,0));normal=(normal-finger*normal.dot(finger)).normalized()
 local_finger=Vector((0,1,0));local_normal=palms(r)['Left'].normalized()
 source=Matrix((local_finger,local_normal,local_finger.cross(local_normal))).transposed()
 target=Matrix((finger,normal,finger.cross(normal))).transposed();desired=target@source.transposed()
 axis=(hand.head-fore.head).normalized()
 natural=(fore.matrix@fore.bone.matrix_local.inverted()@hand.bone.matrix_local).to_3x3()@local_normal
 a=(natural-axis*natural.dot(axis)).normalized();b=(normal-axis*normal.dot(axis)).normalized()
 rotate(fore,axis,math.atan2(axis.dot(a.cross(b)),a.dot(b))*.85)
 hand.matrix=Matrix.Translation(hand.head)@desired.to_4x4();update()
 raised={name:r.pose.bones[name].matrix_basis.copy() for name in ['LeftArm','LeftForeArm','LeftHand']}
 for bone in r.pose.bones:
  m=neutral[bone.name]
  if bone.name in raised:
   t,q,s=m.decompose();rt,rq,rs=raised[bone.name].decompose();bone.matrix_basis=Matrix.LocRotScale(t.lerp(rt,amount),q.slerp(rq,amount),s.lerp(rs,amount))
  else:bone.matrix_basis=m.copy()
 update()
 return {'raiseAmount':amount}
