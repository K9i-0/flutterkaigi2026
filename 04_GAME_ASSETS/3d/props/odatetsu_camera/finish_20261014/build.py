"""Normalize the immutable Tripo camera and add named equipment attachment nodes.

Run in a fresh background Blender process. Coordinates in settings/asset.json
are glTF coordinates: metres, +Y up, +Z optical axis, -X hand-grip side.
"""
import bpy
import hashlib
import json
import math
from pathlib import Path
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

HERE = Path(__file__).resolve().parent
CONFIG = json.loads((HERE / 'settings.json').read_text())
SOURCE = (HERE.parent / CONFIG['source']).resolve()
OUT = HERE / 'odatetsu_camera.glb'
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest() == CONFIG['source_sha256']
bpy.ops.wm.read_factory_settings(use_empty=True)
if SOURCE.suffix == '.fbx':
    bpy.ops.import_scene.fbx(filepath=str(SOURCE))
else:
    bpy.ops.import_scene.gltf(filepath=str(SOURCE))
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
raw_to_gltf = Matrix(CONFIG['blender_source_to_gltf_axes'])
origin = Vector(CONFIG['origin_in_rotated_source'])
scale = CONFIG['scale_metres_per_source_unit']
gltf_to_blender = Matrix(((1,0,0),(0,0,-1),(0,1,0)))
before = {'vertices': sum(len(o.data.vertices) for o in meshes),
          'polygons': sum(len(o.data.polygons) for o in meshes)}
points = []
for i, obj in enumerate(meshes):
    world = obj.matrix_world.copy()
    for v in obj.data.vertices:
        source_p = world @ v.co
        # Keep the camera body and hand grip intact. The generated telephoto
        # barrel was compressed along its axis; restore its reference scale.
        lens = CONFIG.get('lens_proportion_correction')
        if lens and source_p.y < lens['mount_source_y'] and source_p.x > lens['minimum_source_x']:
            distance = lens['mount_source_y'] - source_p.y
            radial_mix = min(1.0, max(0.0, distance / lens['radial_transition_source_units']))
            radial = 1 + (lens['radial_scale'] - 1) * radial_mix
            source_p.x = lens['axis_source_x'] + (source_p.x - lens['axis_source_x']) * radial
            source_p.z = lens['axis_source_z'] + (source_p.z - lens['axis_source_z']) * radial
            source_p.y = lens['mount_source_y'] - distance * lens['axial_scale']
        p = (raw_to_gltf @ source_p - origin) * scale
        points.append(p.copy())
        v.co = gltf_to_blender @ p
    obj.parent = None
    obj.matrix_world = Matrix.Identity(4)
    obj.name = 'OdatetsuCamera' if i == 0 else f'OdatetsuCameraPart{i:02d}'
    obj.data.update()
material_changes = []
for mat in {m for o in meshes for m in o.data.materials if m}:
    bsdf = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    change = {'name': mat.name, 'settings': CONFIG.get('material_overrides', {})}
    for socket_name, value in CONFIG.get('material_overrides', {}).items():
        socket = bsdf.inputs[socket_name]
        for link in list(socket.links):
            mat.node_tree.links.remove(link)
        if socket_name != 'Normal':
            socket.default_value = value
    material_changes.append(change)

def solid_material(name, color, roughness=.55):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*color, 1)
    bsdf.inputs['Roughness'].default_value = roughness
    return mat

