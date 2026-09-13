"""Rebuild the three-part Tripo/Astra Fukuchan v2 from recorded local sources.

Blender --background --factory-startup --python tools/build_fukuchan_v2.py
Does not submit any generation job. Original body/head/hair and game v1 stay intact.
"""
import sys, math, json, hashlib
from pathlib import Path
import bpy, bmesh
from mathutils import Matrix, Vector, Quaternion
from mathutils.bvhtree import BVHTree

sys.path.insert(0,str(Path(__file__).resolve().parent))
from fukuchan_v2_common import OUT, ROOT, bounds, import_part, prepare_materials, studio, render_view

def smooth(a,b,x):
    t=max(0.,min(1.,(x-a)/(b-a)))
    return t*t*(3-2*t)

def import_body():
    bpy.ops.import_scene.fbx(filepath=str(OUT/'rig_source/raw/output_model_url.fbx'))
    rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
    body=next(o for o in bpy.context.scene.objects if o.type=='MESH')
    mw=body.matrix_world.copy();rw=rig.matrix_world.copy()
    rot=Matrix.Rotation(-math.pi/2,4,'Z')
    points=[rot@mw@v.co for v in body.data.vertices]
    lo=Vector([min(p[i] for p in points) for i in range(3)])
    hi=Vector([max(p[i] for p in points) for i in range(3)])
    transform=Matrix.Scale(1.516/(hi.z-lo.z),4)@Matrix.Translation((-(lo.x+hi.x)/2,-(lo.y+hi.y)/2,-lo.z))@rot
    body.data.transform(transform@mw)
    body.parent=None;body.matrix_world=Matrix.Identity(4)
    rig.data.transform(transform@rw);rig.matrix_world=Matrix.Identity(4)
    body.parent=rig;body.matrix_parent_inverse=Matrix.Identity(4)
    rig.name='FukuchanV2Rig';body.name='Body'
    for bone in rig.data.bones:
        old=bone.name;new=old.split(':')[-1]
        if body.vertex_groups.get(old):body.vertex_groups[old].name=new
        bone.name=new
    rig.animation_data_clear();rig.animation_data_create()
    for a in list(bpy.data.actions):bpy.data.actions.remove(a)
    for p in rig.pose.bones:p.rotation_mode='QUATERNION'
    # Correct portrait-reference foreshortening while keeping each hand's size.
    # The same rest-space map applies to mesh AND armature before binding motions.
    def elongate(p):
        p=p.copy();x=abs(p.x)
        offset=.195*min(1.,max(0.,(x-.20)/.285)) if p.z>1.08 else 0.
        p.x+=math.copysign(offset,p.x)
        return p
    for v in body.data.vertices:v.co=elongate(v.co)
    bpy.context.view_layer.objects.active=rig
    bpy.ops.object.mode_set(mode='EDIT')
    for bone in rig.data.edit_bones:
        bone.head=elongate(bone.head);bone.tail=elongate(bone.tail)
    # Headless auto-rig guesses only the stump: extend the two existing joints.
    neck=rig.data.edit_bones['Neck'];head=rig.data.edit_bones['Head']
    neck.head=(0,.012,1.375);neck.tail=(0,.018,1.477)
    head.head=neck.tail;head.tail=(0,.018,1.676)
    for side in ['Left','Right']:
        sign=1 if side=='Left' else -1
        forearm=rig.data.edit_bones[side+'ForeArm'];hand=rig.data.edit_bones[side+'Hand']
        hand.head=(sign*.692,.003,1.332);hand.tail=(sign*.832,.003,1.332)
        forearm.tail=hand.head
        calf=rig.data.edit_bones[side+'Leg'];foot=rig.data.edit_bones[side+'Foot'];toe=rig.data.edit_bones[side+'ToeBase']
        foot.head.z=.073;toe.head.z=.034
        calf.tail=foot.head;foot.tail=toe.head;toe.tail=toe.head+Vector((0,-.07,0))
    bpy.ops.object.mode_set(mode='OBJECT')
    for poly in body.data.polygons:poly.use_smooth=True
    return body,rig

