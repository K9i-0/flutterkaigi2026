"""Local speech blend shapes preserving the accepted textured face at rest.

Coordinates are measured on the normalized canonical characters. These are
small surface deformations, not a dental reconstruction or phoneme rig.
"""
import math

import bpy
import bmesh
from mathutils import Matrix, Vector


def lip_curve(x):
    return .0035 * min(1, abs(x) / .030) ** 2


def prepare_fukuchan_mouth(mesh):
    """Separate the lower lip seam and put a dark oral backing behind it."""
    if mesh.get('speech_seam'):
        return
    mesh.shape_key_clear()
    bm = bmesh.new()
    bm.from_mesh(mesh.data)
    height = 1.501
    # Bisect a curved smile seam by temporarily flattening its coordinates.
    for v in bm.verts:
        v.co.z -= lip_curve(v.co.x)
    faces = [f for f in bm.faces if all(abs(v.co.x) < .065 and v.co.y < -.07
                                      for v in f.verts)
             and min(v.co.z for v in f.verts) <= height <= max(v.co.z for v in f.verts)]
    edges = set(e for f in faces for e in f.edges)
    verts = set(v for f in faces for v in f.verts)
    cut = bmesh.ops.bisect_plane(bm, geom=list(verts) + list(edges) + faces,
                                 plane_co=Vector((0, 0, height)),
                                 plane_no=Vector((0, 0, 1)), dist=1e-7)
    seam = [e for e in cut['geom_cut'] if isinstance(e, bmesh.types.BMEdge)
            and all(abs(v.co.x) < .040 and v.co.y < -.07 for v in e.verts)]
    assert len(seam) >= 2, 'No usable lower-lip seam'
    front_y = min(v.co.y for e in seam for v in e.verts)
    bmesh.ops.split_edges(bm, edges=seam)
    tag = bm.verts.layers.float.new('speech_lower_lip')
    for v in bm.verts:
        if abs(v.co.z - height) < 1e-6 and abs(v.co.x) < .040 and v.co.y < -.07:
            v[tag] = float(all(f.calc_center_median().z < height for f in v.link_faces))
    for v in bm.verts:
        v.co.z += lip_curve(v.co.x)
    dark = bpy.data.materials.new('MouthInterior')
    dark.diffuse_color = (.004, .001, .001, 1)
    dark.use_nodes = True
    dark.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = dark.diffuse_color
    dark.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = .85
    material = len(mesh.data.materials)
    mesh.data.materials.append(dark)
    cavity = bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=12, radius=1,
        matrix=Matrix.Translation((0, front_y + .055, height - .005)) @
        Matrix.Diagonal(Vector((.037, .009, .023, 1))))['verts']
    deform = bm.verts.layers.deform.verify()
    head = mesh.vertex_groups['Head'].index
    for v in cavity:
        v[deform][head] = 1
        for f in v.link_faces:
            f.material_index = material
            f.smooth = True
    bm.to_mesh(mesh.data)
    bm.free()
    mesh['speech_seam'] = True


def add_speech_shapes(mesh, character, landmarks=None):
    if character == 'fukuchan':
        prepare_fukuchan_mouth(mesh)
    mouth, half_width, lower, front, opening = landmarks or {
        'fukuchan': (1.507, .043, 1.451, -.07, .0075),
        'yametaro': (.684, .068, .585, -.12, .027),
    }[character]

    def smooth(a, b, v):
        t = max(0, min(1, (v - a) / (b - a)))
        return t * t * (3 - 2 * t)

    if mesh.data.shape_keys:
        for key in list(mesh.data.shape_keys.key_blocks)[1:]:
            if key.name.startswith('Speech'):
                mesh.shape_key_remove(key)
    else:
        mesh.shape_key_add(name='Basis')
    base = mesh.data.shape_keys.key_blocks[0]
    opened = mesh.shape_key_add(name='SpeechOpen')
    narrow = mesh.shape_key_add(name='SpeechNarrow')
    cavity_indices = {i for p in mesh.data.polygons
                      if mesh.data.materials[p.material_index].name.startswith('MouthInterior')
                      for i in p.vertices}
    affected = 0
    for i, vertex in enumerate(base.data):
        if i in cavity_indices:
            continue
        x, y, z = vertex.co
        side = 1 - smooth(half_width, half_width * 1.9, abs(x))
        face = 1 - smooth(front, front + .035, y)
        jaw = smooth(lower, mouth - .017, z) * (1 - smooth(mouth - .006, mouth + .004, z))
        if character == 'fukuchan':
            tag = mesh.data.attributes.get('speech_lower_lip')
            seam_z = 1.501 + lip_curve(x)
            below = z < seam_z - 1e-6 or (abs(z - seam_z) < 1e-6 and tag.data[i].value > .5)
            side = 1 - smooth(.008, .030, abs(x))
            jaw = smooth(lower, 1.480, z) if below else 0
        weight = side * face * jaw
        opened.data[i].co.z -= opening * weight
        opened.data[i].co.y += opening * .12 * weight
        lips = (math.exp(-((z - mouth) / (half_width * .55)) ** 2) * side * face
                * smooth(lower, lower + .015, z))
        narrow.data[i].co.x -= x * .16 * lips
        if weight > .001 or lips > .001:
            affected += 1
    opened.value = narrow.value = 0
    return {'targets': ['SpeechOpen', 'SpeechNarrow'], 'affectedVertices': affected,
            'maximumJawDisplacement': opening, 'mouthHeight': mouth,
            'source': 'authored localized surface deformation; neutral likeness unchanged'}
