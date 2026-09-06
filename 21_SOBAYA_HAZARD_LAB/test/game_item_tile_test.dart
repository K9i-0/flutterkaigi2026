import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/game_item_tile.dart';
import 'package:sobaya_hazard_lab/game/game_state.dart';

void main() {
  testWidgets(
    'every item fits a compact case cell; herbs use colored grass text',
    (tester) async {
      for (final kind in itemNames.keys) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(
                width: 40,
                height: 40,
                child: GameItemTile(item: BagItem(1, kind, 30, 0, 0, 1, 1)),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: kind);
        if (herbColors.containsKey(kind)) {
          final text = tester.widget<Text>(
            find.byKey(ValueKey('herb-art-$kind')),
          );
          expect(text.data, '草');
          expect(text.style!.color, herbColors[kind]);
        } else {
          expect(find.byKey(ValueKey('item-art-$kind')), findsOneWidget);
        }
      }
    },
  );
  test('Tako appears from the farm, never in the village', () {
    final village = jsonDecode(
      File('assets/village.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final farm = jsonDecode(
      File('assets/farm.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final first = HazardGameState(village);
    expect(first.npcs.map((n) => n['id']), ['yametaro']);
    expect(HazardGameState(farm).npcs.map((n) => n['id']), contains('takosan'));
    first.x = 4;
    first.z = -22.8;
    first.interact();
    expect(first.talkingTo, isNot('takosan'));
  });
}
