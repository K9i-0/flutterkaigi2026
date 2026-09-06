"""Authored one-hand window brace and alternating steps; no mocap claim.
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
        hips.location=rest.inverted()@Vector((.16*arc,-.10*math.sin(math.tau*t),-.18*arc))
        torso=rig.pose.bones['Hips']
        bpy.context.view_layer.update()
        # Shift toward the supporting arm without changing shoulder width.
        # A low two-hand sill plant exceeds these rigs' natural arm reach.
        q=Quaternion((1,0,0),.50*arc)
        torso.matrix=Matrix.Translation(torso.head)@q.to_matrix().to_4x4()@torso.matrix.to_3x3().to_4x4()
        bpy.context.view_layer.update()
        head=rig.pose.bones['Head']
        head.matrix=Matrix.Translation(head.head)@Quaternion((1,0,0),-.30*arc).to_matrix().to_4x4()@head.matrix.to_3x3().to_4x4()
        bpy.context.view_layer.update()
        for side in ['Left','Right']:
            suffix='.L' if side=='Left' else '.R'
            arms=[n+suffix for n in ['UpperArm','Forearm','Hand']] if sobaya else [side+n for n in ['Arm','ForeArm','Hand']]
            legs=[n+suffix for n in ['Thigh','Shin','Foot']] if sobaya else [side+n for n in ['UpLeg','Leg','Foot']]
            sign=1 if rig.pose.bones[arms[0]].head.x>0 else -1
            # Plant the left hand against the inside of the wooden jamb.
            # The other hand balances freely; release before the body passes.
            def ease(value):
                v=min(1,max(0,value));return v*v*(3-2*v)
            release=.48
            contact=ease((t-.08)/.24)*(1-ease((t-release)/.18)) if side=='Left' else 0
            hand=Vector((sign*(.37 if sobaya else .29),-.12,1.03)).lerp(Vector((sign*.715,-sill_forward+.02,(1.6 if sobaya else 1.55)-root_y)),contact)
            solve(arms,hand,Vector((.15,.9,-.2)) if side=='Left' else Vector((sign,.10,-.25)))
            point(arms[2],rig.pose.bones[arms[2]].head+Vector((0,0,-.12)))
            # Each ankle follows its own world-space lift, passage and landing.
            # Keeping both ankles near the pelvis made the earlier pose curl
            # the shoes up toward the shoulders.
            lead=side=='Left'
            start=.12 if lead else .30
            end=.70 if lead else .86
            foot_world_y=.95-1.9*ease((t-start)/(end-start))
            lift=ease((t-start)/.18)*(1-ease((t-(.67 if lead else .77))/.20))
            foot=Vector((sign*.20,foot_world_y-sill_forward,.10+.95*lift-root_y))
            solve(legs,foot,Vector((sign*.35,-1,.9)))
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
    return {'name':'Vault','duration':1.6,'source':'authored one-hand frame brace and alternating ankle paths; runtime root synchronized','passage_m':1.9,'sill_m':.82,'support_hand':'left','support_progress':[.32,.48],'support_wrist_world':[.715,.02,1.6 if sobaya else 1.55]}
