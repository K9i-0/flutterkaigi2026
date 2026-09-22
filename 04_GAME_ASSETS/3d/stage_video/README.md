# Three.js舞台動画キット

入口は `.claude/skills/threejs-video/SKILL.md`。既存73/74を変更せず、新しい作品から利用する共有コード。

- `motion-player.ts`: clone済みGLBごとにcreateMotionPlayerを作り、sample(name, shotLocalSeconds)で任意フレームを再現。毎回rest・モーフを復元。立ち芝居は必要な基準clipを厳密に選択。犬動作はclipを重ねない。
- 演技本体の正本: `../motions/skit_v1/motions.ts`、`flashback-motion.ts`。コピー・改名して分岐させずここを参照。
- 立ち芝居: Explain / InspectMug / SketchMug / SniffMug / ListenFoam / EmptyHands / Conjure / ProudToast（そば屋）、Tsukkomi / Wish / DoubleTake / Listen（やめ太郎）。対象・基準clip・参考尺はcatalog。
- 犬: DogLapping（その場で舐める）、DogSniff（周囲を嗅いで歩く）。そば屋v3専用。DogSniffはmotionPlacementとsampleへ同じ秒を渡す。内groupへ移動、外groupへ舞台配置・向き。対象小道具は外group座標でx=.035,z=.17。172/24秒で停止し、自動ループしない。ループ末尾へ単純modをかけると位置が飛ぶ。
- 舌、ジョッキ、缶、ペンなどは動作に含まれない。手や頭のboneに小道具を追従させる。犬から直立する移行クリップも未収録。カットでつなぐか、接地を確認した専用移行を制作する。
- 背景壁・床とGLB役者のReact雛形はスキルのscripts/init_project.pyが生成。背景パラメータは作品側で変更する。

元動作はプロジェクトの手続き型演技。基準GLBの既存clip・モデルの利用条件は別に保持する。全キャラ共通対応とは扱わない。新モーション追加時は対象モデルのパス・基準姿勢・単位・尺・ループ・小道具・確認画像を記録し、catalogと確認ケースを追加する。

## 初回検証（2026-09-23）

- 新規雛形を.local/threejs-video-kit-checkへ生成し、既存74と同じインストール済み依存を使ったTypeScript検査に合格。クリーンなnpm ciは今回未実施。
- StageStudyを854×480、24fps、192フレームの無音MP4へ実レンダー。8時点の画像で犬の周回とモデル・背景表示を確認、終端までデコード成功。背景と床の境界は意図的に未装飾のセット確認用。
- 正典そば屋GLBのリグで、親groupの移動・回転を含む任意時刻seek、立ち芝居→犬への姿勢リセット、骨行列の有限値、非対応キャラ拒否を検査。2.3秒→6.5秒→0秒→2.3秒の姿勢が一致。
- 素材準備の冪等性、既存project上書き拒否、public外へのパス拒否を検査。
- 無音のため音声・口パクの検証は対象外。完成映像の演技の自然さは作品ごとに確認する。
