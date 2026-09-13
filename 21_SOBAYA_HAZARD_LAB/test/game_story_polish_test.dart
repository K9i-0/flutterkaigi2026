import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/game_events.dart';
import 'package:sobaya_hazard_lab/game/game_state.dart';
import 'package:sobaya_hazard_lab/game/game_dialogue.dart';
import 'package:sobaya_hazard_lab/game/game_voice.dart';

void main() {
  final catalog = VoiceCatalog(
    jsonDecode(File('assets/audio/voice-manifest.json').readAsStringSync()),
  );
  test(
    'facility ending is independent of optional diaries and never returns home',
    () {
      for (final found in [
        <String>{},
        {'diary_end'},
      ]) {
        final d = HazardDirector('ending', foundMemos: found);
        expect(d.shots.map((s) => s.text).join(), contains('アクシデンチュア'));
        expect(d.shots.any((s) => s.readMemo.isNotEmpty), false);
        expect(d.shots.map((s) => s.text).join(), isNot(contains('救助船')));
      }
    },
  );

  test('village history dialogue does not expose the secret engine', () {
    final s =
        HazardGameState(jsonDecode(File('assets/farm.json').readAsStringSync()))
          ..dialogueOwner = 'takosan'
          ..dialogueTopic = 'evidence';
    s.foundMemos.addAll(['returns', 'night_shift']);
    final text = s.dialogueLines.map((l) => l.text).join();
    expect(text, contains('事業を引き揚げ'));
    expect(text, isNot(contains('エンジン')));
    expect(text, isNot(contains('クローン')));
  });

  test('each successful purchase speaks the matching joke without changing transaction rules', () {
    for (final offer in tradeOffers) {
      final s =
          HazardGameState(
              jsonDecode(File('assets/farm.json').readAsStringSync()),
            )
            ..phase = PlayPhase.dialogue
            ..talkingTo = 'takosan'
            ..dialogueOwner = 'takosan'
            ..dialogueTopic = 'greeting'
            ..beers = 20;
      s.buySupplies(offer.id);
      expect(s.tradeMessage, purchaseLines[offer.id]!.text);
      expect(s.beers, 20 - offer.price);
      expect(s.tradePurchases[offer.id], 1);
      expect(s.tradeSerial, 1);
      expect(catalog.cue('purchase', 'たこさん', s.tradeMessage), isNotNull);
      // A purchase is applied once, before the optional speaker exchange.
      final replies = purchaseReplies[offer.id] ?? const <DialogueLine>[];
      for (final reply in replies) {
        expect(s.dialogueChoices, false);
        s.buySupplies(offer.id);
        expect(s.tradePurchases[offer.id], 1);
        s.advanceDialogue();
        expect(s.dialogueLine, reply);
        expect(catalog.cue('reply', reply.speaker, reply.text), isNotNull);
      }
      expect(s.dialogueChoices, true);
      s.beers = 0;
      s.buySupplies(offer.id);
      expect(s.tradeMessage, contains('足りません'));
      expect(s.tradePurchases[offer.id], 1);
      expect(s.tradeSerial, 2);
      expect(s.tradeReplies, isEmpty);
      expect(s.dialogueChoices, true);
    }
  });
  test(
    'all selected event variants have speech assets and valid visual cuts',
    () {
      for (final entry in hazardEvents.entries) {
        for (final found in [
          <String>{},
          {'diary_end'},
        ]) {
          final d = HazardDirector(
            entry.key,
            foundMemos: found,
            voiceSeconds: catalog.eventSeconds,
          );
          for (var i = 0; i < d.shots.length; i++) {
            d.index = i;
            expect(
              catalog.cue('audit', d.shot.voiceSpeaker, d.shot.text),
              isNotNull,
              reason: '${entry.key}:$i',
            );
            expect(
              d.duration,
              greaterThanOrEqualTo(
                catalog.seconds(d.shot.voiceSpeaker, d.shot.text),
              ),
            );
          }
        }
      }
    },
  );
}
