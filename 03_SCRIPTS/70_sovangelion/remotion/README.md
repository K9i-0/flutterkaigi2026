# 第70話リメイクの結合編集

Remotion 4.0.526。`src/edit-manifest.json`が編集タイミングの正本（30fps、740フレーム）。初回動画0〜139フレームと新規20秒をハードカットで接続。生成済みの映像・音声はそのまま保持。

`public/opening-original.mp4`は初回動画、`public/remake.mp4`はリメイク生成素材へのローカルhardlink。別環境ではエピソード直下の対応するMP4からhardlinkまたはコピーを作る。MP4はGit対象外。

```sh
npm ci
npm run typecheck
npm run render -- --browser-executable='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
```

出力は`out/remake_review.mp4`。確認用コピーはエピソード直下`review_remotion_remake_v1.mp4`。採用済み完成版とは区別する。

生成映像内のドック→搭乗席は短いディゾルブになった。最後のやめ太郎は笑顔寄り。これらは生成結果のまま。窓外たこさんの動作・瓦礫・粉塵の継続は終盤4fpsと最終フレームで確認。音声・口形の完全一致は未認証。詳細は`../generation_record_remake_v1.json`。

## 19時版 v2

現行 `src/edit-manifest.json` は752フレーム。初回140＋既存ドック372＋19時版搭乗席240。`edit-manifest-remake-v1.json` に旧版を保持。`public/cockpit-19h.mp4` は `../wan3_result_cockpit_19h_v2_480p.mp4` へのhardlink。確認版は `../review_remotion_remake_19h_v2.mp4`。

## 3分の戦闘拡張版

`SovangelionBattle`はRemotion + Three.jsによる196秒・720p・24fpsの独立Composition。旧`SovangelionRemake`は保持。

```sh
python3 ../prepare_battle.py
npm ci
npm run typecheck
npm run render:battle
```

出力は`../final_remotion_battle_v5.mp4`。台本と制作・監査記録は`../script_battle.md`。タイムラインは`src/battle-manifest.json`、映像は`BattleFilm.tsx` / `BattleScene.tsx`。正典モデルと採用音声・画像を`prepare_battle.py`が`public/battle/`へhardlinkする。
