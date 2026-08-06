# 採用済み本番参照画像の生成プロンプト

動画25から `scene_01_studio_start_production.png`、`logo_yume_tele_master.png`、`screen_morning_clock_production.png` を実ファイルとして流用。新規生成には built-in `image_gen` を使用した。

## `prop_bug_deity_yametaro_statue_production.png`

- identity source：`03_SCRIPTS/00_TEMPLATES/characters/character_yametaro_toy_diorama_3d_basic_sheet.png`
- 用途：Seedanceへ直接入力する、バグ神様の完成石像正本。
- 生成指定：やめたろうの大きな丸い髪、中央の三角形の生え際、丸メガネ、丸頬、小さな笑顔、短い体、襟付き葉柄シャツ、短い脚と靴を、単一の灰色御影石へ変換する。葉柄は浅い石彫り。全身と矩形台座を含む。生身の色、人物、神社背景、文字、銘板、説明パネル、複数ビュー、仏像化、狐・狛犬・悪魔化、透かしを禁止。

## `scene_02_yumemi_shrine_start_production.png`

- edit target：採用したゆめみ神社拝殿の側面構図。
- identity source：`character_fukuchan_basic_sheet.png`。
- prop source：`prop_bug_deity_yametaro_statue_production.png`。
- 用途：4.0秒のハードカット直後へ完全一致させる本番開始フレーム。
- 生成指定：画面左の祭壇に石像1体。中央から右に成人神社関係者5人が正座し、全員の身体は石像側。福ちゃんは最前列の神主で、白衣、深紫袴、`SPONSOR`ストラップ、`福ちゃん`名札。白衣全面へ、チャコール黒と金箔調のブランドロゴ風「ギュンギュン」を大小多数反復する。大きな斜め胸ロゴ、襟沿い、両袖、裾の総柄、金色の幾何学縁取りを重ね、あえて下品で成金趣味の高級ブランド物にする。実在ブランドの意匠は使わず、補助4人の白衣は無地のまま。開始時は全員の口を閉じ、手を腿に置き、ギュンギュンポーズ前。神社、カメラ、自然な朝光、人数、石像を固定し、余計な人物、文字、テロップ、ロゴ、超常VFX、透かしを禁止。

## `scene_02b_gyungyun_pose_start_production.png`

- identity source：`02_CHARACTERS/Fukuchan.jpg`。福ちゃんの顔、目、中央分けの黒髪、48歳の細身体型、笑顔を絶対正本にし、変更するのは衣装だけ。
- pose source：`02_CHARACTERS/Fukuchan.jpg` と `character_fukuchan_basic_sheet.png` の `GYUNGYUN` 欄。両手は小さく軽く握った拳。掌を内向きにして見せず、左右の拳の人差し指側を左右の頬へ当て、親指は人差し指の下、顎側へ丸める。
- environment / clothing source：`scene_02_yumemi_shrine_start_production.png`。同じ拝殿、朝光、石像、福ちゃんの白衣・深紫袴・`SPONSOR`ストラップ・`福ちゃん`名札・黒＋金「ギュンギュン」総柄を継承する。
- prop source：`prop_bug_deity_yametaro_statue_production.png`。
- 用途：9.0秒のハードカット直後へ完全一致させる、ギュンギュン斉唱の本番開始フレーム。
- 生成指定：カメラは神社関係者5人を正面・目線高から撮る左右対称の固定中広角。福ちゃんを中央、無地白衣と淡灰袴の補助4人を左右へ配置し、成人5人全員を立たせる。縦に落ちる袴と接地した足元を見せ、5人の顔と全10手を遮らない。5人全員が同じ拳型ギュンギュンポーズを完成し、口を閉じてカメラ正面を見る。福ちゃんは `Fukuchan.jpg` の黒ジャケット、Tシャツ、黒パンツ、白スニーカーだけを神主衣装へ置換する。白衣の「ギュンギュン」は大小のチャコール黒と金箔調を密に反復し、下品で成金趣味のブランド総柄を維持する。補助4人へ総柄を移植しない。背後の祭壇に石像1体だけを見せる。
- 厳禁：正座、座位、側面、横顔、石像へ向く姿勢、開いた掌、平手の頬当て、指を広げる、祈り手、Vサイン、指ハート、拳が頬から離れる状態、手足の増減、人物増減、福ちゃんの顔・髪の変更、実在ブランド意匠、テロップ、透かし。
- 生成方式：built-in `image_gen`。最終出力は1672×941 PNG。

## `screen_debug_prayer_lower_third_production.png`

- style source：動画25の `screen_chikuwa_lower_third_clean_production.png`。レイアウト、文字階層、紺・白・コーラルの意匠だけを継承し、旧文言は使わない。
- 用途：4.0〜14.0秒の画面下部へ直接合成する透明PNG。14.0秒の石像アップでは消す。
- 表示全文：上段「新たなバグ対策」、中央「ゆめみ神社「デバッグ祈願」」、下段「バグのお祓いサービスを提供」。各1回のみ。
- 生成指定：日本の地方朝ニュース用の高精細な横長テロップ。駅名、人名、肩書、局ロゴ、時計、英訳、追加文、疑似文字、透かしを禁止。built-in `image_gen` でクロマキー背景版を生成し、ローカルで背景をアルファ化。文字、配色、外形、透明四隅を原寸確認した。

## `scene_03_bug_deity_closeup_production.png`

- environment source：`scene_02_yumemi_shrine_start_production.png` の拝殿、祭壇、木材、紙垂、朝光。
- prop source：`prop_bug_deity_yametaro_statue_production.png`。
- 用途：14.0秒の最終ハードカット直後へ完全一致させる、14.0〜15.0秒の1秒だけ使う石像アップの本番開始フレーム。
- 生成指定：同じ祭壇に同じ御影石像を1体だけ置く。50〜70mmの報道用固定アップで、台座、葉柄シャツ、丸頬、丸メガネ、三角形の生え際、大きな髪を鮮明にする。石像は画面右寄り。左下は解説叩き用の暗く静かな余白にする。人物、別の神像、生身化、発光、発話、文字、テロップ、ロゴ、時計、透かしを禁止。

## `screen_bug_deity_caption_production.png`

- composition source：`scene_03_bug_deity_closeup_production.png`。石像の顔、眼鏡、体、台座を隠さない左下配置。
- 用途：14.0〜15.0秒の1秒だけ直接合成する、控えめな文化ニュース風の解説叩き。透明PNG。
- 表示全文：見出し「バグ神様」。本文1行目「ゆめみ村に伝わる」。本文2行目「かつてバグの神様と呼ばれた人物をかたどった石像」。各1回のみで句読点を追加しない。
- デザイン：左下38〜42%幅、画面高24%以下。細いコーラル線を1本だけ使う小さな白見出し札と、半透明の濃紺本文パネル。白い中太ゴシックで480pでも読めるが、石像より目立たせない。巨大見出し、斜めバナー、太い装飾枠、光沢、中央配置、アニメーションを禁止。
- 生成指定：built-in `image_gen` でクロマキー背景版を生成し、ローカルで背景をアルファ化。指定3行の字形、順番、重複なし、透明四隅、石像との非干渉を原寸合成で確認した。
