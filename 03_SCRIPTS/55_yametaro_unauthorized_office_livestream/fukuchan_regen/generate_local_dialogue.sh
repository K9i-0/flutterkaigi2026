#!/bin/bash
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
IRODORI="$PROJECT_ROOT/.claude/skills/seedance/scripts/irodori_speak.sh"

FUKUCHAN_CAPTION="明るく高めの成人男性。無断配信で突然カメラを向けられて本気で焦り、苛立ちと切迫感を強く出して制止する。笑顔や呑気さは出さず、冒頭から短く鋭く畳みかける。"
YAMETARO_CAPTION="本人の中音域と柔らかな関西イントネーションを保つ成人男性。相手が本気で嫌がっているのに悪気なく距離を詰め続ける、ハイテンションでしつこいお調子者。明るく軽く、間を空けずテンポよく食い下がる。"

"$IRODORI" "ちょ、やめ太郎！ 今はあかん！ カメラ止めろって！" "$SCRIPT_DIR/fukuchan_stop_camera_seed100.wav" "$PROJECT_ROOT/02_CHARACTERS/Fukuchan_voice.wav" 100 "$FUKUCHAN_CAPTION"
"$IRODORI" "ええやん、ちょっとだけ！ 何見てるん？ 見せてや！" "$SCRIPT_DIR/yametaro_keep_pestering_seed100.wav" "$PROJECT_ROOT/02_CHARACTERS/Yametaro_voice.wav" 100 "$YAMETARO_CAPTION"
