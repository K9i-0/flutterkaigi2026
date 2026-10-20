"""Reproducible, material-batched Akasaka dusk stage. Run with Blender -b -P."""
import bpy, math, random
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'04_GAME_ASSETS/3d/stages/akasaka'
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
materials={}; batches={}
# Height ratios use 200m = 14 scene units. Horizontal layout is art-directed.
METERS = 14 / 200
TOWER_X, TOWER_Z = 15, -46
PARK_X, PARK_Z = 7.4, 8.2  # half extents: about 211m x 234m
# Fixed skyline accents, outside the park and the front-facing tower silhouette.
# x, z, width, depth, roof height in meters, facade
HIGHRISES = [
 (-30,-48,4.6,5.0,190,3), (-12,-70,4.2,5.2,210,5),
 (-38,-70,5.0,5.0,200,3), (36,-48,4.4,5.0,185,5),
 (43,-70,4.2,5.2,205,3),
]
def material(name,color,texture=None,metal=0,glow=0,rough=.65,emit=None):
 m=bpy.data.materials.new(name); m.use_nodes=True
 m.use_backface_culling=True
 p=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED'); p.inputs['Base Color'].default_value=(*color,1); p.inputs['Metallic'].default_value=metal; p.inputs['Roughness'].default_value=rough
 if texture:
  t=m.node_tree.nodes.new('ShaderNodeTexImage'); t.image=bpy.data.images.load(str(OUT/texture)); m.node_tree.links.new(t.outputs['Color'],p.inputs['Base Color'])
 if texture:
  stem=Path(texture).stem
  mr=OUT/f'{stem}_mr.png'
  if mr.exists():
   packed=m.node_tree.nodes.new('ShaderNodeTexImage'); packed.image=bpy.data.images.load(str(mr)); packed.image.colorspace_settings.name='Non-Color'
   channels=m.node_tree.nodes.new('ShaderNodeSeparateColor'); m.node_tree.links.new(packed.outputs['Color'],channels.inputs['Color'])
   m.node_tree.links.new(channels.outputs['Green'],p.inputs['Roughness']); m.node_tree.links.new(channels.outputs['Blue'],p.inputs['Metallic'])
  normal=OUT/f'{stem}_normal.png'
  if normal.exists():
   tnormal=m.node_tree.nodes.new('ShaderNodeTexImage'); tnormal.image=bpy.data.images.load(str(normal)); tnormal.image.colorspace_settings.name='Non-Color'
   bump=m.node_tree.nodes.new('ShaderNodeNormalMap'); bump.inputs['Strength'].default_value=.6
   m.node_tree.links.new(tnormal.outputs['Color'],bump.inputs['Color']); m.node_tree.links.new(bump.outputs['Normal'],p.inputs['Normal'])
 if glow:
  p.inputs['Emission Color'].default_value=(*color,1); p.inputs['Emission Strength'].default_value=glow
  if emit:
   e=m.node_tree.nodes.new('ShaderNodeTexImage'); e.image=bpy.data.images.load(str(OUT/emit)); m.node_tree.links.new(e.outputs['Color'],p.inputs['Emission Color'])
  elif texture: m.node_tree.links.new(t.outputs['Color'],p.inputs['Emission Color'])
 materials[name]=m
