#!/bin/bash
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
IRODORI="$PROJECT_ROOT/.claude/skills/seedance/scripts/irodori_speak.sh"
MONSTERIZE="$PROJECT_ROOT/.claude/skills/seedance/scripts/sobaya_monsterize.sh"
OUT_DIR="$SCRIPT_DIR/audio"
TASK_TMP="$(mktemp -d /private/tmp/ep55_dialogue.XXXXXX)"

mkdir -p "$OUT_DIR"

YAMETARO_CAPTION="本人の中音域と柔らかな関西イントネーションを保つ成人男性。生配信でテンションが上がったお調子者として、明るく勢いよく、声に笑顔を乗せ、テンポよく大きめの抑揚で話す。眠そう・落ち着きすぎ・低い独白調にはせず、語尾を前向きに跳ね上げる。叫び声にはしない。"
YAMETARO_FAST_CAPTION="本人の中音域と柔らかな関西イントネーションを保つ成人男性。生配信でテンションが上がったお調子者として、明るく勢いよく、声に笑顔を乗せ、間を空けずかなりテンポよく一息で話す。眠そう・落ち着きすぎ・低い独白調にはせず、語尾を前向きに跳ね上げる。叫び声にはしない。"
YAMETARO_CLUELESS_CAPTION="本人の中音域と柔らかな関西イントネーションを保つ成人男性。勤務中の飲酒が禁止だと本気で知らない非常識なお調子者として、悪びれず不思議そうに、明るく無邪気な調子で問いかける。慌てたり冗談めかしたりせず、本人だけは心底普通の質問だと思っている。眠そう・落ち着きすぎ・低い独白調にはしない。"
SOBAYA_CAPTION="低く太い成人男性。隠す気がまったくなく、酒のジョッキを掲げて上機嫌に、短く勢いよく乾杯を宣言する。余計な言葉を足さない。"
FUKUCHAN_CAPTION="明るく高めの成人男性。生配信で社外秘を映されて本気で焦り、切迫して強く制止する。笑顔や呑気さは出さず、短く鋭く言い切る。"

"$IRODORI" "今からオフィスの様子を配信するやで！" "$OUT_DIR/yametaro_01_start_seed100.wav" "$PROJECT_ROOT/02_CHARACTERS/Yametaro_voice.wav" 100 "$YAMETARO_CAPTION"
"$IRODORI" "じゃーん、彼が窓際族のエース、そば屋やで！ お、そば屋さん、勤務中に酒かー？" "$OUT_DIR/yametaro_02_sobaya_intro_seed100.wav" "$PROJECT_ROOT/02_CHARACTERS/Yametaro_voice.wav" 100 "$YAMETARO_FAST_CAPTION"
"$IRODORI" "え、普通の会社は酒ダメなん？" "$OUT_DIR/yametaro_03_office_alcohol_question_seed100.wav" "$PROJECT_ROOT/02_CHARACTERS/Yametaro_voice.wav" 100 "$YAMETARO_CLUELESS_CAPTION"
"$IRODORI" "福ちゃん！ ギュンにちわやで！" "$OUT_DIR/yametaro_04_fukuchan_greeting_seed100.wav" "$PROJECT_ROOT/02_CHARACTERS/Yametaro_voice.wav" 100 "$YAMETARO_CAPTION"

"$IRODORI" "かんぱーい！" "$TASK_TMP/sobaya_raw_seed42.wav" "$PROJECT_ROOT/02_CHARACTERS/Sobaya_voice.wav" 42 "$SOBAYA_CAPTION"
"$MONSTERIZE" "$TASK_TMP/sobaya_raw_seed42.wav" "$OUT_DIR/sobaya_01_kanpai_seed42_monster.wav"

"$IRODORI" "ちょ、やめ太郎！ 今はあかん！" "$OUT_DIR/fukuchan_01_stop_seed100.wav" "$PROJECT_ROOT/02_CHARACTERS/Fukuchan_voice.wav" 100 "$FUKUCHAN_CAPTION"

echo "Temporary raw Sobaya voice: $TASK_TMP/sobaya_raw_seed42.wav"
