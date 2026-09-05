"""Build an original RE4-era village kit, collision/item data and shared props.
Blender --background --factory-startup --python tools/build_hazard_village.py
"""
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

# Plaza and approach. World layout is authored in meters, Blender Y = game Z.
box('Ground',dirt,(0,0,-.16),(62,66,.3))
for h in [('Shotgun',8,-6,8,9,True),('Barn',-4,11,11,7,False),('West',-11,1,7,7,False),('East',14,6,6,7,False),('Entrance',-8,-15,5.5,5,False)]:house(*h)
# Boundary masonry and uneven cliff silhouettes.
for sign in [-1,1]:
 wall('Perimeter',sign*23,1,1.2,52,2.5)
 for k in range(24):
  x=sign*(24+rng.random()*4);z=-25+k*2.3;cylinder('Cliffs',stone,(x,z,1.8+rng.random()),1.8+rng.random(),4+rng.random()*5,7,r2=.65)
wall('Perimeter',-10,24,27,1.1,2.7);wall('Perimeter',20,24,8,1.1,2.7)
wall('Perimeter',-15,-25,16,1.1,2.5);wall('Perimeter',15,-25,16,1.1,2.5)
# A recognizable central bonfire, no burning body.
for i in range(10):
 a=i*math.tau/10;cylinder('Bonfire',stone,(math.cos(a)*1.1,math.sin(a)*1.1,.18),.27,.35,7)
for a in [0,.8,1.6,2.4]:cylinder('Bonfire',wood,(0,0,.3),.13,1.8,8,axis=(math.cos(a),math.sin(a),.15))
for i in range(6):cylinder('Flame_'+str(i),amber,(rng.uniform(-.5,.5),rng.uniform(-.5,.5),.55),.18,.8+rng.random()*.5,5,r2=0)
solid(0,0,2.2,2.2,.6)
# Timber watchtower with climbing interaction.
for x in [-15,-12]:
 for z in [-8,-5]:box('Tower',wood,(x,z,3),(.28,.28,6))
box('Tower',boards,(-13.5,-6.5,4.1),(3.6,3.6,.2))
for i in range(11):box('Tower',boards,(-13.5,-8.3,.3+i*.35),(1,.10,.09))
for x in [-14,-13]:box('Tower',wood,(x,-8.3,2),(.09,.11,4))
box('TowerRoof',roof,(-13.5,-6.5,6.4),(4,4,.22))
for z in [-8.2,-4.8]:box('Tower',wood,(-13.5,z,5),(3.6,.15,.15))
# Farm gate, enclosure and bell arch.
for x in [8,15]:wall('GateArch',x,24,1.1,1.4,5)
box('GateArch',stone,(11.5,24,5),(8,1.5,.5));cylinder('Bell',brass,(11.5,24,4.3),.5,.7,16,r2=.27)
box('FarmGate',wood,(11.5,24,1.5),(6.1,.25,3));solid(11.5,24,6.1,.3,3,id='gate')
for x in [9,10,11,12,13,14]:box('FarmGate',metal,(x,23.82,1.5),(.05,.06,3))
for z in [25.8,27.5,29]:box('FarmRoad',dirt,(11.5,z,-.01),(6.5,2,.02))
# Fences, cart, well and scattered timber.
for i in range(13):
 x=-19+i*.6;box('Fences',wood,(x,7,1),(.12,.12,2))
for z in [.55,1.5]:box('Fences',boards,(-15.4,7,z),(7.8,.09,.14))
solid(-15.4,7,7.8,.2,1.7)
cylinder('Well',stone,(-3,5,.5),.85,1,16);cylinder('Well',black,(-3,5,1.02),.65,.04,16)
solid(-3,5,1.6,1.6,1)
box('Cart',boards,(4,5,.6),(1.6,2.3,.16));box('Cart',wood,(4,6.6,.7),(.1,2,.1))
for x in [3.05,4.95]:cylinder('Cart',wood,(x,5,.48),.5,.13,12,axis=(1,0,0))
solid(4,5,2,2.4,.9)
for i in range(65):
 x=rng.uniform(-29,29);z=rng.uniform(-29,32)
 if abs(x)<22 and -24<z<25:continue
 height=rng.uniform(5,10);cylinder('TreeTrunks',wood,(x,z,height/2),.2,height,7,r2=.08)
 for a in range(3):cylinder('TreeNeedles',leaf,(x,z,height*(.5+a*.17)),1.9-a*.35,height*.55,8,r2=.03)
for i in range(200):
 x=rng.uniform(-21,21);z=rng.uniform(-23,23)
 if abs(x)<5 and -23<z<20:continue
 cylinder('Weeds',grass,(x,z,.13),.07,.26,3,r2=.005)