material('steel',(.7,.7,.7),'steel.png',.55,rough=.55)
material('concrete',(.27,.28,.3)); material('roof',(.13,.19,.22)); material('metal',(.19,.23,.25),metal=.6)
material('gold',(.95,.62,.13)); material('street',(.8,.8,.8),'asphalt.png'); material('paving',(.75,.75,.75),'paving.png')
material('marking',(.85,.84,.80),glow=.12); material('yellowline',(.95,.66,.18),glow=.15)
material('tower',(.95,.24,.055),metal=.3,glow=.35); material('white',(.95,.78,.57),metal=.2,glow=.15)
material('glass',(.10,.19,.23),metal=.45,rough=.2); material('light',(1,.62,.24),glow=1.2)
material('lawn',(.16,.27,.105),rough=1)
material('foliage',(.095,.20,.07),rough=1)
for i in range(6): material('facade'+str(i),(.7,.7,.7),f'facade_{i}.png',glow=1,emit=f'facade_{i}_emit.png')
material('crown',(.9,.86,.78),glow=1)
SIGNS=['akasaka','izakaya','soba','shika','bengoshi','fudosan']
for n in SIGNS: material(n,(1,1,1),f'sign_{n}.png',glow=.4)
# Retired ad slot stays empty to preserve the city's seeded layout.
ADS=[None,'accidenchua','safety']
for n in ADS+['yumemin']:
 if n: material('ad_'+n,(1,1,1),f'ad_{n}.png',glow=.5)
# Moving traffic: one atlas material, one mesh per direction group (see catch_scene.dart).
material('car',(1,1,1),'car_atlas.png',metal=.4,glow=1,rough=.35,emit='car_atlas_emit.png')
material('lamp',(1,.78,.45),glow=1.8); material('redlight',(1,.08,.05),glow=2.2)
material('skyline',(.8,.8,.8),'skyline.png',glow=1,emit='skyline_emit.png')
def mesh(name,verts,faces,uvs=None,obj=None):
 key=obj or name
 if key not in batches: batches[key]=(name,[],[],[])
 _,v,f,uv=batches[key]; offset=len(v); v.extend((x,-z,y) for x,y,z in verts)
 for i,face in enumerate(faces):
  f.append(tuple(offset+j for j in face)); uv.append(uvs[i] if uvs else [(0,0),(1,0),(1,1),(0,1)][:len(face)])
BOX_FACES=[(0,3,2,1),(4,5,6,7),(0,4,7,3),(1,2,6,5),(3,7,6,2),(0,1,5,4)]
def box(name,x,y,z,w,h,d,tile=None,off=(0,0),obj=None,cell=None,face_indices=None):
 """tile=(tu,tv) repeats the texture every tu units across and tv units up."""
 signs=[(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]
 vs=[(x+a*w/2,y+b*h/2,z+c*d/2) for a,b,c in signs]
 uvs=None
 if tile:
  tu,tv=tile; uvs=[]
  for fi,face in enumerate(BOX_FACES):
   axis=[2,2,0,0,1,1][fi]; flip=[-1,1,1,-1,1,1][fi]
   def uv(i):
    a,b,c=signs[i]; lx,ly,lz=(a+1)*w/2,(b+1)*h/2,(c+1)*d/2
    u=(lx if axis==2 else lz if axis==0 else lx)*flip; v=ly if axis!=1 else lz
    return (off[0]+u/tu,off[1]+v/tv)
   uvs.append([uv(i) for i in face])
 if cell is not None: uvs=[[((cell+.5)/4,.5)]*4 for _ in BOX_FACES]
 # Painted lane markings need only their visible top surface, not six faces.
 if face_indices is None and name in ['marking','yellowline']:
  face_indices=[4]
 faces=BOX_FACES if face_indices is None else [BOX_FACES[i] for i in face_indices]
 if uvs is not None and face_indices is not None: uvs=[uvs[i] for i in face_indices]
 mesh(name,vs,faces,uvs,obj)
def rod(name,a,b,r=.04,n=6):
 a,b=Vector(a),Vector(b); axis=(b-a).normalized(); u=axis.cross(Vector((0,1,0)))
 if u.length<.01: u=axis.cross(Vector((1,0,0)))
 u.normalize(); v=axis.cross(u)
 vs=[tuple(p+r*(u*math.cos(i*math.tau/n)+v*math.sin(i*math.tau/n))) for p in [a,b] for i in range(n)]
 mesh(name,vs,[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)])
