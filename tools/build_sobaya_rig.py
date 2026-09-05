"""Skin the canonical Sobaya GLB and bake game animations; no external service.

Blender --background --factory-startup --python tools/build_sobaya_rig.py
The immutable Tripo source, UVs and 4K maps stay intact. Regenerate this derived
asset with this script; editable .blend is retained locally alongside the GLB.
"""
import bpy
import json
import math
from pathlib import Path
from mathutils import Vector, Matrix, Euler, Quaternion

ROOT=Path(__file__).resolve().parent.parent
SOURCE=ROOT/'04_GAME_ASSETS/3d/characters/sobaya/tripo_p2_20260905/sobaya_preview.glb'
OUT=ROOT/'04_GAME_ASSETS/3d/characters/sobaya/rig_v1'
FPS=30
CLIPS={'Idle':2.4,'Walk':1.0,'Run':.7,'ZombieWalk':1.8,
       'DanceStep':2.0,'DanceDisco':2.4,'DanceVictory':2.0,'Toast':2.6,'MugAttack':1.4}
LOOPS=set(CLIPS)-{'Toast','MugAttack'}


def smooth(v):
    v=max(0,min(1,v)); return v*v*(3-2*v)


def keys(t, points):
    for (a,va),(b,vb) in zip(points,points[1:]):
        if t<=b: return va+(vb-va)*smooth((t-a)/(b-a))
    return points[-1][1]


