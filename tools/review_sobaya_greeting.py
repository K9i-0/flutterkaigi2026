"""Render the exported Greeting at eight phases for arm deformation review."""
import bpy
import sys
from mathutils import Vector
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_sobaya_v3_rig import OUT
from build_humanoid_motion import use_action, clear_pose
from sobaya_v2_common import studio

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(OUT / 'sobaya_rig.glb'))
rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
rig.animation_data_clear()
clear_pose(rig)
scene = bpy.context.scene
scene.render.fps = 30
studio()
scene.cycles.samples = 12
scene.render.resolution_x = scene.render.resolution_y = 640
output = OUT / 'qa' / 'greeting'
output.mkdir(parents=True, exist_ok=True)
action = bpy.data.actions['Greeting']
use_action(rig, action)
for phase in [.1, .2, .3, .4, .5, .65, .75, .85]:
    start, end = action.frame_range
    frame = start + (end - start) * phase
    scene.frame_set(int(frame), subframe=frame % 1)
    bpy.context.view_layer.update()
    target = (rig.pose.bones['RightArm'].head + rig.pose.bones['RightHand'].head) / 2
    scene.camera.location = target + Vector((-.25, -3, .25))
    scene.camera.rotation_euler = (target - scene.camera.location).to_track_quat('-Z', 'Y').to_euler()
    scene.camera.data.ortho_scale = .85
    scene.render.filepath = str(output / f'{phase:.2f}.png')
    bpy.ops.render.render(write_still=True)
print('GREETING_ROUNDTRIP_DONE', flush=True)
