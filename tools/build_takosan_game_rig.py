"""Build the canonical six-tentacle, two-human-arm Takosan as smooth rigged 3D.

Blender --background --factory-startup --python tools/build_takosan_game_rig.py
Reference: 03_SCRIPTS/00_TEMPLATES/characters/character_takosan_basic_sheet.png
No generated API geometry or voxel assets are used.
"""
from pathlib import Path
import bpy
import math
import json
import random
from mathutils import Vector, Matrix, Quaternion

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / '04_GAME_ASSETS/3d/characters/takosan/rig_v1'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
parts = []

def material(name, color, roughness=.85):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Roughness'].default_value = roughness
    return m

cloth = material('Graphite woven robe', (.025,.029,.03))
skin = material('Ivory clay face and mitten hands', (.79,.75,.66), .8)
eyes = material('Solid black round eyes', (.0015,.002,.002), .7)
seam = material('Muted pewter embroidery', (.075,.070,.061), .9)
dark = material('Hood inner lining', (.009,.011,.012))
sucker = material('Tentacle suction rims', (.14,.131,.115), .86)

# A tiny, seamless, deterministic weave texture shared by hood, sleeves and
# tentacles. UV repeats are in physical units; this is a material, not a decal.
rng = random.Random(260906)
tex = bpy.data.images.new('Takosan woven graphite', width=128, height=128)
pixels = []
for y in range(128):
    for x in range(128):
        warp = .0008*math.cos(x*math.tau/4) + .0007*math.cos(y*math.tau/4)
        v = .019 + warp + rng.uniform(-.0005,.0005)
        pixels.extend((v*.94,v*.98,v,1))
tex.pixels[:] = pixels
tex.pack()
node = cloth.node_tree.nodes.new('ShaderNodeTexImage')
node.image = tex
cloth.node_tree.links.new(node.outputs['Color'], cloth.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])

def register(o, mat, bone, weights=None):
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    o.select_set(False)
    o.data.materials.clear()
    o.data.materials.append(mat)
    for p in o.data.polygons:
        p.use_smooth = True
    if weights is None:
        o.vertex_groups.new(name=bone).add(list(range(len(o.data.vertices))), 1, 'REPLACE')
    else:
        for i, group in enumerate(weights):
            for name, weight in group.items():
                if weight > .00001:
                    g = o.vertex_groups.get(name) or o.vertex_groups.new(name=name)
                    g.add([i], weight, 'REPLACE')
    uv = o.data.uv_layers.get('UVMap') or o.data.uv_layers.new(name='UVMap')
    for loop in o.data.loops:
        v = o.data.vertices[loop.vertex_index].co
        uv.data[loop.index].uv = ((v.x+v.y*.4)*5.5, v.z*5.5)
    parts.append(o)
    return o

def mesh(name, verts, faces, mat, bone, weights=None):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.update()
    o = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(o)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    return register(o, mat, bone, weights)

def sphere(name, pos, scale, mat, bone, segments=32, rings=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=1, location=pos)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    return register(o, mat, bone)

def blend_weights(t, names):
    f = min(len(names)-1, max(0, t*(len(names)-1)))
    lo = int(f)
    if lo == len(names)-1:
        return {names[lo]: 1}
    return {names[lo]: 1-(f-lo), names[lo+1]: f-lo}

def tube(name, points, radii, mat, bones, sides=12):
    verts, faces, weights = [], [], []
    u = None
    for i, co in enumerate(points):
        p = Vector(co)
        tangent = Vector(points[min(i+1,len(points)-1)]) - Vector(points[max(0,i-1)])
        tangent.normalize()
        if u is None:
            axis = Vector((0,0,1)) if abs(tangent.z) < .85 else Vector((0,1,0))
            u = tangent.cross(axis).normalized()
        else:
            # Parallel-transport the cross-section through a curl. Choosing a
            # new reference axis at every ring twists/flips the tip topology.
            u = (u - tangent*u.dot(tangent)).normalized()
        v = tangent.cross(u).normalized()
        for k in range(sides):
            a = math.tau*k/sides
            verts.append(p + radii[i]*(u*math.cos(a)+v*math.sin(a)))
            weights.append(blend_weights(i/(len(points)-1), bones))
        if i:
            for k in range(sides):
                faces.append(((i-1)*sides+k, (i-1)*sides+(k+1)%sides,
                              i*sides+(k+1)%sides, i*sides+k))
    faces.extend([tuple(reversed(range(sides))), tuple((len(points)-1)*sides+k for k in range(sides))])
    return mesh(name, verts, faces, mat, bones[0], weights)

