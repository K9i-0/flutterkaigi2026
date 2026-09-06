import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/game_cinematic_insert.dart';
import 'package:sobaya_hazard_lab/game/game_events.dart';
import 'package:sobaya_hazard_lab/game/game_voice.dart';

void main() {
  test(
    'long unvoiced narration cannot disappear after the old five seconds',
    () {
      final d = HazardDirector('opening');
      expect(d.shot.voiceSpeaker, 'ナレーション');
      expect(d.shot.speaker, isEmpty);
      for (var i = 0; i < 200; i++) {
        d.tick(.05);
      }
      expect(d.index, 0);
      expect(d.duration, greaterThan(12));
      d.next(); // Manual advance remains available to fast readers.
      expect(d.index, 1);
      expect(d.duration, greaterThan(d.shot.seconds));
    },
  );

  test('all narrative scenes have narration with time after speech', () {
    final catalog = VoiceCatalog(
      jsonDecode(File('assets/audio/voice-manifest.json').readAsStringSync()),
    );
    var count = 0;
    for (final event in hazardEvents.entries) {
      for (var i = 0; i < event.value.length; i++) {
        final shot = event.value[i];
        if (!shot.isNarration) continue;
        count++;
        final cue = catalog.cue('review', shot.voiceSpeaker, shot.text);
        expect(cue, isNotNull, reason: event.key);
        expect(cue!.speaker, 'ナレーション');
        expect(File('assets/${cue.asset}').existsSync(), true);
        final seconds = catalog.seconds(shot.voiceSpeaker, shot.text);
        expect(seconds, greaterThan(5));
        final d = HazardDirector(event.key, voiceSeconds: catalog.eventSeconds)
          ..index = i;
        expect(d.duration, greaterThanOrEqualTo(seconds + 1.5));
        expect(d.duration, greaterThanOrEqualTo(shot.readingSeconds));
      }
    }
    expect(count, 5);
  });

  test('every authored cut resolves an asset/document and a valid camera', () {
    for (final event in hazardEvents.entries) {
      for (var i = 0; i < event.value.length; i++) {
        final shot = event.value[i];
        var previous = -1.0;
        for (final cut in shot.cuts) {
          expect(cut.at, greaterThan(previous));
          expect(cut.at, inInclusiveRange(0, .999));
          previous = cut.at;
          if (cut.image.isNotEmpty) {
            expect(cinematicImages, contains(cut.image));
            expect(
              File('assets/cinematics/${cut.image}.png').existsSync(),
              true,
            );
          }
          if (cut.document.isNotEmpty) {
            expect(cinematicDocuments, contains(cut.document));
          }
          final d = HazardDirector(event.key, foundMemos: {'diary_end'})
            ..index = i;
          d.elapsed = d.duration * cut.at;
          expect(d.cut, cut);
          expect(d.visualProgress, closeTo(0, .00001));
          expect(
            d.view.camera(d.visualProgress).storage.every((x) => x.isFinite),
            true,
          );
        }
      }
    }
  });

  test('village reveal cuts during one spoken line and freezes on pause', () {
    final d = HazardDirector('opening', voiceSeconds: {'event:opening:3': 12})
      ..index = 3;
    final line = d.shot;
    d.elapsed = 2;
    expect(d.cut?.isInsert, false);
    d.elapsed = 4;
    expect(d.cut?.image, 'village-crowd');
    expect(d.shot, same(line));
    expect(d.duration, 12.5);
    final progress = d.visualProgress;
    d.paused = true;
    d.tick(.05);
    expect(d.visualProgress, progress);
    d.next();
    expect(d.elapsed, 0);
    expect(d.visualProgress, 0);
    d.skip();
    expect(d.done, true);
  });

  testWidgets('documents and images fit compact and desktop cinematic areas', (
    tester,
  ) async {
    for (final size in [const Size(640, 230), const Size(1280, 520)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      for (final id in cinematicDocuments.keys) {
        await tester.pumpWidget(
          MaterialApp(
            home: CinematicInsert(cut: EventCut(0, document: id)),
          ),
        );
        expect(find.byKey(ValueKey('cinematic-document-$id')), findsOneWidget);
        expect(tester.takeException(), isNull, reason: '$id $size');
      }
      for (final id in cinematicImages) {
        await tester.pumpWidget(
          MaterialApp(
            home: CinematicInsert(cut: EventCut(0, image: id), progress: 1),
          ),
        );
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 30));
        });
        await tester.pump();
        expect(tester.takeException(), isNull, reason: id);
      }
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}
