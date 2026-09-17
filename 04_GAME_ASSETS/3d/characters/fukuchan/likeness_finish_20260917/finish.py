"""Final reference-color projection on the approved shallow face, immutable geometry."""
import bpy,numpy as np,json,struct
from pathlib import Path
O=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(O.parent/'shallow_face_20260917/fukuchan_balanced.blend'))
o=next(a for a in bpy.context.scene.objects if a.type=='MESH');m=o.data;m.calc_loop_triangles();P=np.array([tuple(o.matrix_world@v.co) for v in m.vertices]);uv=m.uv_layers[0].data
ref=bpy.data.images.load(str(O.parent/'wan_multiview_20260917/inputs/front.png'));rw,rh=ref.size;rp=np.array(ref.pixels[:],np.float32).reshape(rh,rw,4)
def raster(tri,W,H):
 lo=np.maximum(np.floor(tri.min(0)).astype(int),0);hi=np.minimum(np.ceil(tri.max(0)).astype(int),[W-1,H-1])
 if np.any(hi<lo):return
 xx,yy=np.meshgrid(np.arange(lo[0],hi[0]+1),np.arange(lo[1],hi[1]+1));a,b,c=tri;den=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
 if abs(den)<1e-12:return
 u=((b[1]-c[1])*(xx+.5-c[0])+(c[0]-b[0])*(yy+.5-c[1]))/den;v=((c[1]-a[1])*(xx+.5-c[0])+(a[0]-c[0])*(yy+.5-c[1]))/den;w=1-u-v
 return xx,yy,np.stack([u,v,w],-1),(u>=-1e-5)&(v>=-1e-5)&(w>=-1e-5)
def smooth(v):v=np.clip(v,0,1);return v*v*(3-2*v)
def sample(world):
 x=np.clip(411+590*world[...,0]-.5,1,rw-3.001);y=np.clip(rh-(24.5+590*(1.7-world[...,2]))-.5,1,rh-3.001);ix=x.astype(int);iy=y.astype(int)
 def k(t):t=np.abs(t);return np.where(t<1,1.5*t**3-2.5*t**2+1,np.where(t<2,-.5*t**3+2.5*t**2-4*t+2,0))
 out=np.zeros((*x.shape,3),float)
 for j in [-1,0,1,2]:
  for i in [-1,0,1,2]:out+=rp[iy+j,ix+i,:3]*(k(x-ix-i)*k(y-iy-j))[...,None]
 return np.clip(out,0,1)
# Visibility buffer prevents foreground skin from painting the underside of the bangs.
D=1200;depth=np.full((D,D),np.inf,np.float32)
for t in m.loop_triangles:
 p=P[list(t.vertices)]
 if p[:,2].max()<1.4:continue
 pr=np.stack([.5+p[:,0]/.38,.5+(p[:,2]-1.54)/.38],-1)
 r=raster(pr*D,D,D)
 if r is None:continue
 x,y,b,inside=r;d=(b@p)[...,1];depth[y,x]=np.where(inside,np.minimum(depth[y,x],d),depth[y,x])
