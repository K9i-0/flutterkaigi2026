"""Sobaya v3 Greeting palm calibration; apply once to the retargeted action.

The target mesh's palm roll differs from the source rig. Calibrate the greeting
only: mug grips need a separate finger/contact pass. Preserve rest joints and
skinning; distribute the turn across forearm and wrist, fading at clip ends.
"""
import math
from mathutils import Quaternion

REVISION = 'greeting-palm-20260917'

def smooth(value):
    value = max(0.0, min(1.0, value))
    return value * value * (3.0 - 2.0 * value)


def correct_greeting_palm(rig, action):
    if action.get('sobayaPalmRevision') == REVISION:
        return
    bag = action.layers[0].strips[0].channelbag(action.slots[0])
    start, end = action.frame_range
    for name, degrees in [('RightForeArm', -58.5), ('RightHand', -31.5)]:
        path = f'pose.bones["{name}"].rotation_quaternion'
        curves = sorted([c for c in bag.fcurves if c.data_path == path],
                        key=lambda c: c.array_index)
        assert len(curves) == 4
        frames = [p.co.x for p in curves[0].keyframe_points]
        values = []
        for frame in frames:
            phase = (frame - start) / (end - start)
            blend = smooth((phase - .04) / .20) * smooth((.96 - phase) / .20)
            q = Quaternion([c.evaluate(frame) for c in curves])
            q = q @ Quaternion((0, 1, 0), math.radians(degrees) * blend)
            q.normalize()
            if values and q.dot(values[-1]) < 0:
                q.negate()
            values.append(q)
        for i, curve in enumerate(curves):
            for point, q in zip(curve.keyframe_points, values):
                point.co.y = q[i]
            curve.update()
    action['sobayaPalmRevision'] = REVISION
