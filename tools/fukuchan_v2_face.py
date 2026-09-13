"""Local lip geometry, smile and fitted deforming eyelids for the v2 head.

Eyelids use a median color sampled on the adjacent lid skin. They cover the
generated eyes continuously; the asset does not claim independent eye tracking.
"""
import math
import bpy
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
from mathutils.geometry import barycentric_transform

def add_face(head,rig):
    import fukuchan_head_speech as speech
    speech.MOUTH=1.516
    speech.WIDTH=.0335
    report=speech.add_head_speech(head)
    smile=head.shape_key_add(name='Smile',from_mix=False)
    for i,v in enumerate(head.data.vertices):
        x,y,z=v.co
        front=max(0,min(1,(-y-.060)/.025))
        weight=math.exp(-((abs(x)-.026)/.017)**2-((z-1.516)/.023)**2)*front
        smile.data[i].co.z+=.0032*weight
        smile.data[i].co.x+=math.copysign(.0018*weight,x)
    smile.value=0
    head.data.calc_loop_triangles()
    triangles=[tuple(t.vertices) for t in head.data.loop_triangles]
    tree=BVHTree.FromPolygons([v.co for v in head.data.vertices],triangles,all_triangles=True)
    uvdata=head.data.uv_layers.active.data
    uvs=[[uvdata[i].uv.copy() for i in t.loops] for t in head.data.loop_triangles]
    def surface(x,z):
        point,normal,index,_=tree.ray_cast(Vector((x,-.5,z)),Vector((0,1,0)),.65)
        assert point is not None,('Eyelid ray missed',x,z)
        points=[head.data.vertices[i].co for i in triangles[index]]
        coords=[Vector((u.x,u.y,0)) for u in uvs[index]]
        uv=barycentric_transform(point,*points,*coords).xy
        return point,uv
    points=[];closed=[];tex=[];faces=[];sides=[]
    # Landmarks measured in the neutral orthographic render, in metres.
    specs=[('Left',.0355,1.5933,.0190,.0070),('Right',-.0330,1.5923,.0190,.0075)]
    rows=13
    for side,cx,cz,rx,rz in specs:
        for upper in (True,False):
            start=len(points)
            for i in range(33):
                t=i/32;u=2*t-1;x=cx+rx*u
                arc=math.sin(math.pi*t)**.75
                tilt=.0010*u*(1 if cx>0 else -1)
                high=cz+rz*arc+tilt
                low=cz-rz*.78*arc+tilt
                seam=cz-rz*.17*arc+tilt
                outer=high if upper else low
                for j in range(rows):
                    v=j/(rows-1)
                    # Narrow real strip at rest, expands to meet the opposing lid.
                    rest_z=outer+(-.00012*v if upper else .00012*v)*arc
                    end_z=outer+(seam-outer)*v
                    a,_=surface(x,rest_z);b,_=surface(x,end_z)
                    a.y-=.0005;b.y-=.0024
                    # Sample adjacent skin, never stretch an iris across the lid.
                    _,uv=surface(x,cz+(.013+.001*v)*(1 if upper else -1))
                    points.append(a);closed.append(b);tex.append(uv);sides.append(side)
            for i in range(32):
                for j in range(rows-1):
                    a=start+i*rows+j
                    face=(a,a+rows,a+rows+1,a+1)
                    faces.append(tuple(reversed(face)) if upper else face)
    data=bpy.data.meshes.new('FukuchanV2Eyelids');data.from_pydata(points,[],faces);data.update()
    uv=data.uv_layers.new(name='UVMap')
    for p in data.polygons:
        p.use_smooth=True
        for li in p.loop_indices:uv.data[li].uv=tex[data.loops[li].vertex_index]
    obj=bpy.data.objects.new('Eyelids',data);bpy.context.collection.objects.link(obj)
    # Nearest-surface UVs may cross a generated seam between adjacent eyelid
    # vertices. Use the median sampled skin color instead of interpolating
    # unrelated UV islands across the newly created lids.
    from pathlib import Path
    import numpy as np
    im=next(n.image for n in head.data.materials[0].node_tree.nodes if n.type=='TEX_IMAGE' and n.image and Path(n.image.filepath).stem=='Color')
    pixel=np.empty(len(im.pixels),dtype=np.float32);im.pixels.foreach_get(pixel)
    pixel=pixel.reshape((im.size[1],im.size[0],4))
    samples=[pixel[int(uv.y*im.size[1])%im.size[1],int(uv.x*im.size[0])%im.size[0],:3] for uv in tex]
    tone=np.median(samples,axis=0)
    tone=[float(c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4) for c in tone]
    skin=bpy.data.materials.new('EyelidSkin');skin.use_nodes=True
    bs=skin.node_tree.nodes['Principled BSDF'];bs.inputs['Base Color'].default_value=(*tone,1);bs.inputs['Roughness'].default_value=.62
    obj.data.materials.append(skin)
    obj.shape_key_add(name='Basis')
    for name in ['Blink','BlinkLeft','BlinkRight']:
        key=obj.shape_key_add(name=name,from_mix=False)
        for i,p in enumerate(closed):
            if name=='Blink' or name=='Blink'+sides[i]:key.data[i].co=p
        key.value=0
    group=obj.vertex_groups.new(name='Head');group.add(list(range(len(points))),1,'REPLACE')
    obj.parent=rig;obj.matrix_parent_inverse=Matrix.Identity(4)
    mod=obj.modifiers.new('Skin','ARMATURE');mod.object=rig
    # Do not round-trip this mesh through bmesh after adding shape keys: its
    # reordered vertices would invalidate the explicit key coordinate mapping.
    report.update({'smile':'local lip-corner and cheek morph','eyelids':{'vertices':len(points),'targets':['Blink','BlinkLeft','BlinkRight'],'method':'fitted upper/lower surfaces, median adjacent-skin albedo, Head skinning','linearSkinColor':tone,'landmarks':specs}})
    return obj,report
