"""Reference-constrained facial geometry and direct source-image UV projection."""
import bpy,bmesh,numpy as np,math,json
from pathlib import Path
OUT=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(OUT.parent/'finish_C_20260917/fukuchan_finished.blend'))
o=next(o for o in bpy.context.scene.objects if o.type=='MESH');m=o.data
# Remove earlier generic iris caps: source pixels provide the actual iris pattern.
remove_names=('Dark brown iris','Iris outer ring','Single dark pupil')
bm=bmesh.new();bm.from_mesh(m)
remove=[f for f in bm.faces if any(x in m.materials[f.material_index].name for x in remove_names)]
bmesh.ops.delete(bm,geom=remove,context='FACES');bm.to_mesh(m);bm.free();m.update()
P=np.array([tuple(o.matrix_world@v.co) for v in m.vertices]);original=P.copy()
faceverts=set();eyeverts=set();hairverts=set()
for f in m.polygons:
    name=m.materials[f.material_index].name
    if 'soft skin' in name:faceverts.update(i for i in f.vertices if P[i,2]>1.36)
    if 'Natural sclera' in name:eyeverts.update(f.vertices)
    if 'sculpted black hair' in name:hairverts.update(f.vertices)
# Local, smooth corrections from calibrated front comparison. Meters, never cumulative.
for i in faceverts|eyeverts:
    x,y,z=P[i];front=np.clip((.025-y)/.065,0,1)
    if i in eyeverts:front=1
    # Match the measured upper/lower lid opening and height; preserve socket continuity.
    eyecx=.0328 if x>=0 else -.0328
    ew=math.exp(-((x-eyecx)/.027)**4-((z-1.542)/.023)**4)*front
    dz=(.0055+.15*(z-1.542))*ew
    # Lift chin and subtly shorten lower face, leaving the neck fixed.
    dz+=.0045*math.exp(-((z-1.428)/.025)**2-(x/.065)**4)*front
    # Front nose and mouth are slightly higher and mouth less wide.
    dz+=.0018*math.exp(-((z-1.488)/.037)**4-(x/.045)**4)*front
    dx=-x*.045*math.exp(-((z-1.475)/.019)**4-(x/.054)**4)*front
    P[i,0]+=dx;P[i,2]+=dz
# Match the front locks framing the forehead; retain the outer/back hair silhouette.
for i in hairverts:
    x,y,z=P[i]
    w=math.exp(-((z-1.57)/.045)**4)*np.clip((.015-y)/.045,0,1)*np.clip((.095-abs(x))/.025,0,1)
    P[i,0]+=.0055*w
# UV-split vertices at one geometric location must receive the same displacement.
_,weld=np.unique(np.round(original,6),axis=0,return_inverse=True)
sums=np.zeros((weld.max()+1,3));np.add.at(sums,weld,P-original)
counts=np.bincount(weld);P=original+sums[weld]/counts[weld,None]
inv=o.matrix_world.inverted()
for i,v in enumerate(m.vertices):v.co=inv@__import__('mathutils').Vector(P[i])
m.update();m.calc_loop_triangles()
# Recompute area-weighted normals across UV splits after geometric corrections.
acc=np.zeros((weld.max()+1,3))
for t in m.loop_triangles:
    ids=list(t.vertices);p=P[ids];n=np.cross(p[1]-p[0],p[2]-p[0])
    for i in ids:acc[weld[i]]+=n
