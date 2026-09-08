# リターゲットと本編採用

## 入出力を分ける

| 用途 | 場所 |
| --- | --- |
| 元モデル・既存動作 | `04_GAME_ASSETS/3d/motion_library/{sobaya,fukuchan}/` |
| 公開モーション入力 | `04_GAME_ASSETS/3d/motion_library/source/`、取得は `tools/fetch_humanoid_motion.py` |
| 修正版VRM | `04_GAME_ASSETS/vrm/characters/` |
| 体格別VRMA | `04_GAME_ASSETS/vrm/motions/` |
| 比較中間出力 | `.local/vrm-validation/`、`.local/dance_deformation/` |
| 本編用派生GLB | `04_GAME_ASSETS/3d/hazard_adopted/` |

元のmotion_libraryを採用済みGLBで上書きすると再生成入力が循環する。ゲームの `assets/models/` はhazard_adoptedへの相対symlinkを使う。新しい派生物を作る際も元クリップID、顔・体格、表情、ジョッキソケットと裾補助骨を保持する。

## 既存の生成経路

必要な段階だけ実行する。フル再生成は次の順序。Blender実行例は `Blender -b --factory-startup --python tools/<script>.py`。Macの実体は `/Applications/Blender.app/Contents/MacOS/Blender`。

1. `improve_vrm_deformation.py`：元GLBから肩ウェイトを整え、VRMと未修正比較モデルを出力。
2. `build_vrm_motions.py`：待機・歩行・Sprint・ダンス3種を体格別に出力。未修正版が必要なら別途 `-- --baseline`。
3. `build_vrm_run_candidates.py`：Jog / 既存Mixamo Run / 逃走・追跡の各候補。
4. `node tools/validate_humanoid_vrm.mjs` と `node tools/validate_vrm_motions.mjs`。後者は基本と候補の中間GLBが必要で、計18 VRMAを検証。
5. 採用する場合は `build_hazard_adopted_motion.py`、続いて `node tools/validate_hazard_adopted.mjs`。

`export_humanoid_vrm.py` はラッパー。直接CLI実行で修正前モデルへ戻さず、上の生成経路を使う。骨の役割の対応付けはTポーズ再バインドや全軸の統一を意味しない。VRMAには対応骨の回転とhips移動だけを書き出す。

## 肩・腕の変形で得た知見

実装は `tools/humanoid_deformation.py`、根拠は `04_GAME_ASSETS/vrm/DEFORMATION_REVIEW.md`。

- 採用処置はUV境界の同位置頂点も考慮する肩ウェイト3回平滑化と、ダンスの軸回りねじれの制限。単純な隣接頂点だけの平滑化では継ぎ目が割れた。
- 鎖骨10°・上腕45°・前腕60°はこの2モデル向け調整値。人間の一般的な可動域ではない。全ねじれを0にする処置や強い平滑化は悪化する場合があった。
- 専用ツイスト骨がなく、DQ/Preserve Volumeだけでは肉の向きは直らなかった。鎖骨ウェイトの上腕移管や肩支点の小移動も一律の改善にはならなかった。支点移動の試験は完全な再バインド検証ではない。
- 顔・頂点位置・面・モーフ・初期骨行列を保持してウェイトを修正する。非スキン小道具はウェイト正規化検査の対象から除く。
- 四元数の比較・補間は符号を揃える。`body.rest` はrig空間のmatrix_local。ワールド行列と混同しない。

実験用 `tools/probe_dance_deformation.py` は不変のbaselineから毎条件を開始する。全骨を親順に復元してview-layerを更新し、ウェイトも戻す。サンプル後のactionを外さないとレンダー時に試験姿勢が上書きされる。`tools/review_dance_deformation.py` で複数位相・斜め両側の画像を比較できる。局所的な袖・脇の皺は残るため、全動作で完全としない。

## 本編で確認すること

`hazard_adopted/README.md` とmanifest、`lib/game/game_motion_blend.dart` が採用経路の入口。2026-09-08の選択は福ちゃんRun、そば屋Candidate_Chase_Run。逃走・追跡はJogを周期・腕振り・前傾で調整した派生で、新収録素材ではない。

その場プレビューと移動ゲームは別。manifestの足の後退速度から求めた再生基準を、衝突解決後の実移動量へ合わせる。クリップを変えたら再生基準、歩走の位相継承、ジョッキ握りオーバーライドとソケット追従を確認する。

本編は `21_SOBAYA_HAZARD_LAB/lib/game_main.dart`。`lib/main.dart` は検証ラボ。起動・専用extensionは同ディレクトリの `MCP_DEBUGGING.md` を読む。GLB変更はビルドフックの再変換が必要で、hot reloadだけでは反映されない。初回変換の起動タイムアウト時は残ったビルドの進捗を確認し、重複ビルドを乱立させない。

Dart MCP起動後の新しいappURI / DTDURIを使い、Marionetteは別途接続する。extensionのコールバック変更がhot reloadで残った実例があるため、必要ならhot restartし、Marionetteも再接続する。古いURIやPIDを再利用しない。

`madogiwa.inspectHazardGame` のsourceMotion / motionSeconds / enemyMotions / enemyMugGripErrorsを実表示と照合する。`posePreview=true` は時計を止めるため、連続再生の証拠にはならない。

未発見ダンスの確認には `madogiwa.openGameScenario` の `ambientDance`。通常そば屋は生成時20%で3種から抽選、ボス除外、発見・被弾・攻撃などで解除し一度警戒した個体は再開しない。連続再生と発見時の中断、チェックポイント復元を確認する。射撃で試す場合は `gameAction` のaim後にfire。

採用変更では対象のFlutterテスト・analyze・ネイティブ描画を確認する。文書だけの変更でゲーム全ビルドは不要。過去の証跡は `21_SOBAYA_HAZARD_LAB/qa/adopted-vrm-and-dance-20260908.json`。新しい作業の検証済み証拠として流用しない。
