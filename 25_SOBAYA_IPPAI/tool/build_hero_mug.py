"""Refine the canonical mug's glass shell for macro shots. Source stays intact.
/Applications/Blender.app/Contents/MacOS/Blender -b --python tool/build_hero_mug.py
"""
import bpy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'04_GAME_ASSETS/3d/props/beer_mug_v2/beer_mug.blend'
OUT=ROOT/'04_GAME_ASSETS/3d/props/ippai_mug'
OUT.mkdir(parents=True,exist_ok=True)
if SOURCE.exists():
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
else:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE.with_suffix('.glb')))
for obj in list(bpy.data.objects):
    if obj.name not in ['GlassBody','Handle','BeerMugRoot']:
        bpy.data.objects.remove(obj,do_unlink=True)
for name,level in [('GlassBody',1),('Handle',2)]:
    obj=bpy.data.objects[name]
    bpy.context.view_layer.objects.active=obj
    modifier=obj.modifiers.new('Macro glass smooth surface','SUBSURF')
    modifier.subdivision_type='CATMULL_CLARK';modifier.levels=level
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    for poly in obj.data.polygons:poly.use_smooth=True
bpy.ops.export_scene.gltf(filepath=str(OUT/'beer_mug.glb'),export_format='GLB',export_yup=True,export_animations=False,export_materials='EXPORT')
print('Hero glass exported:',OUT/'beer_mug.glb')
