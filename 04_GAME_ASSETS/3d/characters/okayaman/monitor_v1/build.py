"""Rebuild with: Blender --background --python path/to/build.py"""
from pathlib import Path
import bpy
from mathutils import Vector

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[4]
PHOTO = ROOT / '02_CHARACTERS/Okayaman.jpg'
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

def mat(name, color, metal=0, rough=.4):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Metallic'].default_value = metal
    p.inputs['Roughness'].default_value = rough
    return m

black = mat('Graphite polymer', (.018,.022,.028), .25)
metal = mat('Brushed dark aluminum', (.09,.12,.15), .8, .29)
recess = mat('Recess black', (.004,.006,.009))
root = bpy.data.objects.new('Okayaman_Monitor_Root', None)
scene.collection.objects.link(root)
root['source_image'] = '02_CHARACTERS/Okayaman.jpg'
root['units'] = 'metres; front -Y; ground Z=0'
parts = []

def box(name, loc, size, material, bevel=.015):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.object
    o.name = name
    o.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(material)
    if bevel:
        mod = o.modifiers.new('Soft machined edges', 'BEVEL')
        mod.width = bevel
        mod.segments = 3
        bpy.ops.object.modifier_apply(modifier=mod.name)
        mod = o.modifiers.new('Weighted corner normals', 'WEIGHTED_NORMAL')
        bpy.ops.object.modifier_apply(modifier=mod.name)
    o.parent = root
    parts.append(o)
    return o

# A freestanding large display, 2.0 m wide with a 16:9 active panel.
w, h, z = 2.0, 1.125, 1.48
box('Housing', (0,.015,z), (2.075,.105,1.21), black,.024)
box('Rear electronics enclosure', (0,.095,z), (1.62,.095,.86), black,.035)
box('Panel black surround', (0,-.043,z), (2.018,.012,1.143), recess,.008)
box('Pedestal foot', (0,.055,.045), (.94,.60,.09), metal,.035)
box('Stand column', (0,.15,.59), (.115,.12,1.06), metal,.018)
box('Rear VESA mounting plate', (0,.165,1.28), (.30,.045,.38), metal,.012)
box('Stand neck', (0,.12,1.20), (.18,.20,.13), metal,.015)
for x in [-.35,.35]:
    for y in [-.16,.26]:
        box('Rubber foot', (x,y,.009), (.13,.10,.018), recess,.008)
for i in range(20):
    box('Rear vent %02d'%i, ((i-9.5)*.053,.145,1.80), (.028,.003,.11), recess,.006)
for i in range(3):
    box('Input port %d'%i, (.43+i*.075,.145,1.20), (.047,.006,.021), recess,.003)
led = mat('Power LED', (.04,.65,.85))
p = next(n for n in led.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
p.inputs['Emission Color'].default_value = (.02,.55,.8,1)
p.inputs['Emission Strength'].default_value = 2
box('Power indicator', (.91,-.042,.904), (.024,.006,.004),led,.001)

# Preserve the complete photograph and its native aspect ratio; white pillars
# are actual screen pixels/material, not an AI-modified portrait.
img = bpy.data.images.load(str(PHOTO), check_existing=True)
img.pack()
screenmat = bpy.data.materials.new('Canonical photo - unlit emission')
screenmat.use_nodes=True
nodes=screenmat.node_tree.nodes
nodes.clear()
out=nodes.new('ShaderNodeOutputMaterial')
em=nodes.new('ShaderNodeEmission')
tex=nodes.new('ShaderNodeTexImage'); tex.image=img
screenmat.node_tree.links.new(tex.outputs['Color'],em.inputs['Color'])
screenmat.node_tree.links.new(em.outputs[0],out.inputs['Surface'])
white = mat('Screen white side margins',(1,1,1))
n=white.node_tree.nodes; n.clear()
e=n.new('ShaderNodeEmission'); e.inputs['Color'].default_value=(1,1,1,1)
o=n.new('ShaderNodeOutputMaterial'); white.node_tree.links.new(e.outputs[0],o.inputs[0])

def panel(name, width, height, y, material):
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata([(-width/2,y,z-height/2),(width/2,y,z-height/2),(width/2,y,z+height/2),(-width/2,y,z+height/2)],[],[(0,1,2,3)])
    mesh.uv_layers.new()
    for loop,uv in zip(mesh.uv_layers.active.data,[(0,0),(1,0),(1,1),(0,1)]): loop.uv=uv
    ob=bpy.data.objects.new(name,mesh); scene.collection.objects.link(ob)
    ob.data.materials.append(material); ob.parent=root; parts.append(ob)

panel('Display full surface',w,h,-.051,white)
panel('Okayaman canonical photograph',h*img.size[0]/img.size[1],h,-.052,screenmat)
bpy.ops.object.select_all(action='DESELECT')
root.select_set(True)
for o in parts: o.select_set(True)
bpy.context.view_layer.objects.active=root
bpy.ops.export_scene.gltf(filepath=str(OUT/'okayaman_monitor.glb'),use_selection=True,export_apply=True)

# Studio environment is deliberately excluded from the GLB.
floor=mat('Studio floor',(.075,.09,.12),.05,.52)
o=box('Preview ground',(0,0,-.065),(200,200,.1),floor,0)
o.parent=None
scene.world = bpy.data.worlds.new('Studio World')
scene.world.color=(.16,.16,.16)
def aim(o, at): o.rotation_euler=(Vector(at)-o.location).to_track_quat('-Z','Y').to_euler()
for name,loc,power,size in [('Key',(-3,-4,5),850,4),('Rim',(3,2,4),1100,3),('Fill',(3,-3,2),450,3)]:
    bpy.ops.object.light_add(type='AREA',location=loc)
    light=bpy.context.object; light.name=name; light.data.energy=power; light.data.shape='DISK'; light.data.size=size; aim(light,(0,0,1))
bpy.ops.object.camera_add(location=(3,-5,2.9))
cam=bpy.context.object; aim(cam,(0,0,1.08)); scene.camera=cam
cam.data.type='ORTHO'; cam.data.ortho_scale=3.25; cam.data.clip_end=1000
scene.render.engine='CYCLES'; scene.cycles.samples=32
scene.render.resolution_x=1200; scene.render.resolution_y=1200; scene.render.resolution_percentage=100
scene.view_settings.view_transform='Standard'
scene.render.image_settings.file_format='PNG'
scene.render.filepath=str(OUT/'preview.png')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'okayaman_monitor.blend'))
bpy.ops.render.render(write_still=True)
cam.location=(0,-5,2.0); aim(cam,(0,0,1.08))
scene.render.filepath=str(OUT/'front.png'); bpy.ops.render.render(write_still=True)
cam.location=(3,5,2.8); aim(cam,(0,0,1.08))
scene.render.filepath=str(OUT/'rear.png'); bpy.ops.render.render(write_still=True)
print('BUILD_COMPLETE',len(parts)-1,'model meshes')
