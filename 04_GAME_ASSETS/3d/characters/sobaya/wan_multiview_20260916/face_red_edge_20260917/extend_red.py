import bpy,numpy as np,json
from pathlib import Path
O=Path(__file__).resolve().parent;S=O.parent/'face_scale_20260917'
bpy.ops.wm.open_mainfile(filepath=str(S/'sobaya_front_matched.blend'))
img=bpy.data.images['Sobaya reference mask color'];W,H=img.size
p=np.array(img.pixels[:],dtype=np.float32).reshape(H,W,4)[::-1].copy();red=(p[:,:,0]>p[:,:,1]*2)&(p[:,:,0]<.7);before=p.copy()
# Extend only the four eye-facing ends, following the eye ellipse in the existing
# projection texture. The inherited UV already applies the accepted 90% scale.
for cx,cy in [(404.8,545.83),(674.44,555.54)]:
 for ix in range(int((cx-76)*2),int((cx+76)*2)):
  x=(ix+.5)/2;dx=x-cx
  # Rotated ellipse: dx = a cos(t) - roll*b sin(t).
  a,b,r=76.5,83.5,.036
  # Direct sampled boundary avoids assumptions about the affine roll convention.
  t=np.linspace(0,2*np.pi,4096);xx=cx+a*np.cos(t)-r*b*np.sin(t);yy=cy+b*np.sin(t)+r*a*np.cos(t)
  top=yy<cy;bot=~top
  def edge(sel):
   order=np.argsort(xx[sel]);return np.interp(x,xx[sel][order],yy[sel][order])
  upper=np.flatnonzero(red[int((cy-250)*2):int((cy-65)*2),ix])+int((cy-250)*2)
  if len(upper):
   y0=upper[-1];y1=int((edge(top)+12)*2)
   if y1>y0:p[y0:y1+1,ix]=[.50,.025,.045,1]
  lower=np.flatnonzero(red[int((cy+65)*2):int((cy+290)*2),ix])+int((cy+65)*2)
  if len(lower):
   y1=lower[0];y0=max(y1-50,int((edge(bot)-12)*2))
   if y0<y1:p[y0:y1+1,ix]=[.50,.025,.045,1]
img.pixels.foreach_set(p[::-1].copy().ravel());img.filepath_raw=str(O/'sobaya_red_eye_edge.png');img.file_format='PNG';img.save()
# Replace the inherited packed datablock so saved/reopened files use the new PNG.
fresh=bpy.data.images.load(str(O/'sobaya_red_eye_edge.png'),check_existing=False);fresh.name='Sobaya red to eye edge';fresh.pack()
for mat in bpy.data.materials:
 if mat.use_nodes:
  for node in mat.node_tree.nodes:
   if node.type=='TEX_IMAGE' and node.image==img:node.image=fresh
json.dump({'geometry_changed':False,'texture_changed_pixels':int(np.any(p!=before,axis=2).sum()),'eye_edge_overlap_source_px':12},open(O/'change_check.json','w'),indent=2)
s=bpy.context.scene;s.cycles.samples=32
bpy.ops.wm.save_as_mainfile(filepath=str(O/'sobaya_front_matched.blend'))
s.render.filepath=str(O/'front.png');bpy.ops.render.render(write_still=True)
