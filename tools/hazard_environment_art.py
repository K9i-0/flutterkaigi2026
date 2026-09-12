"""Offline art pass for the three Hazard environments.

Large colour masses, architectural trim and ground dressing are baked into the
existing opaque meshes. This never authors colliders, moves a house, obstructs
a window/door or changes the seeded gameplay generator. Roof additions retain
the Roof_<id> node, so the game's existing indoor roof hiding still works.
"""
import math
import random


PATHS = {
    'village': [([(0, -25), (0, -12), (0, 1), (6, 12), (11.5, 24)], 2.3),
                ([(-8, -17.6), (-7, -20), (0, -20)], 1.1),
                ([(-11, -2.6), (-6, -4), (0, -4), (8, -10.6)], 1.25),
                ([(-4, 7.5), (-3, 4), (5, 2), (14, 2.5)], 1.25)],
    'farm': [([(-19, -25), (-19, -18), (-12, -19), (0, -18), (16, -18), (20, -10)], 1.9),
             ([(-12, -19), (-10, -9), (-9, 1), (-9, 14.5)], 1.3),
             ([(-9, 0), (0, 1), (8, 2), (12, 10)], 1.4),
             ([(8, -14), (8, -17), (14, -17)], 1.2)],
    'mountain': [([(-19, -24), (-19, -5), (-19, 4), (-6, 4), (1, 4), (9, 7), (13, 9.5)], 1.65)],
}


def _segment_distance(x, z, a, b):
    dx, dz = b[0] - a[0], b[1] - a[1]
    t = max(0, min(1, ((x - a[0]) * dx + (z - a[1]) * dz) / (dx * dx + dz * dz)))
    return math.hypot(x - a[0] - t * dx, z - a[1] - t * dz)


def _path_weight(region, x, z):
    return max(math.exp(-(_segment_distance(x, z, a, b) / width) ** 4)
               for points, width in PATHS[region] for a, b in zip(points, points[1:]))


def _house_distance(h, x, z):
    return math.hypot(max(0, abs(x - h['x']) - h['w'] / 2 - .22),
                      max(0, abs(z - h['z']) - h['d'] / 2 - .22))


def _ground(api):
    # Replace only the visible top of the original ground box. Identical height
    # and bounds preserve floor/collision agreement. A 1.5m grid lets broad
    # vertex colours describe worn paths without decal overdraw or texture RAM.
    data = api['groups']['Ground'][api['dirt']]
    top_index = max(range(len(data['f'])),
                    key=lambda i: sum(data['v'][v][2] for v in data['f'][i]) / len(data['f'][i]))
    top = [data['v'][i] for i in data['f'].pop(top_index)]
    data['uv'].pop(top_index)
    x0, x1 = min(v[0] for v in top), max(v[0] for v in top)
    z0, z1 = min(v[1] for v in top), max(v[1] for v in top)
    y = max(v[2] for v in top)
    nx, nz = math.ceil((x1 - x0) / 1.5), math.ceil((z1 - z0) / 1.5)
    for i in range(nx):
        for j in range(nz):
            xa, xb = x0 + (x1 - x0) * i / nx, x0 + (x1 - x0) * (i + 1) / nx
            za, zb = z0 + (z1 - z0) * j / nz, z0 + (z1 - z0) * (j + 1) / nz
            api['face']('Ground', api['dirt'], [(xa, za, y), (xb, za, y), (xb, zb, y), (xa, zb, y)],
                        [(xa, za), (xb, za), (xb, zb), (xa, zb)])


