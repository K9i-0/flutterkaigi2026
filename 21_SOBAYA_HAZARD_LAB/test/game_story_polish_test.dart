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
    'ending text, images and voice duration follow actual diary discovery',
    () {
      final index = hazardEvents['ending']!.indexWhere(
        (s) => s.readMemo == 'diary_end',
      );
      for (final read in [false, true]) {
        final d = HazardDirector(
          'ending',
          voiceSeconds: catalog.eventSeconds,
          foundMemos: read ? {'diary_end'} : {},
        )..index = index;
        expect(d.shot.text.contains('あの日記'), read);
        expect(d.shot.cuts.any((c) => c.document == 'diary'), read);
        final cue = catalog.cue('ending', d.shot.voiceSpeaker, d.shot.text);
        expect(cue, isNotNull);
        final seconds = catalog.seconds(d.shot.voiceSpeaker, d.shot.text);
        expect(d.duration, greaterThanOrEqualTo(seconds + .5));
        expect(
          catalog.eventSeconds['event:ending:$index${d.shot.voiceUseSuffix}'],
          seconds,
        );
      }
    },
  );
  test('a ledger alone never makes Fuku claim to have read a diary', () {
    final s =
        HazardGameState(jsonDecode(File('assets/farm.json').readAsStringSync()))
          ..dialogueOwner = 'takosan'
          ..talkingTo = 'takosan'
          ..dialogueTopic = 'evidence';
    s.foundMemos.add('returns');
    expect(s.dialogueLines[1], same(unreadKeeperReply));
    s.foundMemos.add('night_shift');
    expect(s.dialogueLines[1].text, contains('日記にあった'));
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
