import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_beer_rain/balance.dart';
import 'package:sobaya_beer_rain/catch_game.dart';
import 'package:sobaya_beer_rain/character.dart';
import 'package:sobaya_beer_rain/character_picker.dart';

void main() {
  test('normal default, selection lock and retry snapshot', () {
    final g = CatchGame()..lane = true;
    g.start();
    expect(g.roundCharacter, CatchCharacter.ctoOdatetsu);
    expect(g.baseMoveSpeed, 3.4);
    expect(g.baseCatchRadius, .55);
    expect(g.selectCharacter(CatchCharacter.fukuchan), false);
    g.phase = Phase.playing;
    expect(g.selectCharacter(CatchCharacter.fukuchan), false);
    g.phase = Phase.result;
    expect(g.selectCharacter(CatchCharacter.fukuchan), true);
    expect(g.roundCharacter, CatchCharacter.ctoOdatetsu);
    g.start();
    expect(g.roundCharacter, CatchCharacter.fukuchan);
    expect(g.baseMoveSpeed, 3.0);
    expect(g.baseCatchRadius, .64);
    g.balance = Balance.fromMap({'moveSpeed': 5, 'catchRadius': 1.2});
    expect(g.moveSpeed, 3.0);
    expect(g.catchRadius, .64);
  });

  test('character drop pools and difficulty, with reproducible layouts', () {
    final rounds = <CatchCharacter, CatchGame>{};
    for (final character in CatchCharacter.values) {
      final g = CatchGame()..lane = true;
      g.selectCharacter(character);
      g.start(seed: 42);
      rounds[character] = g;
      expect(g.drops.where((d) => d.kind.isBad).map((d) => d.kind).toSet(), {
        character.badDrop,
      });
      expect(
        g.drops.where((d) => !d.kind.isBad).map((d) => d.kind).toSet(),
        character.goodDrops.toSet(),
      );
      final first = g.drops
          .map((d) => (d.x, d.spawn, d.kind, d.facing))
          .toList();
      g.start(seed: 42);
      expect(
        g.drops.map((d) => (d.x, d.spawn, d.kind, d.facing)).toList(),
        first,
      );
      expect(g.drops.every((d) => d.landing <= g.roundSeconds), true);
      g.phase = Phase.playing;
      g.drops
        ..clear()
        ..add(Drop(0, character.badDrop, 0, 0, -3.1));
      g.tick(1 / 60);
      expect(g.bad, 1);
      expect(g.score, -200);
    }
    final easy = rounds[CatchCharacter.fukuchan]!,
        normal = rounds[CatchCharacter.ctoOdatetsu]!,
        hard = rounds[CatchCharacter.sobaya]!;
    expect(easy.fallSeconds, greaterThan(normal.fallSeconds));
    expect(hard.fallSeconds, lessThan(normal.fallSeconds));
    expect(easy.spawnInterval, greaterThan(normal.spawnInterval));
    expect(hard.spawnInterval, lessThan(normal.spawnInterval));
    expect(easy.badRatio, lessThan(normal.badRatio));
    expect(hard.badRatio, greaterThan(normal.badRatio));
  });

  for (final character in CatchCharacter.values) {
    test('${character.id}: speed, radius and full 20-second lane round', () {
      final g = CatchGame()..lane = true;
      g.selectCharacter(character);
      g.start(seed: 7);
      g.phase = Phase.playing;
      g.drops
        ..clear()
        ..add(Drop(0, CanKind.superTry, .63, 0, -3.1));
      g.tick(1 / 60);
      expect(g.caught, character == CatchCharacter.ctoOdatetsu ? 0 : 1);
      for (var i = 0; i < 60; i++) {
        g.tick(1 / 60, inputX: 1, inputY: 1);
      }
      expect(g.vx.abs(), closeTo(character.moveSpeed, .001));
      expect(g.z, 0);
      for (var i = 0; i < 1200; i++) {
        g.tick(1 / 60, inputX: 1);
        expect(g.x.abs(), lessThanOrEqualTo(3.9));
      }
      expect(g.phase, Phase.result);
      expect(g.time, 20);
      expect(g.vx, 0);
      g.start(seed: 7);
      expect(g.baseMoveSpeed, character.moveSpeed);
      expect(g.baseCatchRadius, character.catchRadius);
    });
  }

  test('lane end stops report actual zero speed for Idle', () {
    final g = CatchGame()..lane = true;
    g.start();
    g.phase = Phase.playing;
    for (var i = 0; i < 180; i++) {
      g.tick(1 / 60, inputX: 1);
    }
    expect(g.x, -3.9);
    expect(g.vx, 0);
    g.tick(1 / 60, inputX: -1);
    expect(g.vx, greaterThan(0));
  });

  test('plane retains sobaya, speed 3.5 and configured catch radius', () {
    final g = CatchGame();
    g.selectCharacter(CatchCharacter.ctoOdatetsu);
    g.balance = Balance.fromMap({'moveSpeed': 5, 'catchRadius': .9});
    g.start();
    expect(g.roundCharacter, CatchCharacter.sobaya);
    expect(g.moveSpeed, 3.5);
    expect(g.catchRadius, .9);
    g.phase = Phase.playing;
    for (var i = 0; i < 60; i++) {
      g.tick(1 / 60, inputX: 1);
    }
    expect(g.vx.abs(), closeTo(3.5, .001));
    g.phase = Phase.result;
    g.lane = true;
    g.start();
    expect(g.roundCharacter, CatchCharacter.ctoOdatetsu);
    expect(g.catchRadius, .55);
  });

  testWidgets('picker shows difficulty and selects each character', (
    tester,
  ) async {
    var selected = CatchCharacter.sobaya;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => CharacterPicker(
              selected: selected,
              onSelected: (value) => setState(() => selected = value),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(Image), findsNWidgets(3));
    final portraits = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(portraits.map((image) => (image.image as AssetImage).assetName), [
      'assets/images/fukuchan.jpg',
      'assets/images/cto_odatetsu.png',
      'assets/images/sobaya.jpg',
    ]);
    final positions = CatchCharacter.values
        .map(
          (character) => tester.getCenter(
            find.byKey(ValueKey('character_${character.id}')),
          ),
        )
        .toList();
    expect(positions[2].dy, lessThan(positions[1].dy));
    expect(positions[1].dy, lessThan(positions[0].dy));
    for (final character in CatchCharacter.values) {
      await tester.tap(find.byKey(ValueKey('character_${character.id}')));
      await tester.pump();
      expect(selected, character);
      expect(find.text(character.difficulty), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
}
