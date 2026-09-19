"""Import the recorded whole-body output, normalize to 1.0 unit, and inspect it.

Run Blender --background --factory-startup --python <this file>.
Keeps raw outputs unchanged. No geometry sculpting or rigging.
"""
import json
import math
from pathlib import Path
import bpy
from mathutils import Matrix, Vector

OUT = Path(__file__).resolve().parent
QA = OUT / 'qa'
QA.mkdir(exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
raw = OUT / 'raw'
sources = list(raw.glob('*model*.glb')) or list(raw.glob('*model*.fbx'))
assert len(sources) == 1, sources
source = sources[0]
bpy.context.scene.render.fps = 30
if source.suffix == '.fbx':
    bpy.ops.import_scene.fbx(filepath=str(source))
else:
    bpy.ops.import_scene.gltf(filepath=str(source))
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
assert meshes, 'No imported mesh'
# Tripo default X-forward -> Blender -Y-forward, as in the v2 importer.
for obj in meshes:
    obj.data.transform(Matrix.Rotation(-math.pi / 2, 4, 'Z') @ obj.matrix_world)
    obj.parent = None
    obj.matrix_world = Matrix.Identity(4)
points = [v.co.copy() for o in meshes for v in o.data.vertices]
lo = Vector([min(v[i] for v in points) for i in range(3)])
hi = Vector([max(v[i] for v in points) for i in range(3)])
scale = 1.0 / (hi.z - lo.z)
transform = Matrix.Scale(scale, 4) @ Matrix.Translation((-(lo.x + hi.x)/2, -(lo.y + hi.y)/2, -lo.z))
for obj in meshes:
    obj.data.transform(transform)
    for poly in obj.data.polygons:
        poly.use_smooth = True
materials = []
for mat in bpy.data.materials:
    if not mat.use_nodes:
        continue
    bs = next((n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
    if not bs:
        continue
    maps = {}
    for node in mat.node_tree.nodes:
        if node.type == 'TEX_IMAGE' and node.image:
            role = Path(node.image.filepath).stem.lower()
            maps[role] = node
            if role in ('roughness', 'metallic', 'normal'):
                node.image.colorspace_settings.name = 'Non-Color'
            node.image.pack()
    for role, slot in [('color', 'Base Color'), ('roughness', 'Roughness'), ('metallic', 'Metallic')]:
        if role in maps:
            mat.node_tree.links.new(maps[role].outputs['Color'], bs.inputs[slot])
    if 'normal' in maps:
        normal = next((n for n in mat.node_tree.nodes if n.type == 'NORMAL_MAP'), None)
        if normal is None:
            normal = mat.node_tree.nodes.new('ShaderNodeNormalMap')
        mat.node_tree.links.new(maps['normal'].outputs['Color'], normal.inputs['Color'])
        mat.node_tree.links.new(normal.outputs['Normal'], bs.inputs['Normal'])
    materials.append({'material': mat.name, 'maps': list(maps)})
bpy.ops.object.select_all(action='DESELECT')
for obj in meshes:
    obj.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.export_scene.gltf(filepath=str(OUT / 'yumemin.glb'), export_format='GLB', use_selection=True, export_animations=False)
record = {'source': str(source.relative_to(OUT)), 'mesh_objects': len(meshes),
          'vertices': sum(len(o.data.vertices) for o in meshes),
          'polygons': sum(len(o.data.polygons) for o in meshes),
          'height_units': 1.0, 'rigged': False, 'materials': materials}
(OUT / 'model_report.json').write_text(json.dumps(record, indent=2) + '\n')
# Verify the exported artifact itself by reimporting it for review.
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(OUT / 'yumemin.glb'))
sc = bpy.context.scene
sc.render.engine = 'CYCLES'
sc.cycles.samples = 24
sc.cycles.use_denoising = True
sc.render.resolution_percentage = 100
sc.view_settings.view_transform = 'AgX'
world = bpy.data.worlds.new('ReviewStudio')
world.use_nodes = True
world.node_tree.nodes['Background'].inputs[0].default_value = (.42,.45,.48,1)
world.node_tree.nodes['Background'].inputs[1].default_value = .55
sc.world = world
cam = bpy.data.objects.new('ReviewCamera', bpy.data.cameras.new('ReviewCamera'))
sc.collection.objects.link(cam)
cam.data.type = 'ORTHO'
sc.camera = cam
for name, pos, power, size in [('Key',(-3,-4,5),550,5),('Fill',(4,-1,3),350,4),('Rim',(1,3,4),500,3)]:
    lamp = bpy.data.lights.new(name,'AREA')
    lamp.energy = power
    lamp.shape = 'DISK'
    lamp.size = size
    obj = bpy.data.objects.new(name,lamp)
    sc.collection.objects.link(obj)
    obj.location = pos
    obj.rotation_euler = (Vector((0,0,.5))-obj.location).to_track_quat('-Z','Y').to_euler()
def render(name, direction, target=(0,0,.5), size=1.3):
    point = Vector(target)
    cam.location = point + Vector(direction).normalized()*5
    cam.rotation_euler = (point-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.ortho_scale = size
    sc.render.resolution_x = 640
    sc.render.resolution_y = 640
    sc.render.image_settings.file_format = 'PNG'
    sc.render.filepath = str(QA / (name+'.png'))
    bpy.ops.render.render(write_still=True)
for name, direction in [('front',(0,-1,0)),('three_quarter',(.6,-1,0)),('left',(1,0,0)),('back',(0,1,0)),('right',(-1,0,0))]:
    render(name, direction)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'yumemin.blend'))
print('YUMEMIN_REVIEW_DONE', flush=True)
