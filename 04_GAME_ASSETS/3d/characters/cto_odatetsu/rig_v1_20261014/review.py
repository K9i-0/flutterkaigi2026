"""Render exported rigged GLB poses, not just the Blender working scene."""
import bpy
import json
import sys
from pathlib import Path
from mathutils import Vector

OUT = Path(__file__).resolve().parent
QA = OUT / 'qa'
QA.mkdir(exist_ok=True)
sys.path.insert(0, str(OUT.parents[4] / 'tools'))
from build_humanoid_motion import use_action, clear_pose

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = 30
bpy.ops.import_scene.gltf(filepath=str(OUT / 'cto_odatetsu_rig.glb'))
rig = next(o for o in scene.objects if o.type == 'ARMATURE')
rig.animation_data_clear()
scene.render.engine = 'CYCLES'
scene.cycles.samples = 16
scene.cycles.use_denoising = True
scene.render.resolution_percentage = 100
scene.view_settings.view_transform = 'Standard'
world = bpy.data.worlds.new('Review Studio')
world.use_nodes = True
world.node_tree.nodes['Background'].inputs[0].default_value = (.75, .75, .75, 1)
world.node_tree.nodes['Background'].inputs[1].default_value = .7
scene.world = world
camera = bpy.data.objects.new('Review Camera', bpy.data.cameras.new('Review Camera'))
scene.collection.objects.link(camera)
camera.data.type = 'ORTHO'
scene.camera = camera
for name, location, power, size in [('Key', (2, -3, 4), 160, 4),
                                      ('Fill', (-3, -2, 2), 100, 3),
                                      ('Rim', (1, 3, 3), 140, 3)]:
    light = bpy.data.lights.new(name, 'AREA')
    light.energy, light.shape, light.size = power, 'DISK', size
    obj = bpy.data.objects.new(name, light)
    scene.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (Vector((0, 0, .9)) - obj.location).to_track_quat('-Z', 'Y').to_euler()

def render(name, clip, seconds, direction=(.4, -1, .05), center=(0, 0, .9), size=2.05):
    use_action(rig, None)
    clear_pose(rig)
    if clip:
        use_action(rig, bpy.data.actions[clip])
    frame = seconds * 30
    scene.frame_set(int(frame), subframe=frame - int(frame))
    target = Vector(center)
    camera.location = target + Vector(direction).normalized() * 5
    camera.rotation_euler = (target - camera.location).to_track_quat('-Z', 'Y').to_euler()
    camera.data.ortho_scale = size
    scene.render.resolution_x, scene.render.resolution_y = 720, 900
    scene.render.filepath = str(QA / (name + '.png'))
    bpy.ops.render.render(write_still=True)

if '--hero' in sys.argv:
    render('Greeting', 'Greeting', .9)
    render('hood_greeting', 'Greeting', .9, (.7, 1, .05), (0, 0, 1.3), 1.)
elif '--neck' in sys.argv:
    render('victory_neck_front', 'DanceVictory', 0, (.4, -1, .05), (0, 0, 1.4), .95)
    render('victory_neck_back', 'DanceVictory', 0, (.4, 1, .05), (0, 0, 1.4), .95)
elif '--catalog' in sys.argv:
    for action in list(bpy.data.actions):
        duration = float(action.frame_range[1]) / 30
        render(f'catalog_{action.name}', action.name, duration * .5, size=2.45)
elif '--all' in sys.argv:
    for action in list(bpy.data.actions):
        duration = float(action.frame_range[1]) / 30
        for fraction in [.25, .5, .75]:
            render(f'{action.name}_{round(fraction * 100)}', action.name, duration * fraction)
elif '--hands' in sys.argv:
    for t in [.3, .8, 1.4, 1.9]:
        render(f'greeting_hand_{t}', 'Greeting', t, (.1, -1, .1), (-.23, -.12, 1.40), .65)
    render('gyun_hands', 'GyunGyunPose', 0, (.2, -1, .05), (0, -.1, 1.45), .65)
else:
    render('rest_front', None, 0, (0, -1, 0))
    render('rest_back', None, 0, (0, 1, 0))
    for clip, time in [('Idle', 0), ('Walk', .4), ('Run', .23), ('Greeting', .9),
                       ('DanceDisco', .7), ('GyunGyunPose', 0), ('Kick', .3), ('Aim', 0)]:
        render(clip, clip, time)
    render('hood_greeting', 'Greeting', .9, (.7, 1, .05), (0, 0, 1.3), 1.)
print('ODATETSU_REVIEW_DONE', flush=True)
