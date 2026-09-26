# 歩行・ジャンプ・足跡 QA

Mac debug、Dart MCP起動・Marionette操作。Flutter GPU/SDK/forkへの追加変更なし。

- `flutter analyze`: No issues。
- `flutter test`: 16件通過。カメラのup×forwardと左右移動の一致、斜め速度、ジャンプ・空中移動・二段ジャンプ防止、箱・円柱への着地、天井で横に弾かれないこと、薄い柵・回転箱の衝突、段差、壁押しで足音距離が蓄積しないことを含む。
- UIの右矢印を1.6秒押して浅瀬のx=5→9.38、z=-45維持を確認。yaw=πのカメラでは+xが画面右。足跡6個、濡れ砂の足音イベント増加、音error=null。
- UIジャンプボタンを押し、地面y=.312からy=1.208へ上昇、横移動も確認。その後y=.317へ着地、grounded=true、jumps=1 / landings=1。
- 元の桟橋の入口で柵・柱・段差との衝突を確認。端に寄ったまま前進・右移動すると阻まれる。桟橋入口は中央へ寄るかジャンプして登る。
- [足跡表示](footprints.png)を確認。playerTime=188.72時点で8個。その場でシミュレーションを21秒進め、playerTime=210.58で0個。[消去後](footprints-expired.png)は同じカメラ・位置。
- runtime errorsなし。変更後のDartはhot reload済み。足跡.fmatは完全再起動でbuild hookを再実行。

音源の再生イベント／エラーを確認。システム出力の録音・聴感監査、iPhone/Androidの実機確認は未実施。衝突は既存の回転箱・円柱に基づく簡易形状で、全装飾のメッシュ衝突ではない。足跡は最大48枚の小さい地形追従メッシュで、砂の立体変形ではない。