black = solid_material('Label graphite', (.018,.019,.022))
white = solid_material('Label warm white', (.92,.92,.89))
red = solid_material('O series badge red', (.9,.075,.018))
rubber = solid_material('Focus ring rubber', (.012,.013,.014), .76)
ring = CONFIG.get('focus_ring')
if ring:
    verts, faces = [], []
    count = 512
    loops = [(ring['z_min'], -.0003), (ring['z_min']+.00045, 0),
             (ring['z_max']-.00045, 0), (ring['z_max'], -.0003)]
    for z, bevel in loops:
        for i in range(count):
            theta = i * 2 * math.pi / count
            radius = ring['radius'] + bevel + (.00013 if i % 4 < 2 else 0)
            verts.append(gltf_to_blender @ Vector((ring['centre_x']+radius*math.cos(theta),
                ring['centre_y']+radius*math.sin(theta), z)))
    for k in range(len(loops)-1):
        for i in range(count):
            j = (i+1) % count
            faces.append((k*count+i, k*count+j, (k+1)*count+j, (k+1)*count+i))
    mesh = bpy.data.meshes.new('FocusRingMesh')
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new('FocusRing', mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(rubber)
    for p in obj.data.polygons:
        p.use_smooth = True
    meshes.append(obj)
label_report = []
original_meshes = list(meshes)
depsgraph = bpy.context.evaluated_depsgraph_get()
bvhs = [BVHTree.FromObject(o, depsgraph) for o in original_meshes]
for spec in CONFIG.get('labels', []):
    normal = Vector(spec['normal']).normalized()
    right = Vector(spec['right']).normalized()
    up = normal.cross(right).normalized()
    centre = Vector(spec['centre'])
    ray_origin = gltf_to_blender @ (centre + normal * .04)
    ray_direction = gltf_to_blender @ -normal
    hits = [hit for tree in bvhs if (hit := tree.ray_cast(ray_origin, ray_direction, .08))[0] is not None]
    assert hits, spec['name']
    hit = min(hits, key=lambda h: h[3])
    centre = gltf_to_blender.inverted() @ hit[0] + normal * .00035
    orientation = Matrix((right,up,normal)).transposed()
    rotation = gltf_to_blender @ orientation
    bpy.ops.mesh.primitive_cube_add(size=1, location=gltf_to_blender @ centre)
    plate = bpy.context.object
    plate.name = spec['name'] + '_Plate'
    plate.rotation_euler = rotation.to_euler()
    plate.dimensions = (spec['width'], spec['height'], .0004)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    plate.data.materials.append(red if spec.get('red') else black)
    bevel = plate.modifiers.new('Fine label edge', 'BEVEL')
    bevel.width = .00012
    bevel.segments = 2
    bpy.context.view_layer.objects.active = plate
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    meshes.append(plate)
    curve = bpy.data.curves.new(spec['name'] + '_Text', 'FONT')
    curve.body = spec['text']
    curve.font = bpy.data.fonts.load('/System/Library/Fonts/Supplemental/Arial.ttf')
    curve.align_x = 'CENTER'
    curve.align_y = 'CENTER'
    curve.size = spec['height'] * .76
    curve.space_line = .85
    obj = bpy.data.objects.new(spec['name'], curve)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = gltf_to_blender @ (centre + normal * .00024)
    obj.rotation_euler = rotation.to_euler()
    obj.data.materials.append(white)
    bpy.context.view_layer.update()
    local_width = max(p[0] for p in obj.bound_box) - min(p[0] for p in obj.bound_box)
    local_height = max(p[1] for p in obj.bound_box) - min(p[1] for p in obj.bound_box)
    obj.scale *= min(1, spec['width']*.93/local_width, spec['height']*.88/local_height)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.ops.object.convert(target='MESH')
    meshes.append(obj)
    label_report.append({'name':spec['name'], 'text':spec['text'], 'position':list(centre),
                         'width':spec['width'], 'height':spec['height']})
anchors = {}
for name, pos in CONFIG['anchors'].items():
    obj = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(obj)
    obj.empty_display_type = 'PLAIN_AXES'
    obj.empty_display_size = .012
    obj.location = gltf_to_blender @ Vector(pos)
    # Basis conversion conjugates the rotation; identity remains identity.
    obj.rotation_euler = (0,0,0)
    obj['purpose'] = CONFIG['anchor_purposes'][name]
    anchors[name] = {'position': pos, 'rotation_xyzw': [0,0,0,1],
                     'scale': [1,1,1], 'purpose': CONFIG['anchor_purposes'][name]}
for obj in bpy.context.scene.objects:
    obj.select_set(obj.type in {'MESH','EMPTY'} and (obj in meshes or obj.name in anchors))
for im in bpy.data.images:
    if im.type == 'IMAGE':
        im.pack()
bpy.ops.export_scene.gltf(filepath=str(OUT), export_format='GLB',
    use_selection=True, export_yup=True, export_animations=False,
    export_extras=True, export_image_format='AUTO', export_materials='EXPORT')
lo = [min(p[i] for p in points) for i in range(3)]
hi = [max(p[i] for p in points) for i in range(3)]
asset = {
    'name': 'ODATETSU O7 V + 70–200mm O II',
    'scope': 'flutterkaigi2026 only; do not merge into main',
    'file': OUT.name, 'sha256': hashlib.sha256(OUT.read_bytes()).hexdigest(),
    'units': 'metres', 'axes': {'up': '+Y', 'lens_optical_axis': '+Z', 'hand_grip': '-X'},
    'bounds': {'min': lo, 'max': hi, 'size': [hi[i]-lo[i] for i in range(3)]},
    'anchors': anchors,
    'reference_dimensions_metres': {'body_width': .1303, 'body_height': .0964,
        'body_depth': .0824, 'lens_diameter': .088, 'lens_length_without_hood': .200,
        'hood_length_approximate': .070},
    'dimension_note': 'Body uniformly scaled to 130.3 mm width. Lens locally lengthened and widened to reference proportions; approximate generated geometry, not CAD tolerances.',
    'source': {'path': CONFIG['source'], 'sha256': CONFIG['source_sha256']},
    'shape_policy': 'Body uniformly scaled. Lens radial/axial proportions corrected; original faces and UVs retained. Exact text labels are separate thin meshes.',
    'lens_proportion_correction': CONFIG.get('lens_proportion_correction'),
    'focus_ring': CONFIG.get('focus_ring'),
    'labels': label_report,
    'source_mesh_counts': before, 'material_changes': material_changes,
    'text_policy': {'SONY': 'ODATETSU', 'alpha7_V': 'O7 V', 'G_Master': 'O'},
    'strap': 'Separate accessory; not included in the camera GLB',
}
(HERE / 'asset.json').write_text(json.dumps(asset, ensure_ascii=False, indent=2) + '\n')
bpy.ops.wm.save_as_mainfile(filepath=str(HERE / 'odatetsu_camera.blend'))
print('ODATETSU_CAMERA_BUILT ' + asset['sha256'], flush=True)
