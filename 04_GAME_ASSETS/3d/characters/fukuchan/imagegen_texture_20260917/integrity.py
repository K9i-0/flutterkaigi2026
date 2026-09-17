import bpy,numpy as np,json
from pathlib import Path
O=Path(__file__).resolve().parent

def read(path):
 bpy.ops.wm.open_mainfile(filepath=str(path));o=next(x for x in bpy.context.scene.objects if x.type=='MESH');m=o.data
 p=np.array([tuple(o.matrix_world@v.co) for v in m.vertices]);uv=np.array([tuple(x.uv) for x in m.uv_layers[0].data]);samples={}
 images={}
 for f in m.polygons:
  c=p[list(f.vertices)].mean(0)
  if not (abs(c[0])<.034 and 1.49<c[2]<1.595 and c[1]<-.06):continue
  ma=m.materials[f.material_index]
  if 'Front faithful skin' not in ma.name:continue
  bs=next(n for n in ma.node_tree.nodes if n.type=='BSDF_PRINCIPLED');im=bs.inputs['Base Color'].links[0].from_node.image;w,h=im.size
  if im.name not in images:images[im.name]=np.array(im.pixels[:]).reshape(h,w,4)
  u=uv[list(f.loop_indices)].mean(0);x,y=np.minimum((u*[w,h]).astype(int),[w-1,h-1]);samples[f.index]=images[im.name][y,x].tolist()
 return p,uv,samples
p,u,s=read(O.parent/'front_fidelity_20260917/fukuchan_front_faithful.blend')
q,v,t=read(O/'fukuchan_texture_fixed.blend')
assert np.array_equal(p,q);assert np.array_equal(u,v);assert s==t
report={'geometry_positions_bitwise_equal':True,'uv_coordinates_bitwise_equal':True,'central_face_sampled_polygon_centers':len(s),'central_face_samples_identical':True,'sample_world_region':{'abs_x_less_than':.034,'z':[1.49,1.595],'y_less_than':-.06}}
(O/'integrity_report.json').write_text(json.dumps(report,indent=2)+'\n');print(report)
