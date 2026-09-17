import bpy,numpy as np,json,sys,struct,hashlib
from pathlib import Path
P=Path(__file__).resolve().parent;sys.path.insert(0,str(P.parents[4]/'tools'))
from build_humanoid_motion import use_action,clear_pose,Body
bpy.ops.wm.open_mainfile(filepath=str(P.parent/'likeness_finish_20260917/fukuchan_final.blend'));o=next(o for o in bpy.context.scene.objects if o.type=='MESH')
orig=np.array([tuple(o.matrix_world@v.co) for v in o.data.vertices]);uv=np.array([tuple(t.uv) for t in o.data.uv_layers[0].data]);topology=[tuple(f.vertices) for f in o.data.polygons];oldm=[f.material_index for f in o.data.polygons]

face_loops=[li for f in o.data.polygons if f.material_index==10 for li in f.loop_indices if orig[o.data.loops[li].vertex_index,2]>1.50]
im=next(n.image for n in o.data.materials[10].node_tree.nodes if n.type=='TEX_IMAGE');W,H=im.size
face_xy=np.clip((uv[face_loops]*[W,H]).astype(int),[0,0],[W-1,H-1]);image_pixels=np.array(im.pixels[:],np.float32).reshape(H,W,4);face_pixels=image_pixels[face_xy[:,1],face_xy[:,0]].copy();del image_pixels
bpy.ops.wm.open_mainfile(filepath=str(P/'fukuchan_animated.blend'));o=next(o for o in bpy.context.scene.objects if o.type=='MESH');rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')

im=next(n.image for n in o.data.materials[10].node_tree.nodes if n.type=='TEX_IMAGE');image_pixels=np.array(im.pixels[:],np.float32).reshape(H,W,4);face_delta=float(np.max(abs(image_pixels[face_xy[:,1],face_xy[:,0]]-face_pixels)));del image_pixels
assert face_delta<=1/255+1e-6,face_delta
rest=np.array([tuple(o.matrix_world@v.co) for v in o.data.vertices]);assert np.array_equal(orig,rest);assert np.array_equal(uv,np.array([tuple(t.uv) for t in o.data.uv_layers[0].data]));assert topology==[tuple(f.vertices) for f in o.data.polygons]
changed=[i for i,f in enumerate(o.data.polygons) if f.material_index!=oldm[i]];assert all(oldm[i]==1 and o.data.polygons[i].material_index==10 and min(orig[j,2] for j in topology[i])>1.29 for i in changed)
assert len(rig.data.bones)==54
for v in o.data.vertices:
 assert 1<=len(v.groups)<=4 and abs(sum(g.weight for g in v.groups)-1)<1e-5
 assert all(np.isfinite(g.weight) and g.weight>0 for g in v.groups)
body=Body(rig,[o],'fukuchan');actions=list(bpy.data.actions);report={};edges=np.array([tuple(e.vertices) for e in o.data.edges]);restlen=np.linalg.norm(rest[edges[:,0]]-rest[edges[:,1]],axis=1)
for a in actions:
 use_action(rig,None);clear_pose(rig);use_action(rig,a);frames=a.frame_range;rows=[]
 for fraction in [0,.25,.5,.75,1]:
  frame=float(frames[0]+(frames[1]-frames[0])*fraction);bpy.context.scene.frame_set(int(frame),subframe=frame-int(frame));deps=bpy.context.evaluated_depsgraph_get();ev=o.evaluated_get(deps);mesh=ev.to_mesh();q=np.array([tuple(v.co) for v in mesh.vertices]);assert np.isfinite(q).all();stretch=np.linalg.norm(q[edges[:,0]]-q[edges[:,1]],axis=1)-restlen
  rows.append({'fraction':fraction,'bounds_min':q.min(0).tolist(),'bounds_max':q.max(0).tolist(),'max_edge_extension_m':float(stretch.max()),'left_sole_m':body.skin_floor('l'),'right_sole_m':body.skin_floor('r')});ev.to_mesh_clear()
 report[a.name]=rows
 if a.name=='GyunGyunPose':
  assert abs(rows[0]['right_sole_m']-.003)<.002 and rows[0]['left_sole_m']>.2
  # Reference silhouette: lifted left knee crosses in front of the right hip.
  assert rig.pose.bones['LeftLeg'].head.x < rig.pose.bones['RightUpLeg'].head.x
use_action(rig,None);clear_pose(rig)
b=(P/'fukuchan.glb').read_bytes();magic,version,length=struct.unpack_from('<4sII',b);assert magic==b'glTF' and version==2 and length==len(b);n=struct.unpack_from('<I',b,12)[0];g=json.loads(b[20:20+n]);assert len(g['skins'])==1 and len(g['animations'])==20;assert all('bufferView' in im for im in g['images']);assert {'GyunGyun','GyunGyunPose','Idle','Walk','Run','Greeting'}<={a['name'] for a in g['animations']}
for mat in g['materials']:
 if mat['name'] in ['Front faithful skin','Natural sclera','Balanced forehead skin']:assert mat['pbrMetallicRoughness']['baseColorFactor']==[.36,.36,.36,1]
result={'face_texture_sample_max_delta':face_delta,'approved_world_vertices_exact':True,'topology_uv_exact':True,'neck_material_polygons':len(changed),'max_influences':4,'normalized_weights':True,'bones':len(rig.data.bones),'clips':len(g['animations']),'sha256':hashlib.sha256(b).hexdigest(),'bytes':len(b),'samples':report}
(P/'validation.json').write_text(json.dumps(result,indent=2)+'\n');print('VALIDATION_OK',result['sha256']);print('MAX_EDGE_EXTENSION',sorted([(k,max(s['max_edge_extension_m'] for s in v)) for k,v in report.items()],key=lambda p:-p[1])[:6])
