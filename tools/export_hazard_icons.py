"""Export the approved C artwork into native launcher icon catalogs (macOS sips)."""
import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LAB = ROOT / '21_SOBAYA_HAZARD_LAB'
SOURCE = ROOT / '04_GAME_ASSETS/3d/ui/hazard/icon-concepts-20260908/C-stalker.png'
ADAPTIVE_SOURCE = SOURCE.with_name('C-adaptive.png')


def main():
    outputs = {}
    for platform in ('ios', 'macos'):
        folder = LAB / platform / 'Runner/Assets.xcassets/AppIcon.appiconset'
        for item in json.loads((folder / 'Contents.json').read_text())['images']:
            size = round(float(item['size'].split('x')[0]) * float(item['scale'][:-1]))
            outputs[folder / item['filename']] = size
    res = LAB / 'android/app/src/main/res'
    for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
        outputs[res / f'mipmap-{density}/ic_launcher.png'] = size
    outputs[res / 'drawable-nodpi/ic_launcher_art.png'] = 864
    records = []
    for target, size in outputs.items():
        source = ADAPTIVE_SOURCE if target.name == 'ic_launcher_art.png' else SOURCE
        target.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(['sips', '-z', str(size), str(size), str(source), '--out', str(target)],
                       check=True, capture_output=True)
        records.append({'path': str(target.relative_to(ROOT)), 'size': size,
                        'source': str(source.relative_to(ROOT)),
                        'sha256': hashlib.sha256(target.read_bytes()).hexdigest()})
    manifest = SOURCE.parent / 'adopted-C-exports.json'
    manifest.write_text(json.dumps({'source': str(SOURCE.relative_to(ROOT)),
        'sourceSha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        'adaptiveSourceSha256': hashlib.sha256(ADAPTIVE_SOURCE.read_bytes()).hexdigest(),
        'operation': 'Size-only native sips export; approved artwork unchanged, no corner masks.',
        'outputs': records}, ensure_ascii=False, indent=2) + '\n')
    print(f'Exported {len(outputs)} launcher images from approved C artwork.')


if __name__ == '__main__':
    main()
