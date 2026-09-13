"""Anatomical bind correction and finger skinning for the unchanged Tripo mesh.

Coordinates are measured on the v2 rest mesh (Blender Z up, face toward -Y).
Both hands have mirrored topology. No remeshing or likeness changes are made.
"""
import math
import bpy
from mathutils import Matrix, Quaternion, Vector
from mathutils.kdtree import KDTree

DIGITS = {
    'Index': [( .758,-.035,1.366),(.782,-.053,1.371),(.797,-.068,1.377),(.811,-.078,1.379)],
    'Middle':[( .760,-.030,1.345),(.789,-.055,1.347),(.810,-.075,1.348),(.825,-.085,1.348)],
    'Ring':  [( .761,-.030,1.323),(.786,-.051,1.324),(.806,-.071,1.326),(.821,-.083,1.327)],
    'Little':[( .758,-.027,1.308),(.773,-.041,1.305),(.786,-.054,1.302),(.796,-.065,1.300)],
    'Thumb': [( .714,-.021,1.362),(.718,-.027,1.388),(.734,-.052,1.408),(.736,-.060,1.426)],
}

def smooth(a,b,x):
    t=max(0,min(1,(x-a)/(b-a)))
    return t*t*(3-2*t)

def refine_bind(body,rig):
    bpy.context.view_layer.objects.active=rig
    bpy.ops.object.mode_set(mode='EDIT')
    bones=rig.data.edit_bones
    before={b.name:list(b.head) for b in bones}
    # The headless auto-rig had a lateral torso tilt and unequal clavicles.
    centers={'Root':(0,0,0),'Hips':(0,.008,.80),'Spine':(0,.012,.925),
             'Spine1':(0,.014,1.072),'Spine2':(0,.015,1.22)}
    for name,p in centers.items():bones[name].head=p
    for a,b in [('Hips','Spine'),('Spine','Spine1'),('Spine1','Spine2'),('Spine2','Neck')]:
        bones[a].tail=bones[b].head
    bones['Root'].tail=(0,0,.15)
    for side,sign,suffix in [('Left',1,'L'),('Right',-1,'R')]:
        points=[(0,.012,1.35),(sign*.185,.012,1.34),(sign*.440,.008,1.325),
                (sign*.695,-.014,1.337),(sign*.757,-.030,1.340)]
        for i,part in enumerate(['Shoulder','Arm','ForeArm','Hand']):
            bone=bones[side+part];bone.head=points[i];bone.tail=points[i+1]
            bone.align_roll(Vector((0,-1,0)))
        thigh=bones[side+'UpLeg'];calf=bones[side+'Leg']
        thigh.head=(sign*.096,-.005,.80);thigh.tail=(sign*.135,.005,.419)
        calf.head=thigh.tail;calf.tail=bones[side+'Foot'].head
        for digit,coords in DIGITS.items():
            parent=bones[side+'Hand']
            for i in range(3):
                bone=bones.new(f'{digit}{i+1}.{suffix}')
                bone.head=(sign*coords[i][0],coords[i][1],coords[i][2])
                bone.tail=(sign*coords[i+1][0],coords[i+1][1],coords[i+1][2])
                bone.parent=parent;bone.use_connect=i>0
                bone.align_roll(Vector((0,-1,0)));parent=bone
    bpy.ops.object.mode_set(mode='OBJECT')
    for p in rig.pose.bones:p.rotation_mode='QUATERNION'
    changed=0
    for v in body.data.vertices:
        x=abs(v.co.x)
        if x<.15 or v.co.z<1.17:continue
        side='Left' if v.co.x>0 else 'Right'
        arm=smooth(.15,.27,x);fore=smooth(.397,.485,x);hand=smooth(.675,.720,x)
        weights={'Spine2':1-arm,side+'Arm':arm*(1-fore),side+'ForeArm':arm*fore*(1-hand),side+'Hand':arm*fore*hand}
        for g in list(v.groups):body.vertex_groups[g.group].remove([v.index])
        for n,w in weights.items():
            if w>1e-6:body.vertex_groups[n].add([v.index],w,'REPLACE')
        changed+=1
    return {'jointHeadsBefore':before,'jointHeadsAfter':{b.name:list(b.head_local) for b in rig.data.bones},'armVertices':changed}

