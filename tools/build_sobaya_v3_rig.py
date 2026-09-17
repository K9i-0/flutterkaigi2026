"""Posture correction and game-compatible rig for approved Wan Sobaya v3."""
import bpy,math,json,sys,numpy as np
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
SOURCE=ROOT/'04_GAME_ASSETS/3d/characters/sobaya/wan_multiview_20260916/face_red_edge_20260917/sobaya_front_matched.blend'
OUT=ROOT/'04_GAME_ASSETS/3d/characters/sobaya/rig_v3_20260917';OUT.mkdir(exist_ok=True)
from sobaya_v2_common import studio

def render(name,side=False):
 s=bpy.context.scene;c=s.camera;target=Vector((0,0,.90));c.location=target+Vector((5,0,0) if side else (0,-5,0));c.rotation_euler=(target-c.location).to_track_quat('-Z','Y').to_euler();c.data.ortho_scale=2.02;s.render.resolution_x=800;s.render.resolution_y=1000;s.cycles.samples=20;s.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True)

def source():
 bpy.ops.wm.open_mainfile(filepath=str(SOURCE));objs=[o for o in bpy.context.scene.objects if o.type=='MESH']
 worlds={o.name:o.matrix_world.copy() for o in objs}
 for o in objs:
  o.parent=None;o.matrix_world=worlds[o.name]
  o.data.transform(o.matrix_world);o.matrix_world=Matrix.Identity(4)
 p=np.concatenate([np.array([tuple(v.co) for v in o.data.vertices]) for o in objs]);lo=p.min(0);hi=p.max(0);scale=1.8/(hi[2]-lo[2])
 # Align the approved reference front with the engine's -Y forward axis.
 norm=Matrix.Rotation(math.radians(-8),4,'Z')@Matrix.Scale(scale,4)@Matrix.Translation((-(lo[0]+hi[0])/2,0,-lo[2]))
 for o in objs:o.data.transform(norm)
 p=np.concatenate([np.array([tuple(v.co) for v in o.data.vertices]) for o in objs]);feet=p[(p[:,2]>.085)&(p[:,2]<.16)];center=np.median(feet,axis=0)
 shift=Matrix.Translation((-center[0],-center[1],0))
 for o in objs:o.data.transform(shift)
 for o in list(bpy.context.scene.objects):
  if o not in objs:bpy.data.objects.remove(o,do_unlink=True)
 studio();render('posture_before_side',True)
 # Correct the common body/sole pitch as a rigid transform; no face deformation.
 pivot=Vector((0,0,.10));rot=Matrix.Rotation(math.radians(-10),3,'X')
 for o in objs:
  for v in o.data.vertices:
   v.co=pivot+rot@(v.co-pivot)
 p=np.concatenate([np.array([tuple(v.co) for v in o.data.vertices]) for o in objs]);lo=p.min(0);hi=p.max(0)
 final=Matrix.Scale(1.8/(hi[2]-lo[2]),4)@Matrix.Translation((-(lo[0]+hi[0])/2,-.055,-lo[2]))
 for o in objs:o.data.transform(final)
 render('posture_after_side',True);render('posture_after_front')
 bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'posture.blend'))
 p=np.concatenate([np.array([tuple(v.co) for v in o.data.vertices]) for o in objs]);
 print('SLICES',[(z,np.round(np.quantile(p[abs(p[:,2]-z)<.03], [.05,.5,.95],axis=0),3).tolist()) for z in [.05,.12,.45,.85,1.,1.2,1.4,1.55,1.65]],flush=True)
 return objs
if __name__=='__main__' and '--rig' not in sys.argv:source()