def setup(*, quality=False):
    OUT.mkdir(parents=True,exist_ok=True)
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
    if quality and SOURCE.with_name('sobaya_source.blend').exists():
        bpy.ops.wm.open_mainfile(filepath=str(SOURCE.with_name('sobaya_source.blend')))
    else:
        bpy.ops.import_scene.gltf(filepath=str(SOURCE),merge_vertices=True)
    bpy.context.view_layer.update()
    mesh=next(o for o in bpy.context.scene.objects if o.type=='MESH')
    world=mesh.matrix_world.copy(); mesh.parent=None; mesh.matrix_world=world
    bpy.ops.object.select_all(action='DESELECT'); mesh.select_set(True)
    bpy.context.view_layer.objects.active=mesh
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    mesh.name='SobayaBody'
    # Weld coincident UV-seam vertices, retaining face-corner UVs.
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.remove_doubles(threshold=.00001); bpy.ops.object.mode_set(mode='OBJECT')
    for o in list(bpy.context.scene.objects):
        if o!=mesh: bpy.data.objects.remove(o,do_unlink=True)
    arm=bpy.data.armatures.new('SobayaHumanoid')
    rig=bpy.data.objects.new('SobayaRig',arm); bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active=rig; rig.select_set(True); mesh.select_set(False)
    bpy.ops.object.mode_set(mode='EDIT')
    def bone(name,head,tail,parent=None,deform=True):
        b=arm.edit_bones.new(name); b.head=head; b.tail=tail; b.use_deform=deform
        if parent: b.parent=arm.edit_bones[parent]
        b.align_roll(Vector((0,-1,0)))
        return b
    bone('Root',(0,0,0),(0,0,.18),deform=False)
    bone('Hips',(0,.035,.94),(0,.02,1.06),'Root')
    bone('Spine',(0,.02,1.06),(0,.015,1.25),'Hips')
    bone('Chest',(0,.015,1.25),(0,.025,1.46),'Spine')
    bone('Neck',(0,.025,1.46),(0,-.018,1.59),'Chest')
    bone('Head',(0,-.018,1.59),(0,-.018,1.77),'Neck')
    for side,s in [('L',1),('R',-1)]:
        def v(x,y,z): return (s*x,y,z)
        bone('Shoulder.'+side,v(.055,.03,1.435),v(.267,.035,1.435),'Chest')
        bone('UpperArm.'+side,v(.267,.035,1.435),v(.367,.034,1.13),'Shoulder.'+side)
        bone('Forearm.'+side,v(.367,.034,1.13),v(.395,-.065,.89),'UpperArm.'+side)
        bone('Hand.'+side,v(.395,-.065,.89),v(.394,-.116,.802),'Forearm.'+side)
        specs={
            'Index':[(.365,-.14,.815),(.363,-.157,.766),(.354,-.146,.739)],
            'Middle':[(.387,-.131,.808),(.386,-.146,.756),(.375,-.128,.713)],
            'Ring':[(.409,-.108,.811),(.405,-.121,.763),(.395,-.108,.725)],
            'Little':[(.428,-.084,.826),(.430,-.098,.788),(.423,-.080,.754)],
            'Thumb':[(.347,-.088,.856),(.321,-.115,.815),(.325,-.134,.778)]}
        for digit,points in specs.items():
            bone(digit+'1.'+side,v(*points[0]),v(*points[1]),'Hand.'+side)
            bone(digit+'2.'+side,v(*points[1]),v(*points[2]),digit+'1.'+side)
        bone('Thigh.'+side,v(.147,.035,.935),v(.177,.022,.51),'Hips')
        bone('Shin.'+side,v(.177,.022,.51),v(.208,.047,.115),'Thigh.'+side)
        bone('Foot.'+side,v(.208,.047,.115),v(.214,-.151,.065),'Shin.'+side)
    # Socket basis: local X=world X, local Y=world Z, local Z=-world Y.
    # Rotating the forearm forward by 90 degrees makes a gripped mug upright.
    b=bone('PropSocket.R',(-.394,-.129,.805),(-.394,-.129,.865),'Hand.R',False)
    b.roll=0
    bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.object.select_all(action='DESELECT'); mesh.select_set(True); rig.select_set(True)
    bpy.context.view_layer.objects.active=rig
    bpy.ops.object.parent_set(type='ARMATURE_AUTO')
    # Heat diffusion crosses the narrow armpit/hip gaps of the A-pose.
    # Replace the torso field with smooth anatomical weights; retain heat
    # weights for the detailed hands and limb joints. This also prevents
    # four-weight truncation from switching between unrelated limb bones.
    body_stops=[(.96,'Hips'),(1.17,'Spine'),(1.41,'Chest'),(1.53,'Neck'),(1.58,'Head')]
    for vertex in mesh.data.vertices:
        x,y,z=vertex.co; ax=abs(x)
        original={mesh.vertex_groups[g.group].name:g.weight for g in vertex.groups}
        if z>=1.58:
            weights={'Head':1.0}
        elif not quality and z>.84 and ax<.335:
            core={body_stops[-1][1]:1.0}
            if z<=body_stops[0][0]: core={'Hips':1.0}
            else:
                for (lo,a),(hi,b) in zip(body_stops,body_stops[1:]):
                    if lo<=z<=hi:
                        t=smooth((z-lo)/(hi-lo)); core={a:1-t,b:t}; break
            side='L' if x>0 else 'R'
            arm_start=.245-.10*smooth((z-1.15)/.25)
            arm_mix=smooth((ax-arm_start)/(.335-arm_start))
            arm_weights={n:w for n,w in original.items() if n.endswith('.'+side) and n.split('.')[0] in ['Shoulder','UpperArm','Forearm','Hand']}
            if not arm_weights: arm_weights={'UpperArm.'+side:1.0}
            total=sum(arm_weights.values())
            weights={n:w*(1-arm_mix) for n,w in core.items()}
            for n,w in arm_weights.items(): weights[n]=w/total*arm_mix
            # Keep pants attached through a short, continuous hip transition.
            body_mix=smooth((z-.84)/.10)
            weights={n:w*body_mix for n,w in weights.items()}
            for n,w in original.items(): weights[n]=weights.get(n,0)+w*(1-body_mix)
        else:
            weights=original
        for group in mesh.vertex_groups: group.remove([vertex.index])
        for n,w in weights.items():
            if w>1e-6: mesh.vertex_groups[n].add([vertex.index],w,'REPLACE')
    bpy.context.view_layer.objects.active=mesh
    bpy.ops.object.vertex_group_limit_total(limit=4)
    bpy.ops.object.vertex_group_normalize_all(lock_active=False)
    unweighted=[v for v in mesh.data.vertices if not v.groups or sum(g.weight for g in v.groups)<.99]
    # Heat weights can leave tiny disconnected islands (hair / seams) unbound.
    # Assign only these islands to the closest deform segment, then verify all.
    for vertex in unweighted:
        def distance(b):
            a=b.head_local; d=b.tail_local-a
            t=max(0,min(1,(vertex.co-a).dot(d)/d.length_squared))
            return (vertex.co-a-t*d).length_squared
        nearest=min((b for b in arm.bones if b.use_deform),key=distance)
        for group in mesh.vertex_groups: group.remove([vertex.index])
        mesh.vertex_groups[nearest.name].add([vertex.index],1,'REPLACE')
    print('REPAIRED_UNBOUND_ISLAND_VERTICES',len(unweighted),flush=True)
    assert all(abs(sum(g.weight for g in v.groups)-1)<.001 for v in mesh.data.vertices)
    for p in rig.pose.bones: p.rotation_mode='QUATERNION'
    rig.show_in_front=True; arm.display_type='OCTAHEDRAL'
    bpy.context.scene.render.fps=FPS
    bpy.context.scene.unit_settings.system='METRIC'
    return rig,mesh


