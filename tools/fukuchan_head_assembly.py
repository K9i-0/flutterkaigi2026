"""Fit the independently generated P2 head to Fukuchan's existing game rig.

Keeps the body UVs, weights, rest skeleton and all captured/authored clips.
The neck overlap is inside the jacket collar; the new head has its own UV map.
"""
import bpy
import bmesh
import hashlib
from pathlib import Path
from math import pi
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / '04_GAME_ASSETS/3d/characters/fukuchan/head_p2_20260906/raw/output_model_url.fbx'


def replace_head(body, rig):
    body.shape_key_clear()
    old_bvh = BVHTree.FromPolygons([v.co for v in body.data.vertices],
                                  [list(p.vertices) for p in body.data.polygons])
    before = set(bpy.context.scene.objects)
    fps, fps_base = bpy.context.scene.render.fps, bpy.context.scene.render.fps_base
    bpy.ops.import_scene.fbx(filepath=str(SOURCE))
    # FBX import changes scene FPS even for a static head. Preserve clip timing.
    bpy.context.scene.render.fps, bpy.context.scene.render.fps_base = fps, fps_base
    added = set(bpy.context.scene.objects) - before
    head = next(o for o in added if o.type == 'MESH')
    head.data.transform(Matrix.Rotation(-pi / 2, 4, 'Z') @ head.matrix_world)
    head.parent = None
    head.matrix_world = Matrix.Identity(4)
    points = [v.co.copy() for v in head.data.vertices]
    low = Vector(tuple(min(v[i] for v in points) for i in range(3)))
    high = Vector(tuple(max(v[i] for v in points) for i in range(3)))
    scale = .310 / (high.z - low.z)
    center = Vector(((low.x + high.x) / 2, (low.y + high.y) / 2, low.z))
    transform = Matrix.Translation((0, .002, 1.390)) @ Matrix.Scale(scale, 4) @ Matrix.Translation(-center)
    head.data.transform(transform)
    head.name = 'FukuchanHead'
    # Replace the exposed neck too; put the material boundary under the collar.
    # Preserve jacket triangles using their source albedo instead of a flat cut.
    color_image = next(n.image for n in body.data.materials[0].node_tree.nodes
                       if n.type == 'TEX_IMAGE' and n.image and
                       any(l.to_socket.name == 'Base Color' for l in n.outputs['Color'].links))
    pixels = list(color_image.pixels)
    width, height = color_image.size
    remove_faces = set()
    uv = body.data.uv_layers.active.data
    for polygon in body.data.polygons:
        coords = [body.data.vertices[i].co for i in polygon.vertices]
        if min(v.z for v in coords) > 1.455:
            remove_faces.add(polygon.index)
            continue
        if min(v.z for v in coords) < 1.375 or max(abs(v.x) for v in coords) > .11:
            continue
        center_uv = sum((uv[i].uv for i in polygon.loop_indices), Vector((0, 0))) / len(polygon.loop_indices)
        u, v = center_uv
        offset = ((int(v * height) % height) * width + int(u * width) % width) * 4
        r, g, b = pixels[offset:offset + 3]
        if r > g * 1.07 and r > b * 1.07 and r > .20:
            remove_faces.add(polygon.index)
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.faces[i] for i in remove_faces], context='FACES')
    bmesh.ops.bisect_plane(bm, geom=list(bm.verts) + list(bm.edges) + list(bm.faces),
                          plane_co=(0, 0, 1.455), plane_no=(0, 0, 1),
                          clear_outer=True, dist=1e-7)
    lining = bpy.data.materials.new('FukuchanJacketLining')
    lining.use_nodes = True
    lining.diffuse_color = (.009, .012, .020, 1)
    lining.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = lining.diffuse_color
    lining.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = .9
    material_index = len(body.data.materials)
    body.data.materials.append(lining)
    rim = [e for e in bm.edges if e.is_boundary and all(v.co.z > 1.375 for v in e.verts)]
    deform = bm.verts.layers.deform.verify()
    inside = {}
    for edge in rim:
        for vertex in edge.verts:
            if vertex not in inside:
                point = vertex.co.copy()
                point.x *= .90
                point.y = .002 + (point.y - .002) * .90
                point.z -= .016
                inner = bm.verts.new(point)
                for group, weight in vertex[deform].items():
                    inner[deform][group] = weight
                inside[vertex] = inner
        face = bm.faces.new((edge.verts[0], edge.verts[1], inside[edge.verts[1]], inside[edge.verts[0]]))
        face.material_index = material_index
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(body.data)
    bm.free()
    for vertex in head.data.vertices:
        z = vertex.co.z
        if z > 1.440:
            continue
        origin = Vector((0, .002, z))
        direction = Vector((vertex.co.x, vertex.co.y - .002, 0)).normalized()
        hit, _, _, _ = old_bvh.ray_cast(origin, direction, .3)
        if hit is not None:
            t = max(0., min(1., (1.440 - z) / .028))
            vertex.co = vertex.co.lerp(hit - direction * .001, t * t * (3 - 2 * t))
        if z < 1.410:
            vertex.co.z -= .015 * max(0., min(1., (1.410 - z) / .020))
    head.vertex_groups.clear()
    neck_group = head.vertex_groups.new(name='Neck')
    head_group = head.vertex_groups.new(name='Head')
    for vertex in head.data.vertices:
        t = max(0., min(1., (vertex.co.z - 1.400) / .047))
        t = t * t * (3 - 2 * t)
        head_group.add([vertex.index], t, 'REPLACE')
        neck_group.add([vertex.index], 1 - t, 'REPLACE')
    head.parent = rig
    head.matrix_parent_inverse = Matrix.Identity(4)
    modifier = head.modifiers.new('HeadSkin', 'ARMATURE')
    modifier.object = rig
    for polygon in head.data.polygons:
        polygon.use_smooth = True
    for material in head.data.materials:
        material.name = 'FukuchanHeadPBR'
        nodes = material.node_tree.nodes
        bsdf = next(n for n in nodes if n.type == 'BSDF_PRINCIPLED')
        for node in nodes:
            if node.type == 'TEX_IMAGE' and node.image:
                image = node.image
                # Keep the face albedo at 4K; 2K is sufficient for other PBR maps.
                is_color = any(link.to_node == bsdf and link.to_socket.name == 'Base Color'
                               for link in node.outputs['Color'].links)
                image.name = 'FukuchanHead_' + ('Color' if is_color else image.name.rsplit('_', 1)[-1])
                if not is_color:
                    image.scale(2048, 2048)
                image.pack()
    from fukuchan_head_speech import add_head_speech
    speech = add_head_speech(head)
    head.data.calc_loop_triangles()
    return head, {'source_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
                  'source_task': '5b707218-e8be-48ef-a9c4-e9c95d962d17',
                  'height_range': [1.375, 1.700], 'body_skin_removal_floor': 1.375,
                  'head_triangles': len(head.data.loop_triangles),
                  'speech_shapes': speech,
                  'source': 'P2 separate head; existing body skeleton and animations preserved'}
