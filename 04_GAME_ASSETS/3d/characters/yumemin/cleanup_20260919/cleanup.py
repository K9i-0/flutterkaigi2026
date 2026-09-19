"""Non-destructive cleanup of the Tripo source, bake portable materials, export and verify GLB."""
from pathlib import Path
import bpy,bmesh,numpy as np,json,math
from mathutils import Vector
OUT=Path(__file__).resolve().parent
SRC=OUT.parent/'wan_multiview_20260919'
# Reuse the exact original import, orientation and scale, never the previous edited output.
template=(SRC/'render_preview.py').read_text()
exec(template[:template.index('materials = []')].replace("OUT = Path(__file__).resolve().parent","OUT = SRC"))
OUT=Path(__file__).resolve().parent;QA=OUT/'qa';QA.mkdir(exist_ok=True)
o=meshes[0];m=o.data
bm=bmesh.new();bm.from_mesh(m);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-5);bm.to_mesh(m);bm.free()
# Original eye caps are disconnected shells: remove them instead of leaving overlapping surfaces.
bm=bmesh.new();bm.from_mesh(m)
seen=set();remove=[]
for v in bm.verts:
 if v in seen:continue
 todo=[v];seen.add(v);comp=[]
 while todo:
  a=todo.pop();comp.append(a)
  for ed in a.link_edges:
   b=ed.other_vert(a)
   if b not in seen:seen.add(b);todo.append(b)
 if len(comp)<1500 and max(v.co.y for v in comp)<-.30:remove.extend(comp)
bmesh.ops.delete(bm,geom=remove,context='VERTS');bm.to_mesh(m);bm.free()
xyz=np.array([v.co[:] for v in m.vertices]);original=xyz.copy()
adj=[set() for v in m.vertices]
for e in m.edges:
 a,b=e.vertices;adj[a].add(b);adj[b].add(a)
# Smooth the body and eye surrounds; restrained smoothing on ears/nose/tail.
x,y,z=xyz.T
feature=((z>.83)&(abs(x)>.16))|((y<-.48)&(z<.43))|(y>.46)
weights=np.where(feature,.12,.48)
for step in range(22):
 avg=np.array([xyz[list(a)].mean(axis=0) if a else xyz[i] for i,a in enumerate(adj)])
 xyz+=(avg-xyz)*weights[:,None]
# Fit only the broad body, reject protruding nose, eyes, ears and tail.
mask=(z>.18)&(z<.80)&(y>-.36)&(y<.38)
A=np.column_stack([2*original[mask],np.ones(mask.sum())]);b=(original[mask]**2).sum(axis=1)
sol=np.linalg.lstsq(A,b,rcond=None)[0];center=sol[:3];radius=np.sqrt(sol[3]+(center**2).sum())
# Only the small central crown bump is rounded into the underlying body.
for i,p in enumerate(xyz):
 if abs(p[0])<.16 and p[2]>.90:
  d=p-center;target=center+d/np.linalg.norm(d)*radius
  w=max(0,1-abs(p[0])/.16)*min(1,(p[2]-.90)/.04)
  xyz[i]=p*(1-w)+target*w
# Rebuild only the wrinkled eye support surfaces with local quadratic patches.
eye_specs=[]
for cx in [-.230,.230]:
 dx=xyz[:,0]-cx;dz=xyz[:,2]-.514
 rr=(dx/.067)**2+(dz/.071)**2
 ann=(rr>2.2)&(rr<5.5)&(xyz[:,1]<-.32)
 basis=lambda a,b:np.column_stack([np.ones(len(a)),a,b,a*a,a*b,b*b])
 coeff=np.linalg.lstsq(basis(dx[ann],dz[ann]),xyz[ann,1],rcond=None)[0]
 support=(rr<3.5)&(xyz[:,1]<-.32)
 target_y=basis(dx,dz)@coeff
 w=np.clip((3.5-rr)/1.9,0,1)
 xyz[support,1]=xyz[support,1]*(1-w[support])+target_y[support]*w[support]
 eye_specs.append((cx,float(coeff[0]),.514,float(coeff[1]),float(coeff[2])))
for v,p in zip(m.vertices,xyz):v.co=p
m.update()
for p in m.polygons:p.use_smooth=True
mat=m.materials[0];nodes=mat.node_tree.nodes;links=mat.node_tree.links
tex=next(n for n in nodes if n.type=='TEX_IMAGE' and ('color' in n.image.name.lower() or 'color' in Path(n.image.filepath).stem.lower()))
img=tex.image
nodes.clear()
def node(t):return nodes.new(t)
def mathnode(op,a,b=None):
 n=node('ShaderNodeMath');n.operation=op
 for i,v in enumerate([a,b]):
  if v is None:continue
  if isinstance(v,(int,float)):n.inputs[i].default_value=v
  else:links.new(v,n.inputs[i])
 return n.outputs[0]
def mix(f,a,b):
 n=node('ShaderNodeMixRGB');links.new(f,n.inputs[0])
 for i,v in enumerate([a,b],1):
  if isinstance(v,tuple):n.inputs[i].default_value=v
  else:links.new(v,n.inputs[i])
 return n.outputs[0]