acc/=np.maximum(np.linalg.norm(acc,axis=1)[:,None],1e-12)
N=np.array([tuple(v.normal) for v in m.vertices])
head=np.zeros(len(P),bool);head[list(faceverts|hairverts|eyeverts)]=True;N[head]=acc[weld[head]]
m.normals_split_custom_set_from_vertices(N.tolist())
# Reference calibration: source pixels per meter, center and top offset.
S=590.;CX=411.;TOP=24.5
refpath=OUT/'front_illumination_corrected.png'
if not refpath.exists():refpath=OUT.parent/'wan_multiview_20260917/inputs/front.png'
ref=bpy.data.images.load(str(refpath),check_existing=False)
rw,rh=ref.size;rp=np.array(ref.pixels[:],np.float32).reshape(rh,rw,4)
def project(p):return np.stack([CX+S*p[...,0],rh-(TOP+S*(1.7-p[...,2]))],-1)
def raster(tri,W,H):
    lo=np.maximum(np.floor(tri.min(0)).astype(int),0);hi=np.minimum(np.ceil(tri.max(0)).astype(int),[W-1,H-1])
    if np.any(hi<lo):return
    xx,yy=np.meshgrid(np.arange(lo[0],hi[0]+1),np.arange(lo[1],hi[1]+1));a,b,c=tri
    d=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
    if abs(d)<1e-10:return
    u=((b[1]-c[1])*(xx+.5-c[0])+(c[0]-b[0])*(yy+.5-c[1]))/d
    v=((c[1]-a[1])*(xx+.5-c[0])+(a[0]-c[0])*(yy+.5-c[1]))/d
    w=1-u-v;return xx,yy,np.stack([u,v,w],-1),(u>=-1e-5)&(v>=-1e-5)&(w>=-1e-5)
def sample(uv):
    # Cubic resampling avoids losing input detail through two bilinear filtering steps.
    x=np.clip(uv[...,0]-.5,1,rw-3.001);y=np.clip(uv[...,1]-.5,1,rh-3.001);ix=x.astype(int);iy=y.astype(int)
    def k(t):
        t=np.abs(t);return np.where(t<1,1.5*t**3-2.5*t**2+1,np.where(t<2,-.5*t**3+2.5*t**2-4*t+2,0))
    out=np.zeros((*x.shape,3),float)
    for j in [-1,0,1,2]:
        for i in [-1,0,1,2]:out+=rp[iy+j,ix+i,:3]*(k(x-ix-i)*k(y-iy-j))[...,None]
    return np.clip(out,0,1)
oldskin=next(a for a in m.materials if 'soft skin' in a.name)
skin=oldskin.copy();m.materials.append(skin);skin_index=len(m.materials)-1
for f in m.polygons:
    if m.materials[f.material_index]==oldskin and P[list(f.vertices),2].min()>1.35:f.material_index=skin_index
bs=next(n for n in skin.node_tree.nodes if n.type=='BSDF_PRINCIPLED');tex=bs.inputs['Base Color'].links[0].from_node
W,H=tex.image.size;result=np.array(tex.image.pixels[:],np.float32).reshape(H,W,4);original_pixels=result.copy();uv=m.uv_layers.active.data
# Visible depth at 4x input pixel density. Occluded hair/skin must not receive foreground paint.
D=4;depth=np.full((rh*D,rw*D),np.inf,np.float32)
for t in m.loop_triangles:
    p=P[list(t.vertices)]
    if p[:,2].max()<1.37:continue
    r=raster(project(p)*D,rw*D,rh*D)
    if r is None:continue
    x,y,b,inside=r;d=b@p[:,1];depth[y,x]=np.where(inside,np.minimum(depth[y,x],d),depth[y,x])
