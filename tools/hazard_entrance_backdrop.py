"""Inaccessible forest approach behind the village's south entrance.

All geometry stays beyond game Z=-25. Uses the existing packed earth/stone/
pine materials and a separate random source so gameplay assets are unchanged.
"""
import math
import random

from hazard_environment_kit import backdrop_pine, boards, box, dirt, face, stone, wood


def entrance_height(x, z):
    depth = max(0, -z - 26)
    rise = min(1, depth / 12)
    road = math.exp(-((x - math.sin(depth * .08) * 2) / 4.8) ** 2)
    bank = 2.6 + 1.2 * math.sin(x * .19 + z * .13) + .6 * math.cos(z * .43)
    ridge = 8 * math.exp(-((depth - 41) / 11) ** 2)
    return -.22 + rise * (bank * (1 - road) + ridge)


def build_entrance_backdrop():
    # A continuous heightfield covers the old rectangular floor edge. The
    # winding depression reads as the road the player arrived along.
    for x in range(-48, 48, 4):
        for z in range(-74, -26, 4):
            vertices = [(xx, zz, entrance_height(xx, zz))
                        for xx, zz in [(x, z), (x + 4, z), (x + 4, z + 4), (x, z + 4)]]
            face(f'ApproachTerrain_{x // 32}_{z // 24}', dirt, vertices,
                 [(xx, zz) for xx, zz, _ in vertices])

    random_source = random.Random(4919)
    for side in [-1, 1]:
        # A few near trees frame the entrance. More distant rows break the
        # ridge line; no transparent full-screen layer or new light is needed.
        for row in range(4):
            for column in range(6):
                x = side * (6 + column * 5.5 + random_source.uniform(-1.2, 1.2))
                z = -30 - row * 8 + random_source.uniform(-1.4, 1.4)
                backdrop_pine(x, z, random_source.uniform(6.5, 10.5),
                              entrance_height(x, z))

        # Broken boundary masonry joins the existing entrance without adding
        # a misleading usable doorway, collectible or new collision surface.
        box('ApproachEntrance', stone, (side * 6.6, -25.9, 1.55), (1.0, 1.2, 3.1))
        box('ApproachEntrance', stone, (side * 6.6, -25.9, 3.14), (1.22, 1.4, .22))
        for i in range(5):
            x, z = side * (5.8 - i * .16), -27 - i * 1.3
            base = entrance_height(x, z)
            box('ApproachFence', wood, (x, z, base + .70), (.13, .14, 1.4))
            if i < 4:
                next_base = entrance_height(x - side * .16, z - 1.3)
                for height in [.4, 1.0]:
                    box('ApproachFence', boards,
                        (x - side * .08, z - .65, (base + next_base) / 2 + height),
                        (.095, 1.42, .13))
