"""Audit and package an already-built, private Mac preview of Sobaya Hazard.
Run after flutter build macos --release -t lib/game_main.dart. This does not
upload, notarize, modify signatures, or include source models/credentials.
"""
import argparse
import datetime
import hashlib
import json
import plistlib
import subprocess
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LAB = ROOT / '21_SOBAYA_HAZARD_LAB'
DEFAULT_APP = LAB / 'build/macos/Build/Products/Release/sobaya_hazard_lab.app'


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def checked(command):
    return subprocess.run(command, check=True, text=True, capture_output=True).stdout.strip()


def audit(app):
    app = app.resolve(strict=True)
    checked(['codesign', '--verify', '--deep', '--strict', str(app)])
    for file in app.rglob('*'):
        if file.is_symlink() and not file.resolve(strict=True).is_relative_to(app):
            raise ValueError(f'Bundle symlink escapes application: {file}')
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    assets = app / 'Contents/Frameworks/App.framework/Versions/A/Resources/flutter_assets'
    matched = {}

    def match(source, destination):
        if not destination.is_file() or sha(source) != sha(destination):
            raise ValueError(f'Missing or stale bundle asset: {destination}')
        matched[str(destination.relative_to(assets))] = sha(destination)

    for region in ['village', 'farm', 'mountain']:
        match(LAB / f'assets/{region}.json', assets / f'assets/{region}.json')
    for folder in ['audio', 'audio/voice', 'audio/soundscape', 'collection']:
        for file in (LAB / 'assets' / folder).rglob('*'):
            if file.is_file():
                match(file, assets / 'assets' / folder / file.relative_to(LAB / 'assets' / folder))
    manifest = json.loads((assets / 'flutter_scene_generated/manifest.json').read_text())
    expected = {'beer_mug', 'farm', 'fukuchan', 'items', 'mountain', 'sobaya', 'takosan', 'village', 'yametaro'}
    found = {entry['id'].split('/')[-1] for entry in manifest['entries'] if entry['family'] == 'scene'}
    if found != expected:
        raise ValueError(f'Unexpected model catalog: {found}')
    for entry in manifest['entries']:
        match(LAB / 'flutter_scene_generated' / entry['file'], assets / 'flutter_scene_generated' / entry['file'])
    voice = json.loads((assets / 'assets/audio/voice-manifest.json').read_text())['clips']
    for clip in voice:
        source = LAB / 'assets' / clip['asset']
        destination = assets / 'assets' / clip['asset']
        match(source, destination)
        # Procedural nonverbal cues predate manifest hashes; still compare
        # their bundled bytes to the canonical local asset above.
        expected_hash = clip.get('sha256')
        if expected_hash is None and clip['kind'] != 'nonverbal':
            raise ValueError(f'Missing speech hash: {clip["id"]}')
        if expected_hash is not None and sha(destination) != expected_hash:
            raise ValueError(f'Voice manifest mismatch: {clip["id"]}')
    forbidden = [p for p in assets.rglob('*') if p.suffix in ['.glb', '.fbx', '.blend', '.env']]
    if forbidden:
        raise ValueError('Source/intermediate files must not be bundled')
    exe = app / 'Contents/MacOS' / info['CFBundleExecutable']
    return {
        'date': datetime.datetime.now().astimezone().isoformat(),
        'bundleId': info['CFBundleIdentifier'],
        'version': info['CFBundleShortVersionString'],
        'architectures': checked(['lipo', '-archs', str(exe)]).split(),
        'declaredMinimumMacOS': info['LSMinimumSystemVersion'],
        'signatureIntegrity': 'codesign --verify --deep --strict passed',
        'signatureDistribution': 'ad hoc; not notarized',
        'sceneCount': len(found), 'voiceCueCount': len(voice),
        'assetHashes': matched,
        'appBytes': sum(p.stat().st_size for p in app.rglob('*') if p.is_file() and not p.is_symlink()),
        'binaryHashes': {
            'runner': sha(exe),
            'dartAot': sha(app / 'Contents/Frameworks/App.framework/Versions/A/App'),
        },
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', type=Path, default=DEFAULT_APP)
    parser.add_argument('--revision', required=True, help='Revision used for the build, not inferred from a later dirty worktree')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    report = audit(args.app)
    report['sourceRevision'] = args.revision
    # Never overwrite a previously supplied preview.
    args.output.mkdir(parents=True, exist_ok=False)
    destination = args.output / 'そば屋ハザード.app'
    checked(['ditto', str(args.app.resolve()), str(destination)])
    checked(['codesign', '--verify', '--deep', '--strict', str(destination.resolve())])
    (args.output / 'README.txt').write_text('''そば屋ハザード — Mac検証版

「そば屋ハザード.app」を開いて遊べます。Flutter SDKのインストールは不要です。
村・農場・山道を探索し、そば屋を倒してビールを集め、壁の記録を収集します。

WASD / 矢印: 移動   Shift: 走る   ドラッグ: 視点
Q: 構える   Space: 射撃   R: リロード   E: 調べる・拾う・はしご
X: 回避   F: ひるんだ敵への蹴り   1 / 2: 武器切替   H: ハーブ
Tab: 持ち物   C: 記録   Esc: 一時停止・保存

新しく始めると進行記録を上書きします。収集した記録は維持します。

制作途中のプレビューです。口の動きと台詞の同期、窓越え・掴みは未実装です。
Apple SiliconのMacで起動・操作を確認。Intelと他のMac環境は未実機確認です。
このビルドはローカル検証用のad hoc署名で、Appleの公証は受けていません。
公開配布向けの署名と最終的な安定性確認は別途必要です。
''', encoding='utf-8')
    (args.output / 'build-manifest.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    archive = args.output.with_suffix('.zip')
    if archive.exists():
        raise FileExistsError(archive)
    checked(['ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', str(args.output.resolve()), str(archive.resolve())])
    with zipfile.ZipFile(archive) as bundle:
        if bundle.testzip() is not None:
            raise ValueError('Archive integrity failure')
    summary = {'archive': str(archive), 'bytes': archive.stat().st_size, 'sha256': sha(archive),
               'sourceRevision': args.revision, 'sceneCount': report['sceneCount'], 'voiceCueCount': report['voiceCueCount']}
    (args.output / 'archive-check.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
