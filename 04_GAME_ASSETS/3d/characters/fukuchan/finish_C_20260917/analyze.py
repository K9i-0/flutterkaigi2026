import numpy as np,json
from pathlib import Path
p=Path(__file__).resolve().parent
x=np.load(p/'source_mesh.npz');P=x['positions'];T=x['triangles']
U,inv=np.unique(np.round(P,6),axis=0,return_inverse=True)
adj=[set() for _ in U]
for tri in inv[T]:
 for a,b in [(tri[0],tri[1]),(tri[1],tri[2]),(tri[2],tri[0])]:adj[a].add(b);adj[b].add(a)
seen=set();comps=[]
for i in range(len(U)):
 if i in seen:continue
 ids=[];q=[i];seen.add(i)
 while q:
  j=q.pop();ids.append(j)
  for k in adj[j]:
   if k not in seen:seen.add(k);q.append(k)
 comps.append(ids)
comps.sort(key=len,reverse=True)
for ids in comps[:15]:
 pts=U[ids];print('COMP',len(ids),pts.min(0).tolist(),pts.max(0).tolist())
for z in [1.44,1.48,1.54,1.60,1.63]:
 pts=P[(abs(P[:,2]-z)<.008)&(abs(P[:,0])<.06)];print('SLICE',z,pts.min(0).tolist(),pts.max(0).tolist())
