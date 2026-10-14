"""Render the exported camera GLB in four cardinal views and two detail views."""
import bpy
import hashlib
import json
import shutil
from pathlib import Path
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
QA = HERE / 'qa'
QA.mkdir(exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(HERE / 'odatetsu_camera.glb'))
source_sha256 = hashlib.sha256((HERE/'odatetsu_camera.glb').read_bytes()).hexdigest()
gltf_to_blender = Matrix(((1,0,0),(0,0,-1),(0,1,0)))
s = bpy.context.scene
s.render.engine = 'CYCLES'
s.cycles.samples = 24
s.cycles.use_denoising = True
s.world = bpy.data.worlds.new('Studio')
s.world.use_nodes = True
s.world.node_tree.nodes['Background'].inputs[0].default_value = (.8,.8,.8,1)
s.world.node_tree.nodes['Background'].inputs[1].default_value = .5
s.view_settings.view_transform = 'Standard'
target = gltf_to_blender @ Vector((.016,.003,.130))
for name, pos, power, size in [('Key',(.4,.8,.8),7,.8),('Fill',(-.5,.2,.3),4,.8),('Rim',(.2,.5,-.5),5,.7)]:
    d = bpy.data.lights.new(name, 'AREA')
    d.energy = power
    d.shape = 'DISK'
    d.size = size
    o = bpy.data.objects.new(name,d)
    s.collection.objects.link(o)
    o.location = gltf_to_blender @ Vector(pos)
    o.rotation_euler = (target-o.location).to_track_quat('-Z','Y').to_euler()
d = bpy.data.cameras.new('AuditCamera')
c = bpy.data.objects.new('AuditCamera',d)
s.collection.objects.link(c)
s.camera = c
d.type = 'ORTHO'
s.render.resolution_percentage = 100
s.render.image_settings.file_format = 'PNG'
views = [
    ('front',(0,0,1),(.016,.003,.13),.40,900,900),
    ('back',(0,0,-1),(.016,.003,.13),.40,900,900),
    ('grip',(-1,0,0),(.016,.003,.13),.40,1000,800),
    ('switches',(1,0,0),(.016,.003,.13),.40,1000,800),
    ('hero',(1,.55,1),(.016,.003,.13),.39,1200,1000),
    ('body',(1,.65,1),(.0,.01,.006),.19,1000,1000),
]
for name, direction, pt, scale, width, height in views:
    at = gltf_to_blender @ Vector(pt)
    c.location = at + gltf_to_blender @ Vector(direction).normalized()
    c.rotation_euler = (at-c.location).to_track_quat('-Z','Y').to_euler()
    c.data.ortho_scale = scale
    s.render.resolution_x = width
    s.render.resolution_y = height
    s.render.filepath = str(QA / (name+'.png'))
    bpy.ops.render.render(write_still=True)
shutil.copy2(QA/'hero.png',HERE/'preview.png')
(HERE/'render_manifest.json').write_text(json.dumps({
    'glb_sha256': source_sha256,
    'views': [{'file': f'qa/{name}.png', 'sha256':hashlib.sha256((QA/(name+'.png')).read_bytes()).hexdigest(),
               'width':width,'height':height} for name,direction,pt,scale,width,height in views],
}, indent=2)+'\n')
print('ODATETSU_CAMERA_REVIEWED',flush=True)
