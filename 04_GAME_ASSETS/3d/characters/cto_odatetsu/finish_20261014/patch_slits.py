"""Close the 16 audited clothing slits without moving source vertices or UVs.

Only the explicit four-edge boundary loops in clothing_slits.json are eligible.
Neck, cuffs, eyes, hair, shoe collars and laces are intentionally not processed.
Run inside Blender; import patch_clothing_slits(mesh) from the finishing script.
"""
import json
from collections import Counter
from pathlib import Path

import bmesh
import bpy
import numpy as np


def _arrays(mesh):
    positions = np.empty(len(mesh.vertices) * 3, dtype=np.float32)
    mesh.vertices.foreach_get("co", positions)
    loop_vertices = np.empty(len(mesh.loops), dtype=np.int32)
    mesh.loops.foreach_get("vertex_index", loop_vertices)
    uv = {}
    for layer in mesh.uv_layers:
        values = np.empty(len(layer.data) * 2, dtype=np.float32)
        layer.data.foreach_get("uv", values)
        uv[layer.name] = values
    return positions, loop_vertices, uv


def _edge_counts(bm):
    return {
        "boundary_edges": sum(len(e.link_faces) == 1 for e in bm.edges),
        "multi_face_edges": sum(len(e.link_faces) > 2 for e in bm.edges),
        "wire_edges": sum(len(e.link_faces) == 0 for e in bm.edges),
    }


