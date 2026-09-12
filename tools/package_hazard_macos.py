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
DEFAULT_APP = LAB / 'build/macos/Build/Products/Release/そば屋ハザード.app'


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
    for folder in ['audio', 'audio/voice', 'audio/soundscape', 'audio/combat', 'collection']:
        for file in (LAB / 'assets' / folder).rglob('*'):
            if file.is_file():
                match(file, assets / 'assets' / folder / file.relative_to(LAB / 'assets' / folder))
    manifest = json.loads((assets / 'flutter_scene_generated/manifest.json').read_text())
    if manifest != json.loads((LAB / 'flutter_scene_generated/manifest.json').read_text()):
        raise ValueError('Bundle scene manifest differs from the generated scene catalog')
    expected = {'beer_mug', 'farm', 'fukuchan', 'items', 'mountain', 'sobaya', 'takosan', 'village', 'yametaro'}
    found = {entry['id'].split('/')[-1] for entry in manifest['entries'] if entry['family'] == 'scene'}
    if found != expected:
        raise ValueError(f'Unexpected model catalog: {found}')
    scene_sources = []
    for entry in manifest['entries']:
        match(LAB / 'flutter_scene_generated' / entry['file'], assets / 'flutter_scene_generated' / entry['file'])
        if entry['family'] == 'scene':
            source = (LAB / entry['source']).resolve(strict=True)
            scene_sources.append({
                'id': entry['id'], 'source': str(source.relative_to(ROOT)),
                'sourceSha256': sha(source), 'compiledFile': entry['file'],
                'compiledSha256': sha(assets / 'flutter_scene_generated' / entry['file']),
                'importStamp': entry['stamp'],
            })
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
        'displayName': info.get('CFBundleDisplayName', info['CFBundleName']),
        'appIconSha256': sha(app / 'Contents/Resources/AppIcon.icns'),
        'version': info['CFBundleShortVersionString'],
        'architectures': checked(['lipo', '-archs', str(exe)]).split(),
        'declaredMinimumMacOS': info['LSMinimumSystemVersion'],
        'signatureIntegrity': 'codesign --verify --deep --strict passed',
        'signatureDistribution': 'ad hoc; not notarized',
        'sceneCount': len(found), 'voiceCueCount': len(voice),
        'sceneSources': scene_sources,
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
村・農場・山道を探索し、そば屋の視界を避け、誘導や戦闘を使い分けて脱出を目指します。

WASD / 矢印: 移動   Shift: 走る   Z（またはCtrl）: 忍び足   ドラッグ: 視点
Q: 構える   Space: 射撃   R: リロード   E: 調べる・拾う・はしご・窓越え
1 / 2 / 3: 銃の切替   4: ビール   H: ハーブ
掴まれた時: Eまたは画面の脱出ゲージを長押しして振りほどく
Tab: 持ち物   M: 地図   C: 記録   Esc: 一時停止・保存

装填弾が0の時に射撃を押すと通常のリロードを始めます。装填後にもう一度射撃を押すと発砲します。
Rで早めに手動リロードすることもできます。回避と蹴りは廃止し、通常移動やダッシュで攻撃を避けます。
MacのCtrl＋矢印はOSの画面切り替えと競合するため、忍び足はZを使ってください。
背後から静かに近づくとEでビールを壊してステルス撃破できます。
4でビールを選び、Qで構えて軌道と着地点を確認し、Spaceで1杯投げます。
スマホ操作では下部の装備表示からビールを選び、「構える」→「投げる」。操作ボタンはモードに合わせて切り替わります。
ビールは補給所で払う分と同じ所持数を消費します。未警戒なら一体が調べに行き、目視追跡中は福ちゃんを優先します。
村入口と道中で戦わずビールを拾えます。最高難度でも村・農場は全員を倒さずに通過できます。
目視した敵を地図に記録します。追跡は赤、捜索は橙、帰還は灰緑、その他は黄です。見失った敵の点は最後に見た場所に残ります。
見つかったら建物で視界を切り、Zの忍び足で別の死角へ。最初の角で止まるだけでは確認されることがあります。
捜索中は残り時間と理由を表示します。足音や新しい銃声で捜索が延び、姿を見せると再追跡されます。
解除後もそば屋は持ち場へ戻るので、帰り道へ飛び出さず動きを確認してください。
追跡では強い音楽、捜索では打楽器が引き、敵の足音を聞いて判断できます。
設定の「緊張感の画面演出」は周辺の色・脈動だけを調整します。0%でも状態表示とBGMは残り、音量は別設定です。
ショットガンは単体攻撃で、通常敵にはヘッドショット一発。大きい銃声で周囲の注意を引きます。
設定の「タッチ操作を常に表示」で画面スティック・操作ボタンも使用できます。
設定の「映像」ではバランス／高画質／最高画質を選べます。Macの初期値は高画質です。
解像度65／85／100%は演出と独立して変更できます。M4 Macでの最初の確認は高画質・85%を目安にしてください。
この目安は全機種・全場面の60fpsを保証するものではありません。測定条件はプロジェクトのGRAPHICS.mdを参照してください。

新しく始めると進行記録を上書きします。収集した記録は維持します。

制作途中のプレビューです。福ちゃん・やめ太郎の口は音声の強弱に同期します。音素別の口形は未実装です。
掴み・抵抗・振りほどきを実装しています。手指や全身の反応は調整中です。
はしごと窓は敵も追跡に使います。窓越えの手の接触や服の伸縮は調整中です。
掴みの操作確認はApple SiliconのMacのdebug版で実施しました。
このRelease版の画面操作と、Intel・他のMac環境は未実機確認です。
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
