"""Fit a light-independent black face immediately behind Sobaya's mask openings."""
import math
from pathlib import Path
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

def add_black_backing(head):
    mesh=head.data
    uv=mesh.uv_layers.active.data
    im=next(n.image for n in mesh.materials[0].node_tree.nodes
            if n.type=='TEX_IMAGE' and n.image and Path(n.image.filepath).stem.lower()=='color')
    pixels=np.empty(len(im.pixels),np.float32)
    im.pixels.foreach_get(pixels)
    pixels=pixels.reshape((im.size[1],im.size[0],4))
    colors=[]
    for p in mesh.polygons:
        t=sum((uv[i].uv for i in p.loop_indices),Vector((0,0)))/len(p.loop_indices)
        colors.append(pixels[int(t.y*im.size[1])%im.size[1],int(t.x*im.size[0])%im.size[0],:3].copy())
    tree=BVHTree.FromPolygons([v.co for v in mesh.vertices],[list(p.vertices) for p in mesh.polygons])
    # These positions are in the assembled C-reference head, in metres.
    regions=[('LeftEye',.044,1.643,.027,.027),('RightEye',-.044,1.643,.027,.027),('Mouth',0.,1.565,.032,.012)]
    black=bpy.data.materials.new('MaskBlackBacking')
    black.use_nodes=True;black.diffuse_color=(0,0,0,1);black.use_backface_culling=False
    nodes=black.node_tree.nodes;nodes.clear()
    # A color socket directly into Surface is Blender's glTF-exportable
    # shadeless setup. A bare black Emission shader is not exported as unlit.
    output=nodes.new('ShaderNodeOutputMaterial');color=nodes.new('ShaderNodeRGB')
    color.outputs['Color'].default_value=(0,0,0,1)
    black.node_tree.links.new(color.outputs['Color'],output.inputs['Surface'])
    black['purpose']='Pure black face behind mask; zero reflection and no cavity lighting'
    index=len(mesh.materials);mesh.materials.append(black)
    recolored=0
    for p,rgb in zip(mesh.polygons,colors):
        if p.material_index!=0:continue
        co=sum((mesh.vertices[i].co for i in p.vertices),Vector())/len(p.vertices)
        eye=.013<abs(co.x)<.079 and 1.608<co.z<1.673
        mouth=abs(co.x)<.035 and 1.538<co.z<1.581
        if co.y<-.03 and (eye or mouth) and max(rgb)<.30:
            p.material_index=index;recolored+=1
    vertices=[];faces=[];report=[]
    for name,cx,cz,rx,rz in regions:
        samples=[]
        for i in range(64):
            a=i*math.tau/64;u=1.25*math.cos(a);v=1.25*math.sin(a)
            hit,normal,idx,distance=tree.ray_cast(Vector((cx+rx*u,-.4,cz+rz*v)),Vector((0,1,0)))
            if hit is not None and max(colors[idx])>.35 and hit.y<-.045:
                samples.append(([1,u,v],hit.y))
        if len(samples)<12:raise ValueError('Insufficient mask rim samples: '+name)
        coeff=np.linalg.lstsq(np.array([s[0] for s in samples]),np.array([s[1] for s in samples]),rcond=None)[0]
        def point(u,v):
            # +Y is behind the mask. Keep a thin reveal instead of a deep bowl.
            y=float(np.dot(coeff,[1,u,v]))+.0015
            x,z=cx+rx*u,cz+rz*v
            hit,normal,idx,distance=tree.ray_cast(Vector((x,-.4,z)),Vector((0,1,0)))
            # Follow the cover wherever the shallow plane would pierce it.
            # Use geometric depth rather than a polygon's mean texture color:
            # boundary polygons contain both the dark opening and white lip.
            # Only the deep cavity is filled; the nearby cover stays in front.
            if hit is not None and hit.y<y+.010:
                y=max(y,hit.y+.002)
            return (x,y,z)
        center=len(vertices);vertices.append(point(0,0))
        # Dense radial rings follow the white lip without poking through it.
        # The original opening controls the visible outline.
        segments=96;rings=12
        for j in range(1,rings+1):
            radius=j/rings*1.12
            for i in range(segments):
                a=i*math.tau/segments;vertices.append(point(radius*math.cos(a),radius*math.sin(a)))
        for i in range(segments):faces.append((center,center+1+i,center+1+(i+1)%segments))
        for j in range(rings-1):
            start=center+1+j*segments
            for i in range(segments):
                a=start+i;b=start+(i+1)%segments;faces.append((a,a+segments,b+segments,b))
        report.append({'opening':name,'rimSamples':len(samples),'behindMaskM':.0015,'center':[cx,cz],'surfaceCoefficients':coeff.tolist()})
    data=bpy.data.meshes.new('BlackFaceBehindMask');data.from_pydata(vertices,[],faces);data.update()
    backing=bpy.data.objects.new('BlackFaceBehindMask',data);bpy.context.collection.objects.link(backing)
    data.materials.append(black)
    bpy.ops.object.select_all(action='DESELECT');head.select_set(True);backing.select_set(True)
    bpy.context.view_layer.objects.active=head;bpy.ops.object.join()
    head['blackBacking']='Eye and mouth openings backed 1.5mm under mask, constant black unlit material'
    return {'material':'MaskBlackBacking','cavityFacesRecolored':recolored,'backingVertices':len(vertices),'backingFaces':len(faces),'openings':report}
