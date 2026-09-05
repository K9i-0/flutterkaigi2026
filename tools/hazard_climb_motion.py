"""Bake an authored two-bone IK ladder cycle, shared by both game rigs.
One second travels two 35 cm rungs. Runtime seeks by vertical distance, including
reverse descent and a paused contact pose. This clip is not motion capture.
"""
import math
import bpy
from mathutils import Vector, Matrix, Quaternion


def bake_climb(rig, sobaya=False):
    previous = bpy.data.actions.get('Climb')
    if previous:
        bpy.data.actions.remove(previous)
    action = bpy.data.actions.new('Climb')
    action.use_fake_user = True
    action.use_frame_range = True
    action.frame_start = 0
    action.frame_end = 30
    rig.animation_data_create()
    rig.animation_data.action = action

    def point(name, target):
        bone = rig.pose.bones[name]
        rotation = (bone.tail - bone.head).rotation_difference(target - bone.head)
        bone.matrix = Matrix.Translation(bone.head) @ rotation.to_matrix().to_4x4() @ bone.matrix.to_3x3().to_4x4()
        bpy.context.view_layer.update()

    def solve(names, target, pole):
        a, b, tip = [rig.pose.bones[n] for n in names]
        root = a.head.copy()
        la, lb = (b.head - root).length, (tip.head - b.head).length
        direction = target - root
        distance = max(abs(la - lb) + .005, min(direction.length, la + lb - .005))
        axis = direction.normalized()
        bend = (pole - axis * pole.dot(axis)).normalized()
        along = (la * la - lb * lb + distance * distance) / (2 * distance)
        elbow = root + axis * along + bend * math.sqrt(max(0, la * la - along * along))
        point(a.name, elbow)
        point(b.name, root + axis * distance)

    def lift(phase):
        # Support half: world-space contact stays fixed as the actor rises.
        # Recovery half: carry the limb to the next rung with a rounded arc.
        if phase <= .5:
            return .35 - .7 * phase, 0
        t = (phase - .5) * 2
        return .35 * (t * t * (3 - 2 * t)), math.sin(math.pi * t)

    last_quaternions = {}
    for frame in range(31):
        bpy.context.scene.frame_set(frame)
        for bone in rig.pose.bones:
            bone.rotation_mode = 'QUATERNION'
            bone.matrix_basis = Matrix.Identity(4)
        bpy.context.view_layer.update()
        phase = (frame % 30) / 30
        torso = rig.pose.bones['Chest' if sobaya else 'Spine1']
        torso.rotation_quaternion = Quaternion((1, 0, 0), .055)
        bpy.context.view_layer.update()
        for side, offset in [('Left', 0), ('Right', .5)]:
            suffix = '.L' if side == 'Left' else '.R'
            arm = [n + suffix for n in ['UpperArm', 'Forearm', 'Hand']] if sobaya else [side + n for n in ['Arm', 'ForeArm', 'Hand']]
            leg = [n + suffix for n in ['Thigh', 'Shin', 'Foot']] if sobaya else [side + n for n in ['UpLeg', 'Leg', 'Foot']]
            sign = 1 if rig.pose.bones[arm[0]].head.x > 0 else -1
            foot_lift, foot_arc = lift((phase + offset) % 1)
            hand_lift, hand_arc = lift((phase + offset + .5) % 1)
            # Keep the elbow outside the body; the broad Sobaya torso needs
            # wider contacts than Fukuchan, without shortening the shoulders.
            hand_x = (.34 if sobaya else .25) * sign
            solve(arm, Vector((hand_x, -.38 + .07 * hand_arc, 1.12 + hand_lift)), Vector((sign, .1, -.15)))
            point(arm[2], rig.pose.bones[arm[2]].head + Vector((0, -.10, -.045)))
            solve(leg, Vector((sign * .16, -.24 + .10 * foot_arc, .13 + foot_lift)), Vector((sign * .12, -1, .1)))
            point(leg[2], rig.pose.bones[leg[2]].head + Vector((0, -.15, -.055)))
        if sobaya:
            from sobaya_garment import animate_hem
            animate_hem(rig)
        for bone in rig.pose.bones:
            q = bone.rotation_quaternion
            if bone.name in last_quaternions and q.dot(last_quaternions[bone.name]) < 0:
                q.negate()
            last_quaternions[bone.name] = q.copy()
            bone.keyframe_insert('location', frame=frame, group=bone.name)
            bone.keyframe_insert('rotation_quaternion', frame=frame, group=bone.name)
    rig.animation_data.action = None
    for bone in rig.pose.bones:
        bone.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    return {'name': 'Climb', 'duration': 1, 'vertical_speed_mps': .7,
            'rung_spacing_m': .35, 'source': 'authored two-bone IK; distance-synchronized ladder loop'}
