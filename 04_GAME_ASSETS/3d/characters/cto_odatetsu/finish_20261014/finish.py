"""Local texture projection + material correction; preserve source vertices/UVs."""
import bpy,numpy as np,json,sys
from pathlib import Path
from mathutils import Vector
O=Path(__file__).resolve().parent;Q=O/'qa';sys.path.insert(0,str(O))
bpy.ops.wm.open_mainfile(filepath=str(O/'normalized_base.blend'))
s=bpy.context.scene;o=next(x for x in s.objects if x.type=='MESH');m=o.data;m.calc_loop_triangles()
P=np.array([tuple(v.co) for v in m.vertices]);uv=m.uv_layers.active.data
mat=m.materials[0];bs=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');tex=bs.inputs['Base Color'].links[0].from_node
W,H=tex.image.size;orig=np.array(tex.image.pixels[:],np.float32).reshape(H,W,4);result=orig.copy();occupied=np.zeros((H,W),bool);changed=np.zeros((H,W),bool)

def raster(tri,w,h):
 lo=np.maximum(np.floor(tri.min(0)).astype(int),0);hi=np.minimum(np.ceil(tri.max(0)).astype(int),[w-1,h-1])
 if np.any(hi<lo):return
 xx,yy=np.meshgrid(np.arange(lo[0],hi[0]+1),np.arange(lo[1],hi[1]+1));a,b,c=tri;den=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
 if abs(den)<1e-12:return
 u=((b[1]-c[1])*(xx+.5-c[0])+(c[0]-b[0])*(yy+.5-c[1]))/den;v=((c[1]-a[1])*(xx+.5-c[0])+(a[0]-c[0])*(yy+.5-c[1]))/den;wgt=1-u-v
 return xx,yy,np.stack([u,v,wgt],-1),(u>=0)&(v>=0)&(wgt>=0)

def font_mask(name,words,width,center):
 if '--reuse-type' in sys.argv and (Q/(name+'_type.png')).exists():
  im=bpy.data.images.load(str(Q/(name+'_type.png')),check_existing=False)
  return np.array(im.pixels[:],np.float32).reshape(1024,1024,4)[:,:,3]
 # Native vector type rendered only as a projection mask. No generative lettering.
 scene=bpy.data.scenes.new('Typography_'+name);scene.render.engine='CYCLES';scene.cycles.samples=8;scene.render.resolution_x=scene.render.resolution_y=1024;scene.render.resolution_percentage=100;scene.render.film_transparent=True;scene.view_settings.view_transform='Standard'
 d=bpy.data.cameras.new('TypeCamera');c=bpy.data.objects.new('TypeCamera',d);scene.collection.objects.link(c);c.location=(.5,.5,3);d.type='ORTHO';d.ortho_scale=1;scene.camera=c
 white=bpy.data.materials.new('Print white');white.use_nodes=True;n=white.node_tree.nodes;n.clear();e=n.new('ShaderNodeEmission');e.inputs[0].default_value=(1,1,1,1);out=n.new('ShaderNodeOutputMaterial');white.node_tree.links.new(e.outputs[0],out.inputs[0])
 font=bpy.data.fonts.load('/System/Library/Fonts/Supplemental/Arial Bold Italic.ttf')
 pieces=[];cursor=0
 for word,ratio in words:
  d=bpy.data.curves.new(word,'FONT');d.body=word;d.font=font;d.size=ratio;d.resolution_u=12;a=bpy.data.objects.new(word,d);scene.collection.objects.link(a);a.data.materials.append(white);pieces.append((a,cursor));bpy.context.view_layer.update()
  # Font geometry evaluation uses this scene's depsgraph.
  with bpy.context.temp_override(scene=scene):
   bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get();ev=a.evaluated_get(deps);bounds=[Vector(v) for v in ev.bound_box];ww=max(v.x for v in bounds)-min(v.x for v in bounds)
  cursor+=ww+.12
 total=cursor-.12;factor=width/total
 for a,x in pieces:a.scale=(factor,factor,factor);a.location=(center[0]-width/2+x*factor,center[1],0)
 scene.render.filepath=str(Q/(name+'_type.png'));bpy.ops.render.render(write_still=True,scene=scene.name)
 im=bpy.data.images.load(scene.render.filepath,check_existing=False);arr=np.array(im.pixels[:],np.float32).reshape(1024,1024,4)
 bpy.data.scenes.remove(scene)
 return arr[:,:,3]

masks={'chest':font_mask('chest',[('GROW',1),('with',.64),('YUMEMI',1)],.58,(.5,.515)),
 'shoe_left':font_mask('shoe_left',[('A',1)],.125,(.403,.397)),
 'shoe_right':font_mask('shoe_right',[('A',1)],.125,(.548,.397))}
