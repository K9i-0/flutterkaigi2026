"""Remove raised ink trim from the normalized sheet FBX before speech morphs.

Original texture images stay unchanged. Vertex colors cover ink transferred to
the underlying head, sampling nearby clean skin in 3D without moving face UVs.
"""
import bpy
import bmesh
from mathutils import Vector
from mathutils.kdtree import KDTree


def remove_outlines(mesh):
    adjacency = [set() for _ in mesh.data.vertices]
    for edge in mesh.data.edges:
        a, b = edge.vertices
        adjacency[a].add(b)
        adjacency[b].add(a)
    remaining = set(range(len(adjacency)))
    parts = []
    while remaining:
        seed = remaining.pop()
        stack, part = [seed], {seed}
        while stack:
            for index in adjacency[stack.pop()]:
                if index in remaining:
                    remaining.remove(index)
                    stack.append(index)
                    part.add(index)
        parts.append(part)

    def find_parts(count, expected):
        found = [p for p in parts if len(p) == count]
        assert len(found) == expected, ('Unexpected sheet topology', count)
        return found

    head = find_parts(2518, 1)[0]
    jaw = find_parts(510, 1)[0]
    collar = find_parts(845, 1)[0]
    ears = set.union(*find_parts(212, 2))
    # Guard semantics too if a future source has coincident component counts.
    assert all(.50 < mesh.data.vertices[i].co.z < .84 for i in jaw)
    assert all(.39 < mesh.data.vertices[i].co.z < .57 for i in collar)
    assert all(abs(mesh.data.vertices[i].co.x) > .25 for i in ears)
    original = mesh.data.materials[0]
    image = next(n.image for n in original.node_tree.nodes
                 if n.type == 'TEX_IMAGE' and n.image and
                 any(link.to_socket.name == 'Base Color'
                     for link in n.outputs['Color'].links))
    pixels = list(image.pixels)
    width, height = image.size
    uv = mesh.data.uv_layers.active.data

    def sample(coord):
        u, v = coord
        x = min(width - 1, max(0, int(u * width)))
        y = min(height - 1, max(0, int(v * height)))
        start = (y * width + x) * 4
        return tuple(pixels[start:start + 3])

    def is_skin(color):
        r, g, b = color
        return r > .48 and g > .26 and r > g * 1.20 and g > b * 1.25

    def linear(color):
        return tuple(c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4 for c in color)

    samples, selected = [], []
    for polygon in mesh.data.polygons:
        if polygon.vertices[0] not in head:
            continue
        center = sum((mesh.data.vertices[i].co for i in polygon.vertices), Vector()) / len(polygon.vertices)
        center_uv = sum((uv[i].uv for i in polygon.loop_indices), Vector((0, 0))) / len(polygon.loop_indices)
        color = sample(center_uv)
        if center.z < .87 and is_skin(color):
            samples.append((center, color))
        if (-.21 < center.y < .025 and (center.z < .84 or is_skin(color))) or center.z < .59:
            selected.append(polygon)
    assert len(samples) > 100
    tree = KDTree(len(samples))
    for index, (position, _) in enumerate(samples):
        tree.insert(position, index)
    tree.balance()

    def nearby_skin(position):
        neighbors = tree.find_n(position, 8)
        weights = [1 / max(distance, .005) ** 2 for _, _, distance in neighbors]
        total = sum(weights)
        return tuple(sum(samples[index][1][axis] * weight
                         for (_, index, _), weight in zip(neighbors, weights)) / total
                     for axis in range(3))

    colors = mesh.data.color_attributes.new(name='YametaroSkinColor', type='FLOAT_COLOR', domain='CORNER')
    for entry in colors.data:
        entry.color = (1, 1, 1, 1)
    skin = original.copy()
    skin.name = 'YametaroSkinWithoutInk'
    shader = skin.node_tree.nodes.get('Principled BSDF')
    # The source normal map also contains a groove around the drawn contour.
    # Use the head's smooth mesh normals for this repaired skin surface.
    for socket in ['Base Color', 'Normal']:
        for link in list(shader.inputs[socket].links):
            skin.node_tree.links.remove(link)
    vertex_color = skin.node_tree.nodes.new('ShaderNodeVertexColor')
    vertex_color.layer_name = colors.name
    skin.node_tree.links.new(vertex_color.outputs['Color'], shader.inputs['Base Color'])
    mesh.data.materials.append(skin)
    skin_index = len(mesh.data.materials) - 1
    for polygon in mesh.data.polygons:
        if polygon.vertices[0] in ears:
            selected.append(polygon)
    for polygon in selected:
        polygon.material_index = skin_index
        for loop_index in polygon.loop_indices:
            point = mesh.data.vertices[mesh.data.loops[loop_index].vertex_index].co
            colors.data[loop_index].color = (*linear(nearby_skin(point)), 1)

    cloth = bpy.data.materials.new('YametaroLavenderTrim')
    cloth.use_nodes = True
    cloth.diffuse_color = (.30, .16, .55, 1)
    shader = cloth.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = cloth.diffuse_color
    shader.inputs['Roughness'].default_value = .8
    mesh.data.materials.append(cloth)
    for polygon in mesh.data.polygons:
        if polygon.vertices[0] in collar:
            polygon.material_index = len(mesh.data.materials) - 1

    removed_faces = sum(1 for p in mesh.data.polygons if p.vertices[0] in jaw)
    bm = bmesh.new()
    bm.from_mesh(mesh.data)
    bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.verts[i] for i in jaw], context='VERTS')
    bm.to_mesh(mesh.data)
    bm.free()
    mesh.data.update()
    return {'removedJawVertices': len(jaw), 'removedJawFaces': removed_faces,
            'skinFaces': len(selected), 'earVertices': len(ears),
            'collarVertices': len(collar), 'sourceTexturesUnchanged': True}
