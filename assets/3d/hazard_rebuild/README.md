# 再設計版の人物資産

`locomotion_v1/` は福ちゃん・そば屋の既存承認済み身体と、独立制作のIdle/Walk/Runだけをまとめた派生GLB。身体の頂点編集は行わず、不要な小道具・他の動作を除外している。旧ゲームの歩行素材は含めない。元のcanonicalモデルは保持する。

生成: Blenderで `24_SOBAYA_HAZARD/tools/prepare_characters.py -- INPUT_DIRECTORY OUTPUT_DIRECTORY`。入力SHAと出力SHAはcharacters.json。入力の独立制作クリップ一式は別保管で、再生成入力アーカイブのこのリポジトリへの移管は未完了。派生出力を元のcanonical入力へ上書きしない。

60Hzでimport/exportし、Idle2秒、Walk0.8秒、Run2/3秒を保持する。ゲームは相対symlinkで参照する。任意のVRMに適用できる汎用モーション素材としては扱わない。
