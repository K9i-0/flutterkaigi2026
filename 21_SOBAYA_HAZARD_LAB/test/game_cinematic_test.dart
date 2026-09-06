import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/game_cinematic_insert.dart';
import 'package:sobaya_hazard_lab/game/game_events.dart';

void main() {
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
          final d = HazardDirector(event.key)..index = i;
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