FACADE=(4,8)
# The beam and its two support buildings.
box('steel',0,-.05,0,9.6,.1,.95,(4,1)); box('steel',0,-.36,0,9.6,.52,.12,(4,1)); box('steel',0,-.67,0,9.6,.1,.95,(4,1))
for s in [-1,1]:
 box('gold',0,.006,s*.44,9.4,.008,.025)
 # No two visible faces share a plane: the roof slab tops out 2cm under the
 # beam and over the crown band, otherwise they z-fight while the camera moves.
 box('facade0',s*6,-7.6,0,2.7,12.8,4,FACADE,(.25 if s>0 else .5,.125)); box('concrete',s*6,-.7,0,2.74,1.0,4.04)
 box('roof',s*6,-1.22,0,2.8,.06,4.1); box('roof',s*6,-.11,0,2.85,.18,4.1)
 box('concrete',s*7.37,.07,0,.1,.34,4.0)
 box('steel',s*4.4,.16,0,.16,.32,.94)
 # Bearing seat and end plate where the beam meets the building.
 box('steel',s*4.62,-.62,0,.06,1.25,1.3,(1,1)); box('steel',s*4.45,-.82,0,.34,.14,1.1,(1,1))
 for y in [-.25,-1.0]:
  for z in [-.5,.5]: rod('metal',(s*4.58,y,z),(s*4.52,y,z),.04)
 for i in range(7): box('gold' if i%2==0 else 'metal',s*(3.65+i*.1),.01,0,.09,.015,.74)
 box('metal',s*6.1,.38,-1.25,.9,.84,.8)
 for i in range(6): box('roof',s*6.1,.18+i*.09,-.84,.75,.035,.02)
 for z in [-1.8,1.8]:
  rod('metal',(s*5,-.05,z),(s*7,-.05,z),.06)
  for x in [5,6,7]: rod('metal',(s*x,-.1,z),(s*x,.55,z),.04)
  rod('metal',(s*5,.55,z),(s*7,.55,z),.04)
for x in range(-3,4):
 box('steel',x,-.35,.085,.25,.47,.05,(1,1))
 for z in [-.32,.32]: rod('metal',(x,0,z),(x,.026,z),.047)
 for y in [-.2,-.48]: rod('metal',(x,y,.11),(x,y,.15),.04)
# Road grid: a wide avenue runs under the beam toward Tokyo Tower.
G=-14
box('street',0,G-.15,0,320,.3,320,(4,4))
AVENUE=4.4
XROADS=[(-AVENUE,AVENUE)]+[(c-2,c+2) for c in [24,-24,48,-48,72,-72]]
ZROADS=[(c-2,c+2) for c in [16,-14,-36,-58,-80]]
def edges(roads,lo,hi):
 cuts=sorted(roads); spans=[]; a=lo
 for r0,r1 in cuts:
  if r0>a: spans.append((a,r0))
  a=max(a,r1)
 if hi>a: spans.append((a,hi))
 return spans
XBLOCKS=edges(XROADS,-80,80); ZBLOCKS=edges(ZROADS,-88,36)
rng=random.Random(27)
def lots(a,b,size):
 out=[]; x=a+.7
 while x<b-.7-2.4:
  w=min(rng.uniform(size*.7,size*1.3),b-.7-x)
  if b-.7-(x+w)<2.4: w=b-.7-x
  out.append((x,x+w)); x+=w
 return out
def clear(x,z,w,d):
 # Keep the support buildings, the tower plaza and the expressway corridor open.
 if abs(abs(x)-6)<1.4+w/2 and abs(z)<2+d/2: return False
 if abs(x-TOWER_X)<PARK_X+.8+w/2 and abs(z-TOWER_Z)<PARK_Z+.8+d/2: return False
 for hx,hz,hw,hd,_,_ in HIGHRISES:
  if abs(x-hx)<(w+hw)/2+.5 and abs(z-hz)<(d+hd)/2+.5: return False
 return True
