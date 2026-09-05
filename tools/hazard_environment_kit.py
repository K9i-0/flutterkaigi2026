"""Shared Blender geometry, textured materials and collision kit for Hazard regions."""
import bpy, math, json, random
import numpy as np
from pathlib import Path
from mathutils import Vector, Matrix
ROOT=Path(__file__).resolve().parent.parent
OUT=ROOT/'04_GAME_ASSETS/3d/environments/pueblo';PROPS=ROOT/'04_GAME_ASSETS/3d/props/hazard_kit'
OUT.mkdir(parents=True,exist_ok=True);PROPS.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
rng=random.Random(4905);groups={};mats={};solids=[];houses=[];ramps=[]

def material(name,color,rough=.9,metal=0,pattern=None):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
 if pattern:
  n=512;y,x=np.mgrid[0:n,0:n]/n;noise=np.random.default_rng(22).random((n,n));v=.83+.18*noise
  if pattern=='stone':
   row=np.floor(y*8);xx=(x*5+(row%2)*.5)%1;yy=(y*8)%1;mortar=(xx<.028)|(yy<.055);v*=.8+.25*np.sin(np.floor(x*5+(row%2)*.5)*2+row*7);v[mortar]=.38
  elif pattern=='wood':v*=.83+.055*np.sin(x*180+np.sin(y*15)*2)+.035*np.sin(x*410+y*8)
  elif pattern=='roof':v*=.7+.22*np.cos(x*40);v[(y*8)%1<.06]=.36
  else:v*=.9+.025*np.sin(x*17+np.sin(y*11)*3)
  image=bpy.data.images.new(name+'_albedo',width=n,height=n);pixels=np.ones((n,n,4),dtype=np.float32);pixels[:,:,:3]=np.clip(v[:,:,None]*np.array(color)[None,None,:],0,1);image.pixels.foreach_set(pixels.ravel());image.pack();tex=m.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image;m.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color'])
 mats[name]=m;return name
stone=material('Weathered limestone',(.49,.46,.37),pattern='stone');plaster=material('Aged lime plaster',(.66,.61,.47),pattern='plaster');wood=material('Dark oak beams',(.25,.19,.12),pattern='wood');boards=material('Worn plank',(.43,.34,.22),pattern='wood');roof=material('Clay tiles',(.36,.24,.17),pattern='roof');dirt=material('Damp village earth',(.31,.29,.21),pattern='dirt');metal=material('Iron',(.13,.14,.13),.5,.6);leaf=material('Faded pine needles',(.17,.22,.13));grass=material('Dry weeds',(.34,.32,.18));glass=material('Dark window glass',(.10,.15,.15),.2,.15);brass=material('Brass',(.62,.43,.15),.35,.75);black=material('Gun polymer',(.065,.072,.07),.68);steel=material('Gun blued steel',(.12,.14,.16),.32,.8);green=material('Green herb',(.19,.48,.13));red=material('Red herb',(.53,.12,.09));yellow=material('Yellow herb',(.65,.56,.12));paper=material('Paper',(.78,.76,.64));ammo=material('Red ammunition box',(.51,.09,.065));amber=material('Fire amber',(.85,.36,.055));mats[amber].node_tree.nodes.get('Principled BSDF').inputs['Emission Color'].default_value=(1,.18,.01,1);mats[amber].node_tree.nodes.get('Principled BSDF').inputs['Emission Strength'].default_value=2

# Production photographic albedo sources generated with built-in Imagegen.
for key,file in [(stone,'stone'),(dirt,'earth')]:
 m=mats[key];p=m.node_tree.nodes.get('Principled BSDF');tex=m.node_tree.nodes.new('ShaderNodeTexImage');im=bpy.data.images.load(str(OUT/'textures'/f'{file}.png'));im.scale(1024,1024);im.pack();tex.image=im;m.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color'])

def face(group,mat,verts,uv=None):
 d=groups.setdefault(group,{}).setdefault(mat,{'v':[],'f':[],'uv':[]});i=len(d['v']);d['v'].extend(verts);d['f'].append(tuple(range(i,i+len(verts))));d['uv'].append(uv or [(0,0),(1,0),(1,1),(0,1)][:len(verts)])
