"""Separate sleeves and forearms from the torso by surface distance.

The source mesh has UV seams and one detached forearm. Position welding is used
only to build an analysis graph: the original mesh, topology and UVs are never
changed. Sleeve-cuff seeds bridge the *distance field*, not the mesh, across the
small source openings between skin and cloth. Return one arm/torso blend per
original vertex, suitable for build.py before joint-weight smoothing.
"""
import heapq
import math


def _smooth(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


def arm_surface_masks(mesh_data, arm_path):
    """Return ``(mix_by_vertex, report)`` for this calibrated neutral pose.

    ``arm_path`` is landmarks.json's left-arm path. Zero means core weights;
    one means that side's shoulder/arm/forearm/hand weights. A broad *spatial*
    X transition would stretch the medial forearm when waving. Here the field
    follows the actual surface, with partial binding confined to the arm root.
    """
    points = [tuple(v.co) for v in mesh_data.vertices]
    groups = {}
    for i, p in enumerate(points):
        groups.setdefault(tuple(round(c, 5) for c in p), []).append(i)
    buckets = list(groups.values())
    positions = [points[ids[0]] for ids in buckets]
    index = {i: n for n, ids in enumerate(buckets) for i in ids}
    neighbors = [set() for _ in positions]
    for edge in mesh_data.edges:
        a, b = (index[i] for i in edge.vertices)
        if a != b:
            neighbors[a].add(b)
            neighbors[b].add(a)
    adjacency = [[(j, math.dist(p, positions[j])) for j in neighbors[i]]
                 for i, p in enumerate(positions)]

    def distance(seeds):
        values = [math.inf] * len(positions)
        queue = []
        for i, cost in seeds:
            if cost < values[i]:
                values[i] = cost
                heapq.heappush(queue, (cost, i))
        while queue:
            value, i = heapq.heappop(queue)
            if value != values[i]:
                continue
            for j, length in adjacency[i]:
                candidate = value + length
                if candidate < values[j]:
                    values[j] = candidate
                    heapq.heappush(queue, (candidate, j))
        return values

    torso_seeds = [(i, 0.0) for i, (x, y, z) in enumerate(positions)
                   if abs(x) < .065 and .90 < z < 1.36]
    torso = distance(torso_seeds)
    result = [0.0] * len(points)
    report = {'method': 'UV-position-welded surface distance',
              'graph_vertices': len(positions), 'torso_seeds': len(torso_seeds),
              'geometry_changed': False, 'sides': {}}
    for side, sign in [('Left', 1), ('Right', -1)]:
        wrist = tuple(sign * v if a == 0 else v
                      for a, v in enumerate(arm_path[3]))
        # The skin wrist and lower sleeve both define distance from this wrist.
        # This also covers the detached left forearm without reconnecting it.
        seeds = [(i, math.dist(p, wrist)) for i, p in enumerate(positions)
                 if ((.89 < p[2] < .965 and sign * p[0] > .29)
                     or (1.025 < p[2] < 1.10 and sign * p[0] > .265))]
        arm = distance(seeds)
        full = partial = protected_core = 0
        for node, p in enumerate(positions):
            x, y, z = p
            ax = sign * x
            if ax <= .10 or not .69 < z < 1.425:
                continue
            if not math.isfinite(arm[node]):
                mix = 0.0
            elif not math.isfinite(torso[node]):
                mix = 1.0
            else:
                # At/below the elbow the connected sleeve is exclusively arm;
                # around the shoulder its medial surface blends into the core.
                boundary = -.205 - .13 * _smooth(1.18, 1.32, z)
                mix = _smooth(boundary - .055, boundary + .055,
                              torso[node] - arm[node])
            mix *= 1.0 - _smooth(1.345, 1.425, z)
            # The collar and hood must follow Spine2, even at the outer edge.
            mix *= _smooth(.10, .155, ax)
            for i in buckets[node]:
                result[i] = mix
            full += mix > .999999
            partial += 0.000001 < mix < .999999
            protected_core += mix < .000001 and ax > .14 and .94 < z < 1.19
        report['sides'][side] = {'arm_seeds': len(seeds),
                                 'full_arm_nodes': full,
                                 'root_transition_nodes': partial,
                                 'protected_lower_torso_nodes': protected_core}
    return result, report