def catmull(points, samples=7):
    p = [Vector(points[0]), *map(Vector,points), Vector(points[-1])]
    out = []
    for i in range(1,len(p)-2):
        for j in range(samples):
            t=j/samples
            out.append(.5*((2*p[i])+(-p[i-1]+p[i+1])*t+
                (2*p[i-1]-5*p[i]+4*p[i+1]-p[i+2])*t*t+
                (-p[i-1]+3*p[i]-3*p[i+1]+p[i+2])*t*t*t))
    out.append(Vector(points[-1]))
    return out

def ribbon(name, points, bone='Spine', radius=.006):
    points=catmull(points)
    return tube(name, points, [radius]*len(points), seam, [bone], 6)

# Cloth body: tapered shoulder, broad hem and shallow vertical folds.
profile = [(.27,.246,.155),(.30,.271,.176),(.40,.258,.171),
           (.53,.239,.161),(.66,.221,.149),(.76,.197,.136),(.81,.127,.103)]
verts, faces = [], []
for z,rx,ry in profile:
    for i in range(48):
        a=math.tau*i/48
        fold=1+.012*math.cos(a*12)*(1-(z-.27))
        verts.append((rx*math.cos(a)*fold,ry*math.sin(a)*fold,z))
for j in range(len(profile)-1):
    for i in range(48): faces.append((j*48+i,j*48+(i+1)%48,(j+1)*48+(i+1)%48,(j+1)*48+i))
faces.extend([tuple(reversed(range(48))),tuple((len(profile)-1)*48+i for i in range(48))])
body=mesh('Tailored robe',verts,faces,cloth,'Spine')

# Closed back hood shell with a real recessed opening at the face.
verts,faces=[],[]
rings=[(.253,.231,1.055,-.274),(.265,.244,1.056,-.295),
       (.335,.341,1.084,-.163),(.327,.329,1.098,.045),
       (.246,.252,1.092,.203),(.025,.029,1.092,.29)]
for j,(rx,rz,cz,depth) in enumerate(rings):
    for i in range(64):
        a=math.tau*i/64
        point=.037*max(0,math.sin(a))**12 if j in (2,3) else 0
        verts.append((rx*math.cos(a),depth,cz+rz*math.sin(a)+point))
for j in range(len(rings)-1):
    for i in range(64):faces.append((j*64+i,j*64+(i+1)%64,(j+1)*64+(i+1)%64,(j+1)*64+i))
faces.append(tuple((len(rings)-1)*64+i for i in range(64)))
hood=mesh('Deep pointed hood',verts,faces,cloth,'Head')
hood.data.materials.append(dark)
for p in hood.data.polygons[:64]:p.material_index=1
edge=[(rx*math.cos(math.tau*i/64),-.299,cz+rz*math.sin(math.tau*i/64))
      for i in range(65) for rx,rz,cz in [(.267,.245,1.056)]]
tube('Hood rolled seam',edge,[.007]*len(edge),cloth,['Head'],8)
sphere('Ivory oval face',(0,-.18,1.053),(.232,.134,.205),skin,'Head')
for side in [-1,1]:
    sphere('Round black eye',(.092*side,-.306,1.062),(.044,.017,.047),eyes,'Head',24,12)

