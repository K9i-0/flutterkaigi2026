"""Lip seam and closed oral lining for the P2 replacement head.

An authored amplitude-driven jaw shape, not phoneme recognition or dental rig.
"""
import bpy
import bmesh
from math import exp
from mathutils import Matrix, Vector
from mathutils.geometry import barycentric_transform, closest_point_on_tri

MOUTH = 1.494
WIDTH = .031


def curve(x):
    return .0035 * min(1., (abs(x) / WIDTH) ** 2)


def add_head_speech(head):
    head.shape_key_clear()
    head.data.calc_loop_triangles()
    original_points = [v.co.copy() for v in head.data.vertices]
    original_triangles = [tuple(t.vertices) for t in head.data.loop_triangles]
    original_uv = [tuple(Vector((*head.data.uv_layers.active.data[i].uv, 0)) for i in t.loops)
                   for t in head.data.loop_triangles]
    triangle_faces = [t.polygon_index for t in head.data.loop_triangles]
    bm = bmesh.new()
    bm.from_mesh(head.data)
    original_face = bm.faces.layers.int.new('head_original_face')
    for face in bm.faces:
        face[original_face] = face.index
    for vertex in bm.verts:
        vertex.co.z -= curve(vertex.co.x)
    faces = [f for f in bm.faces if all(abs(v.co.x) < .06 and v.co.y < -.070 for v in f.verts)
             and min(v.co.z for v in f.verts) <= MOUTH <= max(v.co.z for v in f.verts)]
    geom = set(faces) | {e for f in faces for e in f.edges} | {v for f in faces for v in f.verts}
    cut = bmesh.ops.bisect_plane(bm, geom=list(geom), plane_co=(0, 0, MOUTH),
                                plane_no=(0, 0, 1), dist=1e-7)
    seam = [e for e in cut['geom_cut'] if isinstance(e, bmesh.types.BMEdge)
            and all(abs(v.co.x) < WIDTH and v.co.y < -.07 for v in e.verts)]
    assert len(seam) >= 2, 'Replacement head lip seam was not found'
    bmesh.ops.split_edges(bm, edges=seam)
    lower = bm.verts.layers.float.new('head_lower_lip')
    lining = bm.verts.layers.float.new('head_mouth_lining')
    for vertex in bm.verts:
        if abs(vertex.co.z - MOUTH) < 1e-6 and abs(vertex.co.x) < WIDTH and vertex.co.y < -.07:
            vertex[lower] = float(all(f.calc_center_median().z < MOUTH for f in vertex.link_faces))
    dark = bpy.data.materials.new('FukuchanOralLining')
    dark.use_nodes = True
    dark.diffuse_color = (.012, .002, .003, 1)
    dark.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = dark.diffuse_color
    dark.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = .9
    material = len(head.data.materials)
    head.data.materials.append(dark)
    boundary = [e for e in bm.edges if e.is_boundary and
                all(abs(v.co.z - MOUTH) < 1e-6 and abs(v.co.x) < WIDTH and v.co.y < -.07 for v in e.verts)]
    deform = bm.verts.layers.deform.verify()
    head_group = head.vertex_groups['Head'].index
    rear = {}
    # Each upper/lower lip edge goes inward to a shared rear edge. Unlike a flat
    # black ellipsoid, this lining cannot protrude through the curved cheeks.
    for edge in boundary:
        inside = []
        for vertex in edge.verts:
            key = tuple(round(c, 6) for c in vertex.co)
            if key not in rear:
                point = vertex.co.copy()
                point.y += .024
                point.z -= .003
                back = bm.verts.new(point)
                back[deform][head_group] = 1
                back[lining] = 1
                rear[key] = back
            inside.append(rear[key])
        face = bm.faces.new((edge.verts[0], edge.verts[1], inside[1], inside[0]))
        face.material_index = material
    for vertex in bm.verts:
        vertex.co.z += curve(vertex.co.x)
    uv_layer = bm.loops.layers.uv.active
    for face in bm.faces:
        if face.material_index != 0:
            continue
        if not any(abs(v.co.z - MOUTH) < .010 and abs(v.co.x) < .065 and v.co.y < -.07 for v in face.verts):
            continue
        # Reproject cut UVs onto the unmodified face surface. Bisect can leave
        # a narrow texture sliver on the adjacent nonplanar quad.
        for loop in face.loops:
            candidates = [i for i, parent in enumerate(triangle_faces) if parent == face[original_face]]
            if not candidates:
                continue
            index = min(candidates, key=lambda i: (closest_point_on_tri(loop.vert.co, *(original_points[j] for j in original_triangles[i])) - loop.vert.co).length_squared)
            a, b, c = (original_points[i] for i in original_triangles[index])
            point = closest_point_on_tri(loop.vert.co, a, b, c)
            ua, ub, uc = original_uv[index]
            mapped = barycentric_transform(point, a, b, c, ua, ub, uc)
            loop[uv_layer].uv = mapped.xy
    enamel = bpy.data.materials.new('FukuchanUpperTeeth')
    enamel.use_nodes = True
    enamel.diffuse_color = (.60, .55, .46, 1)
    enamel.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = enamel.diffuse_color
    enamel.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = .4
    tooth_material = len(head.data.materials)
    head.data.materials.append(enamel)
    lip_points = [v.co.copy() for e in boundary for v in e.verts]
    for x in [-.021, -.015, -.009, -.003, .003, .009, .015, .021]:
        nearest = min(lip_points, key=lambda p: abs(p.x - x))
        transform = Matrix.Translation((x, nearest.y + .008, MOUTH + curve(x) - .0015)) @ Matrix.Diagonal(Vector((.00285, .0025, .0032, 1)))
        teeth = bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=6, radius=1, matrix=transform)['verts']
        for vertex in teeth:
            vertex[deform][head_group] = 1
            vertex[lining] = 1
            for face in vertex.link_faces:
                face.material_index = tooth_material
                face.smooth = True
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(head.data)
    bm.free()
    # FBX custom loop normals no longer match the split topology. Recompute
    # them so the new lip cuts do not leave bright slivers on the cheeks.
    head.data.normals_split_custom_set([(0, 0, 0)] * len(head.data.loops))
    base = head.shape_key_add(name='Basis')
    opened = head.shape_key_add(name='SpeechOpen')
    narrow = head.shape_key_add(name='SpeechNarrow')
    lower = head.data.attributes['head_lower_lip'].data
    lining = head.data.attributes['head_mouth_lining'].data

    def smooth(a, b, value):
        t = max(0., min(1., (value - a) / (b - a)))
        return t * t * (3 - 2 * t)

    affected = 0
    for i, vertex in enumerate(base.data):
        if lining[i].value > .5:
            continue
        x, y, z = vertex.co
        seam_z = MOUTH + curve(x)
        below = z < seam_z - 1e-6 or (abs(z - seam_z) < 1e-6 and lower[i].value > .5)
        side = 1 - smooth(.010, WIDTH, abs(x))
        front = 1 - smooth(-.07, -.035, y)
        jaw = smooth(1.444, 1.472, z) if below else 0
        weight = side * front * jaw
        opened.data[i].co.z -= .009 * weight
        opened.data[i].co.y += .0015 * weight
        lip = exp(-((z - MOUTH) / .018) ** 2) * side * front
        narrow.data[i].co.x -= x * .14 * lip
        affected += weight > .001 or lip > .001
    opened.value = narrow.value = 0
    return {'targets': ['SpeechOpen', 'SpeechNarrow'], 'affectedVertices': affected,
            'mouthHeight': MOUTH, 'maximumJawDisplacement': .009,
            'source': 'authored split lip seam, inward oral lining and eight static upper teeth; not a phoneme rig'}
