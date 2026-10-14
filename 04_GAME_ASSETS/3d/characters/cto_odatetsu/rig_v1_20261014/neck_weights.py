"""Identify the hoodie independently of the nearby neck, face and hair.

In the approved static source, the hoodie is connected to the upper torso;
neck/face and hair are separate surface components. That structural boundary
is reliable even where the black cloth and dark hair are almost touching.
Position welding is an analysis operation only and never changes the mesh.
"""


def neck_surface_masks(mesh_data):
    """Return ``(hood_mask, hair_mask, report)`` for cloth and rigid hair.

    Use Spine2 instead of height-based neck/head *core* weights when hood_mask[i]
    is true, while preserving the existing arm/core mix at the shoulders.
    Give hair_mask vertices Head=1 before smoothing; leave face/neck skin on
    the existing continuous anatomical blend.
    Remove the old ``y > .065`` core clamp: anatomical skin then retains its
    smooth Spine2 -> Neck -> Head transition without crossing cloth weights.
    No colour threshold, texture modification, or surface reconnection occurs.
    """
    points = [tuple(v.co) for v in mesh_data.vertices]
    groups = {}
    for i, p in enumerate(points):
        groups.setdefault(tuple(round(c, 5) for c in p), []).append(i)
    buckets = list(groups.values())
    positions = [points[ids[0]] for ids in buckets]
    index = {i: node for node, ids in enumerate(buckets) for i in ids}
    adjacency = [set() for _ in positions]
    for edge in mesh_data.edges:
        a, b = (index[i] for i in edge.vertices)
        if a != b:
            adjacency[a].add(b)
            adjacency[b].add(a)
    seen = set()
    components = []
    for start in range(len(positions)):
        if start in seen:
            continue
        seen.add(start)
        stack = [start]
        nodes = []
        while stack:
            node = stack.pop()
            nodes.append(node)
            for neighbor in adjacency[node] - seen:
                seen.add(neighbor)
                stack.append(neighbor)
        components.append(nodes)

    # These central chest seeds cannot belong to neck, hair, hands, or legs.
    # The independent hood drawstrings also overlap this garment-only area.
    garment_nodes = set()
    garment_components = []
    for nodes in components:
        seeds = [node for node in nodes
                 if abs(positions[node][0]) < .065
                 and 1.08 < positions[node][2] < 1.27]
        if seeds:
            garment_nodes.update(nodes)
            garment_components.append({'nodes': len(nodes), 'seeds': len(seeds),
                                       'z_min': min(positions[n][2] for n in nodes),
                                       'z_max': max(positions[n][2] for n in nodes)})
    assert garment_nodes, 'No source upper-torso component found.'
    # Guard against a changed source that has welded the head onto the clothing.
    assert max(positions[n][2] for n in garment_nodes) < 1.48, (
        'Clothing now connects to the head; re-audit the component classifier.')
    hair_nodes = set()
    for nodes in components:
        if any(positions[n][2] > 1.70 for n in nodes):
            hair_nodes.update(nodes)
    assert hair_nodes and not hair_nodes.intersection(garment_nodes)
    assert min(positions[n][2] for n in hair_nodes) > 1.44, (
        'Hair now connects to the face/neck; re-audit the component classifier.')
    hair_mask = [False] * len(points)
    for node in hair_nodes:
        for i in buckets[node]:
            hair_mask[i] = True
    mask = [False] * len(points)
    selected = []
    for node in garment_nodes:
        if positions[node][2] >= 1.31:
            selected.append(node)
            for i in buckets[node]:
                mask[i] = True
    report = {'method': 'separate torso-garment and crown-hair surface components',
              'graph_vertices': len(positions),
              'surface_components': len(components),
              'garment_components': garment_components,
              'selected_position_nodes': len(selected),
              'selected_render_vertices': sum(mask),
              'selected_bounds_xyz': [[min(positions[n][a] for n in selected),
                                       max(positions[n][a] for n in selected)]
                                      for a in range(3)],
              'hair_position_nodes': len(hair_nodes),
              'rigid_hair_render_vertices': sum(hair_mask),
              'hair_below_old_head_cutoff_vertices': sum(
                  len(buckets[n]) for n in hair_nodes if positions[n][2] <= 1.465),
              'protected_face_neck_render_vertices': sum(
                  len(buckets[n]) for n, p in enumerate(positions)
                  if p[2] >= 1.356 and n not in garment_nodes and n not in hair_nodes),
              'garment_core_bone': 'Spine2',
              'shoulder_arm_mix_preserved': True,
              'geometry_uv_texture_unchanged': True}
    return mask, hair_mask, report
