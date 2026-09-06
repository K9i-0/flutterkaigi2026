"""Authored window vault for the two canonical rigs; no mocap claim.
Clip is 1.6 seconds, runtime can retime it for the heavier Sobaya. Root follows
WindowTraversal: 1.9m smooth passage with a .55m sinusoidal lift.
"""
import math
import bpy
from mathutils import Vector, Matrix, Quaternion


def bake_vault(rig, sobaya=False):
    old=bpy.data.actions.get('Vault')
    if old: bpy.data.actions.remove(old)
    action=bpy.data.actions.new('Vault');action.use_fake_user=True
    action.use_frame_range=True;action.frame_start=0;action.frame_end=48
    rig.animation_data_create();rig.animation_data.action=action
    hips=rig.pose.bones['Hips'];rest=hips.bone.matrix_local.to_3x3()
    def point(name,target):
        b=rig.pose.bones[name]
        q=(b.tail-b.head).rotation_difference(target-b.head)
        b.matrix=Matrix.Translation(b.head)@q.to_matrix().to_4x4()@b.matrix.to_3x3().to_4x4()
        bpy.context.view_layer.update()
    def solve(names,target,pole):
        a,b,tip=[rig.pose.bones[n] for n in names];root=a.head.copy()
        la=(b.head-root).length;lb=(tip.head-b.head).length;v=target-root
        d=max(abs(la-lb)+.005,min(v.length,la+lb-.005));axis=v.normalized()
        bend=(pole-axis*pole.dot(axis)).normalized()
        along=(la*la-lb*lb+d*d)/(2*d)
        point(a.name,root+axis*along+bend*math.sqrt(max(0,la*la-along*along)))
        point(b.name,root+axis*d)
    last={}
    for frame in range(49):
        bpy.context.scene.frame_set(frame)
        for b in rig.pose.bones:
            b.rotation_mode='QUATERNION';b.matrix_basis=Matrix.Identity(4)
        t=frame/48;arc=math.sin(math.pi*t)**2;root_y=.55*arc
        travel=1.9*t*t*(3-2*t);sill_forward=.95-travel
        hips.location=rest.inverted()@Vector((0,0,-.22*arc))
        torso=rig.pose.bones['Chest' if sobaya else 'Spine1']
        bpy.context.view_layer.update()
        # Lean toward the sill while the supporting hands carry the weight.
        q=Quaternion((1,0,0),.52*arc)
        torso.matrix=Matrix.Translation(torso.head)@q.to_matrix().to_4x4()@torso.matrix.to_3x3().to_4x4()
        bpy.context.view_layer.update()
        for side,delay in [('Left',.035),('Right',-.035)]:
            suffix='.L' if side=='Left' else '.R'
            arms=[n+suffix for n in ['UpperArm','Forearm','Hand']] if sobaya else [side+n for n in ['Arm','ForeArm','Hand']]
            legs=[n+suffix for n in ['Thigh','Shin','Foot']] if sobaya else [side+n for n in ['UpLeg','Leg','Foot']]
            sign=1 if rig.pose.bones[arms[0]].head.x>0 else -1
            # Blend into a fixed world-space sill contact; release to balance
            # before the pelvis has passed beyond comfortable arm reach.
            contact=math.sin(math.pi*min(1,max(0,(t-.04)/.76)))**.7 if .04<t<.8 else 0
            hand=Vector((sign*(.37 if sobaya else .29),-.12,1.03)).lerp(Vector((sign*(.37 if sobaya else .29),-sill_forward,.85-root_y)),contact)
            solve(arms,hand,Vector((sign,.10,-.25)))
            point(arms[2],rig.pose.bones[arms[2]].head+Vector((0,-.11,-.035)))
            phase=min(1,max(0,(t+delay)/.80))
            tuck=math.sin(math.pi*phase)**2
            foot=Vector((sign*.17,-.10*math.sin(math.pi*phase),.10+(.60 if sobaya else .68)*tuck))
            solve(legs,foot,Vector((sign*.12,-1,.05)))
            point(legs[2],rig.pose.bones[legs[2]].head+Vector((0,-.17,-.04)))
        if sobaya:
            from sobaya_garment import animate_hem
            animate_hem(rig)
        for b in rig.pose.bones:
            q=b.rotation_quaternion
            if b.name in last and q.dot(last[b.name])<0:q.negate()
            last[b.name]=q.copy()
            b.keyframe_insert('location',frame=frame,group=b.name)
            b.keyframe_insert('rotation_quaternion',frame=frame,group=b.name)
    rig.animation_data.action=None
    for b in rig.pose.bones:b.matrix_basis=Matrix.Identity(4)
    bpy.context.view_layer.update()
    return {'name':'Vault','duration':1.6,'source':'authored two-bone IK window vault; runtime root synchronized','passage_m':1.9,'sill_m':.82}
