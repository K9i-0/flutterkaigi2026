"""Normalize the Tripo head and make its eye interiors unlit black.

Blender --background --factory-startup --python this_file.py
Downloads are kept in raw/. Cameras and lights are excluded from head.glb.
"""

from collections import Counter
import hashlib
import json
import math
from pathlib import Path
import struct

import bpy
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
SOURCE = HERE / 'raw/output_model_url.fbx'
HEIGHT = .330  # Nominal head-and-neck height; body fitting is a separate step.


def darken_eye_interiors(obj):
    """Select existing black eye faces by location and source UV color.

    No vertices, UVs, images, or non-eye materials are changed.
    The spatial bounds distinguish eyes from hair, mouth and forehead detail.
    """
    source = obj.data.materials[0]
    color = next(n.image for n in source.node_tree.nodes
                 if n.type == 'TEX_IMAGE' and n.image and
                 any(link.to_socket.name == 'Base Color'
                     for link in n.outputs['Color'].links))
    width, height = color.size
    uv = obj.data.uv_layers.active.data
    selected = []
    sides = [0, 0]
    for polygon in obj.data.polygons:
        point = polygon.center
        if not (point.y < -.055 and .140 < point.z < .215):
            continue
        if ((abs(point.x) - .0385) / .028) ** 2 + ((point.z - .179) / .031) ** 2 > 1:
            continue
        coord = sum((uv[i].uv for i in polygon.loop_indices), Vector((0, 0))) / len(polygon.loop_indices)
        x = min(width - 1, max(0, int(coord.x * width)))
        y = min(height - 1, max(0, int(coord.y * height)))
        offset = (y * width + x) * 4
        rgb = color.pixels[offset:offset + 3]
        if max(rgb) < .18:
            selected.append(polygon)
            sides[point.x > 0] += 1
    assert all(15 <= n <= 300 for n in sides), ('Unexpected eye selection', sides)
    material = bpy.data.materials.new('SobayaEyeInteriorBlack')
    material.diffuse_color = (0, 0, 0, 1)
    material.use_nodes = True
    nodes = material.node_tree.nodes
    nodes.clear()
    emission = nodes.new('ShaderNodeEmission')
    emission.inputs['Color'].default_value = (0, 0, 0, 1)
    output = nodes.new('ShaderNodeOutputMaterial')
    material.node_tree.links.new(emission.outputs[0], output.inputs['Surface'])
    index = len(obj.data.materials)
    obj.data.materials.append(material)
    for polygon in selected:
        polygon.material_index = index
    return {'faces': len(selected), 'faces_per_eye': sides, 'material': material.name,
            'appearance': 'unlit RGB 0,0,0; no reflection', 'geometry_changed': False}


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(SOURCE))
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
assert meshes, 'Tripo output has no mesh'
report = {
    'source': str(SOURCE.relative_to(HERE)),
    'source_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
    'task_id': '1034434c-2bf7-45b0-a534-b1fc12686f5d',
    'objects': [],
    'images': [],
    'normalization': 'Uniform scale only, head and neck 0.330 m; base at origin; Blender -Y / glTF +Z forward.',
    'body_integration': False,
}
for index, obj in enumerate(meshes):
    obj.data = obj.data.copy()
    obj.data.transform(Matrix.Rotation(-math.pi / 2, 4, 'Z') @ obj.matrix_world)
    obj.parent = None
    obj.matrix_world = Matrix.Identity(4)
    obj.name = 'SobayaHead' if index == 0 else f'SobayaHeadPart{index}'

points = [v.co.copy() for o in meshes for v in o.data.vertices]
assert all(math.isfinite(x) for p in points for x in p)
low = Vector(tuple(min(p[i] for p in points) for i in range(3)))
high = Vector(tuple(max(p[i] for p in points) for i in range(3)))
scale = HEIGHT / (high.z - low.z)
base = Vector(((low.x + high.x) / 2, (low.y + high.y) / 2, low.z))
transform = Matrix.Scale(scale, 4) @ Matrix.Translation(-base)
for obj in meshes:
    obj.data.transform(transform)
    obj.data.update()
    report['eye_interior'] = darken_eye_interiors(obj)
    obj.data.calc_loop_triangles()
    report['objects'].append({
        'name': obj.name,
        'vertices': len(obj.data.vertices),
        'polygons': len(obj.data.polygons),
        'triangles': len(obj.data.loop_triangles),
        'polygon_sides': dict(Counter(len(p.vertices) for p in obj.data.polygons)),
        'uv_layers': len(obj.data.uv_layers),
        'materials': [m.name for m in obj.data.materials if m],
    })
