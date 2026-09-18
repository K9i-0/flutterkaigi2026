import bpy,sys
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
from sobaya_v2_common import studio
OUT=ROOT/'04_GAME_ASSETS/3d/print/keychains_20260918'
for name,height in [('takosan',30),('sobaya',40)]:
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.ops.wm.stl_import(filepath=str(OUT/f'{name}_{height}mm_keychain_quote.stl'),forward_axis='Y',up_axis='Z')
 for o in bpy.context.scene.objects:o.matrix_world=Matrix.Scale(1.8/(height+5),4)@o.matrix_world
 studio();s=bpy.context.scene;s.cycles.samples=8;s.render.resolution_x=600;s.render.resolution_y=600
 target=Vector((0,0,.9));s.camera.location=target+Vector((-.6,-4,.9));s.camera.rotation_euler=(target-s.camera.location).to_track_quat('-Z','Y').to_euler();s.camera.data.ortho_scale=2.3
 s.render.filepath=str(OUT/f'{name}_preview.png');bpy.ops.render.render(write_still=True)
