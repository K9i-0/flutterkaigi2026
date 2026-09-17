import bpy,sys,json
from pathlib import Path
from mathutils import Matrix,Vector
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'tools'))
from sobaya_v2_common import studio
out=root/'04_GAME_ASSETS/3d/print/sobaya_150mm_20260918'
for variant in ['color','solid']:
 bpy.ops.wm.open_mainfile(filepath=str(out/f'sobaya_150mm_{variant}_quote.blend'))
 if variant=='solid':
  ob=next(o for o in bpy.context.scene.objects if o.type=='MESH'); adj=[[] for _ in ob.data.vertices]
  for e in ob.data.edges:
   a,b=e.vertices;adj[a].append(b);adj[b].append(a)
  seen=set();comps=[]
  for i in range(len(adj)):
   if i in seen:continue
   stack=[i];seen.add(i);n=0
   while stack:
    v=stack.pop();n+=1
    for u in adj[v]:
     if u not in seen:seen.add(u);stack.append(u)
   comps.append(n)
  print('CONNECTED_COMPONENTS',sorted(comps,reverse=True),flush=True)
  assert len(comps)==1, 'Quote solid must have one connected component'
 for o in list(bpy.context.scene.objects):o.matrix_world=Matrix.Scale(.012,4)@o.matrix_world
 studio();s=bpy.context.scene;s.cycles.samples=12;s.render.resolution_x=800;s.render.resolution_y=800
 target=Vector((0,0,.9));s.camera.location=target+Vector((-1,-4,1));s.camera.rotation_euler=(target-s.camera.location).to_track_quat('-Z','Y').to_euler();s.camera.data.ortho_scale=2.15
 s.render.filepath=str(out/f'preview_{variant}.png');bpy.ops.render.render(write_still=True)
