"""Build game-only derivatives; preserve source models, all clips and texture pixels.

Run with Python + Pillow (e.g. .local/wan-motion-venv/bin/python).
The rigid-part simplifier uses the existing Three.js 0.185.1 local validation kit.
"""
import copy
import hashlib
import io
import json
from pathlib import Path
import struct
import subprocess

from PIL import Image
from replace_glb_animation import read_glb

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / '04_GAME_ASSETS/3d/hazard_adopted/optimized_20260919'
WORK = ROOT / '.local/hazard-optimization-20260919'
SOURCES = {
    'sobaya': ROOT / '04_GAME_ASSETS/3d/hazard_adopted/v3_20260917/sobaya.glb',
    'fukuchan': ROOT / '04_GAME_ASSETS/3d/hazard_adopted/v3_preview_20260917/fukuchan.glb',
}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def accessor_references(doc):
    for mesh in doc.get('meshes', []):
        for p in mesh['primitives']:
            for attrs in [p['attributes'], *p.get('targets', [])]:
                for key in attrs:
                    yield attrs, key
            if 'indices' in p:
                yield p, 'indices'
    for skin in doc.get('skins', []):
        if 'inverseBindMatrices' in skin:
            yield skin, 'inverseBindMatrices'
    for anim in doc.get('animations', []):
        for sampler in anim['samplers']:
            yield sampler, 'input'
            yield sampler, 'output'


def view_references(doc):
    for a in doc['accessors']:
        if 'bufferView' in a:
            yield a, 'bufferView'
        if 'sparse' in a:
            yield a['sparse']['indices'], 'bufferView'
            yield a['sparse']['values'], 'bufferView'
    for image in doc.get('images', []):
        yield image, 'bufferView'


def counts(doc):
    ps = [p for m in doc['meshes'] for p in m['primitives']]
    return {'triangles': sum(doc['accessors'][p['indices']]['count'] // 3 for p in ps),
            'vertices': sum(doc['accessors'][p['attributes']['POSITION']]['count'] for p in ps),
            'primitives': len(ps), 'clips': len(doc.get('animations', [])),
            'accessors': len(doc['accessors']), 'bufferViews': len(doc['bufferViews'])}


def pack(path, destination):
    doc, binary = read_glb(path)
    assert set(doc.get('extensionsUsed', [])) <= {'KHR_materials_specular'}
    assert len(doc['buffers']) == 1
    image_report, overrides = [], {}
    for image in doc.get('images', []):
        idx = image['bufferView']
        v = doc['bufferViews'][idx]
        original = binary[v.get('byteOffset', 0):v.get('byteOffset', 0) + v['byteLength']]
        im = Image.open(io.BytesIO(original))
        pixels = im.convert('RGBA').tobytes()
        # Strip constant opaque alpha and recompress, with no resampling or quantization.
        rgb = im.convert('RGB') if im.mode == 'RGBA' and im.getextrema()[3] == (255, 255) else im
        encoded = io.BytesIO()
        rgb.save(encoded, format='PNG', optimize=True, compress_level=9)
        candidate = encoded.getvalue()
        assert Image.open(io.BytesIO(candidate)).convert('RGBA').tobytes() == pixels
        result = candidate if len(candidate) < len(original) else original
        overrides[idx] = result
        image_report.append({'name': image.get('name'), 'size': list(im.size),
                             'beforeBytes': len(original), 'afterBytes': len(result),
                             'decodedRgbaSha256': sha(pixels), 'pixelsIdentical': True})

    # Remove obsolete accessors and buffers left by previous animation/image replacements.
    refs = list(accessor_references(doc))
    live = sorted({obj[key] for obj, key in refs})
    mapping = {old: new for new, old in enumerate(live)}
    doc['accessors'] = [doc['accessors'][i] for i in live]
    for obj, key in refs:
        obj[key] = mapping[obj[key]]
    refs = list(view_references(doc))
    vertex_views = set()
    for mesh in doc['meshes']:
        for p in mesh['primitives']:
            for attrs in [p['attributes'], *p.get('targets', [])]:
                for idx in attrs.values():
                    if 'bufferView' in doc['accessors'][idx]:
                        vertex_views.add(doc['accessors'][idx]['bufferView'])
    views, data, mapped, unique = [], bytearray(), {}, {}
    for idx in sorted({obj[key] for obj, key in refs}):
        v = copy.deepcopy(doc['bufferViews'][idx])
        payload = overrides.get(idx, binary[v.get('byteOffset', 0):v.get('byteOffset', 0) + v['byteLength']])
        semantic = {k: value for k, value in v.items() if k not in ['buffer', 'byteOffset', 'byteLength', 'name']}
        # glTF requires an explicit interleaved stride when attributes share a
        # view. Preserve independent vertex views; deduplicate animation data.
        identity = (json.dumps(semantic, sort_keys=True), sha(payload), idx if idx in vertex_views else None)
        if identity not in unique:
            data.extend(b'\0' * (-len(data) % 4))
            v.update(buffer=0, byteOffset=len(data), byteLength=len(payload))
            unique[identity] = len(views)
            views.append(v)
            data.extend(payload)
        mapped[idx] = unique[identity]
    for obj, key in refs:
        obj[key] = mapped[obj[key]]
    doc['bufferViews'] = views
    doc['buffers'] = [{'byteLength': len(data)}]
    raw = json.dumps(doc, separators=(',', ':')).encode()
    raw += b' ' * (-len(raw) % 4)
    data.extend(b'\0' * (-len(data) % 4))
    output = struct.pack('<4sII', b'glTF', 2, 28 + len(raw) + len(data))
    output += struct.pack('<I4s', len(raw), b'JSON') + raw
    output += struct.pack('<I4s', len(data), b'BIN\0') + data
    destination.write_bytes(output)
    return doc, image_report


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    WORK.mkdir(parents=True, exist_ok=True)
    subprocess.run(['node', str(ROOT / 'tools/simplify_hazard_rigid_meshes.mjs'),
                    str(SOURCES['sobaya']), str(WORK / 'sobaya.glb'),
                    str(WORK / 'simplification.json')], check=True, cwd=ROOT)
    report = {'date': '2026-09-19', 'models': {}}
    for name, source in SOURCES.items():
        original, _ = read_glb(source)
        output = OUT / f'{name}.glb'
        doc, images = pack(WORK / 'sobaya.glb' if name == 'sobaya' else source, output)
        report['models'][name] = {
            'source': str(source.relative_to(ROOT)), 'sourceSha256': sha(source.read_bytes()),
            'file': str(output.relative_to(ROOT)), 'sha256': sha(output.read_bytes()),
            'beforeBytes': source.stat().st_size, 'afterBytes': output.stat().st_size,
            'before': counts(original), 'after': counts(doc), 'images': images,
        }
    report['rigidSimplification'] = json.loads((WORK / 'simplification.json').read_text())
    (OUT / 'optimization.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({name: {k: v for k, v in row.items() if k not in ['images']}
                      for name, row in report['models'].items()}, indent=2))


if __name__ == '__main__':
    main()
