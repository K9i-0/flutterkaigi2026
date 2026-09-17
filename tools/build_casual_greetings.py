"""Blender CLI: -- --character sobaya --input source.glb --output result.glb.

Only Greeting is replaced. Geometry, skinning, materials and all other clip
buffers remain byte-identical. The source must retain its canonical Idle clip.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import bpy

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tools'))
from casual_greeting import author_greeting, REVISION
from replace_glb_animation import replace_animation

parser = argparse.ArgumentParser()
parser.add_argument('--character', choices=['sobaya', 'fukuchan'], required=True)
parser.add_argument('--input', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args(sys.argv[sys.argv.index('--')+1:])
work = ROOT/'.local/casual_greeting'
work.mkdir(parents=True, exist_ok=True)
proof = ROOT/'04_GAME_ASSETS/3d/motions/casual_greeting_20260917'
proof.mkdir(parents=True, exist_ok=True)
before_hash = hashlib.sha256(args.input.read_bytes()).hexdigest()
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = 30
bpy.ops.import_scene.gltf(filepath=str(args.input.resolve()))
rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
rig.animation_data_clear()
action = author_greeting(rig, args.character)
bpy.data.libraries.write(str(proof/f'{args.character}_greeting.blend'), {action}, fake_user=True)
for other in list(bpy.data.actions):
    if other != action:
        bpy.data.actions.remove(other)
animation_file = work/f'{args.character}_greeting_export.glb'
bpy.ops.export_scene.gltf(filepath=str(animation_file), export_format='GLB',
    export_animations=True, export_animation_mode='ACTIONS', export_frame_range=False,
    export_force_sampling=True, export_skins=True, export_def_bones=False,
    export_anim_single_armature=True)
# Use a temporary path so in-place updates still validate against the input.
staged = work/f'{args.character}_staged.glb'
report = replace_animation(args.input, animation_file, staged)
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_bytes(staged.read_bytes())
report.update(character=args.character, revision=REVISION, seconds=2.2,
    source='New authored neutral-to-raised gesture; no old Greeting trajectory',
    beforeSha256=before_hash, sha256=hashlib.sha256(args.output.read_bytes()).hexdigest())
(proof/f'{args.character}_report.json').write_text(json.dumps(report, indent=2)+'\n')
print('CASUAL_GREETING_DONE', json.dumps(report), flush=True)
