"""Game-only derivatives with embedded textures capped for phone memory.

Geometry, rig, animations, and materials are copied untouched; only embedded
images larger than the cap are downscaled (LANCZOS, same format). The masters
stay where they are; app/assets/models/ symlinks to the outputs.

Models that differ only in materials are merged into one GLB whose extra
looks are KHR_materials_variants, so shared geometry and textures load once.

usage: python3 app/tool/build_mobile_models.py [name ...]  (Pillow)
"""
import io
import json
import struct
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/3d/recruit_exam_mobile'
# Characters stay a few hundred px tall on screen; drops are smaller still.
SOURCES = {
    'fukuchan': ('assets/3d/hazard_rebuild/locomotion_v1/fukuchan.glb', 2048),
    'sobaya': ('assets/3d/hazard_rebuild/locomotion_v1/sobaya.glb', 2048),
    'cto_odatetsu': ('assets/3d/characters/cto_odatetsu/game_mobile_20261021/cto_odatetsu.glb', 2048),
    'yametaro': ('assets/3d/characters/yametaro/rig_nose_v3/yametaro.glb', 1024),
    'yumemin': ('assets/3d/characters/yumemin/color_20260919/yumemin.glb', 1024),
    'chikuwa': ('assets/3d/props/chikuwa/game_v3/chikuwa.glb', 1024),
}
# Extra material variants: output name -> {variant: master with the same mesh}.
# The output's own materials become the variant named first.
VARIANTS = {
    'chikuwa': {
        'normal': None,
        'toxic': 'assets/3d/props/chikuwa/game_v3/chikuwa_toxic.glb',
    },
}


def read_glb(path):
    data = path.read_bytes()
    json_len = struct.unpack_from('<I', data, 12)[0]
    doc = json.loads(data[20:20 + json_len])
    bin_len = struct.unpack_from('<I', data, 20 + json_len)[0]
    binary = data[28 + json_len:28 + json_len + bin_len]
    return doc, binary


def write_glb(doc, binary, path):
    text = json.dumps(doc, separators=(',', ':')).encode()
    text += b' ' * (-len(text) % 4)
    binary += b'\0' * (-len(binary) % 4)
    total = 12 + 8 + len(text) + 8 + len(binary)
    path.write_bytes(
        struct.pack('<III', 0x46546C67, 2, total)
        + struct.pack('<II', len(text), 0x4E4F534A) + text
        + struct.pack('<II', len(binary), 0x004E4942) + binary
    )


def shrink(data, mime, cap):
    image = Image.open(io.BytesIO(data))
    w, h = image.size
    if max(w, h) <= cap:
        return data, (w, h), (w, h)
    scale = cap / max(w, h)
    size = (max(1, round(w * scale)), max(1, round(h * scale)))
    out = io.BytesIO()
    resized = image.resize(size, Image.LANCZOS)
    if mime == 'image/jpeg':
        resized.convert('RGB').save(out, 'JPEG', quality=92)
    else:
        resized.save(out, 'PNG', optimize=True)
    return out.getvalue(), (w, h), size


def shrink_images(doc, binary, cap):
    """Returns the downscaled image payloads by buffer view, and a report."""
    replaced, report = {}, []
    for image in doc.get('images', []):
        view = doc['bufferViews'][image['bufferView']]
        start = view.get('byteOffset', 0)
        data, before, after = shrink(binary[start:start + view['byteLength']], image['mimeType'], cap)
        replaced[image['bufferView']] = data
        report.append({'before': before, 'after': after})
    return replaced, report


def view_data(doc, binary, index, replaced):
    view = doc['bufferViews'][index]
    start = view.get('byteOffset', 0)
    return replaced.get(index, binary[start:start + view['byteLength']])


def add_variants(doc, binary, replaced, variants, cap):
    """Appends each variant master's materials, reusing identical images."""
    names = list(variants)
    for name, source in variants.items():
        if source is None:
            continue
        other, other_bin = read_glb(ROOT / source)
        other_replaced, _ = shrink_images(other, other_bin, cap)
        image_views = {i['bufferView'] for i in other['images']}
        # Only materials may differ: every non-image buffer view must match.
        assert len(other['bufferViews']) == len(doc['bufferViews'])
        for v in range(len(doc['bufferViews'])):
            if v not in image_views:
                assert view_data(doc, binary, v, replaced) == view_data(other, other_bin, v, {}), (source, v)
        images = []
        for image in other['images']:
            data = other_replaced[image['bufferView']]
            same = [k for k, mine in enumerate(doc['images'])
                    if view_data(doc, binary, mine['bufferView'], replaced) == data]
            if same:
                images.append(same[0])
                continue
            doc['bufferViews'].append({'buffer': 0, 'byteLength': len(data)})
            replaced[len(doc['bufferViews']) - 1] = data
            doc['images'].append({**image, 'bufferView': len(doc['bufferViews']) - 1})
            images.append(len(doc['images']) - 1)
        textures = []
        for texture in other['textures']:
            mapped = {**texture, 'source': images[texture['source']]}
            if mapped not in doc['textures']:
                doc['textures'].append(mapped)
            textures.append(doc['textures'].index(mapped))

        def remap(value):
            if isinstance(value, dict):
                return {k: textures[v] if k == 'index' else remap(v) for k, v in value.items()}
            return value
        offset = len(doc['materials'])
        doc['materials'] += [remap(m) for m in other['materials']]
        variant = names.index(name)
        for mesh, other_mesh in zip(doc['meshes'], other['meshes']):
            for prim, other_prim in zip(mesh['primitives'], other_mesh['primitives']):
                mappings = prim.setdefault('extensions', {}).setdefault(
                    'KHR_materials_variants', {'mappings': [{'material': prim['material'], 'variants': [0]}]})['mappings']
                mappings.append({'material': offset + other_prim['material'], 'variants': [variant]})
    doc.setdefault('extensionsUsed', []).append('KHR_materials_variants')
    doc.setdefault('extensions', {})['KHR_materials_variants'] = {
        'variants': [{'name': n} for n in names]}


def build(name, source, cap):
    doc, binary = read_glb(ROOT / source)
    assert len(doc['buffers']) == 1 and 'uri' not in doc['buffers'][0]
    replaced, report = shrink_images(doc, binary, cap)
    if name in VARIANTS:
        add_variants(doc, binary, replaced, VARIANTS[name], cap)
    # Repack every view in order, keeping 4-byte alignment for accessors.
    packed = bytearray()
    for index, view in enumerate(doc['bufferViews']):
        packed += b'\0' * (-len(packed) % 4)
        data = view_data(doc, binary, index, replaced)
        view['byteOffset'] = len(packed)
        view['byteLength'] = len(data)
        packed += data
    doc['buffers'][0]['byteLength'] = len(packed)
    target = OUT / f'{name}.glb'
    write_glb(doc, bytes(packed), target)
    return {
        'source': source,
        'variants': VARIANTS.get(name),
        'cap': cap,
        'images': report,
        'bytes': [(ROOT / source).stat().st_size, target.stat().st_size],
    }


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    names = sys.argv[1:] or list(SOURCES)
    record = OUT / 'build.json'
    summary = json.loads(record.read_text()) if record.exists() else {}
    summary = {n: summary[n] for n in SOURCES if n in summary}
    for name in names:
        summary[name] = build(name, *SOURCES[name])
    record.write_text(json.dumps(summary, indent=1) + '\n')
    for name in names:
        s = summary[name]
        print(name, s['bytes'], [i['after'] for i in s['images']])


if __name__ == '__main__':
    main()
