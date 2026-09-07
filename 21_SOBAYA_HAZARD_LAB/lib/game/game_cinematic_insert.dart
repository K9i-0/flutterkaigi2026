import 'package:flutter/material.dart';

import 'game_events.dart';

const cinematicImages = [
  'village-crowd',
  'engine-archive',
  'harbor',
  'shelter',
];

/// Excerpts are typeset in Flutter so Japanese remains readable at every size.
const cinematicDocuments = <String, (String, String, String)>{
  'gun-receipt': (
    '船内支給品　受領票',
    'ハンドガン　一丁・予備弾\n受領者　福ちゃん',
    '船長の伝言\n「村にはバケモノがいる。いざとなったら使え」',
  ),
  'return-ticket': (
    '搬入船　乗船規定',
    '帰任便への乗船には帰任票が必要\n帰任票の発行担当者：当便に乗船していません',
    '現地案件の完了後に申請してください',
  ),
  'engine-link': ('村から帰るために', '山の廃屋にいる巨大そば屋を倒す', '玄関が開いたら家へ → 二人と話して帰還'),
  'shelter': (
    '宿舎　閉じた扉の向こう',
    '扉を二度たたく。\n内側から、二度返事があった。',
    '水と食事を配布済み\n避難の合図があるまで、鍵をかけて待機',
  ),
  'rescue-radio': (
    '救難通信　たこさん → 救助船',
    '巨大そば屋を倒し、エンジンが止まりました。避難者の搬送をお願いします。\n\n救助船：救難信号、受信しました。',
    '「帰任票は要りません。そこにいる人、全員乗せます」',
  ),
  'decree': (
    '辞令　福ちゃん殿',
    'ゆめみ村・特別研修所へ出向を命ずる。\n帰任日：未定',
    '村のそば屋は銃で撃ってOK。\nよろしく！　よーたん',
  ),
  'ledger': ('そば屋エンジン　変更履歴', '初期計画　四体\n納期短縮　十二体\n追加要求　二十四体', '飼育担当　一名のまま'),
  'withdrawal': (
    '九月九日　案件凍結',
    '回収：契約書・端末・検証機\n責任者・管理職は本日便で帰任',
    'クローン：撤収対象外\n現地補助要員：待機',
  ),
  'arrivals': (
    '特別研修　着任予定',
    '九月十四日　やめ太郎\n九月二十一日　たこさん\n九月二十八日　福ちゃん',
    '受入停止の連絡票：未送信',
  ),
  'radio': (
    'そば屋エンジンの止め方',
    '山の廃屋にいる巨大そば屋を倒す\nそれでエンジンは停止します',
    '救難回線の督促放送も止まります\n救助船はたこさんが呼びます。玄関が開いたら中で二人と話す',
  ),
  'diary': (
    '窓際社員の日記',
    'かえる席　ない\nまわす　しごと　ある\n\nまど　ない\nびーる　うま',
    '後日の書き込み\n一名、水を渡した。たこさん',
  ),
  'rescue': (
    '避難者名簿　照合済み',
    '宿舎の社員　桟橋へ誘導\n前任の世話係　乗船確認\n福ちゃん・やめ太郎・たこさん　最終乗船の準備中',
    '食事と水を配布\n待機中の三名を確認　／　たこさん',
  ),
};

EventCut? dialogueInsert(
  String owner,
  String topic,
  int index, {
  bool postBoss = false,
}) {
  if (postBoss) return null;
  if (topic == 'engine' && index == 0) {
    return const EventCut(0, image: 'engine-archive', label: 'そば屋エンジン　開発記録');
  }
  if (topic == 'evidence' && index < 2) {
    return EventCut(
      0,
      document: owner == 'takosan'
          ? 'ledger'
          : index == 0
          ? 'withdrawal'
          : 'arrivals',
      label: '拾った記録',
    );
  }
  if (owner == 'yametaro' && topic == 'combat' && index == 2) {
    return const EventCut(0, document: 'decree', label: 'よーたんの追記');
  }
  return null;
}

