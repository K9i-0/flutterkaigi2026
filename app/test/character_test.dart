import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_beer_rain/balance.dart';
import 'package:sobaya_beer_rain/catch_game.dart';
import 'package:sobaya_beer_rain/character.dart';
import 'package:sobaya_beer_rain/character_picker.dart';

void main() {
  test('default, selection lock and retry snapshot', () {
    final g = CatchGame()..lane = true;
    g.start();
    expect(g.roundCharacter, CatchCharacter.sobaya);
    expect(g.baseMoveSpeed, 2.6);
    expect(g.baseCatchRadius, .72);
    expect(g.selectCharacter(CatchCharacter.ctoOdatetsu), false);
    g.phase = Phase.playing;
    expect(g.selectCharacter(CatchCharacter.ctoOdatetsu), false);
    g.phase = Phase.result;
    expect(g.selectCharacter(CatchCharacter.ctoOdatetsu), true);
    expect(g.roundCharacter, CatchCharacter.sobaya);
    g.start();
    expect(g.roundCharacter, CatchCharacter.ctoOdatetsu);
    expect(g.baseMoveSpeed, 3.4);
    expect(g.baseCatchRadius, .55);
    // Old debug settings must not overwrite a character's base parameters.
    g.balance = Balance.fromMap({'moveSpeed': 5, 'catchRadius': 1.2});
    expect(g.moveSpeed, 3.4);
    expect(g.catchRadius, .55);
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

  testWidgets('picker displays stats and marks the selected character', (
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
      'assets/images/sobaya.jpg',
      'assets/images/cto_odatetsu.png',
      'assets/images/fukuchan.jpg',
    ]);
    final positions = CatchCharacter.values
        .map(
          (character) => tester.getCenter(
            find.byKey(ValueKey('character_${character.id}')),
          ),
        )
        .toList();
    expect(positions[0].dx, lessThan(positions[1].dx));
    expect(positions[1].dx, lessThan(positions[2].dx));
    expect(positions.map((p) => p.dy).toSet(), hasLength(1));
    for (final character in CatchCharacter.values) {
      await tester.tap(find.byKey(ValueKey('character_${character.id}')));
      await tester.pump();
      expect(selected, character);
      expect(find.text('✓ ${character.label}'), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
}
