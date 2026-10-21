import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yumemi_recruit_exam/catch_game.dart';
import 'package:yumemi_recruit_exam/character.dart';
import 'package:yumemi_recruit_exam/character_picker.dart';
import 'package:yumemi_recruit_exam/l10n.dart';
import 'package:yumemi_recruit_exam/ranking.dart';
import 'package:yumemi_recruit_exam/records.dart';

void main() {
  test('practice has no time limit, keeps dropping and never scores', () {
    final g = CatchGame()
      ..lane = true
      ..practice = true;
    g.start(seed: 3);
    g.phase = Phase.playing;
    var events = 0, last = 0;
    for (var i = 0; i < 90 * 60; i++) {
      // Chase the next drop so catches (good and bad) actually happen.
      g.tick(1 / 60, inputX: g.demoInput().x);
      if (g.eventId != last) {
        last = g.eventId;
        events++;
      }
    }
    expect(g.phase, Phase.playing);
    expect(g.time, greaterThan(89));
    expect(events, greaterThan(20));
    expect(g.message, isIn([GameMessage.caught, GameMessage.bad]));
    expect(g.messagePoints, isNull);
    expect([g.score, g.combo, g.caught, g.bad, g.missed], [0, 0, 0, 0, 0]);
    expect(g.drops.where((d) => d.spawn > g.time), isNotEmpty);
    // Resolved drops are pruned so the list stays bounded.
    expect(g.drops.length, lessThan(60));
    final ids = g.drops.map((d) => d.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('a normal round after practice is unchanged and ends', () {
    final g = CatchGame()..lane = true;
    g.start(seed: 1);
    final normal = g.drops.map((d) => (d.kind, d.x, d.spawn)).toList();
    g
      ..practice = true
      ..start(seed: 1)
      ..practice = false
      ..start(seed: 1);
    expect(g.drops.map((d) => (d.kind, d.x, d.spawn)).toList(), normal);
    g.phase = Phase.playing;
    g.tick(.25);
    for (var i = 0; i < 25 * 60; i++) {
      g.tick(1 / 60);
    }
    expect(g.phase, Phase.result);
  });

  test('records persist per device and rank per character', () async {
    SharedPreferences.setMockInitialValues({});
    final store = RecordStore();
    await store.load();
    GameRecord r(String name, int score, CatchCharacter c, int minute) =>
        GameRecord(
          name: name,
          score: score,
          character: c,
          caught: 1,
          bad: 0,
          missed: 0,
          at: DateTime(2026, 10, 21, 10, minute),
        );
    await store.add(r('a', 500, CatchCharacter.sobaya, 0));
    await store.add(r('b', 900, CatchCharacter.sobaya, 1));
    await store.add(r('c', 2000, CatchCharacter.fukuchan, 2));
    final tie = r('d', 500, CatchCharacter.sobaya, 3);
    await store.add(tie);
    expect(store.ranking(CatchCharacter.sobaya).map((e) => e.name), [
      'b',
      'a',
      'd',
    ]);
    expect(store.rankOf(tie), 2);
    final reloaded = RecordStore();
    await reloaded.load();
    expect(reloaded.records.length, 4);
    expect(reloaded.ranking(CatchCharacter.fukuchan).single.name, 'c');
  });

  testWidgets('picker translates into English', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: L10n(
          strings: const Strings(AppLang.en),
          child: Scaffold(
            body: CharacterPicker(
              selected: CatchCharacter.ctoOdatetsu,
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('CTO Odatetsu'), findsOneWidget);
    expect(find.text('Hard'), findsOneWidget);
    const en = Strings(AppLang.en);
    expect(en.dropDetail(CanKind.chikuwa).note, contains('fish cake'));
  });

  testWidgets('nickname dialog needs a name and returns it trimmed', (
    tester,
  ) async {
    String? result = 'unset';
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showDialog<String>(
              context: context,
              builder: (_) => const RecordDialog(
                score: 1200,
                character: CatchCharacter.sobaya,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final save = find.byKey(const ValueKey('record_save'));
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    // No keyboard until the field is tapped.
    expect(tester.testTextInput.isVisible, isFalse);
    await tester.tap(find.byKey(const ValueKey('record_name')));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.enterText(find.byKey(const ValueKey('record_name')), '  ゆめみ ');
    await tester.pump();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(result, 'ゆめみ');
  });
}
