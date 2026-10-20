"""Game-only derivative; original geometry/20-clip master remains untouched.

uv run --with pillow --with numpy python 26_YUMEMI_RECRUIT_EXAM/tool/optimize_odatetsu.py
Uses the pinned Three.js meshoptimizer kit documented in the shared mobile tool.
"""
import copy
import json
from pathlib import Path
import subprocess
import sys

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from optimize_hazard_models import pack, counts, sha
from build_hazard_mobile_models import write_glb
from replace_glb_animation import read_glb
from validate_optimized_hazard_models import accessor

SOURCE = ROOT / '04_GAME_ASSETS/3d/characters/cto_odatetsu/rig_v1_20261014/cto_odatetsu_rig.glb'
OUT = SOURCE.parent.parent / 'game_mobile_20261021'
WORK = ROOT / '.local/recruit-optimization'


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    WORK.mkdir(parents=True, exist_ok=True)
    mesh_path, map_path = WORK / 'odatetsu-mesh.glb', WORK / 'odatetsu-map.json'
    subprocess.run(['node', str(ROOT / 'tools/simplify_hazard_mobile.mjs'),
                    'cto_odatetsu', str(SOURCE), str(mesh_path), str(map_path)], check=True)
    doc, binary = read_glb(mesh_path)
    clips = {'Idle', 'Walk', 'Run'}
    doc['animations'] = [a for a in doc['animations'] if a['name'] in clips]
    assert {a['name'] for a in doc['animations']} == clips
    trimmed = WORK / 'odatetsu-trimmed.glb'
    write_glb(doc, binary, trimmed)
    target = WORK / 'odatetsu-candidate.glb'
    _, images = pack(trimmed, target)
    old, ob = read_glb(SOURCE)
    new, nb = read_glb(target)

    def equal(a, b):
        assert np.array_equal(accessor(old, ob, a), accessor(new, nb, b))

    for key in ['nodes', 'scenes', 'scene', 'materials', 'textures', 'samplers', 'extensionsUsed']:
        assert old.get(key) == new.get(key), key
    for a, b in zip(old['skins'], new['skins'], strict=True):
        aa, bb = copy.deepcopy(a), copy.deepcopy(b)
        equal(aa.pop('inverseBindMatrices'), bb.pop('inverseBindMatrices'))
        assert aa == bb
    for b in new['animations']:
        a = next(a for a in old['animations'] if a['name'] == b['name'])
        aa, bb = copy.deepcopy(a), copy.deepcopy(b)
        for s, t in zip(aa['samplers'], bb['samplers'], strict=True):
            equal(s.pop('input'), t.pop('input'))
            equal(s.pop('output'), t.pop('output'))
        assert aa == bb
    reductions = json.loads(map_path.read_text())
    protected_faces = 0
    for row in reductions:
        p = old['meshes'][row['mesh']]['primitives'][row['primitive']]
        q = new['meshes'][row['mesh']]['primitives'][row['primitive']]
        ids = np.array(row['retainedSourceVertices'])
        for attrs, targets in zip([p['attributes'], *p.get('targets', [])],
                                  [q['attributes'], *q.get('targets', [])], strict=True):
            assert attrs.keys() == targets.keys()
            for key in attrs:
                assert np.array_equal(accessor(old, ob, attrs[key])[ids],
                                      accessor(new, nb, targets[key])), key
        joint_ids = accessor(old, ob, p['attributes']['JOINTS_0']).astype(int)
        weights = accessor(old, ob, p['attributes']['WEIGHTS_0'])
        names = [old['nodes'][i]['name'] for i in old['skins'][0]['joints']]
        protected = np.array([any(part in name for part in
            ['Head', 'Neck', 'Hand', 'Thumb', 'Index', 'Middle', 'Ring', 'Little'])
            for name in names])
        locked = np.any(protected[joint_ids] & (weights > 0), axis=1)
        before = accessor(old, ob, p['indices']).reshape(-1, 3)
        after = ids[accessor(new, nb, q['indices']).astype(int)].reshape(-1, 3)
        after_faces = {tuple(sorted(face)) for face in after}
        # Whole face/hand triangles must survive, not just isolated vertices.
        for face in before[np.all(locked[before], axis=1)]:
            assert tuple(sorted(face)) in after_faces, 'Protected face changed'
            protected_faces += 1
    candidate_counts = counts(new)
    # Only 1.3% fewer triangles under the conservative identity constraints.
    # Adopt exact geometry instead: lossless images + the three used clips.
    adopted = copy.deepcopy(old)
    adopted['animations'] = [a for a in adopted['animations'] if a['name'] in clips]
    write_glb(adopted, ob, trimmed)
    target = OUT / 'cto_odatetsu.glb'
    _, images = pack(trimmed, target)
    new, nb = read_glb(target)
    for m, n in zip(old['meshes'], new['meshes'], strict=True):
        for p, q in zip(m['primitives'], n['primitives'], strict=True):
            equal(p['indices'], q['indices'])
            for attrs, targets in zip([p['attributes'], *p.get('targets', [])],
                                      [q['attributes'], *q.get('targets', [])], strict=True):
                for key in attrs:
                    equal(attrs[key], targets[key])
    report = {
        'source': str(SOURCE.relative_to(ROOT)), 'sourceSha256': sha(SOURCE.read_bytes()),
        'file': str(target.relative_to(ROOT)), 'sha256': sha(target.read_bytes()),
        'beforeBytes': SOURCE.stat().st_size, 'afterBytes': target.stat().st_size,
        'before': counts(old), 'after': counts(new),
        'images': images, 'preservedClipsExact': sorted(clips),
        'nodesBindPoseMaterialsExact': True, 'retainedVertexAttributesExact': True,
        'allGeometryExact': True,
        'simplificationCandidate': {
            'adopted': False,
            'reason': f"Only {100 * (1 - candidate_counts['triangles'] / counts(old)['triangles']):.1f}% triangle reduction; retain exact geometry",
            'counts': candidate_counts, 'protectedFaceHandTrianglesExact': protected_faces,
            'primitives': [{k: v for k, v in r.items() if k != 'retainedSourceVertices'}
                           for r in reductions],
        },
    }
    (OUT / 'optimization.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
