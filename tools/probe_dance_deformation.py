"""Controlled, non-destructive shoulder deformation experiments in Blender."""
import bpy,sys,json,math
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
from build_humanoid_motion import Body,use_action,clear_pose
OUT=ROOT/'.local/dance_deformation';OUT.mkdir(exist_ok=True)
report=[]
for name in ['sobaya','fukuchan']:
 bpy.ops.wm.read_factory_settings(use_empty=True);sc=bpy.context.scene;sc.render.fps=30
 bpy.ops.import_scene.gltf(filepath=str(ROOT/f'.local/dance_deformation/baseline/characters/{name}.vrm'))
 rig=next(o for o in sc.objects if o.type=='ARMATURE');meshes=[o for o in sc.objects if o.type=='MESH']
 bpy.ops.import_scene.gltf(filepath=str(ROOT/f'.local/vrm-validation/{name}_baseline_motions.glb'))
 for o in list(sc.objects):
  if o.type=='ARMATURE' and o!=rig:bpy.data.objects.remove(o,do_unlink=True)
 for o in sc.objects:
  if o.animation_data:
   for t in list(o.animation_data.nla_tracks):o.animation_data.nla_tracks.remove(t)
 use_action(rig,None);clear_pose(rig);body=Body(rig,meshes,name)
 original={m.name:[{g.group:g.weight for g in v.groups} for v in m.data.vertices] for m in meshes}
 sc.render.engine='CYCLES';sc.cycles.samples=8;sc.cycles.use_denoising=True;sc.render.resolution_x=480;sc.render.resolution_y=480;sc.render.resolution_percentage=100
 sc.world=bpy.data.worlds.new('World');sc.world.use_nodes=True;sc.world.node_tree.nodes['Background'].inputs[0].default_value=(.22,.25,.28,1)
 def aim(o,p):o.rotation_euler=(Vector(p)-o.location).to_track_quat('-Z','Y').to_euler()
 d=bpy.data.lights.new('Softbox','AREA');d.energy=650;d.size=4;o=bpy.data.objects.new('Softbox',d);sc.collection.objects.link(o);o.location=(-3,-4,5);aim(o,(0,0,1))
 camera=bpy.data.objects.new('Camera',bpy.data.cameras.new('Camera'));sc.collection.objects.link(camera);sc.camera=camera;camera.data.type='ORTHO';camera.data.ortho_scale=1.45;camera.location=(3,-5,3.6);aim(camera,(0,0,1.25))
 for clip,seconds in [('Dance_Charleston',0),('Dance_Body_Roll',2.37),('Dance_Body_Roll',.84)]:
  use_action(rig,bpy.data.actions['Library_'+clip]);frame=seconds*30;sc.frame_set(int(frame),subframe=frame%1)
  saved={b.name:b.matrix.copy() for b in rig.pose.bones}
  use_action(rig,None)
  for variant in (sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else ['baseline','dual_quaternion','smooth_weights','swing_only','clavicle_twist','pivot_offset','combined','shoulder_weights']):
   for b in rig.pose.bones:
    b.matrix=saved[b.name];bpy.context.view_layer.update()
   bpy.context.view_layer.update()
   for m in meshes:
    for mod in m.modifiers:
     if mod.type=='ARMATURE':mod.use_deform_preserve_volume=variant=='dual_quaternion'
    for v,weights in zip(m.data.vertices,original[m.name]):
     for g in list(v.groups):m.vertex_groups[g.group].remove([v.index])
     for g,w in weights.items():m.vertex_groups[g].add([v.index],w,'REPLACE')
    m.data.update()
    if variant in ['smooth_weights','combined']:
     # Smooth only the shoulder/upper-arm region, retaining normalization.
     adjacency=[set() for v in m.data.vertices]
     for e in m.data.edges:
      a,b=e.vertices;adjacency[a].add(b);adjacency[b].add(a)
     from mathutils.kdtree import KDTree
     tree=KDTree(len(m.data.vertices))
     for v in m.data.vertices:tree.insert(v.co,v.index)
     tree.balance()
     for v in m.data.vertices:
      matches=[j for co,j,d in tree.find_range(v.co,.00002)]
      union=set().union(*(adjacency[j] for j in matches))|set(matches)
      for j in matches:adjacency[j]=union-{j}
     weights=original[m.name]
     for iteration in range(5):
      new=[]
      for v in m.data.vertices:
       world=m.matrix_world@v.co;neighbors=adjacency[v.index]
       if 1.12<world.z<1.52 and abs(world.x)>.17 and neighbors:
        avg={}
        for j in neighbors:
         for g,w in weights[j].items():avg[g]=avg.get(g,0)+w/len(neighbors)
        item={g:.5*weights[v.index].get(g,0)+.5*avg.get(g,0) for g in set(weights[v.index])|set(avg)}
        item=dict(sorted(item.items(),key=lambda x:-x[1])[:4]);total=sum(item.values());new.append({g:w/total for g,w in item.items()})
       else:new.append(weights[v.index])
      weights=new
     for v,w in zip(m.data.vertices,weights):
      for g in list(v.groups):m.vertex_groups[g.group].remove([v.index])
      for g,value in w.items():m.vertex_groups[g].add([v.index],value,'REPLACE')
    if variant=='shoulder_weights':
     for v in m.data.vertices:
      weights={m.vertex_groups[g.group].name:g.weight for g in v.groups};p=rig.matrix_world.inverted()@m.matrix_world@v.co
      side='l' if p.x>0 else 'r';shoulder=body.inverse['clavicle_'+side];upper=body.inverse['upperarm_'+side]
      w=weights.get(shoulder,0);blend=max(0,min(1,(abs(p.x)-.16)/.13))
      weights[shoulder]=w*(1-blend);weights[upper]=weights.get(upper,0)+w*blend
      for g in list(v.groups):m.vertex_groups[g.group].remove([v.index])
      for n,w in weights.items():
       if w>1e-6:m.vertex_groups[n].add([v.index],w,'REPLACE')
    m.data.update()
   bpy.context.view_layer.update()
   if variant in ['swing_only','clavicle_twist','pivot_offset','combined','shoulder_weights']:
    chest=body.bone('spine_03');chest_delta=saved[chest.name].to_quaternion()@body.rest[chest.name].to_quaternion().inverted()
    for b in rig.pose.bones:
     matrix=saved[b.name].copy();role=body.map.get(b.name,'')
     if (role.startswith(('upperarm_','lowerarm_')) and variant in ['swing_only','combined','pivot_offset']) or (role.startswith('clavicle_') and variant in ['clavicle_twist','combined']):
      child_role=('upperarm_' if role.startswith('clavicle_') else 'lowerarm_' if role.startswith('upperarm_') else 'hand_')+role[-1];child=body.bone(child_role)
      rest_axis=body.rest[child.name].translation-body.rest[b.name].translation
      axis=chest_delta.inverted()@(saved[child.name].translation-matrix.translation)
      q=chest_delta@rest_axis.rotation_difference(axis)@body.rest[b.name].to_quaternion()
      if variant=='combined' and not role.startswith('clavicle_'):
       old=matrix.to_quaternion();angle=q.rotation_difference(old).angle
       q=q.slerp(old,min(1,math.radians(45 if role.startswith('upperarm_') else 60)/max(angle,1e-6)))
      if variant=='pivot_offset':
       delta=Vector((.025 if role.endswith('_l') else -.025,0,-.02))
       q=matrix.to_quaternion()
       skin=matrix.to_quaternion()@body.rest[b.name].to_quaternion().inverted()
       matrix.translation+=chest_delta@delta-skin@delta
      else:matrix=Matrix.Translation(matrix.translation)@q.to_matrix().to_4x4()
     b.matrix=matrix;bpy.context.view_layer.update()
   if variant in ['adopted','strong_weights']:
    from humanoid_deformation import smooth_shoulders,stabilize_arm_twist
    for m in meshes:smooth_shoulders(m,rig,15 if variant=='strong_weights' else 3)
    stabilize_arm_twist(body)
   if variant=='elbow_plane':
    from humanoid_deformation import stabilize_arm_twist
    stabilize_arm_twist(body,'elbow_plane')
   sc.render.filepath=str(OUT/f'{name}_{clip}_{seconds:.2f}_{variant}.png');bpy.ops.render.render(write_still=True)
   report.append({'character':name,'clip':clip,'seconds':seconds,'variant':variant,'image':str(Path(sc.render.filepath).relative_to(ROOT)),'jointDriftM':max((b.head-saved[b.name].translation).length for b in rig.pose.bones)})
(OUT/'controlled-experiments.json').write_text(json.dumps(report,indent=2)+'\n')