def _facade_panel(api, group, h, side):
    # Render-only plaster insets sit behind the existing window frames. Every
    # actual doorway/vault aperture is cut out, including the stealth exits.
    x, z, w, d = (h[k] for k in ['x', 'z', 'w', 'd'])
    holes = []
    if side < 0 or h.get('rearDoor'):
        holes.append((-1.02, 1.02, 0, 2.36))
    for offset in [-w * .29, w * .29]:
        half = .86 if side < 0 and offset < 0 and w >= 7 else .71
        holes.append((offset - half, offset + half, .72, 2.50))
    xs = sorted({-w / 2 + .12, w / 2 - .12, *[v for hole in holes for v in hole[:2]]})
    ys = [.42, .72, 2.36, 2.50, h['height'] - .30]
    ys = sorted({v for v in ys if .42 <= v <= h['height'] - .30})
    # Only the ground floor: upper-storey plaster and windows already exist.
    ys = sorted({min(v, 2.79) for v in ys})
    for xa, xb in zip(xs, xs[1:]):
        if xa < -w / 2 + .12 or xb > w / 2 - .12:
            continue
        for ya, yb in zip(ys, ys[1:]):
            mx, my = (xa + xb) / 2, (ya + yb) / 2
            if any(lo < mx < hi and low < my < high for lo, hi, low, high in holes):
                continue
            zz = z + side * (d / 2 + .184)
            vs = [(x + xa, zz, ya), (x + xb, zz, ya), (x + xb, zz, yb), (x + xa, zz, yb)]
            if side > 0:
                vs.reverse()
            api['face'](group, api['plaster'], vs, [(v[0], v[2]) for v in vs])


def _architecture(api):
    box, face = api['box'], api['face']
    wood, boards, roof, stone = (api[k] for k in ['wood', 'boards', 'roof', 'stone'])
    for h in api['houses']:
        x, z, w, d, height = (h[k] for k in ['x', 'z', 'w', 'd', 'height'])
        g, rg = 'House_' + h['id'], 'Roof_' + h['id']
        for side in [-1, 1]:
            _facade_panel(api, g, h, side)
            # Stacked timber fascia defines the roof silhouette at game distance.
            box(rg, wood, (x + side * (w / 2 + .32), z, height - .075), (.16, d + .96, .23))
            box(rg, roof, (x + side * (w / 2 + .34), z, height + .045), (.25, d + 1.0, .12))
            # Lower timber courses flank the usable door and do not cover it.
            for end in [-1, 1]:
                width = w / 2 - 1.05
                for yy in [.44, 2.64]:
                    box(g, wood, (x + end * (w / 4 + .525), z + side * (d / 2 + .225), yy),
                        (width, .09, .105))
            # On the sides, low horizontal boarding breaks the repetitive stone.
            for yy in [.49, .67, .85, 1.03]:
                box(g, boards, (x + side * (w / 2 + .198), z, yy), (.035, d - .3, .165))
            for zz in [z - d / 2 + .20, z, z + d / 2 - .20]:
                box(g, wood, (x + side * (w / 2 + .235), zz, 1.52), (.12, .115, 2.43))
            # Roofline rafters are batched into the existing roof's wood material.
            for i in range(max(3, round(d / .85)) + 1):
                zz = z - d / 2 + i * d / max(3, round(d / .85))
                box(rg, wood, (x + side * (w / 2 + .12), zz, height - .19), (.70, .11, .14))
        # Existing windows receive slender muntins, adding highlights and shadow
        # contrast to the former opaque teal rectangles. Open vaults stay open.
        for side in [-1, 1]:
            for wi, wx in enumerate([x - w * .29, x + w * .29]):
                window_scale = .64 if w < 4.8 else 1.
                if w < 4.8:
                    wx = x + (-1 if wi == 0 else 1) * (w / 2 - .68)
                for wy in [1.55] + ([4.25] if h['two'] else []):
                    if side < 0 and wi == 0 and w >= 7 and wy < 2:
                        continue
                    if side > 0 and h.get('rearDoor') and h['id'] == 'Tools' and wi == 0 and wy < 2:
                        continue
                    for dx in [-.39, -.195, .195, .39]:
                        box(g, wood, (wx + dx * window_scale, z + side * (d / 2 + .363), wy), (.032, .035, 1.23))
        # A single narrow worn stone threshold cues the entrance; it stays below
        # 3cm and is within the existing door sill, not a new navigation obstacle.
        for side in [-1, 1]:
            if side > 0 and not h.get('rearDoor'):
                continue
            box(g, stone, (x, z + side * (d / 2 + .13), -.004), (1.72, .36, .028))


