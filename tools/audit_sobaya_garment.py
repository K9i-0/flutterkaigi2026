"""Measure exported waist-edge stretching, optionally against a prior GLB.

Blender --background --factory-startup --python tools/audit_sobaya_garment.py
    -- --reference path/to/prior.glb

This samples deformed edges; it does not certify cloth collision or appearance.
"""
import argparse
import hashlib
import json
import sys
from pathlib import Path

import bpy
import numpy as np

ROOT = Path(__file__).resolve().parent.parent


def inspect(path):
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)
    bpy.context.scene.render.fps = 30
    bpy.ops.import_scene.gltf(filepath=str(path))
    rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
    mesh = next(o for o in bpy.context.scene.objects if o.type == 'MESH')
    rest = np.array([v.co[:] for v in mesh.data.vertices])
    edges = np.array([e.vertices[:] for e in mesh.data.edges])
    region = ((rest[:, 2] > .80) & (rest[:, 2] < 1.22)
              & (np.abs(rest[:, 0]) < .30))
    lengths = np.linalg.norm(rest[edges[:, 0]] - rest[edges[:, 1]], axis=1)
    selected = region[edges].all(axis=1) & (lengths > .0001)
    edges, lengths = edges[selected], lengths[selected]
    clips = {}
    for name in ['Idle', 'Walk', 'Run', 'Climb', 'Vault', 'Toast', 'MugAttack',
                 'ZombieWalk', 'DanceStep', 'DanceDisco', 'DanceVictory']:
        action = bpy.data.actions[name]
        rig.animation_data.action = action
        rig.animation_data.action_slot = action.slots[0]
        end = int(round(action.frame_range[1]))
        rows = []
        for sample in range(end * 2 + 1):
            frame = sample / 2
            bpy.context.scene.frame_set(int(frame), subframe=frame % 1)
            bpy.context.view_layer.update()
            evaluated = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
            posed = evaluated.to_mesh()
            coords = np.array([v.co[:] for v in posed.vertices])
            assert np.isfinite(coords).all()
            ratio = np.linalg.norm(coords[edges[:, 0]] - coords[edges[:, 1]], axis=1) / lengths
            rows.append({'frame': frame, 'maxStretch': float(ratio.max()),
                         'p95Stretch': float(np.percentile(ratio, 95)),
                         'edgesOver3x': int((ratio > 3).sum())})
            evaluated.to_mesh_clear()
        clips[name] = {'poses': len(rows), 'maximumEdgeStretch': max(r['maxStretch'] for r in rows),
                       'maximumPoseP95': max(r['p95Stretch'] for r in rows),
                       'edgeSamplesOver3x': sum(r['edgesOver3x'] for r in rows), 'rows': rows}
    return {'source': str(path), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
            'waistEdges': len(edges), 'clips': clips}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--model', type=Path, default=ROOT / '04_GAME_ASSETS/3d/characters/sobaya/rig_v3/sobaya_rig.glb')
    parser.add_argument('--reference', type=Path)
    parser.add_argument('--output', type=Path, default=ROOT / '21_SOBAYA_HAZARD_LAB/evidence/sobaya-garment.json')
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
    report = {'sampleHz': 60, 'region': 'rest z .80..1.22 m, abs(x) < .30 m; edges > .1 mm',
              'limit': 'Edge stretch only, not cloth self-collision or subjective quality.',
              'candidate': inspect(args.model)}
    if args.reference:
        report['reference'] = inspect(args.reference)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({key: {name: {k: v for k, v in clip.items() if k != 'rows'}
                           for name, clip in model['clips'].items()}
                      for key, model in report.items() if key in ['candidate', 'reference']}, indent=2))


if __name__ == '__main__':
    main()