class CinematicInsert extends StatelessWidget {
  const CinematicInsert({super.key, required this.cut, this.progress = 0});
  final EventCut cut;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final document = cinematicDocuments[cut.document];
    return ColoredBox(
      color: const Color(0xff090b09),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (cut.image.isNotEmpty)
            ClipRect(
              child: Transform.scale(
                scale: 1 + .035 * progress.clamp(0, 1),
                child: Image.asset(
                  'assets/cinematics/${cut.image}.png',
                  key: ValueKey('cinematic-image-${cut.image}'),
                  fit: BoxFit.contain,
                  gaplessPlayback: false,
                  semanticLabel: cut.label,
                ),
              ),
            ),
          if (cut.document == 'engine-link')
            EngineLinkDiagram(progress: progress),
          if (document != null && cut.document != 'engine-link')
            Padding(
              padding: const EdgeInsets.fromLTRB(40, 46, 40, 14),
              child: FittedBox(
                fit: BoxFit.contain,
                child: Transform.rotate(
                  angle: -.013,
                  child: Container(
                    key: ValueKey('cinematic-document-${cut.document}'),
                    width: 660,
                    padding: const EdgeInsets.fromLTRB(38, 24, 38, 24),
                    decoration: const BoxDecoration(
                      color: Color(0xffded5b9),
                      boxShadow: [
                        BoxShadow(color: Colors.black, blurRadius: 20),
                      ],
                    ),
                    child: DefaultTextStyle(
                      style: const TextStyle(
                        color: Color(0xff25271f),
                        fontSize: 22,
                        height: 1.55,
                        fontFamily: 'serif',
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            document.$1,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Divider(color: Color(0xff77765c), height: 26),
                          Text(document.$2),
                          const SizedBox(height: 18),
                          Text(
                            document.$3,
                            style: const TextStyle(
                              color: Color(0xff853329),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (cut.label.isNotEmpty)
            Positioned(
              top: 12,
              left: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                color: const Color(0xcc090b09),
                child: Text(
                  cut.label,
                  style: const TextStyle(
                    color: Color(0xffe6dec6),
                    fontSize: 13,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class EngineLinkDiagram extends StatelessWidget {
  const EngineLinkDiagram({super.key, required this.progress});
  final double progress;
  @override
  Widget build(BuildContext context) {
    final stopped = progress >= .6;
    final color = stopped ? const Color(0xff82ba92) : const Color(0xffd6ab70);
    Widget part(IconData icon, String title, String detail) => Container(
      width: 195,
      height: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xff232b29),
        border: Border.all(color: color),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 46, color: color),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(color: Color(0xffe6dec6), fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(detail, style: TextStyle(color: color, fontSize: 16)),
        ],
      ),
    );
    return Padding(
      key: const ValueKey('cinematic-document-engine-link'),
      padding: const EdgeInsets.fromLTRB(30, 42, 30, 12),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 700,
          height: 310,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                stopped ? '玄関が開いたら、二人の無事を確認' : 'エンジンを止める方法',
                style: TextStyle(color: color, fontSize: 26),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  part(
                    Icons.fitness_center,
                    '巨大そば屋',
                    stopped ? '撃退！' : 'こいつを倒す',
                  ),
                  Icon(Icons.arrow_forward, color: color, size: 40),
                  part(Icons.settings, 'そば屋エンジン', stopped ? '停止！' : '倒せば止まる'),
                  Icon(Icons.arrow_forward, color: color, size: 40),
                  part(
                    Icons.settings_input_antenna,
                    '救助船',
                    stopped ? 'たこさんが呼ぶ' : '手配はたこさん',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                stopped
                    ? '最高難度は全そば屋撃退。家でやめ太郎とたこさんに話しかけよう'
                    : '山の廃屋にいる、一番でかいそば屋が目印',
                style: TextStyle(color: color, fontSize: 21),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
