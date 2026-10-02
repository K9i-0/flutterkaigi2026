"""Reproducible, material-batched Akasaka dusk stage. Run with Blender -b -P."""
import bpy, math, random
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'04_GAME_ASSETS/3d/stages/akasaka'
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
materials={}; batches={}
def material(name,color,texture=None,metal=0,glow=0):
 m=bpy.data.materials.new(name); m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1); p.inputs['Metallic'].default_value=metal; p.inputs['Roughness'].default_value=.65
 if texture:
  t=m.node_tree.nodes.new('ShaderNodeTexImage'); t.image=bpy.data.images.load(str(OUT/texture)); m.node_tree.links.new(t.outputs['Color'],p.inputs['Base Color'])
 if glow:
  p.inputs['Emission Color'].default_value=(*color,1); p.inputs['Emission Strength'].default_value=glow
  if texture: m.node_tree.links.new(t.outputs['Color'],p.inputs['Emission Color'])
 materials[name]=m; batches[name]=([],[],[])
material('steel',(.4,.2,.1),'steel.png',.65)
material('concrete',(.27,.28,.3)); material('roof',(.13,.19,.22)); material('metal',(.19,.23,.25),metal=.6)
material('gold',(.95,.62,.13)); material('street',(.09,.10,.14))
material('tower',(.95,.24,.055),metal=.3,glow=.35); material('white',(.95,.78,.57),metal=.2,glow=.15)
material('glass',(.10,.19,.23),metal=.5); material('light',(1,.62,.24),glow=1.2)
for i in range(3): material('facade'+str(i),(.7,.7,.7),f'facade_{i}.png',glow=.08)
for n in ['akasaka','izakaya','yakitori','soba']: material(n,(1,1,1),f'sign_{n}.png',glow=.4)
def mesh(name,verts,faces):
 v,f,uv=batches[name]; offset=len(v); v.extend((x,-z, -14+(y+14)*.78 if name in ['tower','white','glass','light'] else y) for x,y,z in verts)
 for face in faces:
  f.append(tuple(offset+i for i in face)); uv.append([(0,0),(1,0),(1,1),(0,1)][:len(face)])
def box(name,x,y,z,w,h,d):
 vs=[(x+a*w/2,y+b*h/2,z+c*d/2) for a,b,c in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
 mesh(name,vs,[(0,3,2,1),(4,5,6,7),(0,4,7,3),(1,2,6,5),(3,7,6,2),(0,1,5,4)])
def rod(name,a,b,r=.04,n=6):
 a,b=Vector(a),Vector(b); axis=(b-a).normalized(); u=axis.cross(Vector((0,1,0)))
 if u.length<.01: u=axis.cross(Vector((1,0,0)))
 u.normalize(); v=axis.cross(u)
 vs=[tuple(p+r*(u*math.cos(i*math.tau/n)+v*math.sin(i*math.tau/n))) for p in [a,b] for i in range(n)]
 mesh(name,vs,[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)])
box('steel',0,-.05,0,9.6,.1,.95); box('steel',0,-.36,0,9.6,.52,.12); box('steel',0,-.67,0,9.6,.1,.95)
for s in [-1,1]:
 box('gold',0,.004,s*.44,9.4,.008,.025)
 box('concrete',s*6,-7,0,2.7,14,4); box('roof',s*6,-.1,0,2.85,.2,4.1)
 box('steel',s*4.4,.16,0,.16,.32,.94)
 for i in range(7): box('gold' if i%2==0 else 'metal',s*(3.65+i*.1),.01,0,.09,.015,.74)
 box('metal',s*6.1,.4,-1.25,.9,.8,.8)
 for i in range(6): box('roof',s*6.1,.18+i*.09,-.84,.75,.035,.02)
 for z in [-1.8,1.8]:
  rod('metal',(s*5,-.05,z),(s*7,-.05,z),.06)
  for x in [5,6,7]: rod('metal',(s*x,-.1,z),(s*x,.55,z),.04)
  rod('metal',(s*5,.55,z),(s*7,.55,z),.04)
