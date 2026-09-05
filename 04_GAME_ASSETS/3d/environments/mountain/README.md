# そば屋ハザード — 山道・廃屋

`mountain.glb` と `mountain.json` が描画・当たり判定・配置の正本。Flutterから相対symlinkで参照する。

生成: `Blender --background --factory-startup --python tools/build_hazard_regions.py`（リポジトリルート）。共有の建物・材質・単位は `tools/hazard_environment_kit.py`。

7,501 三角面 / 20 meshes / 13 materials / 8,673,852 bytes。1 unit=1m。外部ファイル参照なしのpacked GLB。Flutter Sceneで読み込み時に圧縮変換する。

参照は[Capcomが公開する原作RE4公式ガイド抜粋](https://static.capcom.com/residentevil/files/ResEvil2.pdf)の印刷p59。農場の南西入口・中央小屋・南東二階建て納屋・東出口、山道の曲がり角・トンネル・廃屋の位置関係を新規モデリングした。ガイド画像や原作モデルの取り込みではなく、厳密な寸法・形状の1:1再現は未達。壁の画像は窓際族物語の既存正典素材を使用。

石壁と地面は村と共通のImagegenテクスチャ。山道の岩肌は周期的なノイズと層模様をBlenderスクリプトで合成した専用材質。岩の輪郭は分割した面で作り、歩行用の衝突形状は単純な箱として保つ。

農場: 小屋3軒＋二階建て納屋、囲い、井戸、補給所、画像3枚、青いメダリオン7個、そば屋6体。山道: 曲がる通路、トンネル、廃屋、画像3枚、そば屋6体（うち1体が最終戦）。配役と数量はJSONを正本とする。

実画面での仕上げ・通常操作による長時間通しプレイは体験版全体の監査を継続する。背景遠景、室内細部、イベント演出は追加予定。