# Collectible images stay canonical in the script library.
posters=[
 ('shark','そばシャーク2','03_SCRIPTS/35_soba_shark/poster_soba_shark_2_production.png',-10, -2.66,1.6),
 ('bug','BUG MAN','03_SCRIPTS/37_bug_man_poster/prop_bug_man_poster_production.png',8,-10.69,1.6),
 ('debug','NO WAY DEBUG','03_SCRIPTS/37_bug_man_poster/prop_bug_man_poster_no_way_debug_production.png',-3,7.31,1.6),
 ('detective','名探偵よーたん','03_SCRIPTS/39_detective_yotan_beer_disappearance/poster_detective_yotan_beer_disappearance_production.png',14,2.31,1.6),
 ('wanted','やめ太郎 指名手配','03_SCRIPTS/59_sobaya_professional_window_side/prop_yametaro_wanted_poster.png',-8,-17.69,1.6),
 ('beer','窓際族物語','03_SCRIPTS/32_sobaya_beer_encouragement/prop_madogiwa_movie_poster_production.png',6,-10.30,4.5),
]
collection=[]
for id,title,path,x,z,h in posters:
 m=material('Poster_'+id,(1,1,1),1);im=bpy.data.images.load(str(ROOT/path));im.scale(768,round(768*im.size[1]/im.size[0]));im.pack();p=mats[m].node_tree.nodes.get('Principled BSDF');tex=mats[m].node_tree.nodes.new('ShaderNodeTexImage');tex.image=im;mats[m].node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color']);w=.85;hh=1.28;g='Poster_'+id
 sign=-1 if id=='beer' else 1
 box(g,wood,(x,z+sign*.012,h),(w+.12,.04,hh+.12));face(g,m,[(x-sign*w/2,z-sign*.018,h-hh/2),(x+sign*w/2,z-sign*.018,h-hh/2),(x+sign*w/2,z-sign*.018,h+hh/2),(x-sign*w/2,z-sign*.018,h+hh/2)])
 collection.append({'id':id,'title':title,'source':path,'x':x,'z':z,'y':h-1.0,'node':g})

items=[{'id':'ammo_entry','kind':'ammo','x':-8,'z':-14,'y':.9,'amount':20}, {'id':'herb_west','kind':'green','x':-13,'z':3,'y':.9,'amount':1},{'id':'shotgun','kind':'shotgun','x':6,'z':-3,'y':3.4,'amount':1},{'id':'shells_up','kind':'shells','x':7,'z':-3,'y':3.4,'amount':10},{'id':'key','kind':'key','x':-5,'z':12,'y':.95,'amount':1},{'id':'herb_red','kind':'red','x':14,'z':7,'y':.95,'amount':1},{'id':'ammo_square','kind':'ammo','x':3,'z':4,'y':.85,'amount':20},{'id':'yellow_up','kind':'yellow','x':5,'z':-8,'y':3.35,'amount':1}]
crates=[{'id':'crate_'+str(i),'x':x,'z':z,'kind':'crate' if i%2 else 'barrel'} for i,(x,z) in enumerate([(-4,-13),(4,-12),(-7,6),(10,11),(18,4),(-16,-1),(4,13)])]
enemies=[{'id':i,'x':x,'z':z} for i,(x,z) in enumerate([(-2,-6),(3,-2),(-5,3),(6,7),(-9,6),(11,11),(-2,14),(17,1)])]
data={'version':1,'spawn':{'x':0,'z':-21,'yaw':math.pi},'houses':houses,'solids':solids,'ramps':ramps,'items':items,'crates':crates,'enemies':enemies,'collection':collection,'gate':{'x':11.5,'z':23,'y':0},'tower':{'x':-13.5,'z':-8.8,'top':4.22}}
data['npcs']=[{'id': 'yametaro', 'x': -2.8, 'z': -21.2}]
(OUT/'village.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')

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
export(OUT/'village.glb')
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False);groups={}
# Shared pickup and weapon meshes. Gun points toward Blender -Y, grip at origin.
for name,long in [('Handgun',False),('Shotgun',True)]:
 scale=1;length=.75 if long else .20
 box(name,steel,(0,-length/2,.095),(.048,length,.06));cylinder(name,black,(0,-length-.006,.095),.016,.02,12,axis=(0,1,0))
 box(name,black,(0,.025,-.03),(.045,.07,.13),Matrix.Rotation(-.25,3,'X'))
 box(name,metal,(0,-.03,-.015),(.018,.07,.018));box(name,steel,(0,-.06,.03),(.048,.1,.028))
 box(name,steel,(0,-length+.025,.14),(.008,.012,.018));box(name,steel,(0,-.025,.14),(.035,.012,.014))
 if long:box(name,boards,(0,.16,.04),(.085,.24,.10));box(name,boards,(0,-.42,.075),(.065,.21,.055))
for name,color in [('GreenHerb',green),('RedHerb',red),('YellowHerb',yellow)]:
 cylinder(name,wood,(0,0,.08),.07,.16,10,r2=.095)
 for i in range(6):
  a=i*math.tau/6;face(name,color,[(0,0,.10),(math.cos(a)*.15,math.sin(a)*.15,.19),(math.cos(a+.4)*.11,math.sin(a+.4)*.11,.36)])
box('AmmoBox',ammo,(0,0,.045),(.18,.11,.09));box('AmmoBox',paper,(0,-.056,.045),(.11,.002,.06))
for i in range(5):cylinder('ShellBox',brass,(-.08+i*.04,0,.05),.016,.1,10)
box('ShellBox',ammo,(0,.035,.04),(.22,.085,.08))
cylinder('Key',brass,(0,0,.015),.06,.025,12);box('Key',brass,(0,-.12,.015),(.026,.18,.025));box('Key',brass,(.027,-.20,.015),(.07,.025,.025))
box('Crate',boards,(0,0,.45),(.85,.85,.9))
for z in [.10,.8]:box('Crate',wood,(0,-.44,z),(.88,.055,.07))
box('Crate',wood,(0,-.47,.45),(.065,.06,1.05),Matrix.Rotation(.72,3,'Y'))
cylinder('Barrel',boards,(0,0,.5),.37,1,14)
for z in [.12,.85]:cylinder('Barrel',metal,(0,0,z),.385,.07,14)
export(PROPS/'items.glb')
print('VILLAGE',len(solids),'colliders',len(houses),'houses',len(collection),'posters')