def rotate(rig,name,x=0,y=0,z=0):
    b=rig.pose.bones[name]
    basis=b.bone.matrix_local.to_3x3()
    rotation=Euler(tuple(math.radians(a) for a in (x,y,z)),'XYZ').to_matrix()
    b.rotation_quaternion=(basis.inverted()@rotation@basis).to_quaternion()


def aim_bone(rig,name,head,tail):
    b=rig.pose.bones[name]; rest=b.bone
    q=(rest.tail_local-rest.head_local).rotation_difference(Vector(tail)-Vector(head))
    b.matrix=Matrix.Translation(head)@q.to_matrix().to_4x4()@rest.matrix_local.to_3x3().to_4x4()


def leg(rig,side,ankle,pitch=0):
    thigh=rig.pose.bones['Thigh.'+side]; shin=rig.pose.bones['Shin.'+side]
    hip=thigh.head.copy(); ankle=Vector(ankle)
    a=thigh.bone.length; b=shin.bone.length
    direction=ankle-hip; dist=min(direction.length,a+b-.0001); axis=direction.normalized()
    along=(a*a-b*b+dist*dist)/(2*dist)
    pole=Vector((0,-1,0)); pole=(pole-axis*pole.dot(axis)).normalized()
    knee=hip+axis*along+pole*math.sqrt(max(0,a*a-along*along))
    ankle=hip+axis*dist
    aim_bone(rig,'Thigh.'+side,hip,knee)
    bpy.context.view_layer.update()
    aim_bone(rig,'Shin.'+side,knee,ankle)
    bpy.context.view_layer.update()
    foot=rig.pose.bones['Foot.'+side]
    direction=foot.bone.tail_local-foot.bone.head_local
    aim_bone(rig,'Foot.'+side,ankle,ankle+Euler((math.radians(pitch),0,0)).to_matrix()@direction)


def foot_cycle(phase,stride,lift,stance):
    p=phase%1
    if p<stance: return -stride+2*stride*p/stance,0,0
    u=(p-stance)/(1-stance)
    return stride-2*stride*smooth(u),lift*math.sin(math.pi*u),-15*math.sin(math.pi*u)


def grip(rig,amount):
    hand=rig.pose.bones['Hand.R']
    twist=Quaternion(Vector((0,1,0)),math.radians(-80*amount))
    hand.rotation_quaternion=hand.rotation_quaternion@twist
    # Let the palm wrap vertically around the handle while retaining the
    # authored mug orientation. This is baked into a normal socket bone.
    h=hand.bone.matrix_local.to_3x3()
    socket=rig.pose.bones['PropSocket.R']
    s_basis=socket.bone.matrix_local.to_3x3()
    socket.rotation_quaternion=(s_basis.inverted()@h@twist.inverted().to_matrix()@h.inverted()@s_basis).to_quaternion()
    for side,s in [('R',-1),('L',1)]:
        factor=amount if side=='R' else 0
        for digit in ['Index','Middle','Ring','Little']:
            rotate(rig,digit+'1.'+side,x=65*factor)
            rotate(rig,digit+'2.'+side,x=70*factor)
        rotate(rig,'Thumb1.'+side,x=-20*factor,z=-s*25*factor)
        rotate(rig,'Thumb2.'+side,y=s*30*factor)


