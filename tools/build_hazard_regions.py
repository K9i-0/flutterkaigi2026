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
# Reuse the village's photographic earth/gravel on the cut banks. The former
# periodic procedural strata read as stretched waves from the gameplay camera.
im=next(node.image for node in mats[dirt].node_tree.nodes
        if node.type=='TEX_IMAGE' and node.image.name.startswith('earth'))
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
    # Preserve the navigable footprint; all slopes and trees recede into it.
    # A closed ring mesh replaces the flat lid and repeated conical pillars.
    solid(x,z,w,d,1.45)
    local=random.Random(f'{name}:forest-20260913')
    nx=max(4,math.ceil(w/2.2));nz=max(4,math.ceil(d/2.2))
    perimeter=[]
    for i in range(nx):perimeter.append((-w/2+w*i/nx,-d/2))
    for i in range(nz):perimeter.append((w/2,-d/2+d*i/nz))
    for i in range(nx):perimeter.append((w/2-w*i/nx,d/2))
    for i in range(nz):perimeter.append((-w/2,d/2-d*i/nz))
    def surface(px,pz):
        edge=min(w/2-abs(px-x),d/2-abs(pz-z))
        rise=min(1,max(0,edge)/min(3.8,w*.35,d*.35))
        relief=.5*math.sin(px*.48+pz*.29)+.35*math.cos(pz*.63-px*.18)
        return 1.45+(h-1.45)*rise+relief*rise
    # Enclose each slope band so the third-person camera cannot enter its
    # surface. The upper bands still recede instead of retaining a tall box.
    bottom_height=1.45
    previous_fraction=0
    for fraction in [.2,.4,.7,1.0]:
        inset=previous_fraction*min(3.8,w*.35,d*.35)/min(w,d)
        top=1.45+(h-1.45+.85)*fraction
        solid(x,z,w*(1-2*inset),d*(1-2*inset),top-bottom_height,
              bottom=bottom_height)
        bottom_height=top
        previous_fraction=fraction
    rings=[]
    for inset in [0,.055,.15,.29,.42]:
        ring=[]
        for px,pz in perimeter:
            xx=x+px*(1-2*inset);zz=z+pz*(1-2*inset)
            ring.append((xx,zz,surface(xx,zz)))
        rings.append(ring)
    bottom=[(x+px,z+pz,-.12) for px,pz in perimeter]
    for lo,hi in zip([bottom]+rings[:-1],rings):
        for i in range(len(perimeter)):
            j=(i+1)%len(perimeter)
            mat=rock if lo is bottom or hi is rings[1] else dirt
            vs=[lo[i],lo[j],hi[j],hi[i]]
            along_x=abs(lo[j][0]-lo[i][0])>abs(lo[j][1]-lo[i][1])
            uv=[(px,pz) if mat==dirt else ((px if along_x else pz)/3,hh/3)
                for px,pz,hh in vs]
            face(name,mat,vs,uv)
    center=(x,z,surface(x,z)+.25)
    for i in range(len(perimeter)):
        vs=[rings[-1][i],rings[-1][(i+1)%len(perimeter)],center]
        face(name,dirt,vs,[(px,pz) for px,pz,_ in vs])
    # Staggered groves on the inaccessible banks, using the village's pine art.
    # Keep the tree cards behind the path edge and avoid a regular plantation.
    for ix in range(max(1,int((w-3)/3.7))):
        for iz in range(max(1,int((d-3)/4.1))):
            xx=x-w/2+2.1+ix*3.7+local.uniform(-.35,.35)
            zz=z-d/2+2.1+iz*4.1+local.uniform(-.4,.4)
            if local.random()<.19:continue
            height=local.uniform(4.5,8.5)
            backdrop_pine(xx,zz,height,surface(xx,zz)-.15)

def weeds(name,x,z,count):
    for i in range(count):
        xx=x+rng.uniform(-.7,.7);zz=z+rng.uniform(-.7,.7);h=rng.uniform(.1,.4)
        for a in [rng.random()*math.pi, rng.random()*math.pi]:
            dx=math.cos(a)*.025;dz=math.sin(a)*.025
            face(name,grass,[(xx-dx,zz-dz,0),(xx+dx,zz+dz,0),(xx+dx*2,zz+dz*2,h)],[(0,0),(1,0),(.5,1)])

def save(id,label,subtitle,spawn,items,crates,enemies,collection,npcs,exits,gate_data,targets=None):
    if '--mountain-only' in sys.argv and id!='mountain':return
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
house('Tools',-9,3,7,4,rear_door=True)
house('NorthShed',-10,17,4,5)
house('Barn',8,-9,9,10,True,rear_door=True)
# Two turns of opaque cover along the southern supply approach and barn flank.
# The barn remains an optional upstairs ammunition/collection risk; its rear
# doorway lets a discovered player cross the building and change exit choice.
cover_screen('farm_approach',-8,-18,4.0)
cover_screen('farm_approach_return',-6.1,-16.9,2.2,axis='z')
cover_screen('farm_barn_flank',14.5,-18,4.0)
cover_screen('farm_barn_return',16.4,-16.9,2.2,axis='z')
cover_screen('farm_tools',-15,7.8,4.0)
cover_screen('farm_tools_return',-16.9,8.9,2.2,axis='z')
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
playable_trunk('Notice tree',-11,-16,4,.23,.08)
for x,z in [(-20,8),(-18,17),(0,19),(19,21),(-21,-3)]:
    playable_trunk('Bare trunks',x,z,5.6,.18,.055)
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
    poster('alcohol','禁酒のお知らせ','03_SCRIPTS/19_liveaction_tako_room_escape/prop_notice_no_alcohol_twitter_production.png',-11.03,4.78,1.5),
    poster('recruit','FDE募集','03_SCRIPTS/15_yumemi_island_manmonth_mystery/prop_fde_recruitment_flyer_production.png',5,-13.78,4.45,True)]
