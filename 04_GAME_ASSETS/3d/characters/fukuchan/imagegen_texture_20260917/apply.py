"""Bake Imagegen's registered multiview hair repair onto existing UVs, no geometry edits."""
import bpy,numpy as np,json
from pathlib import Path
OUT=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(OUT.parent/'front_fidelity_20260917/fukuchan_front_faithful.blend'))
o=next(x for x in bpy.context.scene.objects if x.type=='MESH');m=o.data;m.calc_loop_triangles()
P=np.array([tuple(o.matrix_world@v.co) for v in m.vertices]);source_positions=P.copy();uv=m.uv_layers[0].data
im=bpy.data.images.load(str(OUT/'imagegen_hair_repair.png'));gw,gh=im.size;g=np.array(im.pixels[:],np.float32).reshape(gh,gw,4)
side=bpy.data.images.load(str(OUT/'imagegen_profile_repair.png'));sw,sh=side.size;sg=np.array(side.pixels[:],np.float32).reshape(sh,sw,4)
hair_color=np.median(g[:,:,:3][(g[:,:,:3].max(-1)<.12)&(g[:,:,:3].min(-1)>.005)],axis=0)
ref=bpy.data.images.load(str(OUT.parent/'front_fidelity_20260917/front_illumination_corrected.png'));rw,rh=ref.size;rp=np.array(ref.pixels[:],np.float32).reshape(rh,rw,4)
views=[('front',(0,-1,0),(0,1)),('left',(.9,-.7,0),(1,1)),('right',(-.9,-.7,0),(0,0)),('back',(0,1,0),(1,0))]
views += [('profile_left',(1,0,0),(0,0)),('profile_right',(-1,0,0),(1,0))]
D=1024
def raster(tri,W,H):
 lo=np.maximum(np.floor(tri.min(0)).astype(int),0);hi=np.minimum(np.ceil(tri.max(0)).astype(int),[W-1,H-1])
 if np.any(hi<lo):return
 xx,yy=np.meshgrid(np.arange(lo[0],hi[0]+1),np.arange(lo[1],hi[1]+1));a,b,c=tri
 den=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
 if abs(den)<1e-12:return
 u=((b[1]-c[1])*(xx+.5-c[0])+(c[0]-b[0])*(yy+.5-c[1]))/den;v=((c[1]-a[1])*(xx+.5-c[0])+(a[0]-c[0])*(yy+.5-c[1]))/den;w=1-u-v
 return xx,yy,np.stack([u,v,w],-1),(u>=-1e-5)&(v>=-1e-5)&(w>=-1e-5)
prepared=[]
for name,di,panel in views:
 d=np.array(di,float);d/=np.linalg.norm(d);right=np.array([-d[1],d[0],0]);depth=np.full((D,D),np.inf,np.float32)
 def project(p):return np.stack([.5+p@right/.38,.5+(p[...,2]-1.54)/.38],-1)
 for t in m.loop_triangles:
  p=P[list(t.vertices)]
  if p[:,2].max()<1.35:continue
  r=raster(project(p)*D,D,D)
  if r is None:continue
  x,y,b,inside=r;dist=-(b@p)@d;depth[y,x]=np.where(inside,np.minimum(depth[y,x],dist),depth[y,x])
 prepared.append((name,d,right,panel,depth))
