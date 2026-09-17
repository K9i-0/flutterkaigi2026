import bpy,math
from mathutils import Vector,Matrix,Quaternion
from build_humanoid_motion import Body,use_action,clear_pose

def curl(rig,amount):
 for suffix,sign in [('L',1),('R',-1)]:
  for digit in ['Index','Middle','Ring','Little','Thumb']:
   for i,angle in enumerate([85,65,15] if digit!='Thumb' else [55,30,20]):
    b=rig.pose.bones[f'{digit}{i+1}.{suffix}'];axis=b.bone.matrix_local.to_3x3().inverted()@Vector((sign,0,0) if digit=='Thumb' else (0,sign,0));b.rotation_quaternion=Quaternion(axis,math.radians(angle)*amount)

def orient(rig,side,direction,normal):
 h=rig.pose.bones[side+'Hand'];u0=(h.bone.tail_local-h.bone.head_local).normalized();n0=Vector((-1 if side=='Left' else 1,0,0));n0=(n0-u0*n0.dot(u0)).normalized();u1=Vector(direction).normalized();n1=Vector(normal);n1=(n1-u1*n1.dot(u1)).normalized();a=Matrix((u0,n0,u0.cross(n0))).transposed();b=Matrix((u1,n1,u1.cross(n1))).transposed();h.matrix=Matrix.Translation(h.head)@(b@a.transposed()@h.bone.matrix_local.to_3x3()).to_4x4();bpy.context.view_layer.update()

def tuck_thumbs(rig):
 for suffix,side,sign in [('L','Left',1),('R','Right',-1)]:
  hand=rig.pose.bones[side+'Hand'];transform=hand.matrix@hand.bone.matrix_local.inverted()
  a,b,c=[rig.pose.bones[f'Thumb{i}.{suffix}'] for i in [1,2,3]]
  for q in [a,b,c]:q.rotation_quaternion=Quaternion((1,0,0,0))
  bpy.context.view_layer.update();origin=a.head.copy();goal=transform@Vector((sign*.385,-.055,.783));la=(b.head-a.head).length;lb=(c.head-b.head).length;delta=goal-origin;distance=max(abs(la-lb)+.001,min(delta.length,la+lb-.001));axis=delta.normalized();pole=transform.to_3x3()@Vector((-sign,0,0));bend=(pole-axis*pole.dot(axis)).normalized();along=(la*la-lb*lb+distance*distance)/(2*distance);joint=origin+axis*along+bend*math.sqrt(max(0,la*la-along*along))
  for bone,child,target in [(a,b,joint),(b,c,origin+axis*distance)]:
   q=(child.head-bone.head).rotation_difference(target-bone.head);bone.matrix=Matrix.Translation(bone.head)@q.to_matrix().to_4x4()@bone.matrix.to_3x3().to_4x4();bpy.context.view_layer.update()
  target=transform@Vector((sign*.389,-.055,.765));q=(c.tail-c.head).rotation_difference(target-c.head);c.matrix=Matrix.Translation(c.head)@q.to_matrix().to_4x4()@c.matrix.to_3x3().to_4x4();bpy.context.view_layer.update()

def author(rig,mesh):
 body=Body(rig,[mesh],'fukuchan');use_action(rig,bpy.data.actions['Idle']);bpy.context.scene.frame_set(0);neutral={b.name:b.matrix_basis.copy() for b in rig.pose.bones};use_action(rig,None)
 def reset():
  for b in rig.pose.bones:b.matrix_basis=neutral[b.name]
  bpy.context.view_layer.update()
 reset()
 # User correction: subject stands on the RIGHT foot and raises the LEFT knee.
 hip=rig.pose.bones['Hips'];h=hip.matrix.copy();h.translation+=Vector((.065,0,-.02));hip.matrix=h;bpy.context.view_layer.update()
 body.leg_ik('r',Vector((-.13,.032,.105)),body.rest['RightFoot'].to_3x3())
 thigh=rig.pose.bones['LeftUpLeg'];knee=thigh.head+Vector((.50,-.85,.12)).normalized()*body.length('thigh_l','calf_l');body.aim(thigh,knee);calf=rig.pose.bones['LeftLeg'];body.aim(calf,calf.head+Vector((-.25,-.02,-1)));foot=rig.pose.bones['LeftFoot'];foot.matrix=Matrix.Translation(foot.head)@body.rest['LeftFoot'].to_3x3().to_4x4();bpy.context.view_layer.update()
 for side,sign,short in [('Left',1,'l'),('Right',-1,'r')]:
  goal=Vector((sign*.145+.035,-.19,1.34));body.ik(['upperarm_'+short,'lowerarm_'+short,'hand_'+short],goal,Vector((sign*.1,-.25,-1)))
  orient(rig,side,(sign*-.15,0,1),(-sign*.8,.6,0))
 curl(rig,.75);tuck_thumbs(rig)
 # Place the supporting shoe at the floor without disturbing the lifted leg.
 h=hip.matrix.copy();h.translation.z+=.003-body.skin_floor('r');hip.matrix=h;bpy.context.view_layer.update()
 gyun={b.name:b.matrix_basis.copy() for b in rig.pose.bones}
 for name,frames,held in [('GyunGyunPose',30,True),('GyunGyun',120,False)]:
  body.action(name,frames)
  for i in range(frames+1):
   bpy.context.scene.frame_set(i);t=i/frames
   def ease(x):x=max(0,min(1,x));return x*x*(3-2*x)
   a=1 if held else ease(t/.25)*(1-ease((t-.73)/.27))
   for b in rig.pose.bones:
    loc0,q0,s0=neutral[b.name].decompose();loc1,q1,s1=gyun[b.name].decompose();b.location=loc0.lerp(loc1,a);b.rotation_quaternion=q0.slerp(q1,a);b.scale=s0.lerp(s1,a)
   bpy.context.view_layer.update();body.key(i)
 # New calibrated greeting, same short neutral -> raised -> neutral behavior.
 reset();body.ik(['upperarm_r','lowerarm_r','hand_r'],Vector((-.30,-.24,1.40)),Vector((-.5,0,-1)));orient(rig,'Right',(-.15,0,1),(0,-1,0));curl(rig,0);raised={b.name:b.matrix_basis.copy() for b in rig.pose.bones};body.action('Greeting',66)
 for i in range(67):
  bpy.context.scene.frame_set(i);t=i/66;a=min(1,t/.32,max(0,(1-t)/.30));a=a*a*(3-2*a)
  for b in rig.pose.bones:
   l,q,s=neutral[b.name].decompose();l1,q1,s1=raised[b.name].decompose();b.location=l.lerp(l1,a);b.rotation_quaternion=q.slerp(q1,a);b.scale=s
  bpy.context.view_layer.update();body.key(i)
 use_action(rig,None);clear_pose(rig)
 return [{'name':'GyunGyunPose','seconds':1,'source':'user photo, authored fixed pose'},{'name':'GyunGyun','seconds':4,'source':'user photo, authored enter-hold-return'},{'name':'Greeting','seconds':2.2,'source':'authored casual greeting calibrated to new A-pose hands'}]