def box(g,m,c,s,rotation=None):
 x,y,z=c;w,d,h=s;vs=[Vector((a*w/2,b*d/2,k*h/2)) for a,b,k in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
 if rotation:vs=[rotation@v for v in vs]
 vs=[tuple(v+Vector(c)) for v in vs]
 for ids,us in [((0,3,2,1),(w,d)),((4,5,6,7),(w,d)),((0,1,5,4),(w,h)),((1,2,6,5),(d,h)),((2,3,7,6),(w,h)),((3,0,4,7),(d,h))]:face(g,m,[vs[i] for i in ids],[(0,0),(us[0],0),(us[0],us[1]),(0,us[1])])
def cylinder(g,m,c,r,h,n=12,axis=None,r2=None):
 r2=r if r2 is None else r2;q=Vector((0,0,1)).rotation_difference(Vector(axis)) if axis else None
 def p(a,z,r):
  v=Vector((math.cos(a)*r,math.sin(a)*r,z));return tuple((q@v if q else v)+Vector(c))
 for i in range(n):
  a=i*math.tau/n;b=(i+1)*math.tau/n
  face(g,m,[p(a,-h/2,r),p(b,-h/2,r),p(b,h/2,r2),p(a,h/2,r2)])
  face(g,m,[tuple(Vector(c)+(q@Vector((0,0,h/2)) if q else Vector((0,0,h/2)))),p(a,h/2,r2),p(b,h/2,r2)],[(.5,.5),(0,0),(1,0)])
def solid(cx,cz,w,d,h,bottom=0,id=None):solids.append({'x':cx,'z':cz,'w':w,'d':d,'bottom':bottom,'top':bottom+h,'id':id})
def wall(g,cx,cy,w,d,h,bottom=0,mat=None):box(g,mat or stone,(cx,cy,bottom+h/2),(w,d,h));solid(cx,cy,w,d,h,bottom)

def house(id,x,z,w,d,two=False):
 h=5.8 if two else 3.1;g='House_'+id;rg='Roof_'+id;houses.append({'id':id,'x':x,'z':z,'w':w,'d':d,'height':h,'two':two})
 box(g,stone,(x,z,.08),(w,d,.16));box(g,boards,(x,z,.18),(w-.5,d-.5,.08))
 wall(g,x-w/2,z,.35,d,h);wall(g,x+w/2,z,.35,d,h);wall(g,x,z+d/2,w,.35,h)
 # Open doorway; lintel is a real elevated collider.
 for sign in [-1,1]:wall(g,x+sign*(w/4+.43),z-d/2,w/2-.86,.35,h)
 wall(g,x,z-d/2,1.72,.35,h-2.2,2.2)
 for sign in [-1,1]:
  box(g,wood,(x+sign*.9,z-d/2-.08,1.15),(.16,.25,2.3))
  for zz in [z-d/2,z+d/2]:box(g,wood,(x+sign*(w/2-.1),zz,h/2),(.18,.23,h))
 for zz in [z-d/2-.23,z+d/2+.23]:
  for xx in [x-w*.29,x+w*.29]:
   for yy in [1.55]+([4.25] if two else []):
    box(g,wood,(xx,zz,yy),(1.28,.13,1.42));box(g,glass,(xx,zz+(-.08 if zz<z else .08),yy),(1.08,.06,1.2))
    box(g,wood,(xx,zz+(-.13 if zz<z else .13),yy),(.065,.08,1.2))
 if two:
  # Upstairs floor with a stairwell along its east wall.
  box(g,boards,(x-.9,z,2.95),(w-2.3,d-.6,.16));box(g,boards,(x+w/2-1.05,z+d/2-1,2.95),(1.7,1.7,.16))
  for i in range(15):box(g,boards,(x+w/2-1.05,z-d/2+.65+i*.43,.1+i*.1),(1.6,.45,.2+i*.2))
  ramps.append({'x':x+w/2-1.05,'z0':z-d/2+.4,'z1':z-d/2+6.85,'w':1.7,'height':3.03})
  for zz in [z-d/2,z+d/2]:box(g,wood,(x,zz,3),(w,.18,.22))
 # Roof pitch, gables, ridge and chimney.
 rise=w*.3;angle=math.atan2(rise,w/2);length=math.hypot(w/2+.35,rise)
 for sign in [-1,1]:
  box(rg,roof,(x+sign*(w/4+.14),z,h+rise/2),(length,d+.8,.17),Matrix.Rotation(sign*angle,3,'Y'))
  for k in range(int(d/.48)+2):box(rg,roof,(x+sign*(w/4+.14),z-d/2-.2+k*.48,h+rise/2+.1),(length,.045,.05),Matrix.Rotation(sign*angle,3,'Y'))
 for zz in [z-d/2,z+d/2]:face(rg,plaster,[(x-w/2,zz,h),(x+w/2,zz,h),(x,zz,h+rise)])
 cylinder(rg,roof,(x,z,h+rise+.08),.12,d+.85,10,axis=(0,1,0))
 box(rg,stone,(x-w*.28,z+d*.2,h+rise*.7),(.65,.7,1.8));box(rg,metal,(x-w*.28,z+d*.2,h+rise*.7+.95),(.8,.85,.14))
 # Interior furniture gives places to search.
 box(g,wood,(x-w/2+1.05,z+d/2-1,.78),(1.6,.8,.13))
 for a in [-.65,.65]:box(g,wood,(x-w/2+1.05+a,z+d/2-1,.38),(.1,.55,.76))

 if not two:
  box(g,boards,(x+w/2-.7,z+.5,.9),(.8,1.6,1.8));solid(x+w/2-.7,z+.5,.8,1.6,1.8)

def make_objects():
 objects=[]
 for group,parts in groups.items():
  verts=[];faces=[];uvs=[];indices=[];materials=[]
  for mi,(mat,d) in enumerate(parts.items()):
   offset=len(verts);verts.extend(d['v']);faces.extend(tuple(k+offset for k in f) for f in d['f']);uvs.extend(d['uv']);indices.extend([mi]*len(d['f']));materials.append(mats[mat])
  mesh=bpy.data.meshes.new(group);mesh.from_pydata(verts,[],faces);mesh.update();obj=bpy.data.objects.new(group,mesh);bpy.context.collection.objects.link(obj)
  for mat in materials:mesh.materials.append(mat)
  uv=mesh.uv_layers.new()
  for poly,mi,coords in zip(mesh.polygons,indices,uvs):
   poly.material_index=mi
   for li,coord in zip(poly.loop_indices,coords):uv.data[li].uv=tuple(v/(3 if materials[mi].name==stone else 5 if materials[mi].name==dirt else 1) for v in coord)
  objects.append(obj)
 return objects

def export(path):
 make_objects();bpy.ops.object.select_all(action='SELECT');bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=False)

def reset_world():
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 groups.clear();solids.clear();houses.clear();ramps.clear()