for x in range(-3,4):
 box('steel',x,-.35,.085,.25,.47,.05)
 for z in [-.32,.32]: rod('metal',(x,0,z),(x,.026,z),.047)
 for y in [-.2,-.48]: rod('metal',(x,y,.11),(x,y,.15),.04)
box('street',0,-14.2,0,150,.3,150)
rng=random.Random(27)
for row in range(9):
 for col in range(13):
  x=(col-6)*6.7+rng.uniform(-.6,.6); z=-10-row*6.4
  # Preserve the tower's silhouette and foreground playing space.
  if abs(x-12)<5 and abs(z+30)<6: continue
  h=rng.uniform(5,11) if row<3 else rng.uniform(6,12)
  w=rng.uniform(3.4,5.5); d=rng.uniform(3.4,5)
  box('facade'+str(rng.randrange(3)),x,-14+h/2,z,w,h,d)
  box('roof',x,-14+h+.08,z,w+.15,.16,d+.15)
  box('metal',x+.5,-14+h+.4,z,.9,.7,.9)
  if row<3 and col%2==0:
   n=['akasaka','izakaya','yakitori','soba'][col//2%4]
   box(n,x+w/2-.35,-14+h-1.7,z+d/2+.11,.55,2.9,.14)
# Side streets frame the bridge when the camera orbits.
for s in [-1,1]:
 for i in range(5):
  x=s*(12+i*6); z=3+rng.uniform(-2,4); h=rng.uniform(5,10)
  box('facade'+str(i%3),x,-14+h/2,z,4.8,h,4.6); box('roof',x,-14+h,z,5,.15,4.8)
# Tokyo Tower, tapered four-legged lattice with two observation decks.
cx,cz,base=12,-30,-14
levels=[(0,3.8),(3,3),(6,2.2),(9,1.45),(12,1),(15,.7),(18,.48),(20,.3)]
for (y0,w0),(y1,w1) in zip(levels,levels[1:]):
 for sx,sz in [(-1,-1),(1,-1),(1,1),(-1,1)]:
  a=(cx+sx*w0,base+y0,cz+sz*w0); b=(cx+sx*w1,base+y1,cz+sz*w1)
  rod('tower',a,b,.10 if y0<9 else .065)
 for axis in [0,1]:
  for s in [-1,1]:
   def p(t,w,y): return (cx+t*w,base+y,cz+s*w) if axis==0 else (cx+s*w,base+y,cz+t*w)
   rod('tower',p(-1,w0,y0),p(1,w1,y1),.045)
   rod('tower',p(1,w0,y0),p(-1,w1,y1),.045)
   rod('white' if y0 in [6,15] else 'tower',p(-1,w0,y0),p(1,w0,y0),.075)
for y,w in [(9,3.6),(16,1.9)]:
 box('white',cx,base+y,cz,w,.22,w)
 box('glass',cx,base+y+.35,cz,w*.92,.48,w*.92)
 box('light',cx,base+y+.64,cz,w,.1,w)
for i in range(10): rod('white' if i%2 else 'tower',(cx,base+20+i*.5,cz),(cx,base+20+(i+1)*.5,cz),.14-i*.009)
for name,(verts,faces,uvs) in batches.items():
 if not verts: continue
 me=bpy.data.meshes.new(name); me.from_pydata(verts,[],faces); me.update()
 ob=bpy.data.objects.new(name,me); bpy.context.collection.objects.link(ob); me.materials.append(materials[name])
 uv=me.uv_layers.new(name='UVMap')
 for poly,coords in zip(me.polygons,uvs):
  for li,coord in zip(poly.loop_indices,coords): uv.data[li].uv=coord
bpy.ops.export_scene.gltf(filepath=str(OUT/'akasaka.glb'),export_format='GLB',export_yup=True)
print('STAGE',len(bpy.data.objects),'material batches',sum(len(o.data.polygons) for o in bpy.data.objects),'faces')
