# そば屋 — animation quality revision 2

`tools/build_sobaya_rig_v2.py`で再生成する検証用GLB。Tripo原型とrig_v1を残した派生版。43骨（裾補正2骨を含む）、28,576三角面、9クリップ、4ウェイト以内。

- 元のquad `.blend`から開始（ローカルにない場合は正典`sobaya_preview.glb`へフォールバック）。初版の座標による胴体ウェイト上書きを外し、袖口の内側も上腕へ追従。腕の向きを維持しながら鎖骨を連動。
- シャツの白いUV領域を選び、腿の前進時に裾を逃がす補助骨へベイク。服の物理シミュレーションではない。
- 仮面の眼孔に不透明Unlit黒の内張り。仮面の法線ノイズを局所的に抑制、額の不要な突起を平滑化。
- 手は関節位置に合わせた局所メッシュへ置換し、元の手首境界へ接続。指は取っ手を包む2節IKを個別にベイク。元の肌の色・粗さを新しいUVへ投影し、指を細分化して滑らかにした。
- ジョッキの向きを前腕に合わせ、握りを乾杯・攻撃全区間で共有。`PropSocket.R`は別アセットの`Grip`へ取り付ける。

Blender固有のPreserve Volumeや未適用モディファイアには依存しない。実行時は通常のglTF骨アニメーション。編集用`.blend`はローカル保持、GLB・生成コード・メタデータを追跡する。

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/build_sobaya_rig_v2.py
python3 tools/validate_sobaya_rig.py rig_v2
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/review_sobaya_quality.py
```

肩0/45/90/135/160度の正面・側面・背面、全クリップの代表姿勢、顔・握りアップのローカル証跡は`21_SOBAYA_HAZARD_LAB/evidence/quality-v2/`。構造検査PASSは造形の完成保証ではない。手の細かな皮膚・爪、仮面の眼孔輪郭、極端な腕上げの脇皺は追加調整対象。