items=[{'id':'farm_'+id,'kind':kind,'x':x,'z':z,'y':y,'amount':n} for id,kind,x,z,y,n in [
    ('herb','green',-17,-13,.8,1),('barn_ammo','ammo',6,-7,3.35,15),
    ('barn_shells','shells',8,-6,3.35,5),('field_ammo','ammo',-10,17,.85,15),
    ('red','red',-9,3,.85,1),('yellow','yellow',10,-12,3.35,1),
    ('beer_entry','beer',-18,-19,.28,2),('beer_approach','beer',-10,-18.8,.28,1),
    ('beer_tools','beer',-14,6.8,.28,1),('beer_barn','beer',9,-6,3.35,1)]]
for item in items:
    if item['y']<2:item['y']=.28
crates=[{'id':'farm_crate_'+str(i),'x':x,'z':z,'kind':'crate' if i%2 else 'barrel'}
    for i,(x,z) in enumerate([(-17,-17.7),(-8,6),(0,9),(18,16),(7,-14.8),(15,-5)])]
# Watch barn/field approaches while preserving the southwest supply route.
farm_guard_headings=[math.pi/2,math.pi,math.pi,-math.pi/2,math.pi,math.pi]
enemies=[{'id':i,'x':x,'z':z,'active':True,'heading':farm_guard_headings[i]} for i,(x,z) in enumerate([(-5,-3),(0,2),(8,-5),(14,10),(-11,12),(-9,3)])]
enemies[0].update(x=-3,z=-15.5,heading=-math.pi/2,patrol=[[-3,-15.5],[2,-15.5],[2,-18.5],[-3,-18.5]])
enemies[2].update(x=14.2,z=-6,heading=math.pi,patrol=[[14.2,-6],[14.2,-13.5]])
save('farm','CHAPTER 02  /  ABANDONED PROJECT','秘密案件の補給施設。撤収対象外。',{'x':-19,'z':-21,'yaw':math.pi},items,crates,enemies,collection,
    [{'id':'takosan','x':-13,'z':-17.8}],
    [{'id':'back','target':'village','x':-19,'z':-23.5,'radius':1.0,'arrival':{'x':11.5,'z':25.2,'yaw':0}},
     {'id':'forward','target':'mountain','x':21.2,'z':-10,'radius':.9,'requiresGate':True,'arrival':{'x':-19,'z':-21,'yaw':math.pi}}],
    {'x':20,'z':-10,'y':0,'mode':'free','label':'山道への門'},targets)

# Rebuild this chapter without rewriting the adopted mountain environment.
if '--farm-only' in sys.argv:sys.exit(0)

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
# Three spatial grove batches keep the denser forest within the draw budget.
for patch in [key for key in groups if key.startswith('PinePatch_')]:
    for mat,data in groups.pop(patch).items():
        for indices,uv in zip(data['f'],data['uv']):
            vertices=[data['v'][i] for i in indices]
            cx=sum(v[0] for v in vertices)/len(vertices)
            zone='west' if cx < -10 else 'east' if cx > 10 else 'central'
            face('MountainPines_'+zone,mat,vertices,uv)
for x in [-14,-11,-8,-5]:
    box('Tunnel roof',boards,(x,4.0,3.5),(3.3,6,.22))
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
# The entry lookout watches the corridor; the tunnel/yard guards watch its
# exits. Keep the boss's original north-facing introduction intact.
mountain_guard_headings=[math.pi,-math.pi/2,math.pi,math.pi,0,0]
enemies=[{'id':i,'x':x,'z':z,'active':True,'boss':i==4,'heading':mountain_guard_headings[i]} for i,(x,z) in enumerate([
    (-19,-5),(-1,4),(6,5),(15,7),(12,4),(11,7)])]
save('mountain','CHAPTER 03  /  LAST ORDER','誰も終わらせに来ない仕事。',{'x':-19,'z':-21,'yaw':math.pi},items,crates,enemies,collection,
    [{'id':'yametaro','x':16,'z':17.5}, {'id':'takosan','x':13.6,'z':17.1,'afterBoss':True}],
    [{'id':'back','target':'farm','x':-19,'z':-23.5,'radius':1,'arrival':{'x':18,'z':-10,'yaw':math.pi/2}}],
    {'x':13,'z':9.5,'y':0,'mode':'boss','label':'集合場所の家'})
