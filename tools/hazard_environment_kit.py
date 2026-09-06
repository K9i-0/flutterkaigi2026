"""Shared Blender geometry, textured materials and collision kit for Hazard regions."""
import bpy, math, json, random
import numpy as np
from pathlib import Path
from mathutils import Vector, Matrix
ROOT=Path(__file__).resolve().parent.parent
OUT=ROOT/'04_GAME_ASSETS/3d/environments/pueblo';PROPS=ROOT/'04_GAME_ASSETS/3d/props/hazard_kit'
OUT.mkdir(parents=True,exist_ok=True);PROPS.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
rng=random.Random(4905);groups={};mats={};solids=[];houses=[];ramps=[];windows=[]

# Wall art stays deliberately coarse; the reader loads untouched production PNGs.
POSTER_WORLD_LONG_EDGE = 256

def wall_poster_image(path):
 im=bpy.data.images.load(str(path),check_existing=False)
 w,h=im.size
 scale=POSTER_WORLD_LONG_EDGE/max(w,h)
 im.scale(max(1,round(w*scale)),max(1,round(h*scale)))
 im.pack()
 return im

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
stone=material('Weathered limestone',(.49,.46,.37),pattern='stone');plaster=material('Aged lime plaster',(.66,.61,.47),pattern='plaster');wood=material('Dark oak beams',(.25,.19,.12),pattern='wood');boards=material('Worn plank',(.43,.34,.22),pattern='wood');roof=material('Clay tiles',(.36,.24,.17),pattern='roof');dirt=material('Damp village earth',(.31,.29,.21),pattern='dirt');metal=material('Iron',(.13,.14,.13),.5,.6);leaf=material('Faded pine needles',(.17,.22,.13));grass=material('Dry weeds',(.34,.32,.18));glass=material('Dark window glass',(.065,.078,.071),.38,.12);brass=material('Brass',(.62,.43,.15),.35,.75);black=material('Gun polymer',(.065,.072,.07),.68);steel=material('Gun blued steel',(.12,.14,.16),.32,.8);green=material('Green herb',(.19,.48,.13));red=material('Red herb',(.53,.12,.09));yellow=material('Yellow herb',(.65,.56,.12));paper=material('Paper',(.78,.76,.64));ammo=material('Red ammunition box',(.51,.09,.065));amber=material('Fire amber',(.85,.36,.055));mats[amber].node_tree.nodes.get('Principled BSDF').inputs['Emission Color'].default_value=(1,.18,.01,1);mats[amber].node_tree.nodes.get('Principled BSDF').inputs['Emission Strength'].default_value=2

# Production photographic albedo sources generated with built-in Imagegen.
for key,file in [(stone,'stone'),(dirt,'earth'),(boards,'oak-v1'),(wood,'oak-v1'),(roof,'roof-v1'),(plaster,'plaster-v1')]:
 m=mats[key];p=m.node_tree.nodes.get('Principled BSDF');tex=m.node_tree.nodes.new('ShaderNodeTexImage');im=bpy.data.images.load(str(OUT/'textures'/f'{file}.png'));im.scale(1024,1024);im.pack();tex.image=im;m.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color'])

pine=material('Distant pine cutout',(.2,.25,.16),1)
pm=mats[pine];pn=pm.node_tree.nodes;ps=pn.get('Principled BSDF')
pt=pn.new('ShaderNodeTexImage');pi=bpy.data.images.load(str(OUT/'textures/pine-v1.png'))
pi.scale(768,1152);pi.pack();pt.image=pi
pm.node_tree.links.new(pt.outputs['Color'],ps.inputs['Base Color'])
clip=pn.new('ShaderNodeMath');clip.operation='GREATER_THAN';clip.inputs[1].default_value=.45
pm.node_tree.links.new(pt.outputs['Alpha'],clip.inputs[0]);pm.node_tree.links.new(clip.outputs[0],ps.inputs['Alpha'])
pm.surface_render_method='DITHERED';pm.use_backface_culling=False