# Exactly two ordinary sleeve-covered humanoid arms; white hands are undivided.
arm_paths={}
for side,suffix in [(-1,'L'),(1,'R')]:
    path=catmull([(side*.184,0,.746),(side*.252,-.013,.624),
                  (side*.292,-.035,.501),(side*.324,-.054,.401)],5)
    names=[f'UpperArm.{suffix}',f'Forearm.{suffix}']
    tube('Cloth sleeve '+suffix,path,[.093*(1-i/(len(path)-1))+.071*i/(len(path)-1)
        for i in range(len(path))],cloth,names,16)
    sphere('Rounded shoulder '+suffix,(side*.193,0,.722),(.096,.089,.095),cloth,'UpperArm.'+suffix,24,12)
    sphere('White mitten '+suffix,(side*.336,-.058,.357),(.050,.049,.061),skin,'Hand.'+suffix,24,12)
    arm_paths[suffix]=[(side*.184,0,.746),(side*.27,-.024,.557),(side*.327,-.053,.39),(side*.343,-.057,.327)]

# Six separate curled tentacles. Every arm has a three-joint chain and its own
# continuous vertex weights; the visible rims are attached to the same weights.
tentacle_paths=[]
for index,angle in enumerate([-150,-90,-30,30,90,150]):
    a=math.radians(angle)
    d=Vector((math.cos(a),math.sin(a),0))
    bend=Vector((-d.y,d.x,0))*(.025 if index%2 else -.025)
    points=[]
    for r,z in [(.095,.286),(.204,.13),(.34,.079),(.435,.094),(.47,.181),(.431,.232),(.401,.209)]:
        points.append(d*r+bend*(r/.47)+Vector((0,0,z)))
    path=catmull(points,5)
    radii=[.054*(1-i/(len(path)-1))**.95+.006 for i in range(len(path))]
    names=[f'Tentacle{index+1}.{part}' for part in ['Base','Mid','Tip']]
    tube(f'Tentacle {index+1}',path,radii,cloth,names,12)
    tentacle_paths.append((names,path))
    # Visible suction cups on the lower/outward side of each curling tip.
    for k in range(10):
        at=5+k*2
        t=at/(len(path)-1)
        tangent=(path[at+1]-path[at-1]).normalized()
        normal=tangent.cross(d.cross(Vector((0,0,1)))).normalized()
        center=path[at]+normal*(radii[at]+.001)
        radius=.012*(1-t*.5)
        bpy.ops.mesh.primitive_torus_add(major_segments=10,minor_segments=5,
            major_radius=radius,minor_radius=.003,location=center)
        o=bpy.context.object;o.name=f'Suction rim {index+1}-{k}'
        o.rotation_mode='QUATERNION';o.rotation_quaternion=Vector((0,0,1)).rotation_difference(normal)
        register(o,sucker,names[0])
        o.vertex_groups.clear()
        for name,w in blend_weights(t,names).items():
            if w>0:o.vertex_groups.new(name=name).add(list(range(len(o.data.vertices))),w,'REPLACE')

# Broad, low contrast embroidered scrolls follow the cloak surface.
for side in [-1,1]:
    design=[(.038,.75),(.053,.635),(.109,.526),(.185,.426),(.176,.361),
            (.113,.345),(.083,.383),(.105,.412),(.131,.389)]
    points=[]
    for x,z in design:
        rx=.271-(z-.3)*.16;ry=.176-(z-.3)*.085
        points.append((side*x,-ry*math.sqrt(max(.1,1-(x/rx)**2))-.006,z))
    ribbon('Robe scroll',points)
    ribbon('Robe outer sweep',[(side*.118,-.122,.742),(side*.158,-.143,.605),
           (side*.219,-.118,.492),(side*.232,-.115,.35)],radius=.004)

# Join all primitives into a single skinned mesh, preserving material ranges.
bpy.ops.object.select_all(action='DESELECT')
for o in parts:o.select_set(True)
bpy.context.view_layer.objects.active=body
bpy.ops.object.join()
body.name='TakosanBody'
body.data.calc_loop_triangles()
triangle_count=len(body.data.loop_triangles)
bpy.ops.object.select_all(action='DESELECT')
bpy.ops.object.armature_add()
rig=bpy.context.object;rig.name='TakosanRig'
bpy.ops.object.mode_set(mode='EDIT')
rig.data.edit_bones.remove(rig.data.edit_bones[0])
def bone(name,head,tail,parent=None):
    b=rig.data.edit_bones.new(name);b.head=head;b.tail=tail
    if parent:b.parent=rig.data.edit_bones[parent]