sign_i=0
roofs=[]  # roofs left free for the Yumemin billboards
def building(x,z,w,d,h,kind,near):
 global sign_i
 off=(rng.randrange(4)*.25,rng.randrange(8)*.125); f='facade'+str(kind)
 tiers=[(w,d,h)] if h<14 else [(w,d,h*.62),(w*.74,d*.74,h)]
 base=G
 for tw,td,top in tiers:
  box(f,x,(base+G+top-.4)/2,z,tw,G+top-.4-base,td,FACADE,off); base=G+top
  box('concrete',x,base-.2,z,tw+.06,.4,td+.06); box('roof',x,base+.06,z,tw+.12,.12,td+.12)
  if top>11 and rng.random()<.6: box('crown',x,base-.62,z,tw+.04,.16,td+.04)
 top=G+h; tw,td,_=tiers[-1]
 p=rng.random()
 if p<.35: roofs.append((x,z,tw,td,top))
 if p<.35:
  for i in range(rng.randint(2,4)): box('metal',x+rng.uniform(-tw/3,tw/3),top+.28,z+rng.uniform(-td/3,td/3),.7,.45,.6)
 elif p<.6:
  tx,tz=x+rng.uniform(-tw/4,tw/4),z+rng.uniform(-td/4,td/4)
  for sx in [-.35,.35]:
   for sz in [-.35,.35]: rod('metal',(tx+sx,top,tz+sz),(tx+sx,top+.7,tz+sz),.04)
  rod('roof',(tx,top+.7,tz),(tx,top+1.6,tz),.55,10)
 elif p<.75 and near and h<11:
  ad=rng.choice(ADS)
  if ad:
   name='ad_'+ad
   bw=min(tw*.9,4.2)
   box(name,x,top+1.15,z+td/2-.4,bw,bw/2.67,.08)
   for sx in [-bw/3,bw/3]: rod('metal',(x+sx,top,z+td/2-.5),(x+sx,top+.6,z+td/2-.5),.05)
 if h>16:
  rod('metal',(x,top,z),(x,top+3,z),.05)
  for sx in [-1,1]:
   for sz in [-1,1]: box('redlight',x+sx*(tw/2-.15),top+.18,z+sz*(td/2-.15),.22,.22,.22)
  box('redlight',x,top+3.05,z,.2,.2,.2)
 if near and h<13 and rng.random()<.45:
  n=SIGNS[sign_i%len(SIGNS)]; sign_i+=1
  sh=min(3.0,h*.65)
  box(n,x+rng.choice([-1,1])*(w/2-.4),G+h-sh*.55,z+d/2+.1,sh*.2,sh,.14)
for x0,x1 in XBLOCKS:
 for z0,z1 in ZBLOCKS:
  box('paving',(x0+x1)/2,G+.07,(z0+z1)/2,x1-x0,.14,z1-z0,(4,4))
  far=max(abs((x0+x1)/2)/1.6,-(z0+z1)/2)
  size=4.6 if far<30 else 6
  for lx0,lx1 in lots(x0,x1,size):
   for lz0,lz1 in lots(z0,z1,size*1.15):
    w=lx1-lx0-.35; d=lz1-lz0-.35; x=(lx0+lx1)/2; z=(lz0+lz1)/2
    if not clear(x,z,w,d): continue
    # Mostly 35–70m. The tower precinct steps down to 15–40m.
    h=rng.uniform(35,70)*METERS
    if abs(x-TOWER_X)<15 and abs(z-TOWER_Z)<17:
     h=rng.uniform(15,40)*METERS
    elif (x < -18 or abs(x)>38) and rng.random()<.16:
     h=rng.uniform(90,140)*METERS
    kind=rng.choice([3,5]) if h>15 else rng.choice([0,1,2,4,0,1,2,3,4,5])
    building(x,z,w,d,h,kind,z>-40 and abs(x)<46)
