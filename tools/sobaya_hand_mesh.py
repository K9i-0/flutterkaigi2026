"""Local hand retopology with explicit segment weights; no auto-heat islands."""
import bpy,bmesh,math
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
from mathutils.geometry import barycentric_transform, closest_point_on_tri


def rebuild_hands(body,rig):
    body.data.calc_loop_triangles()
    source_positions=[v.co.copy() for v in body.data.vertices]
    source_triangles=[tuple(t.vertices) for t in body.data.loop_triangles]
    source_uv=[tuple(body.data.uv_layers.active.data[i].uv.copy() for i in t.loops) for t in body.data.loop_triangles]
    surface=BVHTree.FromPolygons(source_positions,source_triangles,all_triangles=True)
    bm=bmesh.new();bm.from_mesh(body.data)
    remove=[f for f in bm.faces if abs(f.calc_center_median().x)>.30 and .65<f.calc_center_median().z<.888]
    bmesh.ops.delete(bm,geom=remove,context='FACES');bm.to_mesh(body.data);bm.free();body.data.update()
    for v in body.data.vertices:
        if abs(v.co.x)>.30 and .88<v.co.z<.96:
            side='R' if v.co.x<0 else 'L';t=max(0,min(1,(.935-v.co.z)/.055));t=t*t*(3-2*t)
            for g in body.vertex_groups:g.remove([v.index])
            body.vertex_groups['Forearm.'+side].add([v.index],1-t,'REPLACE')
            body.vertex_groups['Hand.'+side].add([v.index],t,'REPLACE')
    mat=body.data.materials[0].copy();mat.name='Retopo hand projected PBR'
    # Reprojecting a tangent-space normal map across new UV seams creates
    # false hard facets. Reuse skin color, but use the new smooth normals.
    shader=mat.node_tree.nodes.get('Principled BSDF')
    for link in list(mat.node_tree.links):
        if link.to_node==shader and link.to_socket.name=='Normal':
            mat.node_tree.links.remove(link)
    parts=[]
    def tube(name,points,radii,weights,sides=12,flat=1):
        verts=[];faces=[];ws=[]
        for i,(point,radius,w) in enumerate(zip(points,radii,weights)):
            tangent=(points[min(i+1,len(points)-1)]-points[max(0,i-1)]).normalized()
            ref=Vector((1,0,0));u=(ref-tangent*ref.dot(tangent)).normalized();v=tangent.cross(u)
            for n in range(sides):
                a=math.tau*n/sides;verts.append(point+u*(math.cos(a)*radius)+v*(math.sin(a)*radius*flat));ws.append(w)
        for i in range(len(points)-1):
            for j in range(sides):
                a=i*sides+j;b=i*sides+(j+1)%sides;faces.append((a,b,b+sides,a+sides))
        faces.append(tuple(reversed(range(sides))));faces.append(tuple((len(points)-1)*sides+i for i in range(sides)))
        mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
        o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);mesh.materials.append(mat)
        for p in mesh.polygons:p.use_smooth=True
        for index,w in enumerate(ws):
            for group,value in w.items():
                g=o.vertex_groups.get(group) or o.vertex_groups.new(name=group)
                if value:g.add([index],value,'REPLACE')
        parts.append(o)
    for side,sign in [('R',-1),('L',1)]:
        hand=rig.data.bones['Hand.'+side];fore='Forearm.'+side;hname=hand.name
        start=hand.head_local.copy();end=hand.tail_local.copy();axis=(end-start).normalized()
        # Bridge the actual generated cut boundary to the new wrist. Merely
        # overlapping a capsule leaves a visible gap when the wrist twists.
        audit=bmesh.new();audit.from_mesh(body.data)
        edges=[e for e in audit.edges if e.is_boundary and all(sign*v.co.x>.30 and .84<v.co.z<.94 for v in e.verts)]
        adjacency={}
        for e in edges:
            a,b=e.verts
            adjacency.setdefault(a,[]).append(b);adjacency.setdefault(b,[]).append(a)
        loops=[];seen=set()
        for seed in adjacency:
            if seed in seen:continue
            loop=[];v=seed;previous=None
            while v not in seen:
                seen.add(v);loop.append(v)
                nxt=[n for n in adjacency[v] if n!=previous]
                if not nxt:break
                previous,v=v,nxt[0]
            if len(loop)>8:loops.append(loop)
        if loops:
            loop=max(loops,key=len);coords=[v.co.copy() for v in loop]
            area=sum((a.cross(b) for a,b in zip(coords,coords[1:]+coords[:1])),Vector())
            if area.dot(axis)<0:coords.reverse()
            u=Vector((1,0,0));u=(u-axis*u.dot(axis)).normalized();v=axis.cross(u)
            verts=list(coords);weights=[]
            for co in coords:
                t=max(0,min(1,(.935-co.z)/.055));t=t*t*(3-2*t);weights.append({fore:1-t,hname:t})
            rings=[(.20,.034),(.40,.041),(.70,.045),(1.0,.041),(1.11,.018)]
            for fraction,radius in rings:
                centre=start.lerp(end,fraction)
                for co in coords:
                    offset=co-start;a=math.atan2(offset.dot(v),offset.dot(u))
                    verts.append(centre+u*(math.cos(a)*radius)+v*(math.sin(a)*radius*.68))
                    weights.append({hname:1})
            n=len(coords);faces=[]
            for row in range(len(rings)):
                for i in range(n):faces.append((row*n+i,row*n+(i+1)%n,(row+1)*n+(i+1)%n,(row+1)*n+i))
            faces.append(tuple(len(rings)*n+i for i in range(n)))
            mesh=bpy.data.meshes.new('Wrist seam '+side);mesh.from_pydata(verts,[],faces);mesh.update()
            o=bpy.data.objects.new(mesh.name,mesh);bpy.context.collection.objects.link(o);mesh.materials.append(mat)
            for p in mesh.polygons:p.use_smooth=True
            for i,w in enumerate(weights):
                for name,value in w.items():
                    g=o.vertex_groups.get(name) or o.vertex_groups.new(name=name);g.add([i],value,'REPLACE')
            parts.append(o)
            print('WRIST_BRIDGE',side,n,flush=True)
        audit.free()
        if not loops:raise RuntimeError('Missing wrist boundary '+side)
        for digit,r in [('Index',.0115),('Middle',.0125),('Ring',.0115),('Little',.0095),('Thumb',.014)]:
            b1=rig.data.bones[digit+'1.'+side];b2=rig.data.bones[digit+'2.'+side]
            a=b1.head_local.copy();b=b1.tail_local.copy();c=b2.tail_local.copy()
            axis1=(b-a).normalized();axis2=(c-b).normalized()
            points=[a-axis1*.008,a,a.lerp(b,.35),a.lerp(b,.80),b,b.lerp(c,.25),b.lerp(c,.70),c,c+axis2*.003]
            radii=[r*.7,r*1.05,r,r*.98,r*1.03,r*.94,r*.82,r*.6,.001]
            weights=[{hname:.75,b1.name:.25},{hname:.4,b1.name:.6},{b1.name:1},{b1.name:1},
                     {b1.name:.5,b2.name:.5},{b2.name:1},{b2.name:1},{b2.name:1},{b2.name:1}]
            tube(digit+' retopo '+side,points,radii,weights,12)
    for o in parts:
        if 'retopo' in o.name:
            bpy.context.view_layer.objects.active=o
            modifier=o.modifiers.new('Rounded finger topology','SUBSURF');modifier.levels=1
            bpy.ops.object.modifier_apply(modifier=modifier.name)
        uv=o.data.uv_layers.new(name=body.data.uv_layers.active.name)
        # Keep every polygon inside one source UV triangle: independent
        # nearest-vertex UVs can cross atlas islands and produce stripes.
        for polygon in o.data.polygons:
            position,normal,index,distance=surface.find_nearest(polygon.center)
            a,b,c=[source_positions[i] for i in source_triangles[index]]
            ua,ub,uc=[Vector((p.x,p.y,0)) for p in source_uv[index]]
            for index in polygon.loop_indices:
                loop=o.data.loops[index];co=o.data.vertices[loop.vertex_index].co
                position=closest_point_on_tri(co,a,b,c)
                projected=barycentric_transform(position,a,b,c,ua,ub,uc)
                uv.data[index].uv=projected.xy
    bpy.ops.object.select_all(action='DESELECT');body.select_set(True)
    for o in parts:o.select_set(True)
    bpy.context.view_layer.objects.active=body;bpy.ops.object.join()
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.remove_doubles(threshold=.000001)
    bpy.ops.object.mode_set(mode='OBJECT')
