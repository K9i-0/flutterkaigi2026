"""Semantic comparison against immutable pre-optimization game models."""
import copy
import io
import json
from pathlib import Path

import numpy as np
from PIL import Image
from optimize_hazard_models import ROOT, OUT, SOURCES, sha
from replace_glb_animation import read_glb


def accessor(doc, binary, idx):
    a = doc['accessors'][idx]
    width = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}[a['type']]
    dtype = np.dtype({5121: 'u1', 5123: '<u2', 5125: '<u4', 5126: '<f4'}[a['componentType']])
    def read(view, count, components, typ, offset=0):
        v = doc['bufferViews'][view]
        return np.ndarray((count, components), dtype=typ, buffer=binary,
                          offset=v.get('byteOffset', 0) + offset,
                          strides=(v.get('byteStride', components * typ.itemsize), typ.itemsize)).copy()
    values = read(a['bufferView'], a['count'], width, dtype, a.get('byteOffset', 0)) if 'bufferView' in a else np.zeros((a['count'], width), dtype=dtype)
    if 'sparse' in a:
        s = a['sparse']; i = s['indices']; v = s['values']
        typ = np.dtype({5121: 'u1', 5123: '<u2', 5125: '<u4'}[i['componentType']])
        ids = read(i['bufferView'], s['count'], 1, typ, i.get('byteOffset', 0)).ravel()
        values[ids] = read(v['bufferView'], s['count'], width, dtype, v.get('byteOffset', 0))
    return values


def validate():
    report = {}
    for name, source in SOURCES.items():
        old, ob = read_glb(source); new, nb = read_glb(OUT / f'{name}.glb')
        def equal(a, b):
            av, bv = accessor(old, ob, a), accessor(new, nb, b)
            assert np.array_equal(av, bv), (name, a, b)
        for key in ['nodes', 'scenes', 'scene', 'materials', 'textures', 'samplers', 'extensionsUsed']:
            assert old.get(key) == new.get(key), (name, key)
        assert len(old['skins']) == len(new['skins'])
        for a, b in zip(old['skins'], new['skins']):
            aa, bb = copy.deepcopy(a), copy.deepcopy(b)
            equal(aa.pop('inverseBindMatrices'), bb.pop('inverseBindMatrices'))
            assert aa == bb
        assert len(old['animations']) == len(new['animations'])
        for a, b in zip(old['animations'], new['animations']):
            aa, bb = copy.deepcopy(a), copy.deepcopy(b)
            assert len(aa['samplers']) == len(bb['samplers'])
            for s, t in zip(aa['samplers'], bb['samplers']):
                equal(s.pop('input'), t.pop('input')); equal(s.pop('output'), t.pop('output'))
            assert aa == bb
        exact, simplified = [], []
        assert len(old['meshes']) == len(new['meshes'])
        for m, n in zip(old['meshes'], new['meshes']):
            assert {k: v for k, v in m.items() if k != 'primitives'} == {k: v for k, v in n.items() if k != 'primitives'}
            assert len(m['primitives']) == len(n['primitives'])
            for p, q in zip(m['primitives'], n['primitives']):
                material = old['materials'][p['material']]['name']
                assert {k: v for k, v in p.items() if k not in ['indices', 'attributes', 'targets']} == {k: v for k, v in q.items() if k not in ['indices', 'attributes', 'targets']}
                groups = list(zip([p['attributes'], *p.get('targets', [])], [q['attributes'], *q.get('targets', [])]))
                is_reduced = old['accessors'][p['indices']]['count'] != new['accessors'][q['indices']]['count']
                if not is_reduced:
                    equal(p['indices'], q['indices'])
                    for a, b in groups:
                        assert a.keys() == b.keys()
                        for k in a: equal(a[k], b[k])
                    exact.append(material)
                else:
                    assert name == 'sobaya' and material in ['Mask porcelain nose', 'Mask medallion black satin', 'Hair clean charcoal']
                    # Every retained vertex keeps ALL original attributes, including morphs and skin.
                    before, after = [], []
                    for a, b in groups:
                        assert a.keys() == b.keys()
                        for key in a:
                            before.append(accessor(old, ob, a[key]).view(np.uint8).reshape(old['accessors'][a[key]]['count'], -1))
                            after.append(accessor(new, nb, b[key]).view(np.uint8).reshape(new['accessors'][b[key]]['count'], -1))
                    old_rows = {row.tobytes() for row in np.concatenate(before, axis=1)}
                    assert all(row.tobytes() in old_rows for row in np.concatenate(after, axis=1))
                    indices = accessor(new, nb, q['indices'])
                    assert indices.min() >= 0 and indices.max() < after[0].shape[0]
                    simplified.append(material)
        assert len(old['images']) == len(new['images'])
        for a, b in zip(old['images'], new['images']):
            def pixels(d, binary, im):
                v = d['bufferViews'][im['bufferView']]; off = v.get('byteOffset', 0)
                image = Image.open(io.BytesIO(binary[off:off + v['byteLength']])).convert('RGBA')
                return image.size, image.tobytes()
            assert pixels(old, ob, a) == pixels(new, nb, b)
        report[name] = {'sourceSha256': sha(source.read_bytes()), 'sha256': sha((OUT / f'{name}.glb').read_bytes()),
                        'identicalAnimationClips': len(new['animations']), 'identicalNodesAndBindMatrices': True,
                        'identicalMaterialsAndTexturePixels': True, 'exactPrimitives': exact,
                        'simplifiedRigidPrimitives': simplified, 'retainedVertexAttributesExact': True}
    (OUT / 'semantic_validation.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    validate()