def fit_neck(body,head):
    head.data.transform(Matrix.Translation((0,-.023,0)))
    # Shrink the generated neck flange inside the collar, preserving the face.
    for v in head.data.vertices:
        if v.co.z>=1.47:continue
        center=Vector((0,.009,v.co.z));d=v.co-center;d.z=0
        if d.length<1e-8:continue
        unit=d.normalized();radius=1/math.sqrt((unit.x/.052)**2+(unit.y/.048)**2)
        blend=1-smooth(1.40,1.47,v.co.z)
        v.co=v.co.lerp(center+unit*min(d.length,radius),blend)
    bm=bmesh.new();bm.from_mesh(head.data)
    cut=bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),plane_co=(0,0,1.404),plane_no=(0,0,1),clear_inner=True,dist=1e-7)
    ring=[e for e in bm.edges if e.is_boundary and all(v.co.z<1.407 for v in e.verts)]
    if ring:
        result=bmesh.ops.extrude_edge_only(bm,edges=ring)
        for v in result['geom']:
            if isinstance(v,bmesh.types.BMVert):
                v.co.z=1.377;v.co.x*=.96;v.co.y=.009+(v.co.y-.009)*.96
        bottom=[e for e in bm.edges if e.is_boundary and all(v.co.z<1.38 for v in e.verts)]
        bmesh.ops.holes_fill(bm,edges=bottom,sides=0)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(head.data);bm.free()
    # Identify skin by the generated albedo, so the blazer collar is retained.
    mat=body.data.materials[0]
    im=next(n.image for n in mat.node_tree.nodes if n.type=='TEX_IMAGE' and n.image and Path(n.image.filepath).stem=='Color')
    import numpy as np
    pixels=np.empty(len(im.pixels),dtype=np.float32);im.pixels.foreach_get(pixels)
    pixels=pixels.reshape((im.size[1],im.size[0],4));uv=body.data.uv_layers.active.data
    remove=[]
    for p in body.data.polygons:
        coords=[body.data.vertices[i].co for i in p.vertices]
        if min(v.z for v in coords)>1.447:
            remove.append(p.index);continue
        if min(v.z for v in coords)<1.376 or max(abs(v.x) for v in coords)>.095:continue
        c=sum((uv[i].uv for i in p.loop_indices),Vector((0,0)))/len(p.loop_indices)
        r,g,b,_=pixels[int(c.y*im.size[1])%im.size[1],int(c.x*im.size[0])%im.size[0]]
        if r>g*1.07 and r>b*1.07 and r>.2:remove.append(p.index)
    bm=bmesh.new();bm.from_mesh(body.data);bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm,geom=[bm.faces[i] for i in remove],context='FACES')
    # A short inward collar lining closes the otherwise visible generated edge.
    lining=bpy.data.materials.new('JacketLining');lining.use_nodes=True
    bs=lining.node_tree.nodes['Principled BSDF'];bs.inputs['Base Color'].default_value=(.008,.012,.023,1);bs.inputs['Roughness'].default_value=.88
    idx=len(body.data.materials);body.data.materials.append(lining)
    rim=[e for e in bm.edges if e.is_boundary and all(v.co.z>1.36 and abs(v.co.x)<.13 for v in e.verts)]
    inside={};deform=bm.verts.layers.deform.verify()
    for e in rim:
        for v in e.verts:
            if v not in inside:
                q=v.co.copy();q.x*=.9;q.y=.009+(q.y-.009)*.9;q.z-=.019
                n=bm.verts.new(q)
                for g,w in v[deform].items():n[deform][g]=w
                inside[v]=n
        f=bm.faces.new((e.verts[0],e.verts[1],inside[e.verts[1]],inside[e.verts[0]]));f.material_index=idx
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(body.data);bm.free()
    return {'removedBodySkinFaces':len(remove),'neckBase':1.377,'neckFitRadii':[.052,.048]}

def fit_hair(head,hair):
    hair.data.transform(Matrix.Translation((0,-.01,0)))
    tree=BVHTree.FromPolygons([v.co for v in head.data.vertices],[list(p.vertices) for p in head.data.polygons])
    pushed=0
    for v in hair.data.vertices:
        if v.co.z<1.525:continue
        center=Vector((0,.003,v.co.z));d=v.co-center
        if d.length<1e-6:continue
        hit,normal,_,_=tree.ray_cast(center,d.normalized(),.3)
        if hit is not None and (hit-center).length+.003>d.length:
            v.co=hit+d.normalized()*.003;pushed+=1
    # A fitted underlayer closes holes between generated hair ribbons at the nape.
    # It belongs to Hair, remains separate from Head, and follows the same Head bone.
    verts=[];faces=[];mapping={}
    for p in head.data.polygons:
        coords=[head.data.vertices[i].co for i in p.vertices]
        def inside(v):
            front=1-smooth(-.065,.025,v.y)
            edge=1.524+.124*front*(1-smooth(.055,.085,abs(v.x)))
            return v.z>edge
        if not all(inside(v) for v in coords):continue
        ids=[]
        for i in p.vertices:
            if i not in mapping:
                v=head.data.vertices[i];mapping[i]=len(verts);verts.append(v.co+v.normal*.0015)
            ids.append(mapping[i])
        faces.append(ids)
    data=bpy.data.meshes.new('HairUnderlayer');data.from_pydata(verts,[],faces);data.update()
    cap=bpy.data.objects.new('HairUnderlayer',data);bpy.context.collection.objects.link(cap)
    material=bpy.data.materials.new('HairUnderlayerMat');material.use_nodes=True
    bs=material.node_tree.nodes['Principled BSDF'];bs.inputs['Base Color'].default_value=(.008,.006,.005,1);bs.inputs['Roughness'].default_value=.72
    cap.data.materials.append(material)
    bpy.ops.object.select_all(action='DESELECT');hair.select_set(True);cap.select_set(True);bpy.context.view_layer.objects.active=hair;bpy.ops.object.join()
    for p in hair.data.polygons:p.use_smooth=True
    return {'scalpClearanceM':.003,'adjustedHairVertices':pushed,'underlayerFaces':len(faces)}