for image in bpy.data.images:
    if image.size[0] and image.size[1] and image.name not in {'Render Result', 'Viewer Node'}:
        image.pack()
        report['images'].append({'name': image.name, 'size': list(image.size)})
report['dimensions_m'] = list((high - low) * scale)
report['triangles'] = sum(o['triangles'] for o in report['objects'])
report['armatures'] = sum(o.type == 'ARMATURE' for o in bpy.context.scene.objects)
assert report['armatures'] == 0, 'Expected a static independent head'

bpy.ops.object.select_all(action='DESELECT')
for obj in meshes:
    obj.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.context.scene.unit_settings.system = 'METRIC'
bpy.context.scene.unit_settings.scale_length = 1
bpy.ops.wm.save_as_mainfile(filepath=str(HERE / 'head_source.blend'))
bpy.ops.export_scene.gltf(
    filepath=str(HERE / 'head.glb'), export_format='GLB', use_selection=True,
    export_animations=False, export_image_format='AUTO', export_extras=True,
)
# Blender's exporter drops a zero-color Emission shader instead of marking it
# unlit. Write the glTF material explicitly, keeping the binary chunk intact.
raw = (HERE / 'head.glb').read_bytes()
json_size = struct.unpack_from('<I', raw, 12)[0]
document = json.loads(raw[20:20 + json_size])
eye = next(m for m in document['materials'] if m['name'] == 'SobayaEyeInteriorBlack')
eye['pbrMetallicRoughness'] = {
    'baseColorFactor': [0, 0, 0, 1], 'metallicFactor': 0, 'roughnessFactor': 1,
}
eye.setdefault('extensions', {})['KHR_materials_unlit'] = {}
document.setdefault('extensionsUsed', []).append('KHR_materials_unlit')
encoded = json.dumps(document, separators=(',', ':')).encode()
encoded += b' ' * (-len(encoded) % 4)
binary_chunk = raw[20 + json_size:]
header = struct.pack('<4sII', b'glTF', 2, 20 + len(encoded) + len(binary_chunk))
(HERE / 'head.glb').write_bytes(header + struct.pack('<I4s', len(encoded), b'JSON') + encoded + binary_chunk)
report['glb_bytes'] = (HERE / 'head.glb').stat().st_size
report['glb_sha256'] = hashlib.sha256((HERE / 'head.glb').read_bytes()).hexdigest()
report['review_source'] = 'Re-imported final head.glb, including KHR_materials_unlit eye material'
(HERE / 'audit.json').write_text(json.dumps(report, indent=2) + '\n')

# Inspect the delivered file, including its actual exported material behavior.
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(HERE / 'head.glb'))
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = 24
scene.cycles.use_denoising = True
scene.render.resolution_x = scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.world = bpy.data.worlds.new('Head review')
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.16, .16, .16, 1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value = .8
scene.view_settings.view_transform = 'AgX'
target = Vector((0, 0, HEIGHT / 2))

def aim(obj):
    obj.rotation_euler = (target - obj.location).to_track_quat('-Z', 'Y').to_euler()

for location, energy in [((-2, -3, 4), 350), ((2, -2, 2), 180), ((0, 3, 3), 200)]:
    bpy.ops.object.light_add(type='AREA', location=location)
    light = bpy.context.object
    light.data.energy = energy
    light.data.size = 3
    aim(light)
bpy.ops.object.camera_add()
camera = bpy.context.object
camera.data.type = 'ORTHO'
camera.data.ortho_scale = HEIGHT / .86
scene.camera = camera
review = HERE / 'review'
review.mkdir(exist_ok=True)
for name, location in [
    ('front', (0, -3, HEIGHT / 2)),
    ('left', (3, 0, HEIGHT / 2)),
    ('back', (0, 3, HEIGHT / 2)),
    ('right', (-3, 0, HEIGHT / 2)),
    ('three-quarter', (2, -3, HEIGHT / 2)),
]:
    camera.location = location
    aim(camera)
    scene.render.filepath = str(review / f'{name}.png')
    bpy.ops.render.render(write_still=True)
print('SOBAYA_HEAD_AUDIT', json.dumps(report))
