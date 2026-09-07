"""Deformation improvements shared by the VRM model and animation builders."""
import math
import bpy
from mathutils import Matrix
from mathutils.kdtree import KDTree


def smooth_shoulders(mesh, rig, iterations=3):
    """Local seam-aware smoothing; preserve faces, UVs, rest shape and four weights."""
    weights=[{g.group:g.weight for g in v.groups} for v in mesh.data.vertices]
    original=[dict(w) for w in weights]
    adjacency=[set() for v in mesh.data.vertices]
    for edge in mesh.data.edges:
        a,b=edge.vertices;adjacency[a].add(b);adjacency[b].add(a)
    tree=KDTree(len(mesh.data.vertices))
    for v in mesh.data.vertices:tree.insert(v.co,v.index)
    tree.balance()
    for v in mesh.data.vertices:
        matches=[j for co,j,d in tree.find_range(v.co,.00002)]
        union=set().union(*(adjacency[j] for j in matches))|set(matches)
        for j in matches:adjacency[j]=union-{j}
    transform=rig.matrix_world.inverted()@mesh.matrix_world
    active=[]
    for v in mesh.data.vertices:
        p=transform@v.co
        active.append(1.12<p.z<1.52 and abs(p.x)>.17)
    for _ in range(iterations):
        new=[]
        for v in mesh.data.vertices:
            neighbors=adjacency[v.index]
            if active[v.index] and neighbors:
                avg={}
                for j in neighbors:
                    for g,w in weights[j].items():avg[g]=avg.get(g,0)+w/len(neighbors)
                item={g:.5*weights[v.index].get(g,0)+.5*avg.get(g,0) for g in set(weights[v.index])|set(avg)}
                item=dict(sorted(item.items(),key=lambda x:-x[1])[:4]);total=sum(item.values())
                new.append({g:w/total for g,w in item.items()})
            else:new.append(weights[v.index])
        weights=new
    changed=0
    for v,w,old in zip(mesh.data.vertices,weights,original):
        if w==old:continue
        changed+=1
        for g in list(v.groups):mesh.vertex_groups[g.group].remove([v.index])
        for g,value in w.items():mesh.vertex_groups[g].add([v.index],value,'REPLACE')
    mesh.data.update()
    return changed


def stabilize_arm_twist(body, mode='bounded'):
    """Keep joint positions and hand poses; bound axial roll in the torso frame."""
    saved={b.name:b.matrix.copy() for b in body.rig.pose.bones}
    chest=body.bone('spine_03')
    torso=saved[chest.name].to_quaternion()@body.rest[chest.name].to_quaternion().inverted()
    max_change=0
    for bone in body.rig.pose.bones:
        matrix=saved[bone.name].copy();role=body.map.get(bone.name,'')
        if role.startswith(('clavicle_','upperarm_','lowerarm_')):
            next_role=('upperarm_' if role.startswith('clavicle_') else 'lowerarm_' if role.startswith('upperarm_') else 'hand_')+role[-1]
            child=body.bone(next_role)
            rest_axis=body.rest[child.name].translation-body.rest[bone.name].translation
            axis=torso.inverted()@(saved[child.name].translation-matrix.translation)
            reference=torso@rest_axis.rotation_difference(axis)@body.rest[bone.name].to_quaternion()
            if mode=='elbow_plane' and not role.startswith('clavicle_'):
                side=role[-1];upper=body.bone('upperarm_'+side);lower=body.bone('lowerarm_'+side);hand=body.bone('hand_'+side)
                a0=body.rest[lower.name].translation-body.rest[upper.name].translation
                b0=body.rest[hand.name].translation-body.rest[lower.name].translation
                a1=saved[lower.name].translation-saved[upper.name].translation
                b1=saved[hand.name].translation-saved[lower.name].translation
                n0=a0.cross(b0);n1=a1.cross(b1)
                if n0.length>1e-5 and n1.length>1e-5:
                    u0=(a0 if role.startswith('upperarm_') else b0).normalized();u1=(a1 if role.startswith('upperarm_') else b1).normalized()
                    n0.normalize();n1.normalize()
                    r0=Matrix((u0,n0,u0.cross(n0))).transposed()
                    r1=Matrix((u1,n1,u1.cross(n1))).transposed()
                    anatomical=(r1@r0.transposed()).to_quaternion()@body.rest[bone.name].to_quaternion()
                    bend=math.sin(a1.angle(b1))
                    reference=reference.slerp(anatomical,max(0,min(1,(bend-.05)/.15)))
            old=matrix.to_quaternion()
            if reference.dot(old)<0:old.negate()
            angle=reference.rotation_difference(old).angle
            limit=math.radians(10 if role.startswith('clavicle_') else 45 if role.startswith('upperarm_') else 60)
            corrected=reference if mode=='elbow_plane' and not role.startswith('clavicle_') else reference.slerp(old,min(1,limit/max(angle,1e-6)))
            max_change=max(max_change,old.rotation_difference(corrected).angle)
            matrix=Matrix.Translation(matrix.translation)@corrected.to_matrix().to_4x4()
        bone.matrix=matrix;bpy.context.view_layer.update()
    error=max((b.head-saved[b.name].translation).length for b in body.rig.pose.bones)
    return {'maxJointDriftM':error,'maxRotationCorrectionDeg':math.degrees(max_change)}
