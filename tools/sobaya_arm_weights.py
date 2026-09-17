"""Surface-distance arm weights for Sobaya v3; apply once to baseline weights.

Preserves mesh, UVs, bones and actions. Surface distances include coincident
UV seams; disconnected surface islands sample the same continuous field.
"""
import math
from sobaya_pelvis_weights import smooth


def correct_arm_weights(body):
    before = [tuple((g.group, g.weight) for g in v.groups) for v in body.data.vertices]
    for v in body.data.vertices:
     x,y,z=v.co
     if not 1.0<z<1.30:continue
     side='Left' if x>0 else 'Right';a=side+'Arm';f=side+'ForeArm';old={body.vertex_groups[g.group].name:g.weight for g in v.groups};total=old.get(a,0)+old.get(f,0)
     if total<.5:continue
     # Narrow blend at anatomical elbow, retaining arm/torso influence.
     upper=smooth((z-1.09)/.08)
     body.vertex_groups[a].add([v.index],upper*total,'REPLACE');body.vertex_groups[f].add([v.index],(1-upper)*total,'REPLACE')
    import heapq
    adj=[[] for _ in body.data.vertices]
    for e in body.data.edges:
     i,j=e.vertices;length=(body.data.vertices[i].co-body.data.vertices[j].co).length;adj[i].append((j,length));adj[j].append((i,length))
    from mathutils.kdtree import KDTree
    kd=KDTree(len(body.data.vertices))
    for v in body.data.vertices:kd.insert(v.co,v.index)
    kd.balance()
    for v in body.data.vertices:
     for co,j,d in kd.find_range(v.co,.0002):
      if j!=v.index:adj[v.index].append((j,d))
    def distances(seeds):
     dist=[float('inf')]*len(adj);q=[]
     for i in seeds:dist[i]=0;heapq.heappush(q,(0,i))
     while q:
      d,i=heapq.heappop(q)
      if d!=dist[i]:continue
      for j,l in adj[i]:
       if d+l<dist[j]:dist[j]=d+l;heapq.heappush(q,(d+l,j))
     return dist
    arms=distances([v.index for v in body.data.vertices if 1.04<v.co.z<1.12 and abs(v.co.x)>.31])
    torso=distances([v.index for v in body.data.vertices if 1.1<v.co.z<1.4 and abs(v.co.x)<.12])
    finite=[v for v in body.data.vertices if math.isfinite(arms[v.index]+torso[v.index])]
    field=KDTree(len(finite))
    for v in finite:field.insert(v.co,v.index)
    field.balance()
    for v in body.data.vertices:
     x,y,z=v.co
     if not 1.0<z<1.50 or abs(x)<.15:continue
     old={body.vertex_groups[g.group].name:g.weight for g in v.groups};side='Left' if x>0 else 'Right';names=[side+n for n in ['Shoulder','Arm','ForeArm','Hand']];total=sum(old.get(n,0) for n in names)
     near=field.find_n(v.co,8);den=sum(1/(d*d+.0001) for co,j,d in near)
     val=sum((torso[j]-arms[j])/(d*d+.0001) for co,j,d in near)/den
     geo=smooth((val+.06)/.18)
     influence=smooth((1.34-z)/.10)*smooth((abs(x)-.18)/.075)
     mix=total+(geo-total)*influence
     aw={n:old.get(n,0)/total for n in names} if total>1e-7 else {side+'Arm':smooth((z-1.035)/.19),side+'ForeArm':1-smooth((z-1.035)/.19)}
     cw={n:w for n,w in old.items() if n not in names};ct=sum(cw.values())
     if ct<1e-6:cw={'Spine2':1};ct=1
     weights={n:w/ct*(1-mix) for n,w in cw.items()}
     weights.update({n:w*mix for n,w in aw.items()})
     for gi in [g.group for g in v.groups]:body.vertex_groups[gi].remove([v.index])
     for n,w in weights.items():
      if w>1e-7:body.vertex_groups[n].add([v.index],w,'REPLACE')
    changed = 0
    for vertex, old in zip(body.data.vertices, before):
        weights = sorted(((g.group, g.weight) for g in vertex.groups if g.weight > 1e-7), key=lambda pair: -pair[1])[:4]
        if tuple((g.group, g.weight) for g in vertex.groups) == old:
            continue
        changed += 1
        total = sum(w for _, w in weights)
        for gi in [g.group for g in vertex.groups]:
            body.vertex_groups[gi].remove([vertex.index])
        for gi, w in weights:
            body.vertex_groups[gi].add([vertex.index], w / total, 'REPLACE')
    return {'revision': 'arm-surface-20260917', 'changedVertices': changed,
            'maxInfluences': 4, 'geometryChanged': False,
            'boneRestChanged': False, 'animationChanged': False}
