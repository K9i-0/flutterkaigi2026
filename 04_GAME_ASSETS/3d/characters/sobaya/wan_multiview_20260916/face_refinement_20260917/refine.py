import bpy, numpy as np, math, json, bmesh
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent; BASE=OUT.parent
bpy.ops.wm.open_mainfile(filepath=str(BASE/'imagegen_mask_v1/sobaya_refined_final.blend'))
s=bpy.context.scene;o=bpy.data.objects['tripo_node_4861cc5b'];m=o.data
A,B=map(math.radians,(8,-10));N=Vector((math.sin(A)*math.cos(B),-math.cos(A)*math.cos(B),math.sin(B)));Q=(-N).to_track_quat('-Z','Y');R=Q@Vector((1,0,0));U=Q@Vector((0,1,0));T=Vector((-.135,-.70,1.015));K=1024/.34
basis=np.array([R,-U,N]); origin=np.array(T)
def project(p):return (np.asarray(p)-origin)@basis.T*K+np.array([512,512,0])
def world(p):return Vector(tuple(origin+((np.asarray(p)-[512,512,0])/K)@basis))
P=project([tuple(o.matrix_world@v.co) for v in m.vertices]);V=P.copy(); inv=o.matrix_world.inverted()
comps=json.load(open(OUT/'source_components.json'));main=set(comps[0]['ids']);dotids=set(comps[3]['ids'])
# Capture feature planes before sculpting.
planes={}; eyeids=[]
for label,inds in [('L',range(652,676)),('R',range(3175,3199))]:
 ids=set(i for fi in inds for i in m.polygons[fi].vertices);eyeids.append(ids)
 pts=P[list(ids)];planes[label]=np.linalg.lstsq(np.c_[pts[:,:2],np.ones(len(pts))],pts[:,2],rcond=None)[0]
# Independent local changes keep eye spacing and the upper face silhouette fixed.
for i,(x,y,d) in enumerate(P):
 if i not in main or d< -150:continue
 p=V[i]
 for cx,cy in [(404.8,545.83),(674.44,555.54)]:
  dx,dy=x-cx,y-cy;rr=math.sqrt((dx/70)**2+(dy/73)**2)
  w=1 if rr<1.05 else max(0,1-(rr-1.05)/.8)**2
  p[0]+=dx*.17*w;p[1]+=dy*.24*w
 # Smooth closed nose: remove paired nostril relief, retain a rounded tip and bridge.
 if 465<x<620 and 620<y<737:
  wx=np.clip((77.5-abs(x-542.5))/18,0,1);wy=np.clip(min(y-620,737-y)/16,0,1);w=wx*wy
  base=120-.055*(y-695)
  tip=64*math.exp(-((x-548)/44)**4-((y-680)/22)**2)
  bridge=24*math.exp(-((x-548)/24)**2-((y-631)/48)**2)
  p[2]=p[2]*(1-w)+(base+tip+bridge)*w
 # Flatten the former jagged mouth cavity into the continuous mask surface.
 if 431<x<651 and 739<y<820:
  w=np.clip((110-abs(x-541))/18,0,1)*np.clip(min(y-739,820-y)/12,0,1)
  p[2]=p[2]*(1-w)+(112-.08*(y-777))*w
  p[1]+=12*w
# Flatten the original nostril folds under a continuous, smooth nasal surface.
def nosebase(x,y):
 a=(x-545)/100;b=(y-660)/100
 return 114.02034-6.27007*a+8.73957*b-23.65476*a*a-3.77631*a*b+1.05299*b*b
for i,(x,y,d) in enumerate(P):
 if i in main and d>60 and 455<x<637 and 460<y<750:
  weight=np.clip(min((x-455)/15,(637-x)/15,(y-460)/65,(750-y)/15),0,1)
  V[i,2]=V[i,2]*(1-weight)+nosebase(x,y)*weight
