import 'dart:convert';
import 'dart:io';

import 'package:sobaya_hazard_lab/game/game_dialogue.dart';
import 'package:sobaya_hazard_lab/game/game_events.dart';
import 'package:sobaya_hazard_lab/game/game_state.dart';

void main(List<String> args) {
  final rows = <String, Map<String, dynamic>>{};
  void add(String speaker, String text, String usage) {
    if (speaker.isEmpty) return;
    final key = '$speaker\n$text';
    final row = rows.putIfAbsent(
      key,
      () => {'speaker': speaker, 'text': text, 'uses': <String>[]},
    );
    (row['uses'] as List).add(usage);
  }

  add(
    hardSuppliesLine.speaker,
    hardSuppliesLine.text,
    'dialogue:yametaro:supplies:hard',
  );
  for (final event in hazardEvents.entries) {
    for (var i = 0; i < event.value.length; i++) {
      add(
        event.value[i].voiceSpeaker,
        event.value[i].text,
        'event:${event.key}:$i',
      );
      final shot = event.value[i];
      if (shot.unreadText.isNotEmpty) {
        add(shot.voiceSpeaker, shot.unreadText, 'event:${event.key}:$i:unread');
      }
    }
  }
  for (final owner in {
    'yametaro': yametaroDialogue,
    'takosan': takosanDialogue,
    'reaction': companionReactions,
    'mountain_yametaro_before': mountainYametaroBefore,
    'mountain_yametaro_after': mountainYametaroAfter,
    'mountain_takosan_after': mountainTakosanAfter,
  }.entries) {
    for (final topic in owner.value.entries) {
      for (var i = 0; i < topic.value.length; i++) {
        add(
          topic.value[i].speaker,
          topic.value[i].text,
          'dialogue:${owner.key}:${topic.key}:$i',
        );
      }
    }
  }
  for (final line in [mountainRemainingLine, mountainRemainingTakoLine]) {
    add(line.speaker, line.text, 'dialogue:mountain:after:remaining');
  }
  final mountain = HazardGameState(
    jsonDecode(File('assets/mountain.json').readAsStringSync()),
  );
  add(
    unreadKeeperReply.speaker,
    unreadKeeperReply.text,
    'dialogue:takosan:evidence:unread',
  );
  for (final entry in purchaseLines.entries) {
    add(
      entry.value.speaker,
      entry.value.text,
      'dialogue:purchase:${entry.key}',
    );
  }
  for (final entry in purchaseReplies.entries) {
    for (var i = 0; i < entry.value.length; i++) {
      add(
        entry.value[i].speaker,
        entry.value[i].text,
        'dialogue:purchase:${entry.key}:reply:$i',
      );
    }
  }
  for (final alive in [true, false]) {
    for (final e in mountain.enemies.where((e) => e.boss)) {
      e.alive = alive;
    }
    final line = mountain.dialogueLine;
    add(
      line.speaker,
      line.text,
      'dialogue:mountain:${alive ? 'before' : 'after'}',
    );
  }
  final file = File(args.single);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(rows.values.toList())}\n',
  );
  stdout.writeln('Exported ${rows.length} unique spoken lines');
}
