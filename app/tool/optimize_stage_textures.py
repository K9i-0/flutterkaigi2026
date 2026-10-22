"""Downsample only embedded GLB images, preserving source PNGs and geometry.

Run with Pillow after build_akasaka_stage.py. Rebuilding restores full resolution.
Usage: uv run --with pillow python tool/optimize_stage_textures.py [input.glb]
"""
import io
import json
from pathlib import Path
import struct
import sys

from PIL import Image

DEFAULT = Path(__file__).resolve().parents[2] / 'assets/3d/stages/akasaka/akasaka.glb'


def limit(name, size):
    # The camera zooms toward the beam, its support buildings (facade_0) and
    # the characters; keep those. Everything else stays 15+ units away, so it
    # is sized to about one texel per screen pixel on a 2622x1206 display.
    if name == 'facade_0':
        return 512, 1024
    if name.startswith('facade_0'):
        return (128, 256) if name.endswith('_mr') else (256, 512)
    if name.startswith('facade_'):
        # Window masks and roughness need fewer samples than painted detail.
        if name.endswith('_mr'):
            return 64, 128
        return (128, 256) if name.endswith('_emit') else (256, 512)
    if name.startswith('steel'):
        return 512, 128
    if name.startswith('asphalt'):
        return (256, 256) if name == 'asphalt' else (128, 128)
    if name.startswith('skyline'):
        return 128, 128
    if name.startswith('sign_'):
        return 64, 192
    # Billboards are at most ~230px wide on screen, even zoomed in.
    if name == 'ad_sponsors':
        # One 256x96 billboard per 1024x384 atlas cell.
        return size[0] // 4, size[1] // 4
    if name.startswith('ad_'):
        return 256, 96
    return None


def optimize(path):
    raw = path.read_bytes()
    size = struct.unpack_from('<I', raw, 12)[0]
    doc = json.loads(raw[20:20 + size])
    binary = raw[28 + size:]
    replacements = {}
    report = []
    for image in doc['images']:
        view_id = image['bufferView']
        view = doc['bufferViews'][view_id]
        start = view.get('byteOffset', 0)
        payload = binary[start:start + view['byteLength']]
        im = Image.open(io.BytesIO(payload))
        before = im.size
        target = limit(image.get('name', ''), before)
        if target:
            target = tuple(min(a, b) for a, b in zip(before, target))
            # BOX averages data masks without ringing; LANCZOS retains artwork.
            data_map = image.get('name', '').endswith(('_mr', '_normal', '_emit'))
            im = im.resize(target, Image.Resampling.BOX if data_map else Image.Resampling.LANCZOS)
            out = io.BytesIO()
            im.save(out, format='PNG')
            replacements[view_id] = out.getvalue()
        report.append({'name': image.get('name'), 'before': before, 'after': im.size})
    packed = bytearray()
    for index, view in enumerate(doc['bufferViews']):
        start = view.get('byteOffset', 0)
        payload = replacements.get(index, binary[start:start + view['byteLength']])
        packed.extend(b'\0' * (-len(packed) % 4))
        view['byteOffset'] = len(packed)
        view['byteLength'] = len(payload)
        packed.extend(payload)
    doc['buffers'][0]['byteLength'] = len(packed)
    packed.extend(b'\0' * (-len(packed) % 4))
    encoded = json.dumps(doc, separators=(',', ':')).encode()
    encoded += b' ' * (-len(encoded) % 4)
    result = (struct.pack('<III', 0x46546c67, 2, 28 + len(encoded) + len(packed))
              + struct.pack('<II', len(encoded), 0x4e4f534a) + encoded
              + struct.pack('<II', len(packed), 0x004e4942) + packed)
    path.write_bytes(result)
    print(json.dumps({
        'glbBytesBefore': len(raw), 'glbBytesAfter': len(result),
        'rgba8BaseMiBBefore': sum(x['before'][0] * x['before'][1] * 4 for x in report) / 1048576,
        'rgba8BaseMiBAfter': sum(x['after'][0] * x['after'][1] * 4 for x in report) / 1048576,
        'images': report,
    }, indent=2))


if __name__ == '__main__':
    optimize(Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT)