# The source silhouette and hair remain unchanged; only local face features may move.
changed_ids=np.flatnonzero(np.linalg.norm(V-P,axis=1)>1e-7)
allowed=np.zeros(len(P),bool)
for cx,cy in [(404.8,545.83),(674.44,555.54)]:allowed|=((P[:,0]-cx)/70)**2+((P[:,1]-cy)/73)**2<1.85**2
allowed|=(P[:,0]>455)&(P[:,0]<637)&(P[:,1]>460)&(P[:,1]<750)
allowed|=(P[:,0]>431)&(P[:,0]<651)&(P[:,1]>739)&(P[:,1]<820)
assert np.all(allowed[changed_ids]), 'A vertex outside face features moved'
assert all(np.array_equal(V[i],P[i]) for comp in comps[4:] for i in comp['ids']), 'Hair changed'
json.dump({'changed_source_vertices':len(changed_ids),'outside_feature_regions_max_displacement':float(np.max(np.linalg.norm(V[~allowed]-P[~allowed],axis=1))),'hair_unchanged':True,'chin_deformation':False},open(OUT/'geometry_scope_check.json','w'),indent=2)
for v,p in zip(m.vertices,V):v.co=inv@world(p)
# Former mouth triangles now belong to the white mask.
for p in m.polygons:
 if p.material_index==2:p.material_index=0
if bpy.data.objects.get('Mask mouth clean slot'):bpy.data.objects.remove(bpy.data.objects['Mask mouth clean slot'],do_unlink=True)
# Replace the low-poly forehead disk with a smooth black domed medallion.
bm=bmesh.new();bm.from_mesh(m);bm.verts.ensure_lookup_table();bmesh.ops.delete(bm,geom=[bm.verts[i] for i in dotids],context='VERTS');bm.to_mesh(m);bm.free();m.update()
black=bpy.data.materials['Mask absolute black']
def flat_shape(name,points,plane):
 pts=np.array(points);center=pts.mean(0);xy=np.vstack([center,pts]);xyz=np.c_[xy,np.c_[xy,np.ones(len(xy))]@plane]
 mesh=bpy.data.meshes.new(name);mesh.from_pydata([world(p) for p in xyz],[],[(0,(i+1)%len(pts)+1,i+1) for i in range(len(pts))]);mesh.materials.append(black)
 obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj);return obj
for label,cx,cy in [('L',404.8,545.83),('R',674.44,555.54)]:
 # Slight camera roll matches the line connecting the two eyes.
 pts=[]
 for a in np.linspace(0,2*math.pi,128,endpoint=False):
  dx=76.5*math.cos(a);dy=83.5*math.sin(a);pts.append([cx+dx-.036*dy,cy+dy+.036*dx])
 pl=planes[label].copy();pl[2]+=5
 flat_shape('Mask black eye '+label,pts,pl)
# Reference mouth width 55.8% of eye spacing, with smoothly rounded ends.
cx,cy=541,789;rr=21;half=54
pts=[[cx+half+rr*math.cos(a),cy+rr*math.sin(a)] for a in np.linspace(-math.pi/2,math.pi/2,65)]
pts += [[cx-half+rr*math.cos(a),cy+rr*math.sin(a)] for a in np.linspace(math.pi/2,3*math.pi/2,65)]
pts=[[cx+(x-cx)-.036*(y-cy),cy+(y-cy)+.036*(x-cx)] for x,y in pts]
flat_shape('Mask reference mouth',pts,np.array([0,-.08,177.16]))
# A smooth closed cap replaces the paired nostril anatomy; its edge sits inside the mask.
from mathutils.bvhtree import BVHTree
bpy.context.view_layer.update();tree=BVHTree.FromObject(o,bpy.context.evaluated_depsgraph_get())
verts=[];faces=[];nx,ny=72,112
for j,y in enumerate(np.linspace(450,770,ny)):
 for i,x in enumerate(np.linspace(445,647,nx)):
  env=np.clip(min((x-445)/25,(647-x)/25,(y-450)/30,(770-y)/30),0,1);env=env*env*(3-2*env)
  bridge=46*math.exp(-((x-545)/25)**2-((y-615)/64)**2)
  tip=65*math.exp(-((x-545)/41)**4-((y-692)/(40 if y<692 else 10))**2)
  hit=tree.ray_cast(inv@world([x,y,600]),inv.to_3x3()@(-N))
  surface=project([tuple(o.matrix_world@hit[0])])[0,2] if hit[0] is not None else nosebase(x,y)
  depth=surface+(bridge+tip)*env-.15*(1-env)+.1*env
  verts.append(world([x,y,depth]))
  if i and j:
   k=j*nx+i;faces.append((k-nx-1,k-1,k,k-nx))