# Five tall but simple office towers: two setbacks, shared facades/materials,
# no new textures or separate render objects. Roof machinery stays compact.
for x,z,w,d,meters,kind in HIGHRISES:
 h=meters*METERS
 base=G
 for scale,top in [(1,h*.65),(.82,h)]:
  tw,td=w*scale,d*scale
  box('facade'+str(kind),x,(base+G+top-.25)/2,z,tw,G+top-.25-base,td,FACADE)
  box('concrete',x,G+top-.14,z,tw+.06,.22,td+.06)
  box('roof',x,G+top,z,tw+.12,.06,td+.12)
  base=G+top
 box('metal',x,G+h+.24,z,1.1,.45,.8)
 for sx in [-1,1]:
  box('lamp',x+sx*w*.35,G+h+.07,z-d*.35,.10,.08,.10)
# Move all five Yumemin signs to the fixed high-rise roofs, above foreground
# occluders. Existing artwork, material and aspect ratio are preserved.
for x,z,w,d,meters,_ in HIGHRISES:
 top=G+meters*METERS
 bw=min(w*1.25,6.3); bz=z+d*.41+.12
 cy=top+1.45
 box('ad_yumemin',x,cy,bz,bw,bw/2.67,.1)
 box('metal',x,cy,bz-.08,bw+.16,bw/2.67+.16,.05)
 for sx in [-bw/3,bw/3]: rod('metal',(x+sx,top,bz-.1),(x+sx,cy,bz-.1),.06)
print('YUMEMIN',len(HIGHRISES))
# Lane markings, crosswalks, streetlights and traffic on the avenue.
for s in [-1,1]:
 box('yellowline',s*.12,G+.025,-30,.1,.02,140)
 for z in range(-98,38,4): box('marking',s*2.2,G+.02,z,.1,.02,1.8)
 for z in range(-96,36,8):
  if any(r0-1<z<r1+1 for r0,r1 in ZROADS): continue
  rod('metal',(s*4.75,G+.14,z),(s*4.75,G+2.4,z),.05); rod('metal',(s*4.75,G+2.4,z),(s*3.9,G+2.5,z),.04)
  box('lamp',s*3.85,G+2.44,z,.36,.08,.2)
for r0,r1 in ZROADS:
 for z in [r0-.9,r1+.9]:
  for i in range(-7,8): box('marking',i*.56,G+.02,z,.3,.02,1.2)
 for x in range(-90,91,3):
  if abs(x)>AVENUE+1: box('marking',x,G+.02,(r0+r1)/2,1.4,.02,.09)
for x0,x1 in XROADS[1:]:
 for z in range(-98,38,3): box('marking',(x0+x1)/2,G+.02,z,.09,.02,1.4)
# Each group repeats with PERIOD along its axis so the game can scroll the
# mesh by (time * speed) mod PERIOD without a visible seam.
PERIOD={'traffic_zpos':24,'traffic_zneg':24,'traffic_xpos':30,'traffic_xneg':30,'traffic_hwy_xpos':27,'traffic_hwy_xneg':27}
def car(obj,lane,t,axis,sign,y=G,s=1):
 body=1 if rng.random()<.35 else 0
 def b(along,up,acr,la,h,wa,cell):
  # No camera goes under road cars. Lamps are outward-facing quads instead
  # of tiny closed boxes; preserve their atlas colors and exact placement.
  faces=[0,1,2,3,4] if cell<2 else (
   [1 if along>0 else 0] if axis=='z' else [3 if along>0 else 2])
  if axis=='z': box('car',lane+acr,y+up,t+along,wa,h,la,obj=obj,cell=cell,face_indices=faces)
  else: box('car',t+along,y+up,lane+acr,la,h,wa,obj=obj,cell=cell,face_indices=faces)
 b(0,.3*s,0,1.8*s,.36*s,.85*s,body); b(-sign*.1,.62*s,0,1.0*s,.3*s,.74*s,body)
 b(sign*.91*s,.32*s,0,.04,.1*s,.7*s,2); b(-sign*.91*s,.34*s,0,.04,.09*s,.74*s,3)
