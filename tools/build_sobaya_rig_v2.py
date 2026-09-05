"""Sobaya quality revision: source quads, anatomical skinning, mask and grip.

Run with Blender --background --factory-startup --python this file.
The v1 generator and GLB remain available for fixed-camera comparisons.
"""
import bpy
import json
import math
import sys
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion
sys.path.insert(0,str(Path(__file__).resolve().parent))
import build_sobaya_rig as base
from sobaya_hand_mesh import rebuild_hands
from sobaya_garment import setup_hem, animate_hem

ROOT=base.ROOT
OUT=ROOT/'04_GAME_ASSETS/3d/characters/sobaya/rig_v2'


def cuff_weights(mesh):
    # Heat diffusion dilutes the INNER cuff into chest/spine weights while
    # the outer cuff follows the arm. Sharpen this continuous field around
    # the cuff, retaining the soft shoulder cap above it.
    for vertex in mesh.data.vertices:
        z=vertex.co.z
        weights={mesh.vertex_groups[g.group].name:g.weight for g in vertex.groups}
        if 1.19<z<1.48:
            name='UpperArm.'+('R' if vertex.co.x<0 else 'L')
            w=weights.get(name,0)
            if .05<w<.999:
                strength=base.smooth((1.43-z)/.12)
                new=w+(base.smooth((w-.10)/.55)-w)*strength
                weights={n:new if n==name else ww*(1-new)/(1-w) for n,ww in weights.items()}
        if z>1.02:
            for name in ['Thigh.L','Thigh.R']:
                leaked=weights.get(name,0)*base.smooth((z-1.02)/.10)
                if leaked:
                    weights[name]-=leaked
                    weights['Spine']=weights.get('Spine',0)+leaked
        for group in mesh.vertex_groups:group.remove([vertex.index])
        for name,w in weights.items():
            if w>1e-6:mesh.vertex_groups[name].add([vertex.index],w,'REPLACE')
    bpy.context.view_layer.objects.active=mesh
    bpy.ops.object.vertex_group_limit_total(limit=4)
    bpy.ops.object.vertex_group_normalize_all(lock_active=False)


def mask_finish(mesh):
    # The generated cavities contain shiny eyeballs. Opaque black lining caps
    # sit behind the white rim and occlude those surfaces from oblique views.
    black=bpy.data.materials.new('Mask velvet black'); black.use_nodes=True
    nodes=black.node_tree.nodes; nodes.clear()
    output=nodes.new('ShaderNodeOutputMaterial'); emission=nodes.new('ShaderNodeEmission')
    emission.inputs[0].default_value=(.0003,.0003,.0003,1)
    black.node_tree.links.new(emission.outputs[0],output.inputs[0])
    black.use_backface_culling=False
    lining=[]
    for name,x,rx,z,rz,y in [('Eye lining R',-.039,.026,1.651,.026,-.128),
                            ('Eye lining L',.033,.025,1.651,.026,-.127)]:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=12,radius=1,location=(x,y,z))
        obj=bpy.context.object; obj.name=name; obj.scale=(rx,.009,rz)
        obj.data.materials.append(black)
        bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
        for p in obj.data.polygons: p.use_smooth=True
        obj.vertex_groups.new(name='Head').add(list(range(len(obj.data.vertices))),1,'REPLACE')
        lining.append(obj)
    # Normal-map noise on the mask is not facial anatomy. Keep the authored
    # albedo/UV and remove that noise only on front-facing mask polygons.
    mat=mesh.data.materials[0].copy(); mat.name='Mask smooth ceramic'
    shader=mat.node_tree.nodes.get('Principled BSDF')
    for link in list(mat.node_tree.links):
        if link.to_node==shader and link.to_socket.name in ['Normal','Roughness','Metallic']:
            mat.node_tree.links.remove(link)
    shader.inputs['Roughness'].default_value=.62
    shader.inputs['Metallic'].default_value=0
    mesh.data.materials.append(mat); slot=len(mesh.data.materials)-1
    mesh.data.materials.append(black); black_slot=len(mesh.data.materials)-1
    for p in mesh.data.polygons:
        c=p.center
        if c.z>1.56 and c.z<1.731 and c.y<-.11 and abs(c.x)<.09:
            p.material_index=slot
        if c.y<-.13 and ((c.x+.003)/.012)**2+((c.z-1.690)/.012)**2<1:
            p.material_index=black_slot
    for v in mesh.data.vertices:
        if v.co.y<-.13 and ((v.co.x+.003)/.014)**2+((v.co.z-1.690)/.014)**2<1:
            v.co.y=-.152
    bpy.ops.object.select_all(action='DESELECT'); mesh.select_set(True)
    for o in lining:o.select_set(True)
    bpy.context.view_layer.objects.active=mesh; bpy.ops.object.join()


def shoulder_follow(rig):
    # Move the clavicle with elevation, then preserve the authored world
    # orientation of the upper arm. Its head follows the raised shoulder.
    for side,sign in [('L',1),('R',-1)]:
        upper=rig.pose.bones['UpperArm.'+side]
        old=upper.matrix.copy()
        direction=(upper.tail-upper.head).normalized()
        elevation=math.acos(max(-1,min(1,-direction.z)))
        follow=base.smooth((elevation-math.radians(35))/math.radians(110))
        base.rotate(rig,'Shoulder.'+side,y=-sign*22*follow,z=-sign*7*follow)
        bpy.context.view_layer.update()
        location=upper.head.copy()
        upper.matrix=Matrix.Translation(location)@old.to_3x3().to_4x4()
        bpy.context.view_layer.update()


def pose(rig,name,t):
    base.pose(rig,name,t)
    shoulder_follow(rig)
    if name in ['Toast','MugAttack']: contact_grip(rig)
    animate_hem(rig)


