"""Reduce facial relief, preserving frontal landmarks and original texture/UVs."""
import bpy,numpy as np,json
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
SOURCE=OUT.parent/'imagegen_texture_20260917/fukuchan_texture_fixed.blend'
for label,strength in [('mild',.25),('shallow',.42)]:
 bpy.ops.wm.open_mainfile(filepath=str(SOURCE));o=next(a for a in bpy.context.scene.objects if a.type=='MESH');m=o.data
 p=np.array([tuple(o.matrix_world@v.co) for v in m.vertices]);q=p.copy();eligible=np.zeros(len(p),bool)
 for f in m.polygons:
  if any(k in m.materials[f.material_index].name for k in ['Front faithful skin','Natural sclera','soft skin']):eligible[list(f.vertices)]=True
 def smooth(a):a=np.clip(a,0,1);return a*a*(3-2*a)
 x,y,z=p.T
 eligible|=(np.abs(x)<.052)&(z>1.445)&(z<1.505)&(y<-.025)
 weight=smooth((z-1.425)/.035)*smooth((1.63-z)/.035)*smooth((.089-np.abs(x))/.025)*smooth((-.02-y)/.055)*eligible
 # A gently rounded facial envelope, not a flat plane; compress fine relief toward it.
 envelope=-.085+.033*(x/.080)**2+.012*((z-1.535)/.100)**2
 q[:,1]=y+strength*weight*(envelope-y)
 # Reconcile duplicate positions at UV splits so no cracks can open.
 _,weld=np.unique(np.round(p,6),axis=0,return_inverse=True)
 sums=np.zeros((weld.max()+1,3));np.add.at(sums,weld,q-p);q=p+sums[weld]/np.bincount(weld)[weld,None]
 inv=o.matrix_world.inverted()
 old_normals=[tuple(loop.vector) for loop in m.corner_normals]
 for i,v in enumerate(m.vertices):v.co=inv@Vector(q[i])
 m.update();m.calc_loop_triangles();acc=np.zeros((weld.max()+1,3))
 for t in m.loop_triangles:
  ids=list(t.vertices);v=q[ids];n=np.cross(v[1]-v[0],v[2]-v[0]);np.add.at(acc,weld[ids],n)
 acc/=np.maximum(np.linalg.norm(acc,axis=1)[:,None],1e-12)
 # Preserve unrelated custom normals; recompute only the modified facial neighborhood.
 affected=np.zeros(len(p),bool);affected[np.linalg.norm(q-p,axis=1)>1e-9]=True
 for f in m.polygons:
  if any(affected[list(f.vertices)]):
   for li in f.loop_indices:old_normals[li]=tuple(acc[weld[m.loops[li].vertex_index]])
 m.normals_split_custom_set(old_normals)
 assert np.array_equal(p[:,[0,2]],q[:,[0,2]])
 assert np.array_equal(p[z<1.425],q[z<1.425])
 o.name='Fukuchan_Shallow_Face_'+label;bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
 bpy.ops.export_scene.gltf(filepath=str(OUT/('fukuchan_'+label+'.glb')),export_format='GLB',use_selection=True,export_animations=False)
 bpy.ops.wm.save_as_mainfile(filepath=str(OUT/('fukuchan_'+label+'.blend')))
 disp=q[:,1]-p[:,1]
 report={'strength':strength,'modified_vertices':int((abs(disp)>1e-9).sum()),'max_depth_change_mm':float(abs(disp).max()*1000),'frontal_xz_identical':True,'body_below_1_425m_unchanged':True,'uv_and_textures_unchanged':True}
 (OUT/(label+'_report.json')).write_text(json.dumps(report,indent=2)+'\n');print(label,report,flush=True)