def pose(rig,name,t):
    for b in rig.pose.bones:
        b.location=(0,0,0); b.rotation_quaternion=Quaternion(); b.scale=(1,1,1)
    wave=math.sin(math.tau*t)
    hips=rig.pose.bones['Hips']; hipz=0; lean=0
    targets={side:[s*.208,.047,.115,0] for side,s in [('L',1),('R',-1)]}
    rotate(rig,'Forearm.L',x=-7); rotate(rig,'Forearm.R',x=-7)
    if name=='Idle':
        rotate(rig,'Chest',x=1.2*wave); rotate(rig,'Head',z=1.5*wave)
        hipz=.003*(1+wave)
    elif name in ['Walk','Run','ZombieWalk']:
        run=name=='Run'; zombie=name=='ZombieWalk'
        stride=.37 if run else .12 if zombie else .28
        lift=.23 if run else .045 if zombie else .10
        stance=.40 if run else .68 if zombie else .60
        hipz=(-.085 if run else -.008 if zombie else -.04)+(.013 if run else .008)*math.cos(math.tau*t*2)
        lean=9 if run else 7 if zombie else 2
        for side,offset in [('L',0),('R',.54 if zombie else .5)]:
            y,z,p=foot_cycle(t+offset,stride,lift,stance)
            targets[side][1]+=(y if not zombie or side=='L' else y*.75)
            targets[side][2]+=z; targets[side][3]=p
            swing=math.sin(math.tau*(t+offset))
            rotate(rig,'UpperArm.'+side,x=(-73 if zombie else (40 if run else 22)*swing),
                   z=(5 if side=='L' else -5) if zombie else 0)
            rotate(rig,'Forearm.'+side,x=(-12+4*swing if zombie else -72-12*swing if run else -15-10*swing))
            if zombie: rotate(rig,'Hand.'+side,x=28+9*swing,z=8*swing)
        rotate(rig,'Chest',z=5*wave if not zombie else 4*wave)
        rotate(rig,'Head',z=9+3*wave if zombie else -3*wave,x=5 if zombie else 0)
    elif name=='DanceStep':
        hipz=-.025+.018*math.cos(math.tau*t*4)
        hips.location.x=.065*wave
        rotate(rig,'Chest',z=9*wave); rotate(rig,'Head',z=-5*wave)
        for side,s in [('L',1),('R',-1)]:
            swing=math.sin(math.tau*t*2+(0 if s==1 else math.pi))
            targets[side][0]+=s*.075*max(0,swing)
            targets[side][2]+=.065*max(0,swing)
            rotate(rig,'UpperArm.'+side,x=25*swing,z=s*18)
            rotate(rig,'Forearm.'+side,x=-65-20*swing)
    elif name=='DanceDisco':
        pulse=.5-.5*math.cos(math.tau*t*2)
        hipz=-.045+.035*pulse
        rotate(rig,'Hips',z=9*wave); rotate(rig,'Chest',y=8*wave,z=-8*wave)
        rotate(rig,'UpperArm.R',x=-90-20*pulse,z=-24)
        rotate(rig,'Forearm.R',x=-35)
        rotate(rig,'UpperArm.L',x=-12,z=28)
        rotate(rig,'Forearm.L',x=-85,y=-15)
        for digit in ['Middle','Ring','Little']:
            rotate(rig,digit+'1.R',y=-65); rotate(rig,digit+'2.R',y=-60)
        rotate(rig,'Head',z=-7*wave)
        targets['L'][0]+=.03*wave; targets['R'][0]+=.03*wave
    elif name=='DanceVictory':
        pulse=.5-.5*math.cos(math.tau*t*4)
        hipz=-.09+.085*pulse
        rotate(rig,'Chest',x=-4,z=5*wave)
        for side,s in [('L',1),('R',-1)]:
            rotate(rig,'UpperArm.'+side,x=-65-25*pulse,z=s*22)
            rotate(rig,'Forearm.'+side,x=-65-15*(1-pulse))
        rotate(rig,'Head',x=-8)
    elif name=='Toast':
        raise_by=keys(t,[(0,0),(.14,0),(.43,1),(.64,1),(.91,0),(1,0)])
        upper=-12-68*raise_by; fore=-78+33*raise_by
        rotate(rig,'UpperArm.R',x=upper,z=-8*raise_by)
        rotate(rig,'Forearm.R',x=fore)
        rotate(rig,'Hand.R',x=-90-upper-fore,z=8*raise_by)
        rotate(rig,'Chest',z=-5*raise_by)
        rotate(rig,'Head',x=-4*raise_by,z=-6*raise_by)
        grip(rig,1)
    elif name=='MugAttack':
        upper=keys(t,[(0,-12),(.18,20),(.38,-110),(.55,-76),(.66,-58),(1,-12)])
        fore=keys(t,[(0,-78),(.18,-82),(.38,-48),(.55,-12),(.66,-15),(1,-78)])
        twist=keys(t,[(0,0),(.18,-20),(.38,-28),(.55,20),(.7,12),(1,0)])
        rotate(rig,'UpperArm.R',x=upper,z=-10)
        rotate(rig,'Forearm.R',x=fore)
        rotate(rig,'Hand.R',x=keys(t,[(0,0),(.38,10),(.55,4),(1,0)]))
        rotate(rig,'Chest',x=keys(t,[(0,0),(.38,-8),(.55,20),(1,0)]),z=twist)
        rotate(rig,'Head',x=4,z=-twist*.4)
        rotate(rig,'UpperArm.L',x=-30,z=18); rotate(rig,'Forearm.L',x=-75)
        hipz=-.035*math.sin(math.pi*t)**2
        grip(rig,1)
    # Hips local Z is not world Z because edit-bone roll is authored.
    hips.location += hips.bone.matrix_local.to_3x3().inverted()@Vector((0,0,hipz))
    if lean: rotate(rig,'Hips',x=lean)
    bpy.context.view_layer.update()
    for side,a in targets.items(): leg(rig,side,a[:3],a[3])
    bpy.context.view_layer.update()


