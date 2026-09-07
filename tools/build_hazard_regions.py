"""Build the farm and mountain/ruined-house regions for the playable demo.

Reference layout: Capcom-hosted original RE4 official guide extract, printed p59.
Assets are newly modelled in metres; the reference page is never game content.
"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from hazard_environment_kit import *

blue = material('Blue enamel medallion',(.025,.20,.52),.3,.65)
straw = material('Old golden hay',(.41,.34,.15),pattern='wood')
rock = material('Weathered exposed bedrock',(.34,.33,.28),1)
# A packed, tileable rock albedo, generated from periodic ridged noise.
# Geometry below carries the broad silhouette; this supplies small strata.
n=512; yy,xx=np.mgrid[0:n,0:n]/n; noise=np.zeros((n,n))
rr=np.random.default_rng(4907)
for octave in range(1,7):
    for k in range(5):
        fx=int(rr.integers(1,4))*2**(octave-1);fy=int(rr.integers(1,4))*2**(octave-1)
        noise += np.sin((xx*fx+yy*fy)*math.tau+rr.random()*math.tau)/2**(octave*.8)
noise=(noise-noise.min())/(noise.max()-noise.min())
strata=np.abs(np.sin((yy*9+np.sin(xx*math.tau*2)*.35+noise*.7)*math.tau))
v=.60+.40*noise+.15*strata
im=bpy.data.images.new('Bedrock_albedo',width=n,height=n)
pixels=np.ones((n,n,4),dtype=np.float32);pixels[:,:,:3]=v[:,:,None]*np.array([.39,.385,.33]);im.pixels.foreach_set(pixels.ravel());im.pack()
tex=mats[rock].node_tree.nodes.new('ShaderNodeTexImage');tex.image=im
mats[rock].node_tree.links.new(tex.outputs['Color'],mats[rock].node_tree.nodes.get('Principled BSDF').inputs['Base Color'])

def fence(name,x,z,length,axis='x',gap=None):
    count=round(length/.65)
    for i in range(count+1):
        t=-length/2+length*i/count
        if gap and abs(t-gap[0])<gap[1]/2:continue
        xx=x+t if axis=='x' else x;zz=z if axis=='x' else z+t
        box(name,wood,(xx,zz,.72),(.12,.12,1.44))
    segments=[(-length/2,length/2)] if not gap else [(-length/2,gap[0]-gap[1]/2),(gap[0]+gap[1]/2,length/2)]
    for lo,hi in segments:
        for h in [.48,1.05]:
            box(name,boards,(x+(lo+hi)/2 if axis=='x' else x,
                z if axis=='x' else z+(lo+hi)/2,h),
                (hi-lo,.09,.13) if axis=='x' else (.09,hi-lo,.13))
        solid(x+(lo+hi)/2 if axis=='x' else x,z if axis=='x' else z+(lo+hi)/2,
              hi-lo if axis=='x' else .15,.15 if axis=='x' else hi-lo,1.35)

def poster(id,title,source,x,z,h,inside=False):
    mat=material('Poster_'+id,(1,1,1),1)
    im=wall_poster_image(ROOT/source)
    tex=mats[mat].node_tree.nodes.new('ShaderNodeTexImage');tex.image=im
    mats[mat].node_tree.links.new(tex.outputs['Color'],mats[mat].node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
    sign=-1 if inside else 1;w=.85;hh=1.28
    box('Poster_'+id,wood,(x,z+sign*.012,h),(w+.10,.04,hh+.10))
    face('Poster_'+id,mat,[(x-sign*w/2,z-sign*.018,h-hh/2),(x+sign*w/2,z-sign*.018,h-hh/2),
        (x+sign*w/2,z-sign*.018,h+hh/2),(x-sign*w/2,z-sign*.018,h+hh/2)])
    return {'id':id,'title':title,'source':source,'x':x,'z':z,'y':h-1,'node':'Poster_'+id}

def medallion(id,x,z,h):
    name='Medallion_'+id
    cylinder(name,blue,(x,z,h),.13,.025,20,axis=(0,1,0))
    cylinder(name,metal,(x,z,h+.28),.013,.32,6)
    return {'id':id,'x':x,'y':h,'z':z,'radius':.17,'node':name}

def gate(x,z,axis='x'):
    # The named dynamic gate is independent of its static frame.
    for sign in [-1,1]:
        box('GateFrame',wood,(x if axis=='z' else x+sign*1.75,
            z+sign*1.75 if axis=='z' else z,1.7),(.2,.2,3.4))
    box('FarmGate',boards,(x,z,1.25),(.23,3.2,2.5) if axis=='z' else (3.2,.23,2.5))
    solid(x,z,.25 if axis=='z' else 3.2,3.2 if axis=='z' else .25,2.5,id='gate')
    for h in [.3,2.0]:box('FarmGate',metal,(x,z,h),(.27,3.3,.08) if axis=='z' else (3.3,.27,.08))

def rocks(name,x,z,w,d,h):
    # Segmented cliff faces with sloping strata, matching the solid footprint.
    # The irregular surface recedes into the collider instead of hiding a path.
    solid(x,z,w,d,h)
    for side,length in [('south',w),('north',w),('east',d),('west',d)]:
        count=max(2,round(length/1.4)); rows=[]
        for level in range(5):
            row=[]
            for i in range(count+1):
                t=-length/2+length*i/count
                recess=rng.uniform(0,min(.6,w*.22,d*.22)) if level else 0
                hh=h*level/4+(rng.uniform(-.3,.3) if level else 0)
                if side in ['south','north']:
                    px=x+t;pz=z+(-1 if side=='south' else 1)*(d/2-recess)
                else:
                    px=x+(-1 if side=='west' else 1)*(w/2-recess);pz=z+t
                row.append((px,pz,hh))
            rows.append(row)
        for level in range(4):
            for i in range(count):
                vs=[rows[level][i],rows[level][i+1],rows[level+1][i+1],rows[level+1][i]]
                if side in ['north','west']:vs.reverse()
                # Quads are triangulated by glTF export; metre UVs avoid stretching.
                face(name,rock,vs,[(i*.7,level*h/8),((i+1)*.7,level*h/8),((i+1)*.7,(level+1)*h/8),(i*.7,(level+1)*h/8)])
    box(name,rock,(x,z,h-.25),(w,d,.25))
    for i in range(max(2,int(w*d/15))):
        xx=x+rng.uniform(-w*.4,w*.4);zz=z+rng.uniform(-d*.4,d*.4)
        cylinder(name,rock,(xx,zz,h*.94),rng.uniform(.8,1.6),h*.42,7,r2=rng.uniform(.2,.65))

def weeds(name,x,z,count):
    for i in range(count):
        xx=x+rng.uniform(-.7,.7);zz=z+rng.uniform(-.7,.7);h=rng.uniform(.1,.4)
        for a in [rng.random()*math.pi, rng.random()*math.pi]:
            dx=math.cos(a)*.025;dz=math.sin(a)*.025
            face(name,grass,[(xx-dx,zz-dz,0),(xx+dx,zz+dz,0),(xx+dx*2,zz+dz*2,h)],[(0,0),(1,0),(.5,1)])

def save(id,label,subtitle,spawn,items,crates,enemies,collection,npcs,exits,gate_data,targets=None):
    out=ROOT/'04_GAME_ASSETS/3d/environments'/id;out.mkdir(parents=True,exist_ok=True)
    data={'version':1,'id':id,'label':label,'subtitle':subtitle,'spawn':spawn,
        'houses':houses,'windows':windows,'solids':solids,'ramps':ramps,'items':items,'crates':crates,
        'enemies':enemies,'collection':collection,'npcs':npcs,'exits':exits,
        'gate':gate_data,'targets':targets or []}
    (out/(id+'.json')).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    export(out/(id+'.glb'))
    print('REGION',id,len(houses),'buildings',len(solids),'colliders',len(enemies),'enemies')

reset_world();rng.seed(4906)
box('Ground',dirt,(0,0,-.16),(52,58,.3))
# Original farm relationships: approach/save hut southwest; shed in middle;
# animal pen northeast; two-storey barn southeast and exit just beyond it.
house('SaveHut',-16,-14,5,5)
house('Tools',-9,3,7,4)
house('NorthShed',-10,17,4,5)
house('Barn',8,-9,9,10,True)
fence('Animal pen',12,5,15,'x',(-3,2.2))
fence('Animal pen',19,12,14,'z')
fence('Animal pen',12,19,14,'x')
fence('Animal pen',5,14,10,'z',(0,2))
for x,z in [(13,11),(15,14),(8,16)]:
    cylinder('Hay bales',straw,(x,z,.55),.62,1.1,16)
    box('Hay bales',wood,(x,z,.3),(1.1,.1,.1))
    solid(x,z,1.15,1.15,1.1)
# Pearl pendant well and the note tree beside the approach.
cylinder('Old well',stone,(-20,-11,.45),.65,.9,16)
cylinder('Old well water',glass,(-20,-11,.85),.48,.015,16)
solid(-20,-11,1.3,1.3,.9)
cylinder('Notice tree',wood,(-11,-16,2),.23,4,10,r2=.08)
for x,z in [(-20,8),(-18,17),(0,19),(19,21),(-21,-3)]:
    cylinder('Bare trunks',wood,(x,z,2.8),.18,5.6,9,r2=.055)
    for i in range(5):
        a=i*2.399;axis=(math.cos(a),math.sin(a),.5)
        cylinder('Bare branches',wood,(x+axis[0]*.65,z+axis[1]*.65,3.5+i*.35),.065,1.8,7,axis=axis,r2=.013)
# Preserve the southwest entry and eastern exit, with physical boundary walls.
wall('Farm boundary',-22,4,.7,46,2.7);wall('Farm boundary',22,8,.7,31,2.7)
wall('Farm boundary',22,-20,.7,11,2.7);wall('Farm boundary',0,23,44,.7,2.7)
wall('Farm boundary',3,-24,38,.7,2.7)
for i in range(15):
    backdrop_pine(-27+i*3.8,29,7+(i*7%5))
for i in range(10):
    backdrop_pine(-27,-20+i*4.8,7+(i*3%4))
    backdrop_pine(28,-18+i*4.8,8+(i*5%4))
gate(20,-10,'z')
fence('Exit lane',17.5,-12,5,'x');fence('Exit lane',17.5,-8,5,'x')
for x,z in [(-20,-16),(-21,4),(-12,5),(-2,12),(6,18),(18,20),(17,-15),(0,-19)]:weeds('Farm weeds',x,z,24)
targets=[medallion('farm_'+str(i),x,z,h) for i,(x,z,h) in enumerate([
    (-11,-16.2,2.6),(-16,-16.72,2.7),(-8,1-.2,2.5),(-10,14.28,2.8),
    (12,5.15,1.8),(6,-14.22,4.6),(11,19,2.1)])]
collection=[
    poster('work','労働時間のお知らせ','03_SCRIPTS/19_liveaction_tako_room_escape/prop_notice_work_8_hours_production.png',-16,-11.72,1.55),
    poster('alcohol','禁酒のお知らせ','03_SCRIPTS/19_liveaction_tako_room_escape/prop_notice_no_alcohol_twitter_production.png',-9,4.78,1.5),
    poster('recruit','FDE募集','03_SCRIPTS/15_yumemi_island_manmonth_mystery/prop_fde_recruitment_flyer_production.png',5,-13.78,4.45,True)]
items=[{'id':'farm_'+id,'kind':kind,'x':x,'z':z,'y':y,'amount':n} for id,kind,x,z,y,n in [
    ('herb','green',-17,-13,.8,1),('barn_ammo','ammo',6,-7,3.35,15),
    ('barn_shells','shells',8,-6,3.35,5),('field_ammo','ammo',-10,17,.85,15),
    ('red','red',-9,3,.85,1),('yellow','yellow',10,-12,3.35,1)]]
for item in items:
    if item['y']<2:item['y']=.28
crates=[{'id':'farm_crate_'+str(i),'x':x,'z':z,'kind':'crate' if i%2 else 'barrel'}
    for i,(x,z) in enumerate([(-17,-17.7),(-8,6),(0,9),(18,16),(7,-14.8),(15,-5)])]
enemies=[{'id':i,'x':x,'z':z,'active':True} for i,(x,z) in enumerate([(-5,-3),(0,2),(8,-5),(14,10),(-11,12),(-9,3)])]
save('farm','CHAPTER 02  /  ABANDONED PROJECT','秘密案件の補給施設。撤収対象外。',{'x':-19,'z':-21,'yaw':math.pi},items,crates,enemies,collection,
    [{'id':'takosan','x':-13,'z':-17.8}],
    [{'id':'back','target':'village','x':-19,'z':-23.5,'radius':1.0,'arrival':{'x':11.5,'z':25.2,'yaw':0}},
     {'id':'forward','target':'mountain','x':21.2,'z':-10,'radius':.9,'requiresGate':True,'arrival':{'x':-19,'z':-21,'yaw':math.pi}}],
    {'x':20,'z':-10,'y':0,'mode':'free','label':'山道への門'},targets)

reset_world();rng.seed(4907)
box('Ground',dirt,(0,0,-.16),(52,58,.3))
# The confinement-house route: narrow southwest path turns east through a
# tunnel, then opens into the ruined house yard at the northeast end.
rocks('South cliff',0,-13.5,32,25,5.8)
rocks('North cliff',-9,16,24,17,6.5)
rocks('East cliff',14,-12,16,21,5.0)
rocks('West ridge',-26,-9,8.8,31,6)
rocks('Far ridge',26,11,8.8,26,5.5)
rocks('North ridge',11,27,22,8.8,6)
for x,z,base in [(-24,-18,6),(-25,-7,6),(-25,8,6),(-14,18,6.5),(-5,20,6.5),
                 (6,-15,5.8),(19,-9,5),(26,3,5.5),(26,16,5.5),(7,29,6),(18,29,6)]:
    backdrop_pine(x,z,7+abs(x+z)%4,base)
for x in [-14,-11,-8,-5]:
    box('Tunnel roof',rock,(x,4.0,3.5),(3.3,6,.9))
    for z in [1.5,6.5]:box('Tunnel frame',wood,(x,z,1.7),(.22,.25,3.4))
    box('Tunnel frame',wood,(x,4,3.2),(.22,5.5,.25))
for x,z in [(-20,-15),(-17,-8),(-20,2),(-2,6),(2,0),(6,8),(18,8),(20,20)]:weeds('Mountain weeds',x,z,20)
house('Ruins',13,14,12,9)
box('Ruins bed',boards,(9.1,16,.35),(1.5,2.4,.7));solid(9.1,16,1.5,2.4,.7)
box('Ruins table',boards,(16,16,.8),(1.8,.8,.12))
for x,z in [(4,1),(17,2),(4,9)]:
    box('Yard cover',stone,(x,z,.65),(1.6,1.3,1.3));solid(x,z,1.6,1.3,1.3)
gate(20,15,'z')
collection=[
    poster('watch','見てるぞ','03_SCRIPTS/38_miteruzo_horror_poster/poster_miteruzo_variant_c_revised_v3.png',11.2,9.28,1.6),
    poster('drybeer','極度乾燥ビール','03_SCRIPTS/32_sobaya_beer_encouragement/prop_kyokudo_kanso_beer_production.png',14.7,9.28,1.6),
    poster('chair','アロンチェア制作記録','03_SCRIPTS/51_aronchia_makers_vlog/prop_aronchia_handwritten_final.png',11,9.72,1.6,True)]
items=[{'id':'mountain_'+id,'kind':kind,'x':x,'z':z,'y':y,'amount':n} for id,kind,x,z,y,n in [
    ('ammo','ammo',-18,-1,.3,15),('green','green',3,5,.25,1),('shells','shells',16,16,.9,5),('red','red',9,16,.85,1)]]
crates=[{'id':'mountain_crate_'+str(i),'x':x,'z':z,'kind':'crate'}
    for i,(x,z) in enumerate([(-20,-6),(-9,5),(7,7),(18,18)])]
enemies=[{'id':i,'x':x,'z':z,'active':True,'boss':i==4} for i,(x,z) in enumerate([
    (-19,-5),(-1,4),(6,5),(15,7),(12,4),(11,7)])]
save('mountain','CHAPTER 03  /  LAST ORDER','誰も終わらせに来ない仕事。',{'x':-19,'z':-21,'yaw':math.pi},items,crates,enemies,collection,
    [{'id':'yametaro','x':16,'z':17.5}, {'id':'takosan','x':13.6,'z':17.1,'afterBoss':True}],
    [{'id':'back','target':'farm','x':-19,'z':-23.5,'radius':1,'arrival':{'x':18,'z':-10,'yaw':math.pi/2}}],
    {'x':13,'z':9.5,'y':0,'mode':'boss','label':'集合場所の家'})