painted=0
changed=np.zeros((H,W),bool)
for t in m.loop_triangles:
    if m.materials[t.material_index]!=skin:continue
    p=P[list(t.vertices)]
    if p[:,2].max()<1.36:continue
    r=raster(np.array([tuple(uv[i].uv) for i in t.loops])*[W,H],W,H)
    if r is None:continue
    x,y,b,inside=r;world=b@p;pr=project(world)
    ix=np.clip((pr[...,0]*D).astype(int),0,rw*D-1);iy=np.clip((pr[...,1]*D).astype(int),0,rh*D-1)
    vis=(world[...,1]-depth[iy,ix])<.004
    n=np.cross(p[1]-p[0],p[2]-p[0]);n/=max(np.linalg.norm(n),1e-12)
    a=inside*np.clip((.045-world[...,1])/.04,0,1)*np.clip((world[...,2]-1.43)/.025,0,1)
    # Preserve lateral atlas; front projection carries all visible facial features.
    a*=np.clip((.105-np.abs(world[...,0]))/.027,0,1)
    normal=b@N[list(t.vertices)]
    nw=np.clip((np.abs(world[...,0])-.053)/.018,0,1)
    a*=1-nw*(1-np.clip((-normal[...,1]-.30)/.45,0,1))
    # Retain source dark hair fragments incorrectly grouped with skin by Tripo.
    oldcol=original_pixels[y,x,:3]
    oldskin=np.clip((oldcol[...,0]-oldcol[...,2]-.02)/.06,0,1)*np.clip((oldcol[...,0]-.20)/.10,0,1)
    a*=np.where((np.abs(world[...,0])<.060)&(world[...,2]<1.585),1,oldskin)
    col=sample(pr)
    # Prevent source hair/background from spilling onto side cheeks and ears.
    lateral=np.clip((np.abs(world[...,0])-.065)/.018,0,1)
    skin_color=np.clip((col[...,0]-col[...,2]-.025)/.065,0,1)
    a*=1-lateral*(1-skin_color)
    result[y,x,:3]=result[y,x,:3]*(1-a[...,None])+col*a[...,None]
    # Restore neutral neck skin where the original Tripo atlas carries dark smears.
    lateral=np.maximum(np.clip((np.abs(world[...,0])-.055)/.02,0,1),np.clip((world[...,1]+.02)/.03,0,1))
    neck=inside*lateral*np.clip((1.48-world[...,2])/.055,0,1)*np.clip((.05-world[...,1])/.025,0,1)
    neck*=np.clip((.097-np.abs(world[...,0]))/.012,0,1)
    result[y,x,:3]=result[y,x,:3]*(1-neck[...,None])+np.array([.74,.565,.495])*neck[...,None]
    painted+=int((a>.5).sum());changed[y,x]|=inside
# Pad UV borders to eliminate filtering seams without crossing other surface texels.
for _ in range(6):
    old=changed.copy()
    for dy,dx in [(1,0),(-1,0),(0,1),(0,-1)]:
        mask=np.roll(old,(dy,dx),(0,1))&~changed
        result[mask]=np.roll(result,(dy,dx),(0,1))[mask];changed[mask]=True
im=bpy.data.images.new('Front faithful face atlas',width=W,height=H,alpha=True);im.pixels.foreach_set(result.ravel());im.filepath_raw=str(OUT/'face_atlas.png');im.file_format='PNG';im.save();im.pack();tex.image=im
skin.name='Front faithful skin';bs.inputs['Roughness'].default_value=.65;bs.inputs['Specular IOR Level'].default_value=0
# Actual input iris/sclera colors, on the retained curved eyeball geometry.
eye=next(a for a in m.materials if 'Natural sclera' in a.name);eb=next(n for n in eye.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
node=eye.node_tree.nodes.new('ShaderNodeTexImage');node.image=ref;ref.pack();eye.node_tree.links.new(node.outputs['Color'],eb.inputs['Base Color']);eb.inputs['Roughness'].default_value=.4;eb.inputs['Specular IOR Level'].default_value=0
puv=m.uv_layers.new(name='FrontEyeProjection')
for f in m.polygons:
    for li in f.loop_indices:
        q=project(P[m.loops[li].vertex_index]);puv.data[li].uv=(q[0]/rw,q[1]/rh)
un=eye.node_tree.nodes.new('ShaderNodeUVMap');un.uv_map=puv.name;eye.node_tree.links.new(un.outputs['UV'],node.inputs['Vector'])
assert np.array_equal(P[~head],original[~head]), 'Non-head geometry changed'
o.name='Fukuchan_front_faithful'
bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
bpy.ops.export_scene.gltf(filepath=str(OUT/'fukuchan_front_faithful.glb'),export_format='GLB',use_selection=True,export_animations=False)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'fukuchan_front_faithful.blend'))
(OUT/'iteration_report.json').write_text(json.dumps({'projection':{'scale':S,'center_x':CX,'top':TOP},'changed_vertices':int(np.any(P!=original,axis=1).sum()),'body_vertices_unchanged':bool(np.array_equal(P[original[:,2]<1.35],original[original[:,2]<1.35])),'non_head_vertices_unchanged':bool(np.array_equal(P[~head],original[~head])),'max_displacement_m':float(np.linalg.norm(P-original,axis=1).max()),'projected_texels':painted,'reference':'../wan_multiview_20260917/inputs/front.png'},indent=2)+'\n')
print('REFINE_DONE',flush=True)