def skin_parts(rig,head,hair):
    for obj in [head,hair]:
        obj.vertex_groups.clear()
        hg=obj.vertex_groups.new(name='Head');ng=obj.vertex_groups.new(name='Neck')
        for v in obj.data.vertices:
            w=1 if obj==hair else smooth(1.408,1.49,v.co.z)
            hg.add([v.index],w,'REPLACE')
            if w<1:ng.add([v.index],1-w,'REPLACE')
        obj.parent=rig;obj.matrix_parent_inverse=Matrix.Identity(4)
        mod=obj.modifiers.new('Skin','ARMATURE');mod.object=rig

def finish_materials(hair):
    records=prepare_materials()
    for mat in hair.data.materials:
        bs=mat.node_tree.nodes.get('Principled BSDF')
        if bs is None:continue
        for slot,value in [('Metallic',0.),('Roughness',.72),('Specular IOR Level',.25)]:
            for link in list(bs.inputs[slot].links):mat.node_tree.links.remove(link)
            bs.inputs[slot].default_value=value
    # The three original albedos stay 4K; non-color maps use 2K for a game asset.
    for im in bpy.data.images:
        if im.size[0]>2048 and Path(im.filepath).stem in ('Normal','Roughness','Metallic'):
            im.scale(2048,2048);im.pack()
    return records

def stabilize_wrists(body):
    # The generated hidden forearm skin had ~30% Hand influence, while the
    # surrounding sleeve had ~0%. Use the same spatial transition on both.
    changed=0
    for v in body.data.vertices:
        if abs(v.co.x)<.53 or v.co.z<1.1:continue
        side='Left' if v.co.x>0 else 'Right'
        for group in list(v.groups):body.vertex_groups[group.group].remove([v.index])
        w=smooth(.665,.735,abs(v.co.x))
        if w>0:body.vertex_groups[side+'Hand'].add([v.index],w,'REPLACE')
        if w<1:body.vertex_groups[side+'ForeArm'].add([v.index],1-w,'REPLACE')
        changed+=1
    return changed

def build_geometry():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.name='Fukuchan_v2_Review_20260913'
    body,rig=import_body();head=import_part('head',.31,1.394);hair=import_part('hair',.244,1.482)
    report={'neck':fit_neck(body,head),'hair':fit_hair(head,hair)}
    skin_parts(rig,head,hair);report['materials']=finish_materials(hair)
    bpy.context.scene.render.fps=30
    return rig,body,head,hair,report

def main():
    from fukuchan_v2_face import add_face
    from fukuchan_v2_motion import retarget
    from humanoid_deformation import smooth_shoulders
    from build_humanoid_motion import use_action,clear_pose
    rig,body,head,hair,report=build_geometry()
    lids,report['face']=add_face(head,rig)
    report['shoulderVertices']=smooth_shoulders(body,rig)
    report['wristVertices']=stabilize_wrists(body)
    report['animations']=retarget(rig,[body,head,hair,lids])
    meshes=[body,head,hair,lids]
    for obj in meshes:
        if obj.data.shape_keys:
            for key in obj.data.shape_keys.key_blocks:key.value=0
    use_action(rig,None);clear_pose(rig)
    top=max(bounds(o)[1][2] for o in meshes)
    rig.scale=(1.7/top,)*3
    rig['character']='Fukuchan';rig['version']='v2_20260913'
    rig['reference']='02_CHARACTERS/Fukuchan.jpg'
    rig['workflow']='https://www.tripo3d.ai/blog/gpt-6-astra-3d-character-workflow'
    bpy.context.view_layer.update()
    report['heightM']=max(bounds(o)[1][2] for o in meshes)
    report['meshStats']={o.name:{'vertices':len(o.data.vertices),'triangles':sum(len(p.vertices)-2 for p in o.data.polygons),'morphs':list(o.data.shape_keys.key_blocks.keys())[1:] if o.data.shape_keys else []} for o in meshes}
    report['bones']=list(rig.data.bones.keys())
    studio()
    bpy.ops.object.select_all(action='DESELECT')
    for o in [rig,*meshes]:o.select_set(True)
    bpy.context.view_layer.objects.active=rig
    bpy.context.scene.frame_start=0;bpy.context.scene.frame_end=90
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'fukuchan_v2.blend'))
    target=OUT/'fukuchan_v2.glb'
    bpy.ops.export_scene.gltf(filepath=str(target),export_format='GLB',use_selection=True,
        export_animations=True,export_animation_mode='ACTIONS',export_frame_range=False,
        export_anim_slide_to_zero=True,export_anim_single_armature=True,
        export_skins=True,export_all_influences=False,export_def_bones=False,
        export_force_sampling=True,export_morph_animation=False,export_extras=True)
    report['glb']={'bytes':target.stat().st_size,'sha256':hashlib.sha256(target.read_bytes()).hexdigest()}
    (OUT/'assembly_report.json').write_text(json.dumps(report,indent=2)+'\n')
    print('FUKUCHAN_V2_BUILD_DONE',report['glb'],flush=True)

if __name__=='__main__':main()
