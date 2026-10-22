import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:yumemi_recruit_exam/billboards.dart';
import 'package:yumemi_recruit_exam/character.dart';
import 'package:yumemi_recruit_exam/drop_kind.dart';
import 'package:yumemi_recruit_exam/gallery.dart';

void main() {
  test('every game character and item has one gallery subject', () {
    final ids = GallerySubject.all.map((s) => s.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final c in CatchCharacter.values) {
      expect(GallerySubject.byId(c.id)?.character, c);
    }
    for (final k in CanKind.values) {
      expect(GallerySubject.byId(k.name)?.drop, k);
    }
    expect(GallerySubject.byId('akasaka')?.isStage, isTrue);
  });

  test('orbit, zoom and pan stay inside the subject limits', () {
    final c = GalleryController(GallerySubject.byId('sobaya'));
    c.orbit(10, 10);
    expect(c.pitch, GalleryController.maxPitch);
    expect(c.yaw.abs(), lessThanOrEqualTo(math.pi));
    c.zoom(1000);
    expect(c.distance, c.subject.minDistance);
    c.zoom(.0001);
    expect(c.distance, c.subject.maxDistance);
    for (var i = 0; i < 50; i++) {
      c.panBy(1, 1);
    }
    expect(c.pan.length, lessThanOrEqualTo(1.2001));
    c.reset();
    expect(c.distance, c.subject.distance);
    expect(c.pan.length, 0);
  });

  test('auto-rotation waits until the viewer lets go', () {
    final c = GalleryController();
    c.tick(1);
    expect(c.yaw, 0);
    c.tick(2);
    expect(c.yaw, isNot(0));
    final turned = c.yaw;
    c.touch();
    c.tick(1);
    expect(c.yaw, turned);
  });

  test('selecting a subject restores its own opening view', () {
    final c = GalleryController()..zoom(3);
    c.select(GallerySubject.byId('akasaka')!);
    expect(c.distance, 24);
    expect(c.camera().fovFar, greaterThan(100));
  });

  test('the stage pivot roams the city and glides to a focus', () {
    final c = GalleryController(GallerySubject.byId('akasaka'));
    for (var i = 0; i < 400; i++) {
      c.panBy(-1, 0);
    }
    expect(c.pan.x, GalleryController.stageReach);
    expect(c.pan.y, 0, reason: 'map-style panning stays level');
    c.reset();
    c.focus(vm.Vector3(20, 5, -70), distance: 6);
    for (var i = 0; i < 300; i++) {
      c.tick(1 / 60);
    }
    expect(c.focusing, isFalse);
    expect((c.subject.target + c.pan - vm.Vector3(20, 5, -70)).length, 0);
    expect(c.distance, 6);
    c.focus(vm.Vector3.zero(), distance: 60);
    expect(c.distance, 6, reason: 'focusing never pulls back');
    c.orbit(.1, 0);
    expect(c.focusing, isFalse, reason: 'a touch takes over');
  });

  testWidgets('billboards come from the stage atlas, without retired panels', (
    tester,
  ) async {
    final list = (await tester.runAsync(loadBillboards))!;
    final ids = list.map((b) => b.id).toList();
    expect(ids, containsAll(['odatetsu', 'yumemin']));
    expect(ids.last, 'okayaman_vision');
    for (final retired in [
      'exam',
      'accidenchua',
      'safety',
      'recruit',
      'sign',
    ]) {
      expect(ids.where((id) => id.contains(retired)), isEmpty);
    }
    final sponsors = list.where((b) => b.group == BillboardGroup.sponsor);
    expect(sponsors, hasLength(9));
    for (final b in sponsors) {
      expect(b.crop!.right, lessThanOrEqualTo(sponsorAtlasSize.width));
      expect(b.crop!.bottom, lessThanOrEqualTo(sponsorAtlasSize.height));
    }
    final odatetsu = list.firstWhere((b) => b.id == 'odatetsu');
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(width: 200, child: BillboardImage(odatetsu)),
        ),
      ),
    );
    expect(tester.getSize(find.byType(BillboardImage)), const Size(200, 200));
    expect(tester.takeException(), isNull);
  });
}