def make_rig():
 bpy.ops.wm.open_mainfile(filepath=str(OUT/'posture.blend'));meshes=[o for o in bpy.context.scene.objects if o.type=='MESH'];main=bpy.data.objects['tripo_node_4861cc5b'];main.name='SobayaV3Body'
 arm=bpy.data.armatures.new('SobayaV3Skeleton');rig=bpy.data.objects.new('SobayaV3Rig',arm);bpy.context.collection.objects.link(rig);bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
 def bone(name,head,tail,parent=None,deform=True):
  b=arm.edit_bones.new(name);b.head=head;b.tail=tail;b.use_deform=deform
  if parent:b.parent=arm.edit_bones[parent]
  b.align_roll(Vector((0,-1,0)));return b
 bone('Root',(0,0,0),(0,0,.15),deform=False)
 bone('Hips',(0,.025,.91),(0,.025,1.03),'Root')
 bone('Spine',(0,.025,1.03),(0,.025,1.16),'Hips');bone('Spine1',(0,.025,1.16),(0,.025,1.30),'Spine');bone('Spine2',(0,.025,1.30),(0,.025,1.45),'Spine1')
 bone('Neck',(0,.025,1.45),(0,-.035,1.58),'Spine2');bone('Head',(0,-.035,1.58),(0,-.035,1.75),'Neck')
 for s,sign in [('Left',1),('Right',-1)]:
  sy=.04 if sign==1 else -.01;el=(sign*.38,sy,1.13);wrist=(sign*.40,sy-.065,.94);palm=(sign*.413,sy-.10,.815)
  bone(s+'Shoulder',(sign*.045,.025,1.44),(sign*.285,sy,1.43),'Spine2')
  bone(s+'Arm',(sign*.285,sy,1.43),el,s+'Shoulder');bone(s+'ForeArm',el,wrist,s+'Arm');bone(s+'Hand',wrist,palm,s+'ForeArm')
  knee=(sign*.19,.035,.51);ankle=(.205 if sign==1 else -.25,.06 if sign==1 else .025,.115);toe=(ankle[0],ankle[1]-.13,.045)
  bone(s+'UpLeg',(sign*.14,.025,.91),knee,'Hips');bone(s+'Leg',knee,ankle,s+'UpLeg');bone(s+'Foot',ankle,toe,s+'Leg');bone(s+'ToeBase',toe,(toe[0],toe[1]-.06,toe[2]),s+'Foot')
 h=arm.edit_bones['RightHand'];pos=h.head+(h.tail-h.head).normalized()*.075
 bone('PropSocket.R',pos,pos+Vector((0,0,.065)),'RightHand',False)
 bpy.ops.object.mode_set(mode='OBJECT');bpy.ops.object.select_all(action='DESELECT');main.select_set(True);rig.select_set(True);bpy.context.view_layer.objects.active=rig;main.parent=rig;main.matrix_parent_inverse=Matrix.Identity(4);skin=main.modifiers.new('Skin','ARMATURE');skin.object=rig
 adj=[[] for _ in main.data.vertices]
 for e in main.data.edges:
  a,b=e.vertices;adj[a].append(b);adj[b].append(a)
 seen=set();lower=set()
 for start in range(len(adj)):
  if start in seen:continue
  stack=[start];seen.add(start);component=[]
  while stack:
   i=stack.pop();component.append(i)
   for j in adj[i]:
    if j not in seen:seen.add(j);stack.append(j)
  if max(main.data.vertices[i].co.z for i in component)<1.15:lower.update(component)
 maskids={i for f in main.data.polygons if main.data.materials[f.material_index].name.startswith('Mask reference porcelain') for i in f.vertices}
 def smooth(x):t=max(0,min(1,x));return t*t*(3-2*t)
 def core(z):
  stops=[(.94,'Hips'),(1.07,'Spine'),(1.22,'Spine1'),(1.40,'Spine2'),(1.52,'Neck'),(1.60,'Head')]
  for (z0,n0),(z1,n1) in zip(stops,stops[1:]):
   if z<=z1:t=smooth((z-z0)/(z1-z0));return {n0:1-t,n1:t}
  return {'Head':1}
 for o in meshes:
  if o!=main:
   o.vertex_groups.clear();o.vertex_groups.new(name='Head').add(list(range(len(o.data.vertices))),1,'REPLACE');o.parent=rig;o.matrix_parent_inverse=Matrix.Identity(4);mod=o.modifiers.new('Skin','ARMATURE');mod.object=rig
   continue
  for v in o.data.vertices:
   x,y,z=v.co;weights={o.vertex_groups[g.group].name:g.weight for g in v.groups if g.weight>1e-7};side='Left' if x>0 else 'Right'
   if v.index in maskids:weights={'Head':1.}
   elif v.index in lower:
    knee=smooth((z-.40)/.22);ankle=smooth((z-.09)/.14);hips=smooth((z-.80)/.17)
    weights={side+'UpLeg':knee*(1-hips),side+'Leg':(1-knee)*ankle*(1-hips),side+'Foot':(1-knee)*(1-ankle)*(1-hips),'Hips':hips}
   elif z>1.58 or (z>1.48 and y<-.105 and abs(x)<.15):weights={'Head':1.}
   elif z>1.44 and abs(x)<.16:weights=core(z)
   else:
    # A continuous anatomical field avoids heat weights jumping across the
    # narrow shirt/arm gaps. All four weights change smoothly at the cuff.
    start=float(np.interp(z,[.75,1.05,1.22,1.46],[.255,.255,.225,.12]))
    end=float(np.interp(z,[.75,1.05,1.22,1.46],[.315,.325,.335,.31]))
    mix=smooth((abs(x)-start)/(end-start));upper=smooth((z-1.035)/.19);wrist=smooth((z-.91)/.095)
    aw={side+'Arm':upper,side+'ForeArm':(1-upper)*wrist,side+'Hand':(1-upper)*(1-wrist)}
    shoulder=smooth((z-1.36)/.15)*(1-smooth((abs(x)-.16)/.17))*.65
    aw={n:w*(1-shoulder) for n,w in aw.items()};aw[side+'Shoulder']=shoulder
    weights={n:w*(1-mix) for n,w in core(z).items()}
    for n,w in aw.items():weights[n]=weights.get(n,0)+w*mix
   if not weights:
    def dist(b):
     d=b.tail_local-b.head_local;t=max(0,min(1,(v.co-b.head_local).dot(d)/d.length_squared));return (v.co-b.head_local-d*t).length
    nearest=min([b for b in rig.data.bones if b.use_deform],key=dist);weights={nearest.name:1.}
   entries=sorted(weights.items(),key=lambda a:-a[1])[:4];total=sum(w for n,w in entries)
   for g in list(v.groups):o.vertex_groups[g.group].remove([v.index])
   for n,w in entries:
    group=o.vertex_groups.get(n) or o.vertex_groups.new(name=n);group.add([v.index],w/total,'REPLACE')
  # Apply the single subdivision before the armature so the exported mesh has
  # the same interpolated weights and geometry as the Blender preview.
  bpy.context.view_layer.objects.active=o
  for mod in list(o.modifiers):
   if mod.type=='SUBSURF':bpy.ops.object.modifier_apply(modifier=mod.name)
  bpy.ops.object.vertex_group_limit_total(limit=4)
  bpy.ops.object.vertex_group_normalize_all(lock_active=False)
 for o in meshes:
  for mod in o.modifiers:
   if mod.type=='ARMATURE':mod.use_deform_preserve_volume=False
 for b in rig.pose.bones:b.rotation_mode='QUATERNION'
 rig.show_in_front=True;rig['character']='Sobaya';rig['version']='v3_20260917';rig['source']=str(SOURCE.relative_to(ROOT))
 bpy.context.scene.render.fps=30
 bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'sobaya_rig.blend'))
 (OUT/'skinning_report.json').write_text(json.dumps({'bones':len(rig.data.bones),'bodyVertices':len(main.data.vertices),'rigidMaskSourceVertices':len(maskids),'rigidAddedFaceObjects':[o.name for o in meshes if o!=main],'maxInfluences':4,'posturePitchDegrees':-10,'postureIsRigidTransform':True,'individualFingerRig':False},indent=2))
 print('V3_RIG_READY',len(rig.data.bones),len(main.data.vertices),flush=True)
 return rig,meshes
if __name__=='__main__' and '--rig' in sys.argv:make_rig()
