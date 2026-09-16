# たこさん・放射状6脚の修正版

2026-09-16のユーザー添付図（上方向が前）に沿い、前斜め左右・真横左右・後ろ斜め左右へ6本を配置。BlenderのPythonコンソールから `tools/revise_takosan_radial_legs.py` を実行して作成した。

- 入力: `../rig_sheet_v2/takosan.blend`。採用済みモデルへの上書きなし。
- 出力: `takosan.blend`（ローカル編集用）、`takosan.glb`（リグ・3動作付き）。
- Blender正面は-Y。脚の骨の基準方向は -120° / -60° / 0° / 60° / 120° / 180°。
- 左右の一体化した脚は固定。独立した4本の脚メッシュと各3関節のレスト姿勢を同じ角度だけ回転。
- 頭・顔・ローブ・人間型の腕と手、UV、材質、ウェイト、アニメーションキーは維持。脚の巻き方・長さは元モデル由来で左右完全対称ではない。
- 17,591三角面、27骨、Idle / Talk / Wave（各3秒）。`validate_hazard_npc.py` の構造・ウェイト・ループ検証がPASS。
- Blenderで正面・上面・下面とWaveの静止姿勢をレンダリングして確認。`preview_*.png` はローカル確認用でGit対象外。
- 公式サイト・そば屋ハザードの参照先は変更していない。

再生成は元のblendをBlenderで開き、Pythonコンソールで次を実行する（パスは環境に合わせる）。

```python
exec(compile(open('/path/to/repository/tools/revise_takosan_radial_legs.py').read(), 'revise_takosan_radial_legs.py', 'exec'))
```

## 中央残骸の除去

同日の追加修正で、下面中央のU字状残骸381頂点を除去し、内側の開口部を既存の暗い布材質による4面で閉じた。周囲6本の脚の頂点位置は保持。再生成スクリプトは `tools/clean_takosan_radial_center.py` を呼び出す。GLBを再出力し、構造・ウェイト・3動作のループ検証を再度PASS。下面と正面、Wave姿勢の確認画像も更新済み。
