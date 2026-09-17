import bpy, numpy as np, math,json
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent;SRC=OUT.parent/'face_refinement_20260917'
bpy.ops.wm.open_mainfile(filepath=str(SRC/'sobaya_front_matched.blend'))
s=bpy.context.scene;o=bpy.data.objects['tripo_node_4861cc5b'];m=o.data
A,B=map(math.radians,(8,-10));N=Vector((math.sin(A)*math.cos(B),-math.cos(A)*math.cos(B),math.sin(B)));Q=(-N).to_track_quat('-Z','Y');R=Q@Vector((1,0,0));U=Q@Vector((0,1,0));T=Vector((-.135,-.70,1.015));K=1024/.34
basis=np.array([R,-U,N]);origin=np.array(T);center=np.array([539.62,550.69]);scale=.90
def project(p):return (np.asarray(p)-origin)@basis.T*K+[512,512,0]
def world(p):return Vector(origin+((np.asarray(p)-[512,512,0])/K)@basis)
def smooth(t):t=np.clip(t,0,1);return t*t*(3-2*t)
def field(p):
 x,y,d=p.T
 return smooth(np.minimum.reduce([(x-270)/55,(810-x)/55,(y-380)/55,(925-y)/80]))
P=project([tuple(o.matrix_world@v.co) for v in m.vertices]);V=P.copy()
maskidx=next(i for i,mat in enumerate(m.materials) if mat and mat.name.startswith('Mask reference porcelain'))
inside=set();outside=set()
for f in m.polygons:
 (inside if f.material_index==maskidx else outside).update(f.vertices)
# All vertices shared with the mask border or any hair/body surface are pinned.
movable=np.array(sorted(inside-outside));w=field(P[movable]);V[movable,:2]=P[movable,:2]+(center-P[movable,:2])*.1*w[:,None]
inv=o.matrix_world.inverted()
for i in movable:
 if w[np.searchsorted(movable,i)]>0:m.vertices[i].co=inv@world(V[i])
# Carry the high-resolution projection UV with the geometric warp, then apply the
# inverse 90% transform so the red paint itself has the exact common face scale.
uv=m.uv_layers['Mask reference projection'].data
for f in m.polygons:
 for li in f.loop_indices:
  px=V[m.loops[li].vertex_index,:2];source=center+(px-center)/scale
  uv[li].uv=(source[0]/1024,1-source[1]/1152)
report={}
for obj in list(s.objects):
 if obj.type!='MESH' or obj==o:continue
 p=project([tuple(obj.matrix_world@v.co) for v in obj.data.vertices]);v=p.copy()
 # The closed nose cap shares the same smooth transition as its underlying mask.
 weights=field(p) if 'nose' in obj.name else np.ones(len(p))
 v[:,:2]=p[:,:2]+(center-p[:,:2])*.1*weights[:,None]
 if 'black eye' in obj.name:v[:,2]+=7
 matinv=obj.matrix_world.inverted()
 for vert,point in zip(obj.data.vertices,v):vert.co=matinv@world(point)
 report[obj.name]={'vertices':len(v),'scale':scale}
fixed=np.array(sorted(set(range(len(P)))-set(movable)))
assert np.array_equal(P[fixed],V[fixed])
report.update({'face_scale':scale,'pivot_px':center.tolist(),'mask_border_hair_body_unchanged':True,'fixed_vertices':len(fixed),'changed_mask_interior_vertices':int(np.sum(np.linalg.norm(V-P,axis=1)>1e-8))})
json.dump(report,open(OUT/'geometry_check.json','w'),indent=2)
s.cycles.samples=32
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'sobaya_front_matched.blend'))
s.render.filepath=str(OUT/'front.png');bpy.ops.render.render(write_still=True)
