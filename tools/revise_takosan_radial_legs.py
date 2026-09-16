"""Run inside Blender's Python console with the original takosan.blend open.
Reposition the four detached lower tentacles and their rest bones; preserve the
integrated lateral pair, skin weights, UVs, materials and existing animations.
Does not overwrite the adopted rig_sheet_v2 assets or deploy the website.
"""
from pathlib import Path
import bpy
import math
import json
import itertools
import hashlib
from mathutils import Matrix, Vector, Quaternion

ROOT = Path(bpy.data.filepath).parents[5]
SOURCE = ROOT / '04_GAME_ASSETS/3d/characters/takosan/rig_sheet_v2/takosan.blend'
OUT = ROOT / '04_GAME_ASSETS/3d/characters/takosan/rig_radial_v3'
assert Path(bpy.data.filepath) == SOURCE, 'Open the original rig_sheet_v2/takosan.blend first'
OUT.mkdir(parents=True, exist_ok=True)
(OUT / '.gitignore').write_text('*.blend\n*.blend1\npreview_*.png\n')
rig = bpy.data.objects['TakosanRig']
body = bpy.data.objects['TakosanBody']
if bpy.context.object and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
rig.animation_data.action = None
for bone in rig.pose.bones:
    bone.matrix_basis = Matrix.Identity(4)
bpy.context.scene.frame_set(0)
region = body.data.attributes['RigRegion']
original = [v.co.copy() for v in body.data.vertices]
angles = [math.atan2(rig.data.bones[f'Tentacle{j+1}.Base'].head_local.y,
                     rig.data.bones[f'Tentacle{j+1}.Base'].head_local.x) for j in range(4)]
targets = [math.radians(x) for x in [-120, -60, 60, 120]]
def difference(a, b):
    return (a - b + math.pi) % math.tau - math.pi
assignment = min(itertools.permutations(targets), key=lambda values: sum(difference(t, a)**2 for t, a in zip(values, angles)))
rotations = [Matrix.Rotation(difference(target, old), 4, 'Z') for target, old in zip(assignment, angles)]
for vertex in body.data.vertices:
    label = region.data[vertex.index].value
    if 10 <= label <= 13:
        vertex.co = rotations[label - 10] @ original[vertex.index]
body.data.update()
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
for j, rotation in enumerate(rotations):
    for part in ['Base', 'Mid', 'Tip']:
        rig.data.edit_bones[f'Tentacle{j+1}.{part}'].transform(rotation)
bpy.ops.object.mode_set(mode='OBJECT')
bpy.context.view_layer.update()
assert all((v.co - original[v.index]).length < 1e-7 for v in body.data.vertices if not 10 <= region.data[v.index].value <= 13)
import runpy
cleanup = runpy.run_path(str(ROOT / 'tools/clean_takosan_radial_center.py'))['clean_center'](body)
body.data.calc_loop_triangles()
report = {
    'source': str(SOURCE.relative_to(ROOT)),
    'source_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
    'front_axis': '-Y (Blender)',
    'layout': 'Six radial legs: front-left/right, left/right, rear-left/right; no central front or rear leg',
    'tentacle_angles_degrees': [round(math.degrees(a), 3) for a in assignment] + [0, 180],
    'rotated_degrees': [round(math.degrees(difference(t,a)), 3) for t,a in zip(assignment,angles)] + [0,0],
    'triangles': len(body.data.loop_triangles),
    'bones': len(rig.data.bones),
    'clips': [action.name for action in bpy.data.actions],
    'unchanged': ['head', 'robe', 'human arms and hands', 'lateral tentacles', 'UVs', 'materials', 'weights', 'animation keys'],
    'center_cleanup': cleanup,
    'status': 'Local revision, not adopted by website or game',
}
(OUT / 'revision.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n')
bpy.ops.object.select_all(action='DESELECT')
body.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
# Present the result in the GUI, with textured solid shading and a clean front view.
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == 'VIEW_3D':
            space = area.spaces.active
            space.shading.type = 'MATERIAL'
            space.overlay.show_overlays = False
            space.region_3d.view_distance = 2.8
            space.region_3d.view_location = Vector((0,0,.68))
            space.region_3d.view_rotation = Quaternion((1,0,0), math.pi/2)
            space.region_3d.view_perspective = 'ORTHO'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'takosan.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT / 'takosan.glb'), export_format='GLB', use_selection=True,
    export_animations=True, export_animation_mode='ACTIONS', export_frame_range=False,
    export_anim_slide_to_zero=True, export_anim_single_armature=True, export_skins=True, export_force_sampling=True)
print('RADIAL_REVISION_READY', json.dumps(report))
