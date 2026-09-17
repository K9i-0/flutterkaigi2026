"""Localized texture projection and exact vector name badge; immutable source mesh."""
import bpy, numpy as np, math, json, hashlib, bmesh
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
OUT=Path(__file__).resolve().parent
BASE=OUT.parent/'wan_multiview_20260917'
bpy.ops.wm.open_mainfile(filepath=str(BASE/'fukuchan_wholebody.blend'))
s=bpy.context.scene;o=next(o for o in s.objects if o.type=='MESH');m=o.data
P=np.array([tuple(o.matrix_world@v.co) for v in m.vertices]);original_P=P.copy()
m.calc_loop_triangles();uv=m.uv_layers.active.data
# Identify existing disconnected body parts, welding only for classification.
U,inv=np.unique(np.round(P,6),axis=0,return_inverse=True)
adj=[set() for _ in U]
for t in m.loop_triangles:
    a,b,c=inv[list(t.vertices)]
    for i,j in [(a,b),(b,c),(c,a)]:adj[i].add(j);adj[j].add(i)
seen=set();components=[]
for i in range(len(U)):
    if i in seen:continue
    ids=[];stack=[i];seen.add(i)
    while stack:
        j=stack.pop();ids.append(j)
        for k in adj[j]:
            if k not in seen:seen.add(k);stack.append(k)
    components.append(ids)
components.sort(key=len,reverse=True)
labels=np.empty(len(U),int)
for i,ids in enumerate(components):labels[ids]=i
vertex_component=labels[inv]
eye_components=[i for i,ids in enumerate(components) if len(ids)>80 and U[ids,2].min()>1.52 and U[ids,2].max()<1.57]
assert len(eye_components)==2,eye_components
mat=m.materials[0];bs=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
tex=bs.inputs['Base Color'].links[0].from_node
original=tex.image;W,H=original.size
pixels=np.array(original.pixels[:],np.float32).reshape(H,W,4)
clean=bpy.data.images.load(str(OUT/'face_clean_projection.png'),check_existing=False)
cw,ch=clean.size;cp=np.array(clean.pixels[:],np.float32).reshape(ch,cw,4)
result=pixels.copy();painted=np.zeros((H,W),bool)
# Rasterize front depth to protect occluded surfaces from front paint.
DW=DH=1024;depth=np.full((DH,DW),np.inf,np.float32)
def raster(tri,width,height):
    lo=np.maximum(np.floor(tri.min(0)).astype(int),0);hi=np.minimum(np.ceil(tri.max(0)).astype(int),[width-1,height-1])
    if np.any(hi<lo):return None
    xx,yy=np.meshgrid(np.arange(lo[0],hi[0]+1),np.arange(lo[1],hi[1]+1));a,b,c=tri
    den=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
    if abs(den)<1e-10:return None
    u=((b[1]-c[1])*(xx+.5-c[0])+(c[0]-b[0])*(yy+.5-c[1]))/den
    v=((c[1]-a[1])*(xx+.5-c[0])+(a[0]-c[0])*(yy+.5-c[1]))/den
    w=1-u-v
    return xx,yy,np.stack([u,v,w],-1),(u>=-1e-5)&(v>=-1e-5)&(w>=-1e-5)
def projection(p):return np.stack([p[...,0]/.43+.5,(p[...,2]-1.535)/.43+.5],-1)
for t in m.loop_triangles:
    p=P[list(t.vertices)]
    if p[:,2].max()<1.32:continue
    q=raster(projection(p)*[DW,DH],DW,DH)
    if q is None:continue
    x,y,b,inside=q;d=b@p[:,1];current=depth[y,x];depth[y,x]=np.where(inside,np.minimum(current,d),current)
