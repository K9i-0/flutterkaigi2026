"""Smooth local soft-tissue contact correction against the actual mug handle."""
import bpy
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
from sobaya_grip_shape import deform,GRIP_CENTER,MUG_ROTATION


def fit_contact(doc,values,mesh,hand,root):
    before=set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(root/'04_GAME_ASSETS/3d/props/beer_mug_v2/beer_mug.glb'))
    mug=bpy.data.objects['Handle'];grip=bpy.data.objects['Grip'];bpy.context.view_layer.update()
    transform=Matrix.Translation(GRIP_CENTER)@MUG_ROTATION.to_4x4()@grip.matrix_world.inverted()@mug.matrix_world
    surface=BVHTree.FromPolygons([transform@v.co for v in mug.data.vertices],
                                [tuple(p.vertices) for p in mug.data.polygons])
    inverse=hand.inverted();points=[];lookup={};triangles=[]
    for primitive in mesh['primitives']:
        mapping={}
        for i,position in enumerate(values(primitive['attributes']['POSITION'])):
            if position[0]>-.30 or not .68<position[1]<.99:continue
            p=inverse@Vector(position);key=tuple(round(float(x),6) for x in p)
            if key not in lookup:lookup[key]=len(points);points.append(p)
            mapping[i]=lookup[key]
        indices=values(primitive['indices']).ravel()
        for a,b,c in zip(indices[::3],indices[1::3],indices[2::3]):
            if a in mapping and b in mapping and c in mapping:
                tri=(mapping[a],mapping[b],mapping[c])
                if len(set(tri))==3:triangles.append(tri)
    neighbors=[set() for _ in points]
    for a,b,c in triangles:
        neighbors[a].update([b,c]);neighbors[b].update([a,c]);neighbors[c].update([a,b])
    unpacked=[deform(p) for p in points]
    from sobaya_grip_spacing import pack_fingers,measure_spacing
    base,finger_weights,spacing_report=pack_fingers(points,unpacked,neighbors)
    offset=[Vector() for _ in points]
    active=[]
    initial_inside=[]
    for i,p in enumerate(base):
        co,n,f,d=surface.find_nearest(p);signed=(p-co).dot(n)
        if d<.032:active.append(i)
        if signed<0:initial_inside.append(-signed)
    def normals(positions):
        result=[Vector() for _ in positions]
        for a,b,c in triangles:
            n=(positions[b]-positions[a]).cross(positions[c]-positions[a])
            for i in (a,b,c):result[i]+=n
        return [n.normalized() for n in result]
    # A constrained fairing field distributes contact corrections over a
    # roughly 2cm neighborhood; equal positions share one displacement.
    for iteration in range(90):
        next_offsets=[v.copy() for v in offset]
        for i in active:
            if neighbors[i]:
                mean=sum((offset[j] for j in neighbors[i]),Vector())/len(neighbors[i])
                next_offsets[i]=offset[i]*.30+mean*.70
        for i in active:
            p=base[i]+next_offsets[i];co,n,f,d=surface.find_nearest(p);signed=(p-co).dot(n)
            if signed<.00065 and d<.018:
                next_offsets[i]+=n*(.00065-signed)
        offset=next_offsets
    final=[p+d for p,d in zip(base,offset)]
    # Fair the tiny contact folds themselves, not the nails or the whole hand.
    trouble=set()
    for a,b,c in triangles:
        n=(base[b]-base[a]).cross(base[c]-base[a]);nn=(final[b]-final[a]).cross(final[c]-final[a])
        if n.length>1e-10 and nn.length>1e-10 and n.dot(nn)<0:trouble.update([a,b,c])
    weights={i:1. for i in trouble};front=set(trouble)
    for ring,w in [(1,.65),(2,.30),(3,.10)]:
        added={j for i in front for j in neighbors[i] if j not in weights}
        for i in added:weights[i]=w
        front=added
    for iteration in range(60):
        revised=[p.copy() for p in final]
        for i,w in weights.items():
            mean=sum((final[j] for j in neighbors[i]),Vector())/len(neighbors[i])
            revised[i]=final[i].lerp(mean,.25*w)
            co,n,f,d=surface.find_nearest(revised[i]);signed=(revised[i]-co).dot(n)
            if signed<.00065 and d<.018:revised[i]+=n*(.00065-signed)
        final=revised
    offset=[p-q for p,q in zip(final,unpacked)]
    n0=normals(unpacked);n1=normals(final);mapping={}
    for key,i in lookup.items():
        if offset[i].length>1e-7:
            mapping[key]=(offset[i],n0[i].rotation_difference(n1[i]))
    final_inside=[]
    for p in final:
        co,n,f,d=surface.find_nearest(p);signed=(p-co).dot(n)
        if signed<0:final_inside.append(-signed)
    flipped=0
    for a,b,c in triangles:
        n=(base[b]-base[a]).cross(base[c]-base[a]);nn=(final[b]-final[a]).cross(final[c]-final[a])
        if n.length>1e-10 and nn.length>1e-10 and n.dot(nn)<0:flipped+=1
    spacing_report['before']=measure_spacing(points,unpacked,triangles,finger_weights)
    spacing_report['after']=measure_spacing(points,final,triangles,finger_weights)
    report={'fingerSpacing':spacing_report,'method':'90 constrained neighbor-fairing iterations against exported Handle mesh',
            'contactClearanceM':.00065,'correctedUniqueVertices':len(mapping),
            'beforePenetratingVertices':len(initial_inside),'beforeMaxDepthM':max(initial_inside,default=0),
            'afterPenetratingVertices':len(final_inside),'afterMaxDepthM':max(final_inside,default=0),
            'maxContactDisplacementM':max(d.length for d in offset),'facesRotatedOver90Degrees':flipped,'contactFoldFairingVertices':len(weights)}
    for obj in set(bpy.data.objects)-before:bpy.data.objects.remove(obj,do_unlink=True)
    assert not final_inside,report

    return mapping,report
