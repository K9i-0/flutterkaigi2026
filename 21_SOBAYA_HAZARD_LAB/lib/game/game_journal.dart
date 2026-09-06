import 'package:flutter/material.dart';

import 'game_state.dart';
import 'game_story.dart';

class HazardJournal extends StatelessWidget {
  const HazardJournal(this.state, {super.key});
  final HazardGameState state;
  static const ivory = Color(0xffede8d6), gold = Color(0xffd6bd7e);

  void read(BuildContext context, String title, String text, {String? poster}) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xff141b14),
        child: SizedBox(
          width: 720,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(color: gold, fontSize: 20),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('journal-reader-close'),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: ivory),
                    ),
                  ],
                ),
                const Divider(),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        if (poster != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Image.asset(
                              'assets/collection/$poster.png',
                              height: 280,
                              cacheWidth: 800,
                            ),
                          ),
                        Text(
                          text,
                          key: const ValueKey('journal-reader-text'),
                          style: const TextStyle(
                            color: ivory,
                            fontSize: 17,
                            height: 1.85,
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
                'たこさんの声：VOICEVOX:Voidoll',
                style: TextStyle(color: ivory, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