def _ground_dressing(region, api):
    rng = random.Random(83011 + ['village', 'farm', 'mountain'].index(region))
    face, stone, leaf = api['face'], api['stone'], api['leaf']
    # Two folded kite leaves replace the upright triangular fans. Narrow tips
    # and a crease read as foliage in the native renderer, with sparse spacing
    # keeping the total geometry below the original triangle-fan budget.
    for h in api['houses']:
        g = 'House_' + h['id']
        for side in [-1, 1]:
            for k in range(max(2, int(h['d'] * .82))):
                xx = h['x'] + side * (h['w'] / 2 + rng.uniform(.28, .6))
                zz = h['z'] - h['d'] / 2 + .6 + rng.random() * (h['d'] - 1.2)
                if _path_weight(region, xx, zz) > .72:
                    continue
                for j in range(2):
                    angle = j * 2.3 + rng.random() * 1.1
                    length, width = rng.uniform(.15, .29), rng.uniform(.025, .049)
                    height = rng.uniform(.085, .17)
                    dx, dz = math.cos(angle), math.sin(angle)
                    root = (xx, zz, .012)
                    tip = (xx + dx * length, zz + dz * length, height * .8)
                    left = (xx + dx * length * .43 - dz * width,
                            zz + dz * length * .43 + dx * width, height * .68)
                    right = (xx + dx * length * .43 + dz * width,
                             zz + dz * length * .43 - dx * width, height * .43)
                    face(g, leaf, [root, left, tip], [(0, 0), (0, .5), (.5, 1)])
                    face(g, leaf, [root, tip, right], [(0, 0), (.5, 1), (1, .5)])
        # Foundations get a few chipped stones within 14cm of the existing wall,
        # too small to imply usable cover and too low to obstruct a window.
        for side in [-1, 1]:
            for k in range(max(2, int(h['d'] / 1.7))):
                xx = h['x'] + side * (h['w'] / 2 + .20)
                zz = h['z'] - h['d'] / 2 + .5 + rng.random() * (h['d'] - 1)
                width, high = rng.uniform(.12, .27), rng.uniform(.065, .14)
                corners = [(xx - .075, zz - width, .014), (xx + .075, zz - width * .6, .018),
                           (xx + .095, zz + width, .016), (xx - .06, zz + width * .62, .014)]
                peak = (xx + rng.uniform(-.03, .04), zz + width * .11, high)
                # Three visible facets; the fourth lies within the foundation.
                for a, b in [(0, 1), (1, 2), (2, 3)]:
                    face(g, stone, [corners[a], corners[b], peak], [(0, 0), (.24, 0), (.12, .2)])


def _village_ridges(api):
    # The former repeated stone columns made a conspicuous artificial skyline.
    # A continuous low-poly bank lies outside the existing perimeter collider.
    # Keep the same Cliffs node and opaque stone material, so no new draw is
    # needed and the accessible map boundary/camera collision stays identical.
    api['groups'].pop('Cliffs', None)

    def height(x, z):
        outward = max(0, abs(x) - 23.65)
        rise = min(1, outward / 7)
        ridge = 6.5 + 1.6 * math.sin(z * .14 + abs(x) * .10) + .9 * math.cos(z * .33)
        return 1.8 + rise * ridge + .8 * math.sin(outward * .21)

    xs = [23.65, 25.2, 27.7, 31.5, 37.5, 45]
    zs = list(range(-33, 40, 4))
    for side in [-1, 1]:
        for xa, xb in zip(xs, xs[1:]):
            for za, zb in zip(zs, zs[1:]):
                vs = [(side * x, z, height(side * x, z))
                      for x, z in [(xa, za), (xb, za), (xb, zb), (xa, zb)]]
                if side < 0:
                    vs.reverse()
                api['face']('Cliffs', api['stone'], vs, [(v[0], v[1]) for v in vs])
    # A distant northern ridge closes the old empty horizon over the farm gate.
    # Broad geometry supplies the silhouette; distance fog supplies separation.
    # It joins Cliffs, with no extra material or runtime terrain subdivision.
    def distant_height(x, z):
        rise = min(1, max(0, (z - 31) / 27))
        peaks = 16 + 13 * math.exp(-((x + 12) / 17) ** 2) + 8 * math.exp(-((x - 34) / 12) ** 2)
        return .2 + rise * (peaks + 2.1 * math.sin(x * .22 + z * .11))

    for x in range(-64, 64, 8):
        for z in [31, 39, 49, 61, 77]:
            next_z = {31: 39, 39: 49, 49: 61, 61: 77, 77: 93}[z]
            vs = [(xx, zz, distant_height(xx, zz))
                  for xx, zz in [(x, z), (x + 8, z), (x + 8, next_z), (x, next_z)]]
            api['face']('Cliffs', api['stone'], vs, [(v[0], v[1]) for v in vs])
    # Sparse existing pine cards are reused on one far mesh; the very small
    # screen area limits alpha cost and avoids dozens of tiny culling nodes.
    for row in range(4):
        for i in range(30):
            x, z = -53 + i * 3.65 + 1.7 * (row % 2), 42 + row * 10 + 3 * math.sin(i * 1.9 + row)
            base, tree_height = distant_height(x, z), 4.8 + ((i + row) * 7 % 5) * .7
            width = tree_height * .67
            for angle in [0, math.pi / 2]:
                dx, dz = math.cos(angle) * width / 2, math.sin(angle) * width / 2
                api['face']('FarForest', api['pine'],
                            [(x - dx, z - dz, base - .08), (x + dx, z + dz, base - .08),
                             (x + dx, z + dz, base + tree_height), (x - dx, z - dz, base + tree_height)],
                            [(0, 0), (1, 0), (1, 1), (0, 1)])
    # Existing inaccessible alpha-card trees keep their count and width; only
    # their base follows the new ridge, so the bank does not bury their trunks.
    for name, parts in api['groups'].items():
        if not name.startswith('PinePatch_'):
            continue
        for data in parts.values():
            for indices in data['f']:
                center_x = sum(data['v'][i][0] for i in indices) / len(indices)
                center_z = sum(data['v'][i][1] for i in indices) / len(indices)
                if abs(center_x) <= 23.65 or not -33 <= center_z <= 39:
                    continue
                shift = height(center_x, center_z)
                for i in indices:
                    x, z, y = data['v'][i]
                    data['v'][i] = (x, z, y + shift)


