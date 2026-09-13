# 福ちゃん v2 — 公式3パーツ制作

開始残高: 685 credits（2026-09-13 API照会）。初回見積385、予備300。追加購入なし。

正典: `02_CHARACTERS/Fukuchan.jpg`。体・髪のない頭・髪を別々にP2で生成し、Blenderで各パーツを選択可能なまま組み立てる。

入力: bodyは正面1枚、headは正面・左・背面、hairは正面・背面。body背面候補は手の表裏に曖昧さが残るため生成入力には使用しない。hair側面候補は斜め向きのため使用しない。候補はローカル保持。

作業: 全身基準 → 入力部位確認 → 3パーツ生成 → 全方向の接続確認 → 体のリグ再利用またはローカルリグ → 頭・腕・肘・膝の姿勢検査 → 表情と材質 → 3秒の挨拶 → GLBと確認ページ。

参考: https://www.tripo3d.ai/blog/gpt-6-astra-3d-character-workflow

完成結果・検証・再現手順は [README.md](README.md)、確定費用は [provenance.json](provenance.json) を参照。
