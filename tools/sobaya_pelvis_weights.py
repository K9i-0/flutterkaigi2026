"""Blend Sobaya's trouser bridge continuously across the two thighs.

Apply once after subdivision to the anatomical baseline weights. Geometry,
UVs, rest bones and actions are unchanged. Do not apply to already corrected
weights: rebuild the baseline first.
"""


def smooth(value):
    value = max(0.0, min(1.0, value))
    return value * value * (3.0 - 2.0 * value)


def correct_pelvis_weights(body):
    lower_bones = {
        'Hips', 'LeftUpLeg', 'RightUpLeg', 'LeftLeg', 'RightLeg',
        'LeftFoot', 'RightFoot',
    }
    changed = 0
    for vertex in body.data.vertices:
        x, _, z = vertex.co
        if not .65 < z < .98 or abs(x) > .25:
            continue
        old = {body.vertex_groups[g.group].name: g.weight for g in vertex.groups}
        if not old or not set(old).issubset(lower_bones):
            continue
        width = .075 * smooth((z - .65) / .10)
        if width <= 0:
            continue
        left = smooth((x + width) / (2 * width))
        hip = old.get('Hips', 0)
        central = 1 - smooth(abs(x) / .13)
        hip += (1 - hip) * central * smooth((z - .68) / .13) * .90
        weights = {
            'Hips': hip,
            'LeftUpLeg': (1 - hip) * left,
            'RightUpLeg': (1 - hip) * (1 - left),
        }
        if max(abs(weights.get(n, 0) - old.get(n, 0)) for n in lower_bones) < 1e-7:
            continue
        for group in list(vertex.groups):
            body.vertex_groups[group.group].remove([vertex.index])
        for name, weight in weights.items():
            if weight > 1e-7:
                body.vertex_groups[name].add([vertex.index], weight, 'REPLACE')
        changed += 1
    return {'revision': 'pelvis-blend-20260917', 'changedVertices': changed,
            'geometryChanged': False, 'boneRestChanged': False,
            'animationChanged': False, 'maxInfluencesInCorrection': 3}
