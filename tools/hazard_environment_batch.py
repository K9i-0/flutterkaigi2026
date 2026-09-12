"""Lossless offline batching of the static Hazard house bodies.

Only House_ objects enter this pass, after each source house has received its
own UVs and colour bake. Roofs, doors, gates, collectibles and forest patches
retain their independent visibility nodes. No vertices are welded or reduced.
"""
import hashlib
import json
import struct

import bpy


def _payload(objects):
    faces = []
    counts = {'vertices': 0, 'polygons': 0, 'corners': 0,
              'uvValues': 0, 'colorValues': 0}
    for obj in objects:
        mesh = obj.data
        uv = mesh.uv_layers.active.data
        colors = mesh.color_attributes['EnvironmentTint'].data
        counts['vertices'] += len(mesh.vertices)
        counts['polygons'] += len(mesh.polygons)
        counts['corners'] += len(mesh.loops)
        counts['uvValues'] += len(uv)
        counts['colorValues'] += len(colors)
        for polygon in mesh.polygons:
            digest = hashlib.sha256()
            digest.update(mesh.materials[polygon.material_index].name.encode())
            digest.update(struct.pack('<I?', len(polygon.loop_indices), polygon.use_smooth))
            for li in polygon.loop_indices:
                position = obj.matrix_world @ mesh.vertices[mesh.loops[li].vertex_index].co
                normal = obj.matrix_world.to_3x3() @ polygon.normal
                digest.update(struct.pack('<12f', *position, *normal, *uv[li].uv, *colors[li].color))
            faces.append(digest.digest())
    counts['facePayloadSha256'] = hashlib.sha256(b''.join(sorted(faces))).hexdigest()
    return counts


def batch_static_architecture(objects):
    house_objects = [obj for obj in objects if obj.name.startswith('House_')]
    if not house_objects:
        return objects
    before = _payload(house_objects)
    source_names = [obj.name for obj in house_objects]
    before_primitives = sum(len({p.material_index for p in obj.data.polygons}) for obj in house_objects)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in house_objects:
        obj.select_set(True)
    merged = house_objects[0]
    bpy.context.view_layer.objects.active = merged
    if len(house_objects) > 1:
        bpy.ops.object.join()
    merged.name = 'StaticArchitecture'
    merged.data.name = 'StaticArchitecture'
    after = _payload([merged])
    assert before == after, ('Architecture batching changed the geometry/UV/colour payload', before, after)
    after_primitives = len({p.material_index for p in merged.data.polygons})
    report = {'sourceHouseNodes': source_names, 'before': before, 'after': after,
              'primitiveCountBefore': before_primitives,
              'primitiveCountAfter': after_primitives,
              'primitiveReduction': before_primitives - after_primitives,
              'payloadPreserved': True}
    # glTF extras are audit evidence only; rendering does not consume them.
    merged['hazardArchitectureBatch'] = json.dumps(report, sort_keys=True)
    print('ARCHITECTURE_BATCH', json.dumps(report, sort_keys=True))
    return [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
