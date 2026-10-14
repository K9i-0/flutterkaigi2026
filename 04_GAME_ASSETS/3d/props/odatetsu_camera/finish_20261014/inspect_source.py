"""Import the untouched Tripo source into a separate background Blender scene."""
import bpy
import hashlib
import json
from pathlib import Path
from mathutils import Vector

HERE = Path(__file__).resolve().parent
QA = HERE / 'qa'
QA.mkdir(exist_ok=True)
RAW = HERE.parent / 'tripo_20261014/raw'
sources = list(RAW.glob('*.fbx')) or list(RAW.glob('*.glb'))
assert len(sources) == 1, sources
source = sources[0]
bpy.ops.wm.read_factory_settings(use_empty=True)
if source.suffix == '.fbx':
    bpy.ops.import_scene.fbx(filepath=str(source))
else:
    bpy.ops.import_scene.gltf(filepath=str(source))
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
points = [o.matrix_world @ v.co for o in meshes for v in o.data.vertices]
lo = Vector(tuple(min(p[i] for p in points) for i in range(3)))
hi = Vector(tuple(max(p[i] for p in points) for i in range(3)))
center = (lo + hi) / 2
extent = max(hi - lo)
report = {'source': str(source.relative_to(HERE.parent)),
          'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
          'blender_world_bounds': [list(lo), list(hi)],
          'objects': [], 'materials': []}
for o in meshes:
    report['objects'].append({'name': o.name, 'vertices': len(o.data.vertices),
        'polygons': len(o.data.polygons), 'matrix_world': [list(row) for row in o.matrix_world]})
for mat in bpy.data.materials:
    bsdf = next((n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
    report['materials'].append({'name': mat.name,
        'metallic': bsdf.inputs['Metallic'].default_value if bsdf else None,
        'roughness': bsdf.inputs['Roughness'].default_value if bsdf else None,
        'images': [n.image.name for n in mat.node_tree.nodes if n.type == 'TEX_IMAGE' and n.image]})
for im in bpy.data.images:
    if im.type == 'IMAGE':
        im.filepath_raw = str(QA / (Path(im.name).stem + '.png'))
        im.file_format = 'PNG'
        im.save()
(HERE / 'source_inspection.json').write_text(json.dumps(report, indent=2) + '\n')
s = bpy.context.scene
s.render.engine = 'CYCLES'
s.cycles.samples = 12
s.cycles.use_denoising = True
s.world = bpy.data.worlds.new('Studio')
s.world.use_nodes = True
s.world.node_tree.nodes['Background'].inputs[0].default_value = (.75, .75, .75, 1)
s.world.node_tree.nodes['Background'].inputs[1].default_value = .5
s.view_settings.view_transform = 'Standard'
for name, xyz, power in [('Key',(2,-3,4),180),('Fill',(-3,-2,2),100),('Rim',(1,3,3),130)]:
    d = bpy.data.lights.new(name, 'AREA')
    d.energy = power * extent * extent
    d.shape = 'DISK'
    d.size = extent * 3
    o = bpy.data.objects.new(name, d)
    s.collection.objects.link(o)
    o.location = center + Vector(xyz) * extent
    o.rotation_euler = (center - o.location).to_track_quat('-Z', 'Y').to_euler()
d = bpy.data.cameras.new('AuditCamera')
c = bpy.data.objects.new('AuditCamera',d)
s.collection.objects.link(c)
s.camera = c
d.type = 'ORTHO'
d.ortho_scale = extent * 1.17
s.render.resolution_x = 720
s.render.resolution_y = 720
s.render.resolution_percentage = 100
s.render.image_settings.file_format = 'PNG'
for name, direction in [('neg_y',(0,-1,0)),('pos_y',(0,1,0)),('pos_x',(1,0,0)),('neg_x',(-1,0,0)),('top',(0,0,1)),('hero',(1,-1,.65))]:
    c.location = center + Vector(direction).normalized() * extent * 4
    c.rotation_euler = (center - c.location).to_track_quat('-Z','Y').to_euler()
    s.render.filepath = str(QA / ('source_' + name + '.png'))
    bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(HERE / 'source.blend'))
print('CAMERA_SOURCE_INSPECTED', flush=True)
