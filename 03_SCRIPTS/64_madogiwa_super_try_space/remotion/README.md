# 宇宙HUD試作

2026-09-09。第二弾の本番制作前の見た目検証。完成30秒動画ではない。

## 再生

`out/hud_test.mp4`: 832×480、30fps、8秒、240フレーム、無音。
通常通信→接近警告→そば屋識別。タイミングはsrc/edit-manifest.json。

npm ci / npm run typecheck / npm run render
Remotion 4.0.522（2026-09-09 npm view remotion versionで確認）。ローカルでは既存episode63の同一依存へのnode_modules symlinkを使用。新規環境はnpm ciで復元可能。

## 仮素材

public/space_plate.png: built-in image_genで生成した文字なし静止宇宙背景。元生成ID 01a08360-58cb-7342-956d-8ad1e16c95c1。ローカル検証素材で本番未採用、Git除外。
public/okayaman.jpg: 02_CHARACTERS/Okayaman.jpgのコピー。静止画のため演技や口の同期は未検証。Git除外、再試作時は正典からコピーする。
そば屋の映像は未挿入。追跡枠は仮の軌道であり物体追跡ではない。音声波形も演出上の仮表示。

## 判定

通常・警告・識別の480p PNGを目視。主警告、日本語字幕の判読・文字切れなし。補助計器の小文字は雰囲気用で物語を依存させない。
TypeScript合格。ffprobeで832×480、30fps、8.000秒、240フレーム確認。ffmpeg終端デコード合格。
実時間の試聴、動く人物との合成、実映像への追従とバイザー光学表現は未検証。

推奨分担: Wanに宇宙・船外作業・普段着のそば屋・通信人物の演技・照明を担当させ、Remotionで字幕、警告、数値、細いHUD、商品コピーを合成。
HUDはヘルメット内の主観カット限定。外からヘルメット曲面越しに見るHUDはWanの光・反射と設計を合わせる必要あり。
今回の試作はRemotion実装可能性の確認であり、Wanとの実生成A/B比較ではない。Wan APIは未実行。
