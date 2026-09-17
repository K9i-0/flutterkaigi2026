"""Author a short 'hey' from a neutral pose, independently of the old Greeting.

Calibrated for Sobaya v3 and Fukuchan v2. The only sampled source pose is Idle
frame zero. Anatomical palm normals are fixed rig-space calibration constants;
no trajectories or timed corrections are inherited from the old greeting.
"""
import math
import bpy
from mathutils import Matrix, Quaternion, Vector
from build_humanoid_motion import use_action, clear_pose

REVISION = 'casual-hey-20260917'
FPS = 30
FRAMES = 66
PALM_NORMAL = {'sobaya': (-.9200587, 0, -.3917801),
               'fukuchan': (.0807076, 0, .9967378)}

def ease(x):
    x = max(0., min(1., x))
    return x*x*x*(x*(6*x-15)+10)


def aim(rig, name, child, goal):
    bone = rig.pose.bones[name]
    delta = (rig.pose.bones[child].head-bone.head).rotation_difference(goal-bone.head)
    bone.matrix = Matrix.Translation(bone.head) @ delta.to_matrix().to_4x4() @ bone.matrix.to_3x3().to_4x4()
    bpy.context.view_layer.update()


def author_greeting(rig, character):
    scene = bpy.context.scene
    use_action(rig, None)
    clear_pose(rig)
    use_action(rig, bpy.data.actions['Idle'])
    scene.frame_set(0)
    bpy.context.view_layer.update()
    neutral = {b.name: b.matrix_basis.copy() for b in rig.pose.bones}
    use_action(rig, None)
    arm, fore, hand = [rig.pose.bones[n] for n in ['RightArm', 'RightForeArm', 'RightHand']]
    origin = arm.head.copy()
    upper, lower = (fore.head-arm.head).length, (hand.head-fore.head).length
    goal = origin + Vector((-.16, -.32 if character == 'sobaya' else -.27,
                            .04 if character == 'sobaya' else .07))
    delta = goal-origin
    distance = delta.length
    assert abs(upper-lower) < distance < upper+lower
    axis = delta.normalized()
    pole = Vector((-.5, .05, -1))
    bend = (pole-axis*pole.dot(axis)).normalized()
    along = (upper*upper-lower*lower+distance*distance)/(2*distance)
    elbow = origin + axis*along + bend*math.sqrt(upper*upper-along*along)
    aim(rig, 'RightArm', 'RightForeArm', elbow)
    aim(rig, 'RightForeArm', 'RightHand', goal)
    # A relaxed palm facing the listener; fingers lean slightly outwards.
    finger = Vector((-.25, -.06, 1)).normalized()
    normal = Vector((0, -1, 0))
    normal = (normal-finger*normal.dot(finger)).normalized()
    local_finger = Vector((0, 1, 0))
    local_normal = Vector(PALM_NORMAL[character]).normalized()
    source = Matrix((local_finger, local_normal, local_finger.cross(local_normal))).transposed()
    target = Matrix((finger, normal, finger.cross(normal))).transposed()
    hand.matrix = Matrix.Translation(hand.head) @ (target @ source.transposed()).to_4x4()
    bpy.context.view_layer.update()
    raised = {b.name: b.matrix_basis.copy() for b in rig.pose.bones}
    old = bpy.data.actions.get('Greeting')
    if old:
        bpy.data.actions.remove(old)
    action = bpy.data.actions.new('Greeting')
    action.use_fake_user = True
    action.use_frame_range = True
    action.frame_start, action.frame_end = 0, FRAMES
    action['motionRevision'] = REVISION
    use_action(rig, action)
    previous = {}
    for frame in range(FRAMES+1):
        scene.frame_set(frame)
        seconds = frame/FPS
        amount = ease((seconds-.12)/.50) * (1-ease((seconds-1.12)/.82))
        nod = ease((seconds-.30)/.35) * (1-ease((seconds-.82)/.48))
        for bone in rig.pose.bones:
            loc, q, scale = neutral[bone.name].decompose()
            if bone.name in ['RightArm', 'RightForeArm', 'RightHand']:
                q = q.slerp(raised[bone.name].to_quaternion(), amount)
            if character == 'fukuchan' and bone.name.endswith('.R') and any(bone.name.startswith(d) for d in ['Thumb', 'Index', 'Middle', 'Ring', 'Little']):
                q = q.slerp(Quaternion((1, 0, 0, 0)), amount*.85)
            if bone.name == 'Head':
                q = q @ Quaternion((1, 0, 0), math.radians(2.5)*nod)
            if bone.name in previous and q.dot(previous[bone.name]) < 0:
                q.negate()
            previous[bone.name] = q.copy()
            bone.rotation_mode = 'QUATERNION'
            bone.location, bone.rotation_quaternion, bone.scale = loc, q, scale
            for attr in ['location', 'rotation_quaternion', 'scale']:
                bone.keyframe_insert(attr, frame=frame, group=bone.name)
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for point in curve.keyframe_points:
                        point.interpolation = 'LINEAR'
    scene.render.fps = FPS
    scene.frame_set(22)
    return action
