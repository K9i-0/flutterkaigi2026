"""Build the village and shared props from the canonical Hazard environment kit."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from hazard_environment_kit import *
from hazard_entrance_backdrop import build_entrance_backdrop
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
 for z in [-8,-5]:
  box('Tower',wood,(x,z,3),(.28,.28,6));solid(x,z,.28,.28,6)
box('Tower',boards,(-13.5,-6.5,4.1),(3.6,3.6,.2))
solid(-13.5,-6.5,3.6,3.6,.2,bottom=4)
for i in range(16):box('Tower',boards,(-13.5,-8.3,.35+i*.35),(1,.10,.09))
for x in [-14,-13]:box('Tower',wood,(x,-8.3,2.825),(.09,.11,5.65))
box('TowerRoof',roof,(-13.5,-6.5,6.4),(4,4,.22))
box('Tower',wood,(-13.5,-4.8,5),(3.6,.15,.15))
# Leave the ladder exit open between the front rail segments.
for x in [-14.65,-12.35]:box('Tower',wood,(x,-8.2,5),(1.3,.15,.15))
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
 height=rng.uniform(5,10);backdrop_pine(x,z,height)
for i in range(200):
 x=rng.uniform(-21,21);z=rng.uniform(-23,23)
 if abs(x)<5 and -23<z<20:continue
 if any(abs(x-h['x'])<h['w']/2+.25 and abs(z-h['z'])<h['d']/2+.25 for h in houses):continue
 weed_tuft('Weeds',x,z)

build_entrance_backdrop()

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
# These supplies lie on the floor; only the upstairs set has an elevated floor.
for item in items:
 if item['y']<2:item['y']=.28
crates=[{'id':'crate_'+str(i),'x':x,'z':z,'kind':'crate' if i%2 else 'barrel'} for i,(x,z) in enumerate([(-4,-13),(4,-12),(-7,6),(10,11),(18,4),(-16,-1),(4,13)])]
enemies=[{'id':i,'x':x,'z':z,'active':True} for i,(x,z) in enumerate([(-2,-6),(3,-2),(-5,3),(6,7),(-9,6),(11,11),(-2,14),(17,1)])]
data={'version':1,'spawn':{'x':0,'z':-21,'yaw':math.pi},'houses':houses,'windows':windows,'solids':solids,'ramps':ramps,'items':items,'crates':crates,'enemies':enemies,'collection':collection,'gate':{'x':11.5,'z':23,'y':0},'tower':{'x':-13.5,'z':-8.8,'top':4.22}}
data['npcs']=[{'id': 'yametaro', 'x': -2.8, 'z': -21.2}, {'id': 'takosan', 'x': -13, 'z': -18}]
data.update({'id': 'village', 'label': 'CHAPTER 01  /  PUEBLO', 'subtitle': '静かな村、騒がしい住人。', 'exits': [{'id': 'forward', 'target': 'farm', 'x': 11.5, 'z': 27.2, 'radius': 1.2, 'requiresGate': True, 'arrival': {'x': -19, 'z': -21, 'yaw': 3.141592653589793}}]})
data['gate'].update(mode='key',label='農場への門')
(OUT/'village.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')

export(OUT/'village.glb')
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False);groups.clear()
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