mesh=bpy.data.meshes.new('Closed smooth nose surface');mesh.from_pydata(verts,[],faces)
obj=bpy.data.objects.new('Mask closed nose without nostrils',mesh);bpy.context.collection.objects.link(obj)
mat=bpy.data.materials.new('Mask porcelain nose');mat.use_nodes=True;bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(.656,.664,.656,1);bs.inputs['Roughness'].default_value=.68;bs.inputs['Specular IOR Level'].default_value=.2;mesh.materials.append(mat)
for f in mesh.polygons:f.use_smooth=True
mod=obj.modifiers.new('Smooth nasal surface','SUBSURF');mod.levels=1;mod.render_levels=1
# Forehead center moves upward by 22px, same apparent diameter.
dotP=P[list(dotids)].mean(0);dotP[0]=546.8;dotP[1]=398.7
bpy.ops.mesh.primitive_uv_sphere_add(segments=64,ring_count=32,location=world(dotP))
dot=bpy.context.object;dot.name='Mask domed forehead medallion';dot.rotation_euler=Q.to_euler();dot.scale=(40/K,40/K,14/K)
mat=bpy.data.materials.new('Mask medallion black satin');mat.use_nodes=True;bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(.009,.012,.014,1);bs.inputs['Roughness'].default_value=.29;bs.inputs['Specular IOR Level'].default_value=.45;dot.data.materials.append(mat)
for f in dot.data.polygons:f.use_smooth=True
# Reproject crisp reference red contours into the edited mask's existing atlas.
ref=json.load(open(OUT/'reference_landmarks.json'));le=np.array(ref['eyeL']['center']);re=np.array(ref['eyeR']['center']);v=re-le;refbasis=np.array([[v[0],v[1]],[-v[1],v[0]]])/np.linalg.norm(v)
targetbasis=np.array([[1,-.036],[.036,1]])
contours=[]
for key in ['redUL','redUR','redLL','redLR']:
 pts=np.array(json.load(open(OUT/'reference_red_contours.json'))[key]);pts=(pts-(le+re)/2)@refbasis.T*(269.81/np.linalg.norm(v));pts=pts@targetbasis.T+[539.62,550.69]
 # Chaikin rounds pixel-staircase contours while preserving the characteristic taper.
 for _ in range(3):pts=np.stack([.75*pts+.25*np.roll(pts,-1,axis=0),.25*pts+.75*np.roll(pts,-1,axis=0)],axis=1).reshape(-1,2)
 contours.append(pts)
redmap=np.zeros((2304,2048),np.float32)
for pts in contours:
 pts=pts*2
 for y in range(max(0,int(pts[:,1].min())),min(2304,int(pts[:,1].max())+1)):
  scan=y+.5;inter=[]
  for (ax,ay),(bx,by) in zip(pts,np.roll(pts,-1,axis=0)):
   if (ay>scan)!=(by>scan):inter.append(ax+(bx-ax)*(scan-ay)/(by-ay))
  inter.sort()
  for left,right in zip(inter[::2],inter[1::2]):
   redmap[y,max(0,int(math.ceil(left-.5))):min(2048,int(math.ceil(right-.5)))]=1
