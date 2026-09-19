# ゆめみん 両目の白い隙間修正

最新モデル: `yumemin_clean_v2.glb`。元版は `../cleanup_20260919/`。

前回、Tripoの独立した目のメッシュを交換した際、身体側に左右2個の穴（境界辺78本）が残っていた。背景が縁から見える原因となったため、身体と同じ水色の面で両方を閉じた。

目のメッシュ座標・大きさ・配置・材質は変更していない。元の身体頂点も形状変更せず、接合面のみ追加。UV分割の重複頂点を結合し、法線を再計算。

GLB再読み込み後、身体・両目すべての開いた境界辺が0本であることを確認。左右の接写、正面、両斜め、見上げの6画像を `qa/` へ保存し、背景が見える白い隙間がないことを目視確認した。結果は `validation.json`。

再現: Blender backgroundで `fix_eye_seams.py` を実行する。追加API生成・課金なし。

## 公式サイト採用（2026-09-19）

ユーザー採用済み。公式サイトの3D表示とARはこのGLBを共通利用する。静的モデルで、リグ・モーションなし。サイト側へ複製せず `public/models/characters/yumemin.glb` から相対symlinkで参照。

- 3D: https://madogiwa.work/characters/yumemin
- AR: https://madogiwa.work/camera/yumemin
- AR初期サイズ: 大きめ60cm、ぬいぐるみ20cm、自撮り12cm。設定上の身長を定義するものではない。
- USDZはブラウザ内で生成。iPhone SafariのQuick Look向け。実機での空間配置確認は別途必要。
- 採用GLBをGit管理。Blender編集ファイル・修正前素材・QA画像はローカル保持。

公開前検証：公式サイトのローカルページで正面表示・顔アップ、60cm/20cm/12cmすべてのUSDZ生成完了を確認。`npm run verify`（48 tests、型検査、lint、build、Worker startup、deploy dry-run）成功。iPhone実機のAR配置は未確認。