def lane_cars(obj,lane,lo,hi,axis,sign,gap,y=G,s=1):
 P=PERIOD[obj]; pattern=[]; t=rng.uniform(0,2)
 while t<P-gap[0]: pattern.append(t); t+=rng.uniform(*gap)
 # Cover one extra period on both ends: the offset scrolls up to P either way.
 k=math.floor((lo-P)/P)
 while k*P<hi+P:
  for t in pattern:
   if lo-P<=k*P+t<=hi+P: car(obj,lane,k*P+t,axis,sign,y,s)
  k+=1
for lane,sign in [(-3.3,1),(-1.1,1),(1.1,-1),(3.3,-1)]:
 lane_cars('traffic_zpos' if sign>0 else 'traffic_zneg',lane,-96,36,'z',sign,(2.8,7))
for r0,r1 in ZROADS:
 lane_cars('traffic_xpos',r0+1,-90,90,'x',1,(4,11)); lane_cars('traffic_xneg',r1-1,-90,90,'x',-1,(4,11))
# Elevated expressway over the cross street seen just past the beam.
EZ,EY=-64,G+5.2
box('concrete',0,EY,EZ,184,.5,3.8); box('street',0,EY+.27,EZ,183.8,.04,3.6,(4,4))
for s in [-1,1]: box('concrete',0,EY+.55,EZ+s*1.85,184,.6,.12)
box('marking',0,EY+.3,EZ,184,.02,.08)
for x in range(-90,91,9):
 box('concrete',x,(G+EY)/2,EZ,.9,EY-G,.9); box('concrete',x,EY-.45,EZ,1.4,.4,3.2)
 rod('metal',(x,EY+.85,EZ-1.85),(x,EY+2,EZ-1.85),.04); box('lamp',x,EY+2,EZ-1.6,.2,.08,.5)
lane_cars('traffic_hwy_xpos',EZ-.9,-90,90,'x',1,(3,9),EY+.3,.95)
lane_cars('traffic_hwy_xneg',EZ+.9,-90,90,'x',-1,(3,9),EY+.3,.95)
# Distant skyline ring hides the edge of the modelled city.
for i in range(90):
 a=-math.pi+i*math.tau/90+rng.uniform(-.02,.02)
 if math.pi-abs(a)<.7: continue  # behind the camera
 rad=rng.uniform(92,104); x,z=math.sin(a)*rad,-math.cos(a)*rad-20
 h=rng.uniform(50,120)*METERS
 # Keep the skyline behind the landmark below its observation decks.
 if x>0: h=min(h,70*METERS)
 w=rng.uniform(6,11)
 box('skyline',x,G+h/2,z,w,h,w,(8,8),(rng.random(),0))
 if h>24: box('redlight',x,G+h+.2,z,.5,.4,.5)
# Open park: solid low-poly trees and shared material batches, no new textures
# or dynamic lights. Paths lead toward the tower from the beam side.
cx,cz,base=TOWER_X,TOWER_Z,G
box('lawn',cx,G+.16,cz,PARK_X*2,.12,PARK_Z*2)
box('paving',cx,G+.235,cz,8.4,.035,8.4,(4,4))
box('paving',cx,G+.235,cz,1.5,.035,PARK_Z*2,(4,4))
box('paving',cx,G+.235,cz,PARK_X*2,.035,1.5,(4,4))
for sx in [-1,1]:
 box('paving',cx+sx*(PARK_X-1),G+.235,cz,.7,.035,PARK_Z*2-1.4,(4,4))
for sz in [-1,1]:
 box('paving',cx,G+.235,cz+sz*(PARK_Z-.7),PARK_X*2-1.4,.035,.7,(4,4))