def build():
    rig,mesh=setup()
    scene=bpy.context.scene
    rig.animation_data_create()
    for name,duration in CLIPS.items():
        action=bpy.data.actions.new(name); action.use_fake_user=True
        rig.animation_data.action=action
        frames=round(duration*FPS)
        for frame in range(frames+1):
            scene.frame_set(frame); pose(rig,name,frame/frames)
            for b in rig.pose.bones:
                b.keyframe_insert('rotation_quaternion',frame=frame,group=b.name)
                b.keyframe_insert('location',frame=frame,group=b.name)
        action.use_frame_range=True; action.frame_start=0; action.frame_end=frames
        print('BAKED',name,frames,flush=True)
    rig.animation_data.action=None
    pose(rig,'Idle',0); scene.frame_set(0)
    scene.frame_start=0; scene.frame_end=78
    mesh.data.calc_loop_triangles()
    report={'source':str(SOURCE.relative_to(ROOT)),'rig_version':1,'bone_count':len(rig.data.bones),
        'deform_bones':sum(b.use_deform for b in rig.data.bones),'weighted_vertices':len(mesh.data.vertices),
        'triangles':len(mesh.data.loop_triangles),'max_vertex_influences':4,'socket':'PropSocket.R',
        'root_motion':'in-place; horizontal displacement is controlled by the game',
        'clips':[{'name':n,'duration':d,'loop':n in LOOPS,'fps':FPS,'prop':'beer_mug' if n in ['Toast','MugAttack'] else None} for n,d in CLIPS.items()]}
    (OUT/'rig.json').write_text(json.dumps(report,indent=2)+'\n')
    bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); mesh.select_set(True)
    bpy.context.view_layer.objects.active=rig
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'sobaya_rig.blend'))
    bpy.ops.export_scene.gltf(filepath=str(OUT/'sobaya_rig.glb'),export_format='GLB',use_selection=True,
        export_animations=True,export_animation_mode='ACTIONS',export_frame_range=False,
        export_anim_slide_to_zero=True,export_anim_single_armature=True,export_skins=True,
        export_all_influences=False,export_def_bones=False,export_force_sampling=True,
        export_extras=True,export_image_format='AUTO')
    print('SOBAYA_RIG',json.dumps(report),flush=True)


if __name__=='__main__': build()