def polish_environment(region, api):
    _ground(api)
    _architecture(api)
    _ground_dressing(region, api)
    if region == 'village':
        _village_ridges(api)
    houses = api['houses']

    def tint(group, material, v, normal):
        x, z, y = v
        color = [1., 1., 1.]
        if material == api['dirt']:
            path = _path_weight(region, x, z)
            broad = .5 + .27 * math.sin(x * .23 + z * .15) + .23 * math.cos(z * .32 - x * .13)
            # Muted moss at the margins; warm packed earth on readable routes.
            margin = (.53 + broad * .17, .66 + broad * .17, .54 + broad * .13)
            road = (.97, .93, .86)
            color = [margin[i] * (1 - path) + road[i] * path for i in range(3)]
            if group == 'Ground':
                distance = min((_house_distance(h, x, z) for h in houses), default=20)
                contact = .70 + .30 * min(1, distance / 1.10)
                color = [c * contact for c in color]
        elif group.startswith(('House_', 'Roof_')):
            h = next((h for h in houses if group.endswith('_' + h['id'])), None)
            if material == api['stone']:
                color = [.75, .79, .77]
            elif material == api['plaster']:
                color = [.91, .96, .98]
            elif material == api['wood']:
                color = [.65, .67, .66]
            elif material == api['boards']:
                color = [.76, .77, .73]
            elif material == api['glass']:
                color = [.53, .64, .68]
            elif material == api['roof']:
                color = [.60, .77, .89]
            if h and material not in [api['glass'], api['amber'], api['metal']]:
                # Broad baked shade under eaves and at the foundation, replacing
                # costly all-scene GI with static architectural depth cues.
                base = .70 + .30 * min(1, max(0, y) / .80)
                eave = 1 - .21 * max(0, 1 - abs(y - (h['height'] - .2)) / .65)
                face_shade = .97 if abs(normal[2]) > .8 else .92
                color = [c * base * eave * face_shade for c in color]
        elif group == 'Cliffs':
            # Forest-floor colour is baked into the broad bank, preventing its
            # reused rock grain from reading as an enormous pale quarry.
            mass = .92 + .08 * math.sin(x * .26 + z * .16)
            color = [.29 * mass, .39 * mass, .36 * mass]
        elif material == api['stone']:
            color = [.74, .80, .79]
        if material == api['leaf']:
            variation = .78 + .16 * math.sin(x * 1.7 + z * 2.3)
            root_shade = .65 + .35 * min(1, max(0, y) / .14)
            color = [.42 * variation * root_shade, .33 * variation * root_shade,
                     .19 * variation * root_shade]
        return (*color, 1.)

    return tint
