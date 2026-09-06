import 'package:flutter/material.dart';

import 'game_state.dart';
import 'game_story.dart';

class JournalRecord {
  const JournalRecord(this.title, this.text, {this.poster});
  final String title, text;
  final String? poster;
}

JournalRecord journalRecord(HazardGameState state, String key) {
  if (key.startsWith('memo:')) {
    final memo = villageMemos.firstWhere((m) => m.id == key.substring(5));
    return JournalRecord(memo.title, '${memo.author}\n\n${memo.text}');
  }
  final id = key.substring(7);
  final row = state.gallery.firstWhere((p) => p['id'] == id);
  return JournalRecord(
    row['title'],
    '裏面の書き込み\n\n${posterEvidence[id] ?? ''}',
    poster: id,
  );
}

/// Both immediate pickup reading and the journal use the same full-size reader.
class JournalRecordReader extends StatelessWidget {
  const JournalRecordReader({
    super.key,
    required this.record,
    required this.onClose,
  });
  final JournalRecord record;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final text = SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: SelectableText(
        record.text,
        key: const ValueKey('journal-reader-text'),
        style: const TextStyle(
          color: HazardJournal.ivory,
          fontSize: 18,
          height: 1.85,
        ),
      ),
    );
    return Dialog(
      backgroundColor: const Color(0xff141b14),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: SizedBox(
        width: 980,
        height: MediaQuery.sizeOf(context).height * .9,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      record.title,
                      style: const TextStyle(
                        color: HazardJournal.gold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('journal-reader-close'),
                    tooltip: '閉じる',
                    onPressed: onClose,
                    icon: const Icon(Icons.close, color: HazardJournal.ivory),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: record.poster == null
                    ? text
                    : DefaultTabController(
                        length: 2,
                        child: Column(
                          children: [
                            const TabBar(
                              labelColor: HazardJournal.gold,
                              unselectedLabelColor: HazardJournal.ivory,
                              tabs: [
                                Tab(
                                  text: 'ポスター',
                                  key: ValueKey('reader-image-tab'),
                                ),
                                Tab(
                                  text: '裏面の書き込み',
                                  key: ValueKey('reader-notes-tab'),
                                ),
                              ],
                            ),
                            Expanded(
                              child: TabBarView(
                                children: [
                                  JournalPosterViewer(id: record.poster!),
                                  text,
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class JournalPosterViewer extends StatefulWidget {
  const JournalPosterViewer({super.key, required this.id});
  final String id;
  @override
  State<JournalPosterViewer> createState() => _JournalPosterViewerState();
}

class _JournalPosterViewerState extends State<JournalPosterViewer> {
  final transform = TransformationController();
  @override
  void dispose() {
    transform.dispose();
    super.dispose();
  }

  void zoom(double factor, Size size) {
    final current = transform.value.getMaxScaleOnAxis();
    final next = (current * factor).clamp(1.0, 6.0);
    final center = Offset(size.width / 2, size.height / 2);
    final point = transform.toScene(center);
    transform.value = Matrix4.identity()
      ..setEntry(0, 0, next)
      ..setEntry(1, 1, next)
      ..setEntry(0, 3, center.dx - point.dx * next)
      ..setEntry(1, 3, center.dy - point.dy * next);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Stack(
      children: [
        Positioned.fill(
          child: InteractiveViewer(
            key: const ValueKey('journal-poster-zoom'),
            transformationController: transform,
            minScale: 1,
            maxScale: 6,
            trackpadScrollCausesScale: true,
            child: SizedBox.expand(
              child: Image.asset(
                'assets/collection/${widget.id}.png',
                key: const ValueKey('journal-poster-original'),
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                // No cacheWidth: this is the original production image, not wall art.
              ),
            ),
          ),
        ),
        Positioned(
          right: 8,
          bottom: 8,
          child: Material(
            color: const Color(0xe6141b14),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: const ValueKey('reader-zoom-out'),
                  tooltip: '縮小',
                  icon: const Icon(Icons.remove, color: HazardJournal.ivory),
                  onPressed: () => zoom(1 / 1.5, constraints.biggest),
                ),
                IconButton(
                  key: const ValueKey('reader-zoom-in'),
                  tooltip: '拡大',
                  icon: const Icon(Icons.add, color: HazardJournal.ivory),
                  onPressed: () => zoom(1.5, constraints.biggest),
                ),
                IconButton(
                  key: const ValueKey('reader-zoom-reset'),
                  tooltip: '全体を表示',
                  icon: const Icon(
                    Icons.fit_screen,
                    color: HazardJournal.ivory,
                  ),
                  onPressed: () {
                    transform.value = Matrix4.identity();
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class HazardJournal extends StatelessWidget {
  const HazardJournal(this.state, {super.key});
  final HazardGameState state;
  static const ivory = Color(0xffede8d6), gold = Color(0xffd6bd7e);

  void read(BuildContext context, String title, String text, {String? poster}) {
    showDialog<void>(
      context: context,
      builder: (context) => JournalRecordReader(
        record: JournalRecord(title, text, poster: poster),
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: DefaultTabController(
      length: 2,
      child: SizedBox(
        height: 510,
        child: Column(
          children: [
            TabBar(
              labelColor: gold,
              unselectedLabelColor: ivory,
              tabs: [
                Tab(
                  key: const ValueKey('journal-memos'),
                  text:
                      '村のメモ ${state.foundMemos.length}/${villageMemos.length}',
                ),
                Tab(
                  key: const ValueKey('journal-posters'),
                  text:
                      'ポスター ${state.collected.length}/${state.gallery.length}',
                ),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ListView(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          '現地でEを押して収集。メモはこの冒険のセーブに記録されます。',
                          style: TextStyle(color: ivory),
                        ),
                      ),
                      for (final m in villageMemos)
                        ListTile(
                          key: ValueKey('journal-memo-${m.id}'),
                          leading: Icon(
                            state.foundMemos.contains(m.id)
                                ? Icons.description_outlined
                                : Icons.lock_outline,
                            color: gold,
                          ),
                          title: Text(
                            state.foundMemos.contains(m.id)
                                ? m.title
                                : '未発見のメモ',
                            style: const TextStyle(color: ivory),
                          ),
                          subtitle: Text(
                            state.foundMemos.contains(m.id)
                                ? m.author
                                : {
                                    'village': 'ゆめみ村',
                                    'farm': '農場',
                                    'mountain': '山道',
                                  }[m.zone]!,
                            style: const TextStyle(color: gold),
                          ),
                          onTap: state.foundMemos.contains(m.id)
                              ? () => read(
                                  context,
                                  m.title,
                                  '${m.author}\n\n${m.text}',
                                )
                              : null,
                        ),
                    ],
                  ),
                  GridView.count(
                    crossAxisCount: 3,
                    childAspectRatio: .8,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    children: [
                      for (final row in state.gallery)
                        InkWell(
                          key: ValueKey('collection-${row['id']}'),
                          onTap: state.collected.contains(row['id'])
                              ? () => read(
                                  context,
                                  row['title'],
                                  '裏面の書き込み\n\n${posterEvidence[row['id']] ?? ''}',
                                  poster: row['id'],
                                )
                              : null,
                          child: Column(
                            children: [
                              Expanded(
                                child: state.collected.contains(row['id'])
                                    ? Image.asset(
                                        'assets/collection/${row['id']}.png',
                                        cacheWidth: 350,
                                        fit: BoxFit.contain,
                                      )
                                    : const Icon(
                                        Icons.lock_outline,
                                        color: gold,
                                        size: 40,
                                      ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Text(
                                  state.collected.contains(row['id'])
                                      ? row['title']
                                      : '未発見',
                                  style: const TextStyle(color: ivory),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'たこさんの声：VOICEVOX:Voidoll\nナレーション：ゆめテレアナウンサー / Irodori-TTS',
                style: TextStyle(color: ivory, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