def patch_clothing_slits(mesh):
    """Add 16 local quads; preserve all existing vertices, loops and UV values.

    New corners inherit UVs from their longest adjacent boundary edge's face.
    This favors the long sides of the narrow slit and never averages separate
    atlas islands. Existing corner attributes and topology remain untouched.
    """
    spec = json.loads(Path(__file__).with_name("clothing_slits.json").read_text())
    if len(mesh.vertices) != spec["source_vertices"] or len(mesh.polygons) != spec["source_faces"]:
        raise ValueError("Clothing slit IDs require the unchanged normalized source topology")
    original = _arrays(mesh)
    # Packed custom normals are encoded relative to a topology-derived basis;
    # simply retaining their bytes is insufficient when a boundary is closed.
    original_normals = np.array([tuple(n.vector) for n in mesh.corner_normals], dtype=np.float32)
    old_face_count = len(mesh.polygons)
    original_face_vertices = [tuple(p.vertices) for p in mesh.polygons]
    bm = bmesh.new()
    candidate = None
    try:
        bm.from_mesh(mesh)
        bm.verts.ensure_lookup_table()
        bm.edges.ensure_lookup_table()
        bm.faces.ensure_lookup_table()
        before = _edge_counts(bm)
        uv_layers = list(bm.loops.layers.uv.values())
        prepared = []

        # Validate every target before adding any face.
        for item in spec["loops"]:
            ids = item["vertices"]
            if len(ids) != 4 or len(set(ids)) != 4:
                raise ValueError(f"Invalid slit whitelist entry: {ids}")
            verts = [bm.verts[i] for i in ids]
            selected = set(verts)
            edges = {e for v in verts for e in v.link_edges if e.is_boundary and set(e.verts) <= selected}
            if len(edges) != 4 or any(sum(v in e.verts for e in edges) != 2 for v in verts):
                raise ValueError(f"Whitelisted vertices no longer form one four-edge boundary: {ids}")
            # Build a cycle opposite to each adjacent face's shared-edge winding.
            following = {}
            for edge in edges:
                face = edge.link_faces[0]
                loop = next(loop for loop in face.loops if loop.edge == edge)
                a, b = loop.vert, loop.link_loop_next.vert
                if b in following:
                    raise ValueError(f"Inconsistent neighboring face orientation: {ids}")
                following[b] = a
            ordered = [verts[0]]
            for _ in range(3):
                ordered.append(following[ordered[-1]])
            if len(set(ordered)) != 4 or following[ordered[-1]] != ordered[0]:
                raise ValueError(f"Cannot orient audited slit from adjacent faces: {ids}")
            # These audited loops lie on trousers/torso, below the head and
            # away from cuffs/hands. The whitelist is the primary protection.
            if any(abs(v.co.x) > .25 or not .40 < v.co.z < 1.33 for v in ordered):
                raise ValueError(f"Slit location no longer matches clothing-only bounds: {ids}")
            corner_uvs = []
            for vertex in ordered:
                edge = max((e for e in edges if vertex in e.verts), key=lambda e: e.calc_length())
                face = edge.link_faces[0]
                neighbor = next(loop for loop in face.loops if loop.vert == vertex)
                corner_uvs.append([neighbor[layer].uv.copy() for layer in uv_layers])
            # Use dominant adjacent boundary length, not arbitrary face order.
            material_lengths = Counter()
            smooth_lengths = Counter()
            for edge in edges:
                face = edge.link_faces[0]
                material_lengths[face.material_index] += edge.calc_length()
                smooth_lengths[face.smooth] += edge.calc_length()
            prepared.append((ordered, corner_uvs, material_lengths.most_common(1)[0][0],
                             smooth_lengths.most_common(1)[0][0], ids))

        for ordered, corner_uvs, material_index, smooth, _ in prepared:
            face = bm.faces.new(ordered)
            face.material_index = material_index
            face.smooth = smooth
            for loop, values in zip(face.loops, corner_uvs):
                for layer, value in zip(uv_layers, values):
                    loop[layer].uv = value
        bm.normal_update()
        after = _edge_counts(bm)
        if after["boundary_edges"] != before["boundary_edges"] - 4 * len(prepared):
            raise AssertionError("Slit closure did not remove exactly the audited boundary edges")
        if any(after[k] != before[k] for k in ["multi_face_edges", "wire_edges"]):
            raise AssertionError("Slit closure introduced a nonmanifold junction or wire edge")

        # Validate a temporary mesh before writing back to the supplied mesh.
        candidate = bpy.data.meshes.new("CTO slit integrity check")
        bm.to_mesh(candidate)
        normals = np.array([tuple(n.vector) for n in candidate.corner_normals], dtype=np.float32)
        normals[:len(original_normals)] = original_normals
        candidate.normals_split_custom_set(normals)
        candidate_normals = np.array([tuple(n.vector) for n in candidate.corner_normals], dtype=np.float32)
        normal_error = float(np.max(np.abs(candidate_normals[:len(original_normals)] - original_normals)))
        if normal_error > 1e-3:
            raise AssertionError(f"Original corner normals changed beyond packing tolerance: {normal_error}")
        updated = _arrays(candidate)
        if not np.array_equal(original[0], updated[0]):
            raise AssertionError("Source vertex positions changed")
        if not np.array_equal(original[1], updated[1][:len(original[1])]):
            raise AssertionError("Source loop vertex indices changed")
        if [tuple(p.vertices) for p in candidate.polygons[:old_face_count]] != original_face_vertices:
            raise AssertionError("Source face winding or indices changed")
        if set(original[2]) != set(updated[2]) or any(
            not np.array_equal(values, updated[2][name][:len(values)])
            for name, values in original[2].items()
        ):
            raise AssertionError("Source UV coordinates changed")
        bm.to_mesh(mesh)
        mesh.normals_split_custom_set(normals)
        mesh.update()
        restored_normals = np.array([tuple(n.vector) for n in mesh.corner_normals], dtype=np.float32)
        normal_error = float(np.max(np.abs(restored_normals[:len(original_normals)] - original_normals)))
        if normal_error > 1e-3:
            raise AssertionError(f"Original corner normals changed beyond packing tolerance: {normal_error}")
        return {
            "patched_loops": len(prepared),
            "added_faces": len(mesh.polygons) - old_face_count,
            "added_vertices": 0,
            "source_vertex_positions_bitwise_equal": True,
            "source_loop_vertices_bitwise_equal": True,
            "source_uv_coordinates_bitwise_equal": True,
            "source_corner_normals_max_abs_error": normal_error,
            "new_uv_policy": "copy corner UV from longest adjacent boundary edge face; no cross-island averaging",
            "normal_policy": "opposite shared-edge winding to all adjacent faces",
            "before": before,
            "after": after,
        }
    finally:
        if candidate is not None:
            bpy.data.meshes.remove(candidate)
        bm.free()