def tree(x,z,h):
 rod('metal',(x,G+.2,z),(x,G+h*.48,z),.065,5)
 # Three rings and pointed crown, no alpha cards or individual objects.
 rings=[(.32,.20),(.48,.34),(.76,.28),(1,0)]
 verts=[(x+math.cos(i*math.tau/7)*h*r,G+h*y,z+math.sin(i*math.tau/7)*h*r)
        for y,r in rings for i in range(7)]
 faces=[(j*7+i,(j+1)*7+i,(j+1)*7+(i+1)%7,j*7+(i+1)%7) for j in range(3) for i in range(7)]
 faces.append(tuple(range(7)))
 mesh('foliage',verts,faces)
park_rng=random.Random(333)
for sx in [-1,1]:
 for dz in [-6.6,-4.4,-2.2,2.2,4.4,6.6]:
  tree(cx+sx*(PARK_X-1.8),cz+dz,park_rng.uniform(.9,1.3))
for sz in [-1,1]:
 for dx in [-4,-2,2,4]:
  tree(cx+dx,cz+sz*(PARK_Z-1.6),park_rng.uniform(.85,1.2))
for sx in [-1,1]:
 for dz in [-6,-3,3,6]:
  box('metal',cx+sx*1.15,G+.42,cz+dz,.12,.42,.12)
  box('lamp',cx+sx*1.15,G+.65,cz+dz,.15,.06,.15)
# Tokyo Tower: 333m tip, 150m main deck and 250m upper deck.
TS=333*METERS/25
levels=[(y*TS,w) for y,w in [(0,3.8),(3,3),(6,2.2),(9,1.45),(12,1),(15,.7),(18,.48),(20,.3)]]
for (y0,w0),(y1,w1) in zip(levels,levels[1:]):
 for sx,sz in [(-1,-1),(1,-1),(1,1),(-1,1)]:
  a=(cx+sx*w0,base+y0,cz+sz*w0); b=(cx+sx*w1,base+y1,cz+sz*w1)
  rod('tower',a,b,.10 if y0<9 else .065)
 for axis in [0,1]:
  for s in [-1,1]:
   def p(t,w,y): return (cx+t*w,base+y,cz+s*w) if axis==0 else (cx+s*w,base+y,cz+t*w)
   rod('tower',p(-1,w0,y0),p(1,w1,y1),.045)
   rod('tower',p(1,w0,y0),p(-1,w1,y1),.045)
   rod('white' if any(abs(y0-y*TS)<.001 for y in [6,15]) else 'tower',p(-1,w0,y0),p(1,w0,y0),.075)
for y,w in [(150*METERS,3.6),(250*METERS,1.9)]:
 box('white',cx,base+y,cz,w,.22,w)
 box('glass',cx,base+y+.35,cz,w*.92,.48,w*.92)
 box('light',cx,base+y+.64,cz,w,.1,w)
for i in range(10): rod('white' if i%2 else 'tower',(cx,base+(20+i*.5)*TS,cz),(cx,base+(20+(i+1)*.5)*TS,cz),.14-i*.009)
for name,(mat,verts,faces,uvs) in batches.items():
 if not verts: continue
 me=bpy.data.meshes.new(name); me.from_pydata(verts,[],faces); me.update()
 ob=bpy.data.objects.new(name,me); bpy.context.collection.objects.link(ob); me.materials.append(materials[mat])
 uv=me.uv_layers.new(name='UVMap')
 for poly,coords in zip(me.polygons,uvs):
  for li,coord in zip(poly.loop_indices,coords): uv.data[li].uv=coord
bpy.ops.export_scene.gltf(filepath=str(OUT/'akasaka.glb'),export_format='GLB',export_yup=True)
print('STAGE',len(bpy.data.objects),'material batches',sum(len(o.data.polygons) for o in bpy.data.objects),'faces')