# Give mask polygons a dedicated high-resolution planar UV map: crisp lines without atlas overlap.
source=bpy.data.images['Sobaya_Final_Color_v2'];W,H=source.size;orig=np.array(source.pixels[:],np.float32).reshape(H,W,4)
uvsrc=m.uv_layers.active.data;uvnew=m.uv_layers.new(name='Mask reference projection');coords=project([tuple(o.matrix_world@v.co) for v in m.vertices])
imagepixels=np.empty((2304,2048,4),np.float32);imagepixels[:]=[.83,.835,.83,1];imagepixels[redmap>0]=[.50,.025,.045,1]
img=bpy.data.images.new('Sobaya reference mask color',width=2048,height=2304,alpha=True);img.pixels.foreach_set(imagepixels[::-1].copy().ravel());img.filepath_raw=str(OUT/'sobaya_front_matched_color.png');img.file_format='PNG';img.save();img.pack()
maskmat=m.materials[0].copy();maskmat.name='Mask reference porcelain and red';m.materials.append(maskmat);mi=len(m.materials)-1
bs=next(n for n in maskmat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');tex=bs.inputs['Base Color'].links[0].from_node;tex.image=img
uvnode=maskmat.node_tree.nodes.new('ShaderNodeUVMap');uvnode.uv_map=uvnew.name;maskmat.node_tree.links.new(uvnode.outputs['UV'],tex.inputs['Vector'])
changed=0
for face in m.polygons:
 pp=coords[list(face.vertices)];x,y,d=pp.mean(0);pworld=o.matrix_world@face.center
 samples=[]
 for li in face.loop_indices:
  vi=m.loops[li].vertex_index;px,py,_=coords[vi];uvnew.data[li].uv=(px/1024,1-py/1152)
  uv=uvsrc[li].uv;samples.append(orig[min(H-1,max(0,int(uv.y*H))),min(W-1,max(0,int(uv.x*W))),:3])
 rgb=np.mean(samples,axis=0);ispaint=(rgb.max()>.6 and rgb.max()-rgb.min()<.28) or (rgb[0]>rgb[1]*1.3 and rgb[0]>.12)
 central=245<x<855 and 255<y<1040
 if face.material_index==0 and pworld.y<-.62 and 255<y<1040 and (ispaint or central) and d> -100:
  face.material_index=mi;changed+=1
m.uv_layers.active_index=0
# Unify the remaining white mask atlas at the material boundary with a feathered color correction.
bpy.context.view_layer.update();ev=o.evaluated_get(bpy.context.evaluated_depsgraph_get());em=ev.to_mesh();em.calc_loop_triangles();ep=project([tuple(o.matrix_world@v.co) for v in em.vertices]);euv=em.uv_layers[0].data;out=orig.copy();painted=np.zeros((H,W),bool)
for tri in em.loop_triangles:
 p=ep[list(tri.vertices)]
 if tri.material_index not in (0,mi) or p[:,1].max()<245 or p[:,1].min()>1040 or p[:,2].max()< -250:continue
 uv=np.array([tuple(euv[i].uv) for i in tri.loops])*[W,H];lo=np.maximum(np.floor(uv.min(0)).astype(int),0);hi=np.minimum(np.ceil(uv.max(0)).astype(int),[W-1,H-1])
 if np.any(hi<lo):continue
 xx,yy=np.meshgrid(np.arange(lo[0],hi[0]+1),np.arange(lo[1],hi[1]+1));qx=xx+.5;qy=yy+.5;a,b,c=uv;den=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
 if abs(den)<1e-9:continue
 u=((b[1]-c[1])*(qx-c[0])+(c[0]-b[0])*(qy-c[1]))/den;v=((c[1]-a[1])*(qx-c[0])+(a[0]-c[0])*(qy-c[1]))/den;w=1-u-v;inside=(u>=0)&(v>=0)&(w>=0)
 pp=u[:,:,None]*p[0]+v[:,:,None]*p[1]+w[:,:,None]*p[2];x,y,d=pp.transpose(2,0,1);rgb=orig[yy,xx,:3]
 worldp=origin+((pp-[512,512,0])/K)@basis
 valid=inside&(worldp[:,:,1]<-.54)&(worldp[:,:,2]>.885)&(x>220)&(x<860)&(y>245)&(y<1040)&(d> -250)
 oldred=(rgb[:,:,0]>rgb[:,:,1]*1.3)&(rgb[:,:,0]>.12)
 neutral=(rgb[:,:,0]>rgb[:,:,1]*.975)&(rgb[:,:,0]>rgb[:,:,2]*.975)
 alpha=valid*np.maximum(np.clip((rgb.max(2)-.50)/.15,0,1)*neutral,oldred)
 out[yy,xx,:3]=out[yy,xx,:3]*(1-alpha[:,:,None])+np.array([.83,.835,.83])*alpha[:,:,None];painted[yy,xx]|=alpha>0
for _ in range(3):
 old=painted.copy()
 for dy,dx in [(1,0),(-1,0),(0,1),(0,-1)]:
  mask=np.roll(old,(dy,dx),(0,1))&~painted;out[mask]=np.roll(out,(dy,dx),(0,1))[mask];painted[mask]=True
ev.to_mesh_clear();bodyimg=bpy.data.images.new('Sobaya matched body atlas',width=W,height=H,alpha=True);bodyimg.pixels.foreach_set(out.ravel());bodyimg.filepath_raw=str(OUT/'sobaya_body_color.png');bodyimg.file_format='PNG';bodyimg.save();bodyimg.pack()
bs=next(n for n in m.materials[0].node_tree.nodes if n.type=='BSDF_PRINCIPLED');bs.inputs['Base Color'].links[0].from_node.image=bodyimg
# Save the editable candidate and render with the audit camera (extra canvas below chin).
s.render.resolution_x=1024;s.render.resolution_y=1152;s.render.resolution_percentage=100;s.cycles.samples=32
c=s.camera;c.data.ortho_scale=.3825;c.location=T-U*(64/K)+N*3;c.rotation_euler=Q.to_euler()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'sobaya_front_matched.blend'))
s.render.filepath=str(OUT/'front.png');bpy.ops.render.render(write_still=True)
print('FACE REFINEMENT COMPLETE',changed)