bone('Root',(0,0,0),(0,0,.29))
bone('Spine',(0,0,.29),(0,0,.81),'Root')
bone('Head',(0,0,.81),(0,0,1.20),'Spine')
for suffix,pts in arm_paths.items():
    bone('UpperArm.'+suffix,pts[0],pts[1],'Spine')
    bone('Forearm.'+suffix,pts[1],pts[2],'UpperArm.'+suffix)
    bone('Hand.'+suffix,pts[2],pts[3],'Forearm.'+suffix)
for names,path in tentacle_paths:
    indices=[0,10,20,len(path)-1]
    for i,name in enumerate(names):bone(name,path[indices[i]],path[indices[i+1]],'Root' if i==0 else names[i-1])
bpy.ops.object.mode_set(mode='OBJECT')
ground_offset=-min(v.co.z for v in body.data.vertices)
ground_transform=Matrix.Translation((0,0,ground_offset))
body.data.transform(ground_transform)
rig.data.transform(ground_transform)
body.parent=rig
mod=body.modifiers.new('Skin','ARMATURE');mod.object=rig
rig.animation_data_create()
bpy.context.scene.render.fps=30
for b in rig.pose.bones:b.rotation_mode='QUATERNION'
def turn(name,axis,angle):
    b=rig.pose.bones[name]
    local=b.bone.matrix_local.to_3x3().inverted()@Vector(axis)
    b.rotation_quaternion=Quaternion(local,angle)
for name in ['Idle','Talk','Wave']:
    a=bpy.data.actions.new(name);a.use_fake_user=True;a.use_frame_range=True;a.frame_start=0;a.frame_end=90
    rig.animation_data.action=a
    for frame in range(91):
        t=frame/90*math.tau
        for b in rig.pose.bones:b.matrix_basis=Matrix.Identity(4)
        turn('Head',(0,1,0),.025*math.sin(t))
        rig.pose.bones['Spine'].location.y=.003*math.sin(t)
        for i,(names,path) in enumerate(tentacle_paths):
            turn(names[1],(0,0,1),.025*math.sin(t+i*math.tau/6))
            turn(names[2],(0,0,1),.07*math.sin(t+i*math.tau/6))
        if name=='Talk':
            turn('UpperArm.R',(1,0,0),-.20)
            turn('Forearm.R',(1,0,0),-.35-.10*math.sin(t*2))
            turn('Head',(0,0,1),.04*math.sin(t))
        if name=='Wave':
            turn('UpperArm.R',(0,1,0),-.70)
            turn('Forearm.R',(0,1,0),-1.45+.10*math.sin(t*2))
        for b in rig.pose.bones:
            b.keyframe_insert('location',frame=frame,group=b.name)
            b.keyframe_insert('rotation_quaternion',frame=frame,group=b.name)
rig.animation_data.action=None
for b in rig.pose.bones:b.matrix_basis=Matrix.Identity(4)
bpy.context.scene.frame_set(0)
bpy.ops.object.select_all(action='DESELECT');body.select_set(True);rig.select_set(True)
bpy.context.view_layer.objects.active=rig
(OUT/'.gitignore').write_text('*.blend\n*.blend1\n')
report={'height_m':max(v.co.z for v in body.data.vertices),'triangles':triangle_count,'bones':len(rig.data.bones),
        'materials':len(body.data.materials),'clips':['Idle','Talk','Wave'],
        'humanoid_arms':2,'undivided_white_hands':2,'lower_tentacles':6,
        'source':'procedural Blender / canonical basic sheet','units':'metres'}
(OUT/'rig.json').write_text(json.dumps(report,indent=2)+'\n')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'takosan.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'takosan.glb'),export_format='GLB',use_selection=True,
    export_animations=True,export_animation_mode='ACTIONS',export_frame_range=False,
    export_anim_slide_to_zero=True,export_anim_single_armature=True,export_skins=True,
    export_force_sampling=True)
print('TAKOSAN',json.dumps(report))