orig=node('ShaderNodeTexImage');orig.image=img
bw=node('ShaderNodeRGBToBW');links.new(orig.outputs['Color'],bw.inputs[0]);eye=mathnode('LESS_THAN',bw.outputs[0],.035)
geo=node('ShaderNodeNewGeometry');sep=node('ShaderNodeSeparateXYZ');links.new(geo.outputs['Position'],sep.inputs[0]);X,Y,Z=[sep.outputs[k] for k in ['X','Y','Z']]
# Rebuild the two clean eye borders at the measured source bounds; no eye repositioning.
eye_distance=mathnode('ADD',mathnode('POWER',mathnode('DIVIDE',mathnode('SUBTRACT',mathnode('ABSOLUTE',X),.230),.067),2),mathnode('POWER',mathnode('DIVIDE',mathnode('SUBTRACT',Z,.514),.071),2))
eye=mathnode('MULTIPLY',mathnode('LESS_THAN',eye_distance,1),mathnode('LESS_THAN',Y,-.35))
white=mathnode('GREATER_THAN',Y,.035)
blue=(.055,.32,.58,1);ivory=(.88,.90,.92,1);black=(.006,.007,.009,1)
color=mix(white,blue,ivory)
out=node('ShaderNodeOutputMaterial');em=node('ShaderNodeEmission');links.new(color,em.inputs['Color']);links.new(em.outputs[0],out.inputs['Surface'])
# Bake the cleaned material on the existing UVs for standard glTF compatibility.
baked=bpy.data.images.new('Yumemin_Clean_BaseColor',width=2048,height=2048,alpha=False)
target=node('ShaderNodeTexImage');target.image=baked;nodes.active=target
bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
sc=bpy.context.scene;sc.render.engine='CYCLES';sc.cycles.samples=1;sc.render.bake.margin=16
bpy.ops.object.bake(type='EMIT')
baked.filepath_raw=str(OUT/'base_color.png');baked.file_format='PNG';baked.save();baked.pack()
nodes.clear();bs=node('ShaderNodeBsdfPrincipled');bs.inputs['Roughness'].default_value=.68;bs.inputs['Metallic'].default_value=0
bt=node('ShaderNodeTexImage');bt.image=baked;links.new(bt.outputs['Color'],bs.inputs['Base Color']);out=node('ShaderNodeOutputMaterial');links.new(bs.outputs[0],out.inputs['Surface'])
# Tail is a disconnected shell in the source: assign its entire surface blue.
seen=set();tail_ids=set()
for i in range(len(adj)):
 if i in seen:continue
 todo=[i];seen.add(i);comp=[]
 while todo:
  a=todo.pop();comp.append(a)
  for b in adj[a]:
   if b not in seen:seen.add(b);todo.append(b)
 if min(xyz[j,1] for j in comp)>.35:tail_ids.update(comp)
tail_mat=bpy.data.materials.new('Yumemin_Tail_Blue');tail_mat.use_nodes=True
tbs=next(n for n in tail_mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');tbs.inputs['Base Color'].default_value=blue;tbs.inputs['Roughness'].default_value=.68
m.materials.append(tail_mat)
for poly in m.polygons:
 if all(j in tail_ids for j in poly.vertices):poly.material_index=len(m.materials)-1
# Smooth shallow ellipsoid eyes replace the noisy generated eye caps.
eye_mat=bpy.data.materials.new('Yumemin_Matte_Eyes');eye_mat.use_nodes=True
ebs=next(n for n in eye_mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
ebs.inputs['Base Color'].default_value=black;ebs.inputs['Roughness'].default_value=.58
for idx,(cx,cy,cz,dy_dx,dy_dz) in enumerate(eye_specs):
 normal=Vector((dy_dx,-1,dy_dz)).normalized()
 bpy.ops.mesh.primitive_uv_sphere_add(segments=48,ring_count=32,location=Vector((cx,cy,cz))+normal*.003)
 e=bpy.context.object;e.name='Eye_'+('L' if cx>0 else 'R')
 e.rotation_euler=normal.to_track_quat('Y','Z').to_euler()
 e.scale=(.070,.022,.072)
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 e.data.materials.append(eye_mat)
 for poly in e.data.polygons:poly.use_smooth=True
 meshes.append(e)
bpy.ops.object.select_all(action='DESELECT')
for obj in meshes:obj.select_set(True)
bpy.context.view_layer.objects.active=o
bpy.ops.export_scene.gltf(filepath=str(OUT/'yumemin_clean.glb'),export_format='GLB',use_selection=True,export_animations=False)
report={'source':'../wan_multiview_20260919/raw/output_model_url.fbx','vertices':sum(len(obj.data.vertices) for obj in meshes),'polygons':sum(len(obj.data.polygons) for obj in meshes),'mesh_objects':len(meshes),'vertex_displacement_max':float(np.linalg.norm(xyz-original,axis=1).max()),'vertex_displacement_mean':float(np.linalg.norm(xyz-original,axis=1).mean()),'body_fit_center':center.tolist(),'body_fit_radius':float(radius),'rigged':False,'edits':['local weighted smoothing','central crown bump cleanup','clean blue-white boundary','wrinkled eye support rebuilt locally; clean shallow ellipsoid eyes at source locations','removed generated normal and roughness noise','matte clean base color bake']}
(OUT/'cleanup_report.json').write_text(json.dumps(report,indent=2)+'\n')
# Render the exported GLB itself with the same studio used for the original.
suffix=template[template.index('# Verify the exported artifact'):]
suffix=suffix.replace("'yumemin.glb'","'yumemin_clean.glb'").replace("'yumemin.blend'","'yumemin_clean.blend'")
suffix=suffix.replace("('right',(-1,0,0))]","('right',(-1,0,0)),('top',(0,-.2,1)),('bottom',(0,-.2,-1))]")
exec(suffix)
print('YUMEMIN_CLEANUP_DONE',flush=True)