def finger_ik(rig,digit,target,pole):
    first=rig.pose.bones[digit+'1.R'];second=rig.pose.bones[digit+'2.R']
    start=first.head.copy(); delta=target-start
    a=first.bone.length;b=second.bone.length
    dist=max(abs(a-b)+.0001,min(delta.length,a+b-.0001));axis=delta.normalized()
    along=(a*a-b*b+dist*dist)/(2*dist)
    pole=(pole-axis*pole.dot(axis)).normalized()
    mid=start+axis*along+pole*math.sqrt(max(0,a*a-along*along))
    def aim(b,head,tail):
        q=(b.tail-b.head).rotation_difference(tail-head)
        b.matrix=Matrix.Translation(head)@(q.to_matrix()@b.matrix.to_3x3()).to_4x4()
        bpy.context.view_layer.update()
    aim(first,start,mid)
    aim(second,mid,start+axis*dist)


def contact_grip(rig):
    hand=rig.pose.bones['Hand.R'];socket=rig.pose.bones['PropSocket.R']
    mug_rotation=socket.matrix.to_3x3()
    forearm=rig.pose.bones['Forearm.R']
    up=mug_rotation.col[2].normalized()
    forward=(forearm.tail-forearm.head).normalized()
    radial=-(forward-up*forward.dot(up)).normalized()
    mug_rotation=Matrix((radial,up.cross(radial),up)).transposed()
    wrist=hand.head.copy()
    # Knuckle row runs down the vertical handle; palm approaches from -Y.
    row=(rig.data.bones['Index1.R'].head_local-rig.data.bones['Little1.R'].head_local).normalized()
    long=hand.bone.tail_local-hand.bone.head_local
    long=(long-row*long.dot(row)).normalized()
    rest=Matrix((long,row,long.cross(row))).transposed()
    desired=Matrix((Vector((-1,0,0)),Vector((0,0,1)),Vector((0,1,0)))).transposed()
    orientation=mug_rotation@desired@rest.transposed()
    hand.matrix=Matrix.Translation(wrist)@(orientation@hand.bone.matrix_local.to_3x3()).to_4x4()
    for digit in ['Index','Middle','Ring','Little','Thumb']:
        for joint in [1,2]:rig.pose.bones[f'{digit}{joint}.R'].rotation_quaternion=Quaternion()
    bpy.context.view_layer.update()
    mug=Matrix.Translation(wrist-mug_rotation@Vector((.240,-.035,.083)))@mug_rotation.to_4x4()
    for digit in ['Index','Middle','Ring','Little']:
        h=mug.inverted()@rig.pose.bones[digit+'1.R'].head
        target=mug@Vector((.161,.025,h.z))
        finger_ik(rig,digit,target,mug_rotation@Vector((-1,0,0)))
    finger_ik(rig,'Thumb',mug@Vector((.182,-.008,.145)),mug_rotation@Vector((0,-1,0)))
    socket.matrix=mug@Matrix.Translation((.155,0,.117))
    bpy.context.view_layer.update()


def build():
    OUT.mkdir(parents=True,exist_ok=True)
    rig,mesh=base.setup(quality=True)
    cuff_weights(mesh)
    setup_hem(mesh,rig)
    rebuild_hands(mesh,rig)
    mask_finish(mesh)
    for p in mesh.data.polygons:p.use_smooth=True
    scene=bpy.context.scene;rig.animation_data_create()
    for name,duration in base.CLIPS.items():
        action=bpy.data.actions.new(name);action.use_fake_user=True
        rig.animation_data.action=action
        frames=round(duration*base.FPS)
        for frame in range(frames+1):
            scene.frame_set(frame);pose(rig,name,frame/frames)
            for b in rig.pose.bones:
                b.keyframe_insert('rotation_quaternion',frame=frame,group=b.name)
                b.keyframe_insert('location',frame=frame,group=b.name)
        action.use_frame_range=True;action.frame_start=0;action.frame_end=frames
        print('BAKED',name,flush=True)
    rig.animation_data.action=None;pose(rig,'Idle',0);scene.frame_set(0)
    scene.frame_start=0;scene.frame_end=78
    mesh.data.calc_loop_triangles()
    source=base.SOURCE.with_name('sobaya_source.blend')
    if not source.exists():source=base.SOURCE
    report={'source':str(source.relative_to(ROOT)),
        'rig_version':2,'bone_count':len(rig.data.bones),'deform_bones':sum(b.use_deform for b in rig.data.bones),
        'weighted_vertices':len(mesh.data.vertices),'triangles':len(mesh.data.loop_triangles),
        'max_vertex_influences':4,'socket':'PropSocket.R','root_motion':'in-place',
        'clips':[{'name':n,'duration':d,'loop':n in base.LOOPS,'fps':base.FPS,
                  'prop':'beer_mug' if n in ['Toast','MugAttack'] else None} for n,d in base.CLIPS.items()]}
    (OUT/'rig.json').write_text(json.dumps(report,indent=2)+'\n')
    bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);mesh.select_set(True)
    bpy.context.view_layer.objects.active=rig
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'sobaya_rig.blend'))
    bpy.ops.export_scene.gltf(filepath=str(OUT/'sobaya_rig.glb'),export_format='GLB',use_selection=True,
        export_animations=True,export_animation_mode='ACTIONS',export_frame_range=False,
        export_anim_slide_to_zero=True,export_anim_single_armature=True,export_skins=True,
        export_all_influences=False,export_def_bones=False,export_force_sampling=True,
        export_extras=True,export_image_format='AUTO')
    print('SOBAYA_RIG_V2',json.dumps(report),flush=True)

if __name__=='__main__':build()