report={};material_masks={}
for mi,mat in enumerate(list(m.materials)):
 if not any(k in mat.name for k in ['Front faithful skin','sculpted black hair']):continue
 bs=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');tex=bs.inputs['Base Color'].links[0].from_node
 W,H=tex.image.size;pixels=np.array(tex.image.pixels[:],np.float32).reshape(H,W,4);result=pixels.copy();best=np.zeros((H,W),np.float32);fix=np.zeros((H,W),bool);occupied=np.zeros((H,W),bool)
 for t in m.loop_triangles:
  if t.material_index!=mi:continue
  p=P[list(t.vertices)]
  if p[:,2].max()<1.42:continue
  r=raster(np.array([tuple(uv[i].uv) for i in t.loops])*[W,H],W,H)
  if r is None:continue
  x,y,b,inside=r;occupied[y,x]|=inside;world=b@p;n=np.cross(p[1]-p[0],p[2]-p[0]);n/=max(np.linalg.norm(n),1e-12)
  region=(world[...,2]>1.60)|((world[...,2]>1.475)&(np.abs(world[...,0])>.060))|((world[...,2]>1.56)&(np.abs(world[...,0])>.043))|((world[...,1]>.005)&(world[...,2]>1.43))
  fringe=(world[...,2]>1.525)&(world[...,1]<-.105)&(np.abs(world[...,0])>.038)
  fringe|=(world[...,2]>1.60)&(world[...,1]<-.10)
  fringe|=(world[...,2]>1.56)&(np.abs(world[...,0])>.055)&(world[...,1]<-.072)
  fringe|=(world[...,2]>1.58)&(np.abs(world[...,0])>.050)&(world[...,1]<-.072)
  region|=fringe
  # Protect the actual central forehead and ear surfaces.
  forehead=(np.abs(world[...,0])<np.clip(.063-.50*(world[...,2]-1.55),.018,.063))&(world[...,2]>1.555)&(world[...,2]<1.63)&(world[...,1]<0)&(world[...,1]>-.105)&~fringe
  cheek=(np.abs(world[...,0])<.079)&(world[...,2]<1.555)&(world[...,1]<-.04)&(world[...,1]>-.105)
  ear=(np.abs(world[...,0])>.073)&(world[...,2]>1.465)&(world[...,2]<1.555)&(world[...,1]>-.03)&(world[...,1]<.065)
  region&=~(forehead|cheek)
  fallback=(fringe|('sculpted black hair' in mat.name))&region&~ear&inside
  result[y,x,:3]=np.where(fallback[...,None],hair_color,result[y,x,:3]);fix[y,x]|=fallback
  for name,d,right,panel,depth in prepared:
   px=.5+world@right/.38;py=.5+(world[...,2]-1.54)/.38
   ix=np.clip((px*D).astype(int),0,D-1);iy=np.clip((py*D).astype(int),0,D-1)
   visible=(-world@d-depth[iy,ix])<.004
   profile=name.startswith('profile')
   score=(abs(n@d)**2)*visible*inside*region*(px>0)*(px<1)*(py>0)*(py<1)
   replace=score>best[y,x]
   gx=np.clip(((px+panel[0])*gw/2).astype(int),0,gw-1);gy=np.clip(((py+panel[1])*gh/2).astype(int),0,gh-1);color=g[gy,gx,:3]
   if profile:
    gx=np.clip(((px+panel[0])*sw/2).astype(int),0,sw-1);gy=np.clip((py*sh).astype(int),0,sh-1);color=sg[gy,gx,:3]
   is_hair=(color.max(-1)<.23)&((color.max(-1)-color.min(-1))<.08)
   is_skin=(color[...,0]>.3)&(color[...,0]-color[...,2]>.06)
   accept=is_hair| (is_skin & ~fringe & (ear|('sculpted black hair' in mat.name)))
   # Accept the generated hair; protected facial regions never enter this projection.
   result[y,x,:3]=np.where((replace&accept)[...,None],color,result[y,x,:3])
   fix[y,x]|=replace&is_hair;best[y,x]=np.maximum(best[y,x],score)
  if 'sculpted black hair' in mat.name:
   # Some forehead polygons inherited the hair material. Restore their exact front color.
   rx=np.clip(411+590*world[...,0]-.5,0,rw-2);ry=np.clip(rh-(24.5+590*(1.7-world[...,2]))-.5,0,rh-2)
   ix=rx.astype(int);iy=ry.astype(int);fx=rx-ix;fy=ry-iy
   color=rp[iy,ix,:3]*(1-fx)[...,None]*(1-fy)[...,None]+rp[iy,ix+1,:3]*fx[...,None]*(1-fy)[...,None]+rp[iy+1,ix,:3]*(1-fx)[...,None]*fy[...,None]+rp[iy+1,ix+1,:3]*fx[...,None]*fy[...,None]
   result[y,x,:3]=np.where((forehead&inside)[...,None],color,result[y,x,:3])
  # A foreground skin pixel must not overwrite an occluded, positively identified hair face.
  c=result[y,x,:3];dark=(c.max(-1)<.20)&((c.max(-1)-c.min(-1))<.06)
  result[y,x,:3]=np.where((fallback&~dark)[...,None],hair_color,result[y,x,:3])
  result[y,x,:3]=np.where(fallback[...,None],np.minimum(result[y,x,:3],hair_color*1.4),result[y,x,:3])
  preserve_lower=(world[...,2]<1.555)&~fringe
  preserve=(ear|preserve_lower)&inside
  result[y,x,:3]=np.where(preserve[...,None],pixels[y,x,:3],result[y,x,:3])
  fix[y,x]&=~preserve
 # Pad edited islands against texture filtering seams.
 for _ in range(6):
  old=fix.copy()
  for dy,dx in [(1,0),(-1,0),(0,1),(0,-1)]:
   mask=np.roll(old,(dy,dx),(0,1))&~fix&~occupied
   result[mask]=np.roll(result,(dy,dx),(0,1))[mask];fix[mask]=True
 out=bpy.data.images.new('Imagegen repair '+str(mi),width=W,height=H,alpha=True);out.pixels.foreach_set(result.ravel());out.filepath_raw=str(OUT/('texture_'+str(mi)+'.png'));out.file_format='PNG';out.save();out.pack();tex.image=out
 report[mat.name]={'changed_texels':int(np.any(result[:,:,:3]!=pixels[:,:,:3],axis=2).sum()),'accepted_hair_texels':int(fix.sum())};material_masks[mi]=(fix,W,H)
# Hair triangles formerly assigned to skin must use hair roughness as well.
hair=next(a for a in m.materials if 'sculpted black hair' in a.name)
for mi,(mask,W,H) in material_masks.items():
 mat=m.materials[mi]
 if 'Front faithful skin' not in mat.name:continue
 replacement=hair.copy();replacement.name='Imagegen hair on corrected skin atlas'
 rb=next(n for n in replacement.node_tree.nodes if n.type=='BSDF_PRINCIPLED');sb=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');rb.inputs['Base Color'].links[0].from_node.image=sb.inputs['Base Color'].links[0].from_node.image
 m.materials.append(replacement);ri=len(m.materials)-1;count=0
 for f in m.polygons:
  if f.material_index!=mi:continue
  coords=np.array([tuple(uv[i].uv) for i in f.loop_indices]);c=coords.mean(0);xx=int(np.clip(c[0]*W,0,W-1));yy=int(np.clip(c[1]*H,0,H-1))
  if mask[yy,xx]:f.material_index=ri;count+=1
 report['hair_material_faces']=count
assert np.array_equal(source_positions,np.array([tuple(o.matrix_world@v.co) for v in m.vertices]))
o.name='Fukuchan_Imagegen_Texture_Fixed';bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
bpy.ops.export_scene.gltf(filepath=str(OUT/'fukuchan_texture_fixed.glb'),export_format='GLB',use_selection=True,export_animations=False)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'fukuchan_texture_fixed.blend'))
report['geometry_unchanged']=True;(OUT/'repair_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print('REPAIR_DONE',flush=True)
