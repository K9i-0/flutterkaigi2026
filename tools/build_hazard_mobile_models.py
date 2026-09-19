"""Build separate mobile models, preserving the current game's source assets."""
import io
import json
import struct
import subprocess
from pathlib import Path

from PIL import Image
from optimize_hazard_models import ROOT, pack, counts, sha
from replace_glb_animation import read_glb

OUT = ROOT / '04_GAME_ASSETS/3d/hazard_adopted/mobile_20260919'
WORK = ROOT / '.local/hazard-mobile-20260919'
SOURCES = {
    'sobaya': '04_GAME_ASSETS/3d/hazard_adopted/optimized_20260919/sobaya.glb',
    'fukuchan': '04_GAME_ASSETS/3d/hazard_adopted/optimized_20260919/fukuchan.glb',
    'yametaro': '04_GAME_ASSETS/3d/characters/yametaro/rig_nose_v3/yametaro.glb',
    'takosan': '04_GAME_ASSETS/3d/characters/takosan/rig_sheet_v2/takosan.glb',
}
# Keep the main face atlas of both realistic characters at its original resolution.
TEXTURE_LIMITS = {'sobaya': [2048, None], 'fukuchan': [2048, 2048, None, None, 2048, 2048],
                  'yametaro': [None, 1024, None, None, 1024], 'takosan': [None, 1024]}


def write_glb(doc, binary, path):
    doc['buffers'] = [{'byteLength': len(binary)}]
    raw = json.dumps(doc, separators=(',', ':')).encode()
    raw += b' ' * (-len(raw) % 4)
    binary += b'\0' * (-len(binary) % 4)
    path.write_bytes(struct.pack('<4sII', b'glTF', 2, 28 + len(raw) + len(binary)) +
                     struct.pack('<I4s', len(raw), b'JSON') + raw +
                     struct.pack('<I4s', len(binary), b'BIN\0') + binary)


def textures(name, path, output):
    doc, binary = read_glb(path)
    report = []
    assert len(doc['images']) == len(TEXTURE_LIMITS[name])
    for image, limit in zip(doc['images'], TEXTURE_LIMITS[name]):
        v = doc['bufferViews'][image['bufferView']]
        start = v.get('byteOffset', 0)
        im = Image.open(io.BytesIO(binary[start:start + v['byteLength']])).convert('RGB')
        size = im.size
        if limit and max(size) > limit:
            factor = limit / max(size)
            im = im.resize(tuple(round(x * factor) for x in size), Image.Resampling.LANCZOS)
            encoded = io.BytesIO(); im.save(encoded, format='PNG', optimize=True)
            binary += b'\0' * (-len(binary) % 4)
            image['bufferView'] = len(doc['bufferViews']); image['mimeType'] = 'image/png'
            doc['bufferViews'].append({'buffer': 0, 'byteOffset': len(binary), 'byteLength': len(encoded.getvalue())})
            binary += encoded.getvalue()
        report.append({'name': image.get('name'), 'before': list(size), 'after': list(im.size),
                       'baseRgbaBytesBefore': size[0] * size[1] * 4,
                       'baseRgbaBytesAfter': im.width * im.height * 4})
    write_glb(doc, binary, output)
    return report


def main():
    OUT.mkdir(parents=True, exist_ok=True); WORK.mkdir(parents=True, exist_ok=True)
    report = {'date': '2026-09-19', 'profile': 'mobile', 'models': {}}
    for name, relative in SOURCES.items():
        source = ROOT / relative
        subprocess.run(['node', str(ROOT / 'tools/simplify_hazard_mobile.mjs'), name,
                        str(source), str(WORK / f'{name}-mesh.glb'), str(WORK / f'{name}-mesh.json')],
                       check=True, cwd=ROOT)
        images = textures(name, WORK / f'{name}-mesh.glb', WORK / f'{name}-texture.glb')
        doc, _ = pack(WORK / f'{name}-texture.glb', OUT / f'{name}.glb')
        original, _ = read_glb(source)
        row = {'source': relative, 'sourceSha256': sha(source.read_bytes()),
               'file': str((OUT / f'{name}.glb').relative_to(ROOT)),
               'sha256': sha((OUT / f'{name}.glb').read_bytes()),
               'beforeBytes': source.stat().st_size, 'afterBytes': (OUT / f'{name}.glb').stat().st_size,
               'before': counts(original), 'after': counts(doc), 'textures': images,
               'geometry': [{k: v for k, v in primitive.items() if k != 'retainedSourceVertices'}
                            for primitive in json.loads((WORK / f'{name}-mesh.json').read_text())]}
        report['models'][name] = row
        print(name, row['before'], '=>', row['after'], flush=True)
    (OUT / 'manifest.json').write_text(json.dumps(report, indent=2) + '\n')


if __name__ == '__main__':
    main()