def face(group,mat,verts,uv=None):
 d=groups.setdefault(group,{}).setdefault(mat,{'v':[],'f':[],'uv':[]});i=len(d['v']);d['v'].extend(verts);d['f'].append(tuple(range(i,i+len(verts))));d['uv'].append(uv or [(0,0),(1,0),(1,1),(0,1)][:len(verts)])
def box(g,m,c,s,rotation=None):
 x,y,z=c;w,d,h=s;vs=[Vector((a*w/2,b*d/2,k*h/2)) for a,b,k in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
 if rotation:vs=[rotation@v for v in vs]
 vs=[tuple(v+Vector(c)) for v in vs]
 for ids,us in [((0,3,2,1),(w,d)),((4,5,6,7),(w,d)),((0,1,5,4),(w,h)),((1,2,6,5),(d,h)),((2,3,7,6),(w,h)),((3,0,4,7),(d,h))]:
  uv=[(0,0),(us[0],0),(us[0],us[1]),(0,us[1])]
  if m==roof or (m in [wood,boards] and us[0]>us[1]):uv=[(v,u) for u,v in uv]
  face(g,m,[vs[i] for i in ids],uv)
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

def backdrop_pine(x,z,height,base=0):
 # Three alpha-tested cards (6 triangles), grouped spatially for culling. These
 # trees are confined to inaccessible background terrain, never playable cover.
 g=f'PinePatch_{math.floor(x/12)}_{math.floor(z/12)}'
 width=height*(.57+.06*math.sin(x*1.7+z))
 for i in range(3):
  a=x*.77+z*.31+i*math.pi/3;dx=math.cos(a)*width/2;dz=math.sin(a)*width/2
  face(g,pine,[(x-dx,z-dz,base-.08),(x+dx,z+dz,base-.08),
      (x+dx,z+dz,base+height),(x-dx,z-dz,base+height)],[(0,0),(1,0),(1,1),(0,1)])

def weed_tuft(g,x,z):
 for i in range(4):
  a=x+z*.4+i*2.399;dx=math.cos(a);dz=math.sin(a)
  h=.17+.14*(.5+.5*math.sin(i*7+x*3));w=.018
  lo=[(x-dz*w,z+dx*w,0),(x+dz*w,z-dx*w,0)]
  mid=[(px+dx*.055,pz+dz*.055,h*.65) for px,pz,_ in lo]
  tip=(x+dx*.11,z+dz*.11,h)
  face(g,grass,[lo[0],lo[1],mid[1],mid[0]])
  face(g,grass,[mid[0],mid[1],tip],[(0,0),(1,0),(.5,1)])

def window(g,x,z,h,sign,shutter=False):
 # Layered sill, lintel and four small dirty panes replace the flat teal square.
 box(g,wood,(x,z,h),(1.30,.12,1.44))
 for dx in [-.275,.275]:
  for dz in [-.30,.30]:box(g,glass,(x+dx,z+sign*.078,h+dz),(.49,.035,.53))
 for dx in [-.60,0,.60]:box(g,wood,(x+dx,z+sign*.115,h),(.07,.09,1.35))
 for dz in [-.66,0,.66]:box(g,wood,(x,z+sign*.12,h+dz),(1.25,.09,.065))
 box(g,stone,(x,z+sign*.12,h-.77),(1.48,.38,.15))
 box(g,wood,(x,z+sign*.04,h+.80),(1.48,.23,.15))
 if shutter:
  for side in [-1,1]:
   # Open against the facade; stays within the existing wall exclusion margin.
   xx=x+side*.96
   box(g,boards,(xx,z-sign*.015,h),(.53,.10,1.32))
   for dz in [-.44,.44]:box(g,wood,(xx,z+sign*.05,h+dz),(.54,.07,.08))
   for dz in [-.49,.49]:box(g,metal,(xx-side*.20,z+sign*.095,h+dz),(.12,.025,.065))

def interior_details(g,id,x,z,w,d):
 # Detail existing furniture footprints so navigation/collision stays identical.
 tx=x-w/2+1.05;tz=z+d/2-1
 for dx in [-.47,.40]:
  cylinder(g,paper,(tx+dx,tz,.87),.18,.035,16)
  cylinder(g,metal,(tx+dx,tz,.892),.12,.013,16)
 cylinder(g,metal,(tx,tz+.13,1.015),.095,.30,12,r2=.07)
 cylinder(g,black,(tx,tz+.13,1.169),.055,.008,12)
 box(g,paper,(tx+.18,tz-.18,.865),(.22,.30,.016))
 for dx in [-.4,.4]:
  box(g,wood,(tx+dx,tz,.41),(.44,.42,.08))
  for a in [-.15,.15]:box(g,wood,(tx+dx+a,tz,.22),(.055,.33,.38))
 # Plate shelf above the search table, against the rear wall.
 box(g,boards,(tx,z+d/2-.26,1.96),(1.8,.30,.10))
 for dx in [-.65,.65]:box(g,wood,(tx+dx,z+d/2-.20,1.77),(.09,.16,.36))
 for dx in [-.5,0,.5]:
  cylinder(g,paper,(tx+dx,z+d/2-.28,2.16),.16,.045,12,axis=(0,1,0))

def facade_details(g,id,x,z,w,d,h,two):
 # Plaster upper storeys and selected cottages distinguish rooms at a distance.
 if two or id in ['Entrance','SaveHut','Ruins']:
  low=3.12 if two else 2.30;hh=h-low
  for side in [-1,1]:
   box(g,plaster,(x+side*(w/2+.182),z,low+hh/2),(.018,d,hh))
   box(g,plaster,(x,z+side*(d/2+.182),low+hh/2),(w,.018,hh))
 # The base and eave lines make wall/ground and wall/roof junctions readable.
 for side in [-1,1]:
  box(g,wood,(x+side*(w/2+.19),z,h-.12),(.17,d+.25,.22))
  box(g,wood,(x,z+side*(d/2+.19),h-.12),(w+.35,.17,.22))
  box(g,stone,(x+side*(w/2+.19),z,.25),(.12,d,.25))
  if side==1:box(g,stone,(x,z+d/2+.19,.25),(w,.12,.25))
  else:
   for s in [-1,1]:box(g,stone,(x+s*(w/4+.48),z-d/2-.19,.25),(w/2-.96,.12,.25))
 for zz in [z-d/2+.3,z+d/2-.3]:
  for xx in [x-w/2+.3,x+w/2-.3]:box(g,wood,(xx,zz,h-.24),(.15,.65,.16))
 # A small caged oil lantern marks the usable entrance without another light.
 lx=x+1.22;lz=z-d/2-.37
 box(g,metal,(lx,lz+.13,2.38),(.09,.30,.07))
 cylinder(g,metal,(lx,lz,2.27),.014,.20,8)
 box(g,amber,(lx,lz,2.01),(.12,.12,.20))
 for dx in [-.10,.10]:
  for dz in [-.10,.10]:box(g,metal,(lx+dx,lz+dz,2.03),(.025,.025,.33))
 for hh in [1.85,2.21]:box(g,metal,(lx,lz,hh),(.25,.25,.06))
 cylinder(g,metal,(lx,lz,2.28),.19,.10,4,r2=.055)

def house(id,x,z,w,d,two=False):
 h=5.8 if two else 3.1;g='House_'+id;rg='Roof_'+id;houses.append({'id':id,'x':x,'z':z,'w':w,'d':d,'height':h,'two':two})
 # The walking plane is game Y=0. Keep boards at that height so feet and
 # contact shadows do not disappear 22 cm into the visible indoor floor.
 box(g,stone,(x,z,-.14),(w,d,.16));box(g,boards,(x,z,-.04),(w-.5,d-.5,.08))
 wall(g,x-w/2,z,.35,d,h);wall(g,x+w/2,z,.35,d,h);wall(g,x,z+d/2,w,.35,h)
 # Selected front windows are real openings, with identical mesh/collider cuts.
 vaultable = w >= 7
 wx=x-w*.29;wz=z-d/2;half=.78;sill=.82;lintel=2.42
 for sign in [-1,1]:
  if sign==-1 and vaultable:
   lo=x-w/2;hi=x-.86
   for a,b in [(lo,wx-half),(wx+half,hi)]:
    wall(g,(a+b)/2,wz,b-a,.35,h)
   wall(g,wx,wz,half*2,.35,sill)
   wall(g,wx,wz,half*2,.35,h-lintel,lintel)
   windows.append({'id':id+'_front','x':wx,'z':wz,'sill':sill,'top':lintel,'width':half*2})
  else:wall(g,x+sign*(w/4+.43),wz,w/2-.86,.35,h)
 wall(g,x,z-d/2,1.72,.35,h-2.2,2.2)
 facade_details(g,id,x,z,w,d,h,two)
 for sign in [-1,1]:
  box(g,wood,(x+sign*.9,z-d/2-.08,1.15),(.16,.25,2.3))
  for zz in [z-d/2,z+d/2]:box(g,wood,(x+sign*(w/2-.1),zz,h/2),(.18,.23,h))
 for zz in [z-d/2-.23,z+d/2+.23]:
  for i,xx in enumerate([x-w*.29,x+w*.29]):
   for yy in [1.55]+([4.25] if two else []):
    if vaultable and zz<z and i==0 and yy==1.55:
     # Open frame and outward-folded shutters; no glass or center crossbar.
     for sign in [-1,1]:
      box(g,wood,(wx+sign*.82,wz,1.62),(.09,.48,1.70))
      box(g,boards,(wx+sign*1.10,wz+.06,1.62),(.48,.10,1.48))
     box(g,wood,(wx,wz,2.46),(1.75,.48,.09))
     box(g,stone,(wx,wz,.79),(1.75,.52,.06))
    else:window(g,xx,zz,yy,-1 if zz<z else 1,shutter=(w>=7 and i==0))
 if two:
  # Upstairs floor with a stairwell along its east wall.
  box(g,boards,(x-.9,z,2.95),(w-2.3,d-.6,.16));box(g,boards,(x+w/2-1.05,z+d/2-1,2.95),(1.7,1.7,.16))
  solid(x-.9,z,w-2.3,d-.6,.16,2.87)
  solid(x+w/2-1.05,z+d/2-1,1.7,1.7,.16,2.87)
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
 interior_details(g,id,x,z,w,d)

 if not two:
  box(g,boards,(x+w/2-.7,z+.5,.9),(.8,1.6,1.8));solid(x+w/2-.7,z+.5,.8,1.6,1.8)
  # Doors, raised panels, hinges and handles on the existing cupboard.
  for zz in [z+.12,z+.88]:
   box(g,wood,(x+w/2-1.115,zz,.92),(.035,.72,1.58))
   box(g,boards,(x+w/2-1.142,zz,.92),(.025,.56,1.36))
   cylinder(g,metal,(x+w/2-1.18,zz+.20,.96),.024,.045,8,axis=(1,0,0))

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
   period={stone:3,dirt:5,wood:1.4,boards:1.4,roof:1.5,plaster:3}.get(materials[mi].name,1)
   for li,coord in zip(poly.loop_indices,coords):uv.data[li].uv=tuple(v/period for v in coord)
  objects.append(obj)
 return objects

def export(path):
 make_objects();bpy.ops.object.select_all(action='SELECT');bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=False)

def reset_world():
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 groups.clear();solids.clear();houses.clear();ramps.clear();windows.clear()