for t in m.loop_triangles:
    p=P[list(t.vertices)]
    if p[:,2].max()<1.36:continue
    q=raster(np.array([tuple(uv[i].uv) for i in t.loops])*[W,H],W,H)
    if q is None:continue
    x,y,b,inside=q;world=b@p;proj=projection(world)
    dx=np.clip((proj[...,0]*DW).astype(int),0,DW-1);dy=np.clip((proj[...,1]*DH).astype(int),0,DH-1)
    vis=(world[...,1]-depth[dy,dx])<.006
    n=np.cross(p[1]-p[0],p[2]-p[0]);n=n/max(np.linalg.norm(n),1e-12)
    facing=np.clip((-n[1]+.1)/.5,0,1)
    # Soft transition on lateral cheeks and lower neck; no clothes projected.
    feather=np.clip((world[...,2]-1.365)/.035,0,1)*np.clip((.12-np.abs(world[...,0]))/.035,0,1)
    alpha=inside*vis*facing*feather
    valid=(proj[...,0]>0)&(proj[...,0]<1)&(proj[...,1]>0)&(proj[...,1]<1)
    ix=np.clip((proj[...,0]*cw).astype(int),0,cw-1);iy=np.clip((proj[...,1]*ch).astype(int),0,ch-1)
    # Alpha from the emission source is implicit in visible mesh; don't use generated background.
    alpha*=valid
    result[y,x,:3]=result[y,x,:3]*(1-alpha[...,None])+cp[iy,ix,:3]*alpha[...,None]
    painted[y,x]|=alpha>.01
# Separate side projections remove ear/jaw/neck contamination without mirroring.
for side,sign in [('left',1),('right',-1)]:
    sideim=bpy.data.images.load(str(OUT/('face_clean_'+side+'.png')),check_existing=False)
    sw,sh=sideim.size;sp=np.array(sideim.pixels[:],np.float32).reshape(sh,sw,4)
    for t in m.loop_triangles:
        p=P[list(t.vertices)]
        if vertex_component[t.vertices[0]]!=0:continue
        if p[:,2].max()<1.37 or (sign*p[:,0]).max()<.025:continue
        n=np.cross(p[1]-p[0],p[2]-p[0]);n=n/max(np.linalg.norm(n),1e-12)
        facing=np.clip((sign*n[0]-.1)/.55,0,1)
        if facing<=0:continue
        q=raster(np.array([tuple(uv[i].uv) for i in t.loops])*[W,H],W,H)
        if q is None:continue
        x,y,b,inside=q;world=b@p
        px=sign*world[...,1]/.43+.5;py=(world[...,2]-1.535)/.43+.5
        ix=np.clip((px*sw).astype(int),0,sw-1);iy=np.clip((py*sh).astype(int),0,sh-1)
        color=sp[iy,ix,:3]
        skin_color=(color[...,0]>.25)&(color[...,0]>color[...,2]*1.15)
        start=np.where(world[...,2]<1.515,.030,.075)
        feather=np.clip((sign*world[...,0]-start)/.02,0,1)*np.clip((world[...,2]-1.36)/.035,0,1)
        feather*=np.where(world[...,2]<1.515,1,np.clip((world[...,1]+.07)/.035,0,1))
        alpha=inside*facing*feather*skin_color*(px>0)*(px<1)*(py>0)*(py<1)
        result[y,x,:3]=result[y,x,:3]*(1-alpha[...,None])+color*alpha[...,None]
        painted[y,x]|=alpha>.01
# Dilate updated texels only into atlas padding, never over other painted surface.
for _ in range(2):
    old=painted.copy()
    for dy,dx in [(1,0),(-1,0),(0,1),(0,-1)]:
        mask=np.roll(old,(dy,dx),(0,1))&~painted
        result[mask]=np.roll(result,(dy,dx),(0,1))[mask];painted[mask]=True
im=bpy.data.images.new('Fukuchan finished C albedo',width=W,height=H,alpha=True)
im.pixels.foreach_set(result.ravel());im.filepath_raw=str(OUT/'fukuchan_finished_albedo.png');im.file_format='PNG';im.save();im.pack();tex.image=im
def disconnect(node,slot):
    for link in list(node.inputs[slot].links):node.id_data.links.remove(link)
