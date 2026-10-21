import 'dart:async';

import 'package:flutter/material.dart';

import 'app_style.dart';
import 'character.dart';
import 'l10n.dart';
import 'records.dart';

/// Nickname entry after a round. Top-aligned so the landscape keyboard fits.
/// Untouched, it closes itself as a skip so the booth's next player can start.
class RecordDialog extends StatefulWidget {
  const RecordDialog({
    super.key,
    required this.score,
    required this.character,
    this.timeoutSeconds = 10,
  });
  final int score;
  final CatchCharacter character;
  final int timeoutSeconds;
  @override
  State<RecordDialog> createState() => _RecordDialogState();
}

class _RecordDialogState extends State<RecordDialog> {
  final name = TextEditingController();
  final focus = FocusNode();
  late int remaining = widget.timeoutSeconds;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (--remaining <= 0) {
        timer?.cancel();
        Navigator.pop(context);
      } else {
        setState(() {});
      }
    });
    // Tapping the field or typing means someone is entering a name.
    focus.addListener(engage);
    name.addListener(engage);
  }

  void engage() {
    if (timer == null || !(focus.hasFocus || name.text.isNotEmpty)) return;
    timer!.cancel();
    setState(() => timer = null);
  }

  @override
  void dispose() {
    timer?.cancel();
    focus.dispose();
    name.dispose();
    super.dispose();
  }

  void submit() {
    final text = name.text.trim();
    if (text.isNotEmpty) Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return AlertDialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.fromLTRB(40, 12, 40, 12),
      titlePadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      title: Text(
        '${t.recordTitle}  ·  ${widget.score} pt  ·  ${t.character(widget.character)}',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 420,
        child: TextField(
          key: const ValueKey('record_name'),
          controller: name,
          focusNode: focus,
          // The keyboard opens on tap so the score stays visible first.
          maxLength: RecordStore.maxName,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(labelText: t.nickname),
          onSubmitted: (_) => submit(),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('record_skip'),
          onPressed: () => Navigator.pop(context),
          child: Text(timer == null ? t.skip : t.skipIn(remaining)),
        ),
        ValueListenableBuilder(
          valueListenable: name,
          builder: (context, value, _) => FilledButton(
            key: const ValueKey('record_save'),
            onPressed: value.text.trim().isEmpty ? null : submit,
            child: Text(t.save),
          ),
        ),
      ],
    );
  }
}

/// Per-character leaderboard; scores are not comparable across difficulties.
class RankingDialog extends StatefulWidget {
  const RankingDialog({
    super.key,
    required this.store,
    required this.initial,
    this.highlight,
  });
  final RecordStore store;
  final CatchCharacter initial;
  final GameRecord? highlight;
  @override
  State<RankingDialog> createState() => _RankingDialogState();
}

class _RankingDialogState extends State<RankingDialog> {
  late var character = widget.initial;
  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final list = widget.store.ranking(character);
    return Dialog(
      key: const ValueKey('ranking'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    t.ranking,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final c in pickerOrder)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                key: ValueKey('ranking_${c.id}'),
                                visualDensity: VisualDensity.compact,
                                labelStyle: const TextStyle(fontSize: 12),
                                label: Text(t.character(c)),
                                selected: c == character,
                                onSelected: (_) =>
                                    setState(() => character = c),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('ranking_close'),
                    tooltip: t.close,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Flexible(
                child: list.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          t.noRecords,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: brandMuted),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final r = list[i];
                          // Ties share a rank.
                          final rank =
                              list.where((o) => o.score > r.score).length + 1;
                          final mine = identical(r, widget.highlight);
                          return Container(
                            color: mine ? brandPale : null,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 40,
                                  child: Text(
                                    '$rank',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: rank <= 3 ? brandBlue : brandInk,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    r.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${r.score} pt',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
