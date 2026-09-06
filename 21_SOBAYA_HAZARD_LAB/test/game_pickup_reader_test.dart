import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/game_checkpoint.dart';
import 'package:sobaya_hazard_lab/game/game_journal.dart';
import 'package:sobaya_hazard_lab/game/game_state.dart';

void main() {
  test(
    'poster pickup freezes gameplay, closes once and survives save/restart',
    () {
      final map = jsonDecode(
        File('assets/village.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final s = HazardGameState(map)
        ..x = -8
        ..z = -18.8
        ..inputY = 1;
      s.interact();
      expect(s.phase, PlayPhase.reading);
      expect(s.readingRecord, 'poster:wanted');
      expect(s.inputY, 0);
      final health = s.health, time = s.time, z = s.z;
      for (var i = 0; i < 240; i++) {
        s.tick(.05);
      }
      expect(s.health, health);
      expect(s.time, time);
      expect(s.z, z);
      s.toggle(PlayPhase.inventory);
      expect(s.phase, PlayPhase.reading);
      s.closeCollectedRecord();
      expect(s.phase, PlayPhase.playing);
      expect(s.readingRecord, isNull);
      s.interact();
      expect(s.phase, PlayPhase.playing);
      expect(s.collected, {'wanted'});
      s.restart();
      expect(s.readingRecord, isNull);
      expect(s.collected, {'wanted'});
    },
  );

  test(
    'saving while a memo is open keeps collection but not a stale reader',
    () {
      final map = jsonDecode(
        File('assets/village.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final s = HazardGameState(map)
        ..x = -6.8
        ..z = -13;
      for (final e in s.enemies) {
        e.active = false;
      }
      s.interact();
      expect(s.readingRecord, 'memo:proposal');
      expect(s.checkpointRequested, true);
      final restored = restoreHazardCheckpoint(s.checkpoint(), map, {});
      expect(restored.foundMemos, contains('proposal'));
      expect(restored.phase, PlayPhase.playing);
      expect(restored.readingRecord, isNull);
    },
  );

  testWidgets(
    'poster reader uses the original, zooms and exposes its back notes',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: JournalRecordReader(
            record: const JournalRecord('ポスター', '裏面の証拠', poster: 'wanted'),
            onClose: () {},
          ),
        ),
      );
      final image = tester.widget<Image>(
        find.byKey(const ValueKey('journal-poster-original')),
      );
      expect(
        image.image,
        isA<AssetImage>(),
      ); // No ResizeImage/cacheWidth restriction.
      final viewer = tester.widget<InteractiveViewer>(
        find.byKey(const ValueKey('journal-poster-zoom')),
      );
      await tester.tap(find.byKey(const ValueKey('reader-zoom-in')));
      expect(viewer.transformationController!.value.getMaxScaleOnAxis(), 1.5);
      await tester.tap(find.byKey(const ValueKey('reader-zoom-reset')));
      expect(viewer.transformationController!.value.getMaxScaleOnAxis(), 1);
      await tester.tap(find.byKey(const ValueKey('reader-notes-tab')));
      await tester.pumpAndSettle();
      expect(find.text('裏面の証拠'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
