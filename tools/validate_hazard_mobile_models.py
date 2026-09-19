"""Validate mobile derivatives against source arrays and generator vertex maps."""
import copy
import io
import json

import numpy as np
from PIL import Image
from build_hazard_mobile_models import ROOT, OUT, WORK, SOURCES, TEXTURE_LIMITS
from optimize_hazard_models import sha
from replace_glb_animation import read_glb
from validate_optimized_hazard_models import accessor


def validate():
    report = {}
    manifest = json.loads((OUT / 'manifest.json').read_text())
    for name, relative in SOURCES.items():
        source = ROOT / relative; target = OUT / f'{name}.glb'
        old, ob = read_glb(source); new, nb = read_glb(target)
        row = manifest['models'][name]
        assert row['sourceSha256'] == sha(source.read_bytes())
        assert row['sha256'] == sha(target.read_bytes())
        def equal(a, b):
            assert np.array_equal(accessor(old, ob, a), accessor(new, nb, b)), (name, a, b)
        for key in ['nodes', 'scenes', 'scene', 'materials', 'textures', 'samplers', 'extensionsUsed']:
            assert old.get(key) == new.get(key), (name, key)
        for a, b in zip(old['skins'], new['skins'], strict=True):
            aa, bb = copy.deepcopy(a), copy.deepcopy(b)
            equal(aa.pop('inverseBindMatrices'), bb.pop('inverseBindMatrices')); assert aa == bb
        for a, b in zip(old['animations'], new['animations'], strict=True):
            aa, bb = copy.deepcopy(a), copy.deepcopy(b)
            for s, t in zip(aa['samplers'], bb['samplers'], strict=True):
                equal(s.pop('input'), t.pop('input')); equal(s.pop('output'), t.pop('output'))
            assert aa == bb
        maps = json.loads((WORK / f'{name}-mesh.json').read_text())
        for entry in maps:
            mi, pi = entry['mesh'], entry['primitive']
            a, b = old['meshes'][mi], new['meshes'][mi]
            assert {k: v for k, v in a.items() if k != 'primitives'} == {k: v for k, v in b.items() if k != 'primitives'}
            p, q = a['primitives'][pi], b['primitives'][pi]
            assert p['material'] == q['material']
            ids = np.array(entry['retainedSourceVertices'])
            for attrs, targets in zip([p['attributes'], *p.get('targets', [])], [q['attributes'], *q.get('targets', [])], strict=True):
                assert attrs.keys() == targets.keys()
                for key in attrs:
                    before = accessor(old, ob, attrs[key]); after = accessor(new, nb, targets[key])
                    assert np.array_equal(before[ids], after), (name, mi, pi, key)
            index = accessor(new, nb, q['indices'])
            assert 0 <= index.min() <= index.max() < len(ids)
            w = accessor(new, nb, q['attributes']['WEIGHTS_0'])
            assert np.max(np.abs(w.sum(1) - 1)) < .0001
        for i, (a, b) in enumerate(zip(old['images'], new['images'], strict=True)):
            def decode(d, binary, image):
                v = d['bufferViews'][image['bufferView']]; off = v.get('byteOffset', 0)
                return Image.open(io.BytesIO(binary[off:off+v['byteLength']])).convert('RGB')
            original, mobile = decode(old, ob, a), decode(new, nb, b)
            limit = TEXTURE_LIMITS[name][i]
            if limit and max(original.size) > limit:
                original = original.resize(tuple(round(x*limit/max(original.size)) for x in original.size), Image.Resampling.LANCZOS)
            assert original.size == mobile.size and original.tobytes() == mobile.tobytes()
        report[name] = {'sourceSha256': row['sourceSha256'], 'sha256': row['sha256'],
                        'animationClipsExact': len(new['animations']), 'nodesAndBindPoseExact': True,
                        'materialsExact': True, 'retainedVertexAttributesExact': True,
                        'morphNamesAndRetainedDeltasExact': True, 'textureRecipeExact': True,
                        'weightsNormalized': True}
    (OUT / 'validation.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    validate()
