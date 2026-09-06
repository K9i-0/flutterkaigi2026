"""Paired authored grab/struggle/release poses for Sobaya and Fukuchan.

Both source rigs face -Y. In a pair, Fukuchan is at (0, -.70, 0), facing
Sobaya. Runtime owns approach, spacing and the shared one-second hold clock.
This is authored IK, not motion capture or a cloth simulation.
"""
import math

import bpy
from mathutils import Matrix, Quaternion, Vector

SEPARATION = .70


def bake_grapple(rig, *, sobaya=False):
    def ease(value):
        t = min(1, max(0, value))
        return t * t * (3 - 2 * t)

    def point(name, target):
        bone = rig.pose.bones[name]
        q = (bone.tail - bone.head).rotation_difference(target - bone.head)
        bone.matrix = (Matrix.Translation(bone.head) @ q.to_matrix().to_4x4()
                       @ bone.matrix.to_3x3().to_4x4())
        bpy.context.view_layer.update()

    def solve(names, target, pole):
        upper, lower, tip = [rig.pose.bones[n] for n in names]
        origin = upper.head.copy()
        a, b = (lower.head - origin).length, (tip.head - lower.head).length
        delta = target - origin
        distance = max(abs(a - b) + .002, min(delta.length, a + b - .002))
        axis = delta.normalized()
        bend = (pole - axis * pole.dot(axis)).normalized()
        along = (a * a - b * b + distance * distance) / (2 * distance)
        point(upper.name, origin + axis * along + bend * math.sqrt(max(0, a * a - along * along)))
        point(lower.name, origin + axis * distance)

    specs = ([('Grab', 27, False), ('Hold', 30, True), ('Release', 21, False)]
             if sobaya else [('Struggle', 30, True), ('BreakFree', 21, False)])
    report = []
    for name, frames, loop in specs:
        old = bpy.data.actions.get(name)
        if old:
            bpy.data.actions.remove(old)
        action = bpy.data.actions.new(name)
        action.use_fake_user = True
        action.use_frame_range = True
        action.frame_start, action.frame_end = 0, frames
        rig.animation_data_create()
        rig.animation_data.action = action
        previous = {}
        for frame in range(frames + 1):
            bpy.context.scene.frame_set(frame)
            for bone in rig.pose.bones:
                bone.rotation_mode = 'QUATERNION'
                bone.matrix_basis = Matrix.Identity(4)
            t = frame / frames
            hold = 1 if loop else ease(t) if name == 'Grab' else 1 - ease((t - .28) / .72)
            sway = math.sin(math.tau * t) if loop else 0
            push = math.sin(math.pi * min(1, t / .5)) ** 2 if name == 'BreakFree' else 0
            chest = rig.pose.bones['Chest' if sobaya else 'Spine1']
            bpy.context.view_layer.update()
            lean = (.23 if sobaya else .08) * hold
            chest.matrix = (Matrix.Translation(chest.head)
                            @ Quaternion((1, 0, 0), lean).to_matrix().to_4x4()
                            @ chest.matrix.to_3x3().to_4x4())
            bpy.context.view_layer.update()
            head = rig.pose.bones['Head']
            head.matrix = (Matrix.Translation(head.head)
                           @ Quaternion((1, 0, 0), -lean * .7).to_matrix().to_4x4()
                           @ head.matrix.to_3x3().to_4x4())
            bpy.context.view_layer.update()
            for side, sign in [('Left', 1), ('Right', -1)]:
                suffix = '.L' if side == 'Left' else '.R'
                names = ([n + suffix for n in ['UpperArm', 'Forearm', 'Hand']]
                         if sobaya else [side + n for n in ['Arm', 'ForeArm', 'Hand']])
                rest = rig.data.bones[names[2]].head_local.copy()
                contact = (Vector((sign * .25 + .008 * sway, -.52, 1.31 + .006 * sway))
                           if sobaya else Vector((sign * .27 - .008 * sway,
                                                  -.30 - .14 * push, 1.23 + .006 * sway)))
                target = rest.lerp(contact, hold)
                solve(names, target, Vector((sign * .8, .3, -.8)))
                hand = rig.pose.bones[names[2]]
                direction = Vector((0, -.09, -.045)) if sobaya else Vector((0, -.055, .09))
                point(hand.name, hand.head + direction)
            if sobaya:
                from sobaya_garment import animate_hem
                animate_hem(rig)
            for bone in rig.pose.bones:
                q = bone.rotation_quaternion
                if bone.name in previous and q.dot(previous[bone.name]) < 0:
                    q.negate()
                previous[bone.name] = q.copy()
                bone.keyframe_insert('location', frame=frame, group=bone.name)
                bone.keyframe_insert('rotation_quaternion', frame=frame, group=bone.name)
        report.append({'name': name, 'duration': frames / 30, 'fps': 30,
                       'loop': loop, 'pair_separation_m': SEPARATION,
                       'source': 'authored paired upper-body IK; shared hold clock'})
    rig.animation_data.action = None
    for bone in rig.pose.bones:
        bone.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    return report