def skin_fingers(body,rig):
    paths={d:[Vector(p) for p in points] for d,points in DIGITS.items()}
    for suffix in ['L','R']:
        for digit in paths:
            for i in range(1,4):body.vertex_groups.new(name=f'{digit}{i}.{suffix}')
    count=0
    for v in body.data.vertices:
        p=Vector((abs(v.co.x),v.co.y,v.co.z))
        if p.x<.705 or p.z<1.28:continue
        # Choose the digit in the palm plane; depth does not cross-assign fingers.
        candidates=[]
        for digit,points in paths.items():
            best=(1e9,0.)
            length=0.
            for a,b in zip(points,points[1:]):
                ab=b-a;t=max(0,min(1,(p-a).dot(ab)/ab.length_squared));q=a+ab*t
                distance=math.hypot(p.x-q.x,p.z-q.z)
                if distance<best[0]:best=(distance,length+t*ab.length)
                length+=ab.length
            candidates.append((best[0],digit,best[1]))
        _,digit,along=min(candidates)
        points=paths[digit]
        influence=smooth(1.365,1.391,p.z) if digit=='Thumb' else smooth(.746,.772,p.x)
        if influence<1e-6:continue
        lengths=[(b-a).length for a,b in zip(points,points[1:])]
        w2=smooth(lengths[0]-.007,lengths[0]+.007,along)
        w3=smooth(sum(lengths[:2])-.005,sum(lengths[:2])+.005,along)
        suffix='L' if v.co.x>0 else 'R';side='Left' if v.co.x>0 else 'Right'
        weights={side+'Hand':1-influence,f'{digit}1.{suffix}':influence*(1-w2),
                 f'{digit}2.{suffix}':influence*w2*(1-w3),f'{digit}3.{suffix}':influence*w2*w3}
        for g in list(v.groups):body.vertex_groups[g.group].remove([v.index])
        for n,w in weights.items():
            if w>1e-6:body.vertex_groups[n].add([v.index],w,'REPLACE')
        count+=1
    # Weld UV-duplicate vertices for weight diffusion. Otherwise nearby points
    # can choose opposite sides of a digit boundary and tear into spikes.
    adjacency=[set() for _ in body.data.vertices]
    for edge in body.data.edges:
        a,b=edge.vertices;adjacency[a].add(b);adjacency[b].add(a)
    tree=KDTree(len(body.data.vertices))
    for v in body.data.vertices:tree.insert(v.co,v.index)
    tree.balance()
    active=[v.index for v in body.data.vertices if abs(v.co.x)>.707 and v.co.z>1.28]
    for i in active:
        matches=[j for _,j,_ in tree.find_range(body.data.vertices[i].co,.00003)]
        neighbors=set().union(*(adjacency[j] for j in matches))|set(matches)
        for j in matches:adjacency[j]=neighbors-{j}
    weights=[{g.group:g.weight for g in v.groups} for v in body.data.vertices]
    for _ in range(5):
        revised=list(weights)
        for i in active:
            neighbors=adjacency[i]
            if not neighbors:continue
            w={g:value*.5 for g,value in weights[i].items()}
            for j in neighbors:
                for g,value in weights[j].items():w[g]=w.get(g,0)+.5*value/len(neighbors)
            w=dict(sorted(w.items(),key=lambda item:-item[1])[:4]);total=sum(w.values())
            revised[i]={g:value/total for g,value in w.items()}
        weights=revised
    for i in active:
        for g in list(body.data.vertices[i].groups):body.vertex_groups[g.group].remove([i])
        for g,w in weights[i].items():body.vertex_groups[g].add([i],w,'REPLACE')
    return count

