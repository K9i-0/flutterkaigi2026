"""Game-only derivatives with embedded textures capped for phone memory.

Geometry, rig, animations, and materials are copied untouched; only embedded
images larger than the cap are downscaled (LANCZOS, same format). The masters
stay where they are; app/assets/models/ symlinks to the outputs.

usage: python3 app/tool/build_mobile_models.py  (Pillow)
"""
import io
import json
import struct
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
    'chikuwa_toxic': ('assets/3d/props/chikuwa/game_v3/chikuwa_toxic.glb', 1024),
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


def build(name, source, cap):
    doc, binary = read_glb(ROOT / source)
    assert len(doc['buffers']) == 1 and 'uri' not in doc['buffers'][0]
    replaced = {}
    report = []
    for image in doc.get('images', []):
        view = doc['bufferViews'][image['bufferView']]
        start = view.get('byteOffset', 0)
        data, before, after = shrink(binary[start:start + view['byteLength']], image['mimeType'], cap)
        replaced[image['bufferView']] = data
        report.append({'before': before, 'after': after})
    # Repack every view in order, keeping 4-byte alignment for accessors.
    packed = bytearray()
    for index, view in enumerate(doc['bufferViews']):
        packed += b'\0' * (-len(packed) % 4)
        start = view.get('byteOffset', 0)
        data = replaced.get(index, binary[start:start + view['byteLength']])
        view['byteOffset'] = len(packed)
        view['byteLength'] = len(data)
        packed += data
    doc['buffers'][0]['byteLength'] = len(packed)
    target = OUT / f'{name}.glb'
    write_glb(doc, bytes(packed), target)
    return {
        'source': source,
        'cap': cap,
        'images': report,
        'bytes': [(ROOT / source).stat().st_size, target.stat().st_size],
    }


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    summary = {name: build(name, *spec) for name, spec in SOURCES.items()}
    (OUT / 'build.json').write_text(json.dumps(summary, indent=1) + '\n')
    for name, s in summary.items():
        print(name, s['bytes'], [i['after'] for i in s['images']])


if __name__ == '__main__':
    main()