# Coordinates correspond to prepare.py's orthographic albedo renders.
views=[('chest',np.array([0,-1,0]),np.array([0,0,1.25]),.48,(.19,.80,.475,.585)),('shoe_left',np.array([1,0,0]),np.array([.22,0,.09]),.37,(.30,.515,.365,.535)),('shoe_right',np.array([-1,0,0]),np.array([-.22,0,.09]),.37,(.42,.67,.365,.535))]
views += [('shoe_inner_left',np.array([-1,0,0]),np.array([.22,0,.09]),.37,(.12,.87,.36,.63)),('shoe_inner_right',np.array([1,0,0]),np.array([-.22,0,.09]),.37,(.12,.87,.36,.63))]
source_name={'shoe_inner_left':'shoe_right','shoe_inner_right':'shoe_left'}
D=1024;report={};prepared=[]
for name,d,pt,scale,box in views:
 right=np.array([-d[1],d[0],0]);depth=np.full((D,D),np.inf,np.float32)
 for t in m.loop_triangles:
  p=P[list(t.vertices)]
  if name=='shoe_inner_left' and p[:,0].max()<.08:continue
  if name=='shoe_inner_right' and p[:,0].min()>-.08:continue
  proj=np.stack([.5+(p-pt)@right/scale,.5+(p[:,2]-pt[2])/scale],-1);r=raster(proj*D,D,D)
  if r is None:continue
  x,y,b,inside=r;dist=-(b@p)@d;depth[y,x]=np.where(inside,np.minimum(depth[y,x],dist),depth[y,x])
 im=bpy.data.images.load(str(O/'repair_inputs'/(source_name.get(name,name)+'_clean.png')));iw,ih=im.size;pix=np.array(im.pixels[:],np.float32).reshape(ih,iw,4)
 prepared.append((name,d,pt,scale,box,right,depth,pix,iw,ih));report[name]=0
for t in m.loop_triangles:
 p=P[list(t.vertices)];r=raster(np.array([tuple(uv[i].uv) for i in t.loops])*[W,H],W,H)
 if r is None:continue
 x,y,b,inside=r;occupied[y,x]|=inside
 world=b@p;n=np.cross(p[1]-p[0],p[2]-p[0]);n/=max(np.linalg.norm(n),1e-12)
 for name,d,pt,sc,box,right,depth,pix,iw,ih in prepared:
  if n@d<(-.2 if name.startswith('shoe_inner') else .12):continue
  px=.5+(world-pt)@right/sc;py=.5+(world[...,2]-pt[2])/sc
  ix=np.clip((px*D).astype(int),0,D-1);iy=np.clip((py*D).astype(int),0,D-1)
  region=inside&(px>box[0])&(px<box[1])&(py>box[2])&(py<box[3])&(-world@d-depth[iy,ix] < (.04 if name.startswith('shoe_inner') else .0025))
  if name.startswith('shoe_inner'):region&=(world[...,2]>.04)&(world[...,2]<.115)
  if name=='shoe_inner_left':region&=world[...,0]>.08
  if name=='shoe_inner_right':region&=world[...,0]<-.08
  if name=='chest':
   # Keep the two raised cords untouched and never paint their lettering.
   region&=~((abs(world[...,0]+.036)<.007)|(abs(world[...,0]-.037)<.007))
  if not np.any(region):continue
  gx=np.clip((px*iw).astype(int),0,iw-1);gy=np.clip((py*ih).astype(int),0,ih-1);col=pix[gy,gx,:3]
  # Feather only at the perimeter of the limited repair window.
  edge=np.minimum.reduce([px-box[0],box[1]-px,py-box[2],box[3]-py]);blend=np.clip(edge/.01,0,1)*region
  alpha=masks[source_name.get(name,name)][iy,ix]*region
  final=col*(1-alpha[...,None])+np.array([.93,.93,.93])*alpha[...,None]
  result[y,x,:3]=result[y,x,:3]*(1-blend[...,None])+final*blend[...,None]
  changed[y,x]|=region;report[name]+=int(region.sum())
for _ in range(6):
 old=changed.copy()
 for dy,dx in [(1,0),(-1,0),(0,1),(0,-1)]:
  mask=np.roll(old,(dy,dx),(0,1))&~changed&~occupied;result[mask]=np.roll(result,(dy,dx),(0,1))[mask];changed[mask]=True
im=bpy.data.images.new('CTO_Odatetsu_Albedo',width=W,height=H,alpha=True);im.pixels.foreach_set(result.ravel());im.filepath_raw=str(O/'cto_odatetsu_albedo.png');im.file_format='PNG';im.save();im.pack();tex.image=im
# All character surfaces are nonmetallic. Discard noisy generated micro-normal and roughness maps.
for key,value in [('Metallic',0),('Roughness',.72),('Specular IOR Level',.28)]:
 for l in list(bs.inputs[key].links):mat.node_tree.links.remove(l)
 bs.inputs[key].default_value=value
for l in list(bs.inputs['Normal'].links):mat.node_tree.links.remove(l)
mat.name='CTO_Odatetsu_Matte'
from patch_slits import patch_clothing_slits
report['clothing_slits']=patch_clothing_slits(m)
assert np.array_equal(P,np.array([tuple(v.co) for v in m.vertices]))
report['source_vertices_preserved']=True;report['texture_size']=[W,H];report['changed_texels']=int(changed.sum());report['basecolor_only_in_local_masks']=True
bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
bpy.ops.export_scene.gltf(filepath=str(O/'cto_odatetsu_static.glb'),export_format='GLB',use_selection=True,export_animations=False)
bpy.ops.wm.save_as_mainfile(filepath=str(O/'cto_odatetsu_finished.blend'))
(O/'finish_report.json').write_text(json.dumps(report,indent=2)+'\n')
print('FINISH_DONE',flush=True)