def material(name,color=None,rough=.7,spec=.22):
    a=mat.copy();a.name=name;b=next(n for n in a.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    for slot in ['Roughness','Metallic','Normal']:disconnect(b,slot)
    b.inputs['Roughness'].default_value=rough;b.inputs['Metallic'].default_value=0;b.inputs['Specular IOR Level'].default_value=spec
    if color is not None:
        disconnect(b,'Base Color');b.inputs['Base Color'].default_value=(*color,1)
    return a
skin=material('C soft skin, clean normals',rough=.68,spec=.18)
hair=material('C matte sculpted black hair',rough=.76,spec=.20)
cloth=material('C matte fabric',rough=.84,spec=.16)
# Uniform dark hair removes pale atlas contamination; retain skin subpixels on
# polygons crossing the actual hairline instead of painting whole triangles black.
hbs=next(n for n in hair.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
hair_mask=np.clip((pixels[:,:,0]-pixels[:,:,2]-.02)/.045,0,1)
hair_pixels=result.copy();hair_pixels[:,:,:3]=result[:,:,:3]*hair_mask[:,:,None]+np.array([.016,.019,.026])*(1-hair_mask[:,:,None])
hi=bpy.data.images.new('Hair clean atlas with skin boundary',width=W,height=H,alpha=True)
hi.pixels.foreach_set(hair_pixels.ravel());hi.filepath_raw=str(OUT/'fukuchan_hair_albedo.png');hi.file_format='PNG';hi.save();hi.pack()
hbs.inputs['Base Color'].links[0].from_node.image=hi
for a in [skin,hair,cloth]:m.materials.append(a)
counts={a.name:0 for a in [skin,hair,cloth]}
for f in m.polygons:
    p=P[list(f.vertices)].mean(0)
    colors=[]
    for li in f.loop_indices:
        u,v=uv[li].uv;colors.append(pixels[min(H-1,max(0,int(v*H))),min(W-1,max(0,int(u*W))),:3])
    rgb=np.mean(colors,axis=0)
    hair_region=(p[2]>1.58 or (abs(p[0])>.063 and p[2]>1.445) or (p[1]>.025 and p[2]>1.405))
    comp=vertex_component[f.vertices[0]]
    proj=projection(p);ix=int(np.clip(proj[0]*cw,0,cw-1));iy=int(np.clip(proj[1]*ch,0,ch-1));projected_rgb=cp[iy,ix,:3]
    repaired_hair=(p[2]>1.58 or (p[2]>1.475 and abs(p[0])>.066)) and p[1]<0 and projected_rgb.max()<.24
    is_hair=comp==0 and ((hair_region and rgb.max()<.24) or p[2]>1.635 or (abs(p[0])>.05 and p[2]>1.605) or repaired_hair)
    is_skin=not is_hair and comp in [0,3,4,*eye_components]
    f.material_index=2 if is_hair else (1 if is_skin else 3)
    counts[m.materials[f.material_index].name]+=1
# Replace only the two identified coarse eyeball components, preserving sockets.
eye_ids=set(np.flatnonzero(np.isin(vertex_component,eye_components)).tolist())
eye_bounds=[]
for i in eye_components:
    pts=U[components[i]];eye_bounds.append((pts.min(0),pts.max(0)))
bm=bmesh.new();bm.from_mesh(m);bm.verts.ensure_lookup_table()
bmesh.ops.delete(bm,geom=[bm.verts[i] for i in eye_ids],context='VERTS');bm.to_mesh(m);bm.free();m.update()
white_eye=material('Natural sclera',(.40,.42,.41),.38,.38)
iris=material('Dark brown iris',(.020,.009,.004),.20,.42)
rim=material('Iris outer ring',(.013,.009,.006),.42,.28)
pupil=material('Single dark pupil',(.0015,.002,.0025),.16,.48)
eye_objects=[]
def cap(name,center,radii,radius,material):
    cx,cy,cz=center;rx,ry,rz=radii;shift=.0012
    verts=[(cx,cy-ry*math.sqrt(1-(shift/rz)**2)-.00015,cz+shift)];faces=[]
    segments=64;rings=5
    for j in range(1,rings+1):
        r=radius*j/rings
        for i in range(segments):
            a=2*math.pi*i/segments;dx=r*math.cos(a);dz=r*math.sin(a)+shift
            yy=cy-ry*math.sqrt(max(0,1-(dx/rx)**2-(dz/rz)**2))-.00015
            verts.append((cx+dx,yy,cz+dz))
    for i in range(segments):faces.append((0,1+i,1+(i+1)%segments))
    for j in range(1,rings):
        for i in range(segments):
            a=1+(j-1)*segments+i;b=1+(j-1)*segments+(i+1)%segments;c=1+j*segments+(i+1)%segments;d=1+j*segments+i;faces.append((a,b,c,d))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.materials.append(material)
    obj=bpy.data.objects.new(name,mesh);s.collection.objects.link(obj)
    for f in mesh.polygons:f.use_smooth=True
    eye_objects.append(obj)
for i,(lo,hi) in enumerate(eye_bounds):
    center=(lo+hi)/2;radii=(hi-lo)/2
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48,ring_count=24,location=center)
    eye=bpy.context.object;eye.name='Smooth eyeball '+str(i);eye.scale=radii;eye.data.materials.append(white_eye)
    for f in eye.data.polygons:f.use_smooth=True
    eye_objects.append(eye)
    for name,r,eye_mat,offset in [('Iris rim',.0078,rim,0),('Brown iris',.0072,iris,.00005),('Pupil',.0034,pupil,.00010)]:
        c=center.copy();c[1]-=offset;cap(name+' '+str(i),c,radii,r,eye_mat)
# Cover original illegible print inside its existing badge frame.
tree=BVHTree.FromObject(o,bpy.context.evaluated_depsgraph_get())
center=(-.004,1.032);width=.104;height=.057
hits=[]
for x in np.linspace(center[0]-width/2,center[0]+width/2,7):
    for z in np.linspace(center[1]-height/2,center[1]+height/2,5):
        hit=tree.ray_cast(Vector((x,-2,z)),Vector((0,1,0)))
        if hit[0] is not None:hits.append(hit[0].y)
badge_y=min(hits)-.0008
white=material('Name badge white',(.91,.91,.895),.75,.12)
black=material('Name badge ink',(.008,.009,.010),.85,.10)
bpy.ops.mesh.primitive_cube_add(size=1,location=(center[0],badge_y,center[1]))
plate=bpy.context.object;plate.name='Name badge clean face';plate.dimensions=(width,.001,height)
bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
plate.data.materials.append(white)
bev=plate.modifiers.new('Subtle rounded card corners','BEVEL');bev.width=.0013;bev.segments=3
bpy.context.view_layer.objects.active=plate;bpy.ops.object.modifier_apply(modifier=bev.name)
curve=bpy.data.curves.new('Exact Japanese 福ちゃん','FONT');curve.body='福ちゃん';curve.align_x='CENTER';curve.align_y='CENTER'
curve.font=bpy.data.fonts.load('/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc');curve.size=.03;curve.resolution_u=12
text=bpy.data.objects.new('福ちゃん',curve);s.collection.objects.link(text)
text.rotation_euler=(math.pi/2,0,0);text.location=(center[0],badge_y-.00065,center[1])
text.data.materials.append(black)
bpy.context.view_layer.update();text.scale*=min(.083/text.dimensions.x,.022/text.dimensions.y)
bpy.ops.object.select_all(action='DESELECT');text.select_set(True);bpy.context.view_layer.objects.active=text;bpy.ops.object.convert(target='MESH')
text=bpy.context.object
# Keep one reusable whole-body mesh after adding the badge face and exact lettering.
bpy.ops.object.select_all(action='DESELECT')
for a in [o,plate,text,*eye_objects]:a.select_set(True)
bpy.context.view_layer.objects.active=o;bpy.ops.object.join();o.name='Fukuchan_C_Finished'
remaining=original_P[[i for i in range(len(original_P)) if i not in eye_ids]]
after_P=np.array([tuple(o.matrix_world@v.co) for v in o.data.vertices[:len(remaining)]])
assert np.allclose(remaining,after_P,atol=1e-7),'Geometry outside eyeballs moved'
(OUT/'finish_report.json').write_text(json.dumps({'original_vertices':len(P),'geometry_outside_eyeballs_unchanged':True,'removed_coarse_eye_vertices':len(eye_ids),'eye_bounds':[ [a.tolist(),b.tolist()] for a,b in eye_bounds],'repainted_texels':int(painted.sum()),'material_faces':counts,'badge_text':'福ちゃん','badge_center':[center[0],badge_y,center[1]],'badge_font':'Hiragino Kaku Gothic W6','source_glb':str(BASE/'fukuchan_wholebody.glb')},ensure_ascii=False,indent=2)+'\n')
bpy.ops.export_scene.gltf(filepath=str(OUT/'fukuchan_finished.glb'),export_format='GLB',use_selection=True,export_animations=False)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'fukuchan_finished.blend'))
print('FINISH_MODEL_DONE',flush=True)