report={}
for mi,mat in enumerate(m.materials):
 if mat.name not in ['Front faithful skin','Balanced forehead skin']:continue
 nodes=mat.node_tree.nodes;tex=next(n for n in nodes if n.type=='TEX_IMAGE');W,H=tex.image.size;old=np.array(tex.image.pixels[:],np.float32).reshape(H,W,4);result=old.copy();occupied=np.zeros((H,W),bool);changed=np.zeros((H,W),bool)
 for t in m.loop_triangles:
  if t.material_index!=mi:continue
  p=P[list(t.vertices)]
  if p[:,2].max()<1.43:continue
  r=raster(np.array([tuple(uv[i].uv) for i in t.loops])*[W,H],W,H)
  if r is None:continue
  x,y,b,inside=r;occupied[y,x]|=inside;world=b@p;wx,wy,wz=world[...,0],world[...,1],world[...,2]
  ix=np.clip(((.5+wx/.38)*D).astype(int),0,D-1);iy=np.clip(((.5+(wz-1.54)/.38)*D).astype(int),0,D-1);vis=(wy-depth[iy,ix])<.002
  color=sample(world);oldcolor=old[y,x,:3]
  # Keep all repaired hair texels and preserve the side/ear/neck atlas.
  skin=(oldcolor[...,0]>.28)&(oldcolor[...,0]-oldcolor[...,2]>.055)&(color[...,0]-color[...,2]>.045)
  a=inside*vis*skin*smooth((.080-np.abs(wx))/.020)*smooth((wz-1.435)/.020)*smooth((1.634-wz)/.014)*smooth((-.035-wy)/.035)
  result[y,x,:3]=result[y,x,:3]*(1-a[...,None])+color*a[...,None];changed[y,x]|=a>0
 for _ in range(4):
  oldmask=changed.copy()
  for dy,dx in [(1,0),(-1,0),(0,1),(0,-1)]:
   mask=np.roll(oldmask,(dy,dx),(0,1))&~changed&~occupied;result[mask]=np.roll(result,(dy,dx),(0,1))[mask];changed[mask]=True
 im=bpy.data.images.new('Final front colors '+str(mi),width=W,height=H,alpha=True);im.pixels.foreach_set(result.ravel());im.filepath_raw=str(O/('atlas_'+str(mi)+'.png'));im.file_format='PNG';im.save();im.pack();tex.image=im
 report[mat.name]={'changed_texels':int(changed.sum())}
# Retain the original reference's pupil, iris and catchlight pixels on the curved eyes.
eye=next(mat for mat in m.materials if mat.name=='Natural sclera')
for n in eye.node_tree.nodes:
 if n.type=='TEX_IMAGE':n.image=ref
ref.pack()
# A subtle neutral fill keeps the center-part hair readable under the site's directional lights.
for mat in m.materials:
 if 'sculpted black hair' in mat.name or 'Imagegen hair' in mat.name:
  bs=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');bs.inputs['Emission Color'].default_value=(.010,.012,.016,1);bs.inputs['Emission Strength'].default_value=1;bs.inputs['Roughness'].default_value=.64
# Calibrate overall facial luminance for the site's bright ACES-mapped lighting,
# preserving the approved 45:55 diffuse/reference-color ratio.
for mat in m.materials:
 if mat.name not in ['Front faithful skin','Natural sclera','Balanced forehead skin']:continue
 bs=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
 bs.inputs['Emission Strength'].default_value=.44
 for node in mat.node_tree.nodes:
  if node.type=='MIX_RGB' and node.blend_type=='MULTIPLY':node.inputs[2].default_value=(.36,.36,.36,1)
bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;o.name='Fukuchan_Likeness_Final'
bpy.ops.export_scene.gltf(filepath=str(O/'fukuchan_final.glb'),export_format='GLB',use_selection=True,export_animations=False);bpy.ops.wm.save_as_mainfile(filepath=str(O/'fukuchan_final.blend'))
# Preserve the approved diffuse/emission balance after Blender's export.
p=O/'fukuchan_final.glb';data=p.read_bytes();n=struct.unpack_from('<I',data,12)[0];g=json.loads(data[20:20+n]);tail=data[20+n:]
for mat in g['materials']:
 if mat['name'] in ['Front faithful skin','Natural sclera','Balanced forehead skin']:mat['pbrMetallicRoughness']['baseColorFactor']=[.36,.36,.36,1]
j=json.dumps(g,separators=(',',':')).encode();j+=b' '*((-len(j))%4);p.write_bytes(struct.pack('<4sII',b'glTF',2,20+len(j)+len(tail))+struct.pack('<II',len(j),0x4e4f534a)+j+tail)
report['geometry_and_uv_unchanged']=True;(O/'finish_report.json').write_text(json.dumps(report,indent=2)+'\n');print('FINISH_DONE',flush=True)