def orient_hand(rig,side,direction,normal):
    h=rig.pose.bones[side+'Hand'];rest=h.bone.matrix_local
    u0=(h.bone.tail_local-h.bone.head_local).normalized()
    n0=Vector((0,-1,0));n0=(n0-u0*n0.dot(u0)).normalized()
    u1=Vector(direction).normalized();n1=Vector(normal);n1=(n1-u1*n1.dot(u1)).normalized()
    a=Matrix((u0,n0,u0.cross(n0))).transposed();b=Matrix((u1,n1,u1.cross(n1))).transposed()
    h.matrix=Matrix.Translation(h.head)@(b@a.transposed()@rest.to_3x3()).to_4x4()
    bpy.context.view_layer.update()

def fingers(rig,amount,trigger=False):
    for suffix in ['L','R']:
        for digit in DIGITS:
            angles=[45,65,35] if digit=='Thumb' else [45,78,42]
            if trigger and suffix=='R' and digit=='Index':angles=[8,30,12]
            for i,angle in enumerate(angles):
                b=rig.pose.bones.get(f'{digit}{i+1}.{suffix}')
                if b:b.rotation_quaternion=Quaternion((1,0,0),math.radians(angle)*amount)

def finish_pose(body,name,t=0.):
    """Palms and grip are authored in the target's anatomical frame."""
    rig=body.rig
    # Scapulohumeral rhythm: the clavicle participates above shoulder height.
    # Keep the already-authored wrist target with a second two-bone solve.
    for side,sign,short in [('Right',-1,'r'),('Left',1,'l')]:
        arm=rig.pose.bones[side+'Arm'];fore=rig.pose.bones[side+'ForeArm'];hand=rig.pose.bones[side+'Hand']
        goal=hand.head.copy();pole=fore.head-(arm.head+goal)*.5;hand_rotation=hand.matrix.to_quaternion()
        lift=math.radians(26)*smooth(.08,.43,goal.z-arm.head.z)
        if lift>1e-5:
            clavicle=rig.pose.bones[side+'Shoulder']
            clavicle.matrix=Matrix.Translation(clavicle.head)@Quaternion((0,1,0),-sign*lift).to_matrix().to_4x4()@clavicle.matrix.to_3x3().to_4x4()
            bpy.context.view_layer.update()
            body.ik(['upperarm_'+short,'lowerarm_'+short,'hand_'+short],goal,pole)
            hand.matrix=Matrix.Translation(hand.head)@hand_rotation.to_matrix().to_4x4()
            bpy.context.view_layer.update()
    aim=name in ['Aim','AimShotgun']
    reload=name in ['ReloadHandgun','ReloadShotgun']
    if aim:
        shotgun=name=='AimShotgun'
        goals={'Right':(-.050,-.440,1.235),'Left':(.022,-.458,1.225)}
        if shotgun:goals={'Right':(-.060,-.220,1.240),'Left':(-.015,-.525,1.315)}
        for side,sign,short in [('Right',-1,'r'),('Left',1,'l')]:
            body.ik(['upperarm_'+short,'lowerarm_'+short,'hand_'+short],Vector(goals[side]),Vector((sign*.4,.1,-1)))
            orient_hand(rig,side,(0,-1,-.08),(0,0,1) if shotgun and side=='Left' else (-sign,0,0))
        fingers(rig,.93,trigger=True)
    elif reload:
        for side,sign in [('Left',1),('Right',-1)]:
            hand=rig.pose.bones[side+'Hand'];fore=rig.pose.bones[side+'ForeArm']
            orient_hand(rig,side,hand.head-fore.head,(-sign,0,0))
        fingers(rig,.65,trigger=True)
    elif name=='Test_Grip':
        for side,sign,short in [('Right',-1,'r'),('Left',1,'l')]:
            body.ik(['upperarm_'+short,'lowerarm_'+short,'hand_'+short],Vector((sign*.26,-.32,1.22)),Vector((sign*.4,0,-1)))
            orient_hand(rig,side,(0,0,1),(0,-1,0))
        fingers(rig,math.sin(math.pi*t)**2)
    elif name=='Greeting':fingers(rig,0)
    else:
        if name=='Test_ElbowBend':
            for side in ['Left','Right']:orient_hand(rig,side,(0,0,1),(0,-1,0))
        fingers(rig,.16 if name in ['Idle','Walk'] else .35 if name=='Run' else .12)
    bpy.context.view_layer.update()
