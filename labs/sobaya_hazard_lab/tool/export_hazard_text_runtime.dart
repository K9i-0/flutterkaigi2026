// Pure-Dart portion of export_hazard_text.py: evaluate the real story tables.
import 'dart:convert';
import 'dart:io';

import 'package:sobaya_hazard_lab/game/game_dialogue.dart';
import 'package:sobaya_hazard_lab/game/game_events.dart';
import 'package:sobaya_hazard_lab/game/game_settings.dart';
import 'package:sobaya_hazard_lab/game/game_state.dart';
import 'package:sobaya_hazard_lab/game/game_story.dart';

Map<String, Object?> line(DialogueLine value) => {
  'speaker': value.speaker,
  'text': value.text,
};

Map<String, Object?> cut(EventCut value) => {
  'at': value.at,
  if (value.label.isNotEmpty) 'label': value.label,
  if (value.image.isNotEmpty) 'image': value.image,
  if (value.document.isNotEmpty) 'document': value.document,
};

// bossAlive describes the giant's campaign-wide state, including when this
// region has no boss of its own. Campaign traversal carries this event flag.
void setCampaignBossState(HazardGameState state, bool bossAlive) {
  for (final enemy in state.enemies.where((e) => e.boss)) {
    enemy.alive = bossAlive;
  }
  if (!bossAlive) state.seenEvents.add('giant_defeated');
}

void main() {
  final maps = <String, Map<String, dynamic>>{
    for (final region in ['village', 'farm', 'mountain'])
      region: jsonDecode(File('assets/$region.json').readAsStringSync()),
  };
  final dialogueTrees = {
    'yametaro': yametaroDialogue,
    'takosan': takosanDialogue,
    'reaction': companionReactions,
    'purchaseReply': purchaseReplies,
    'mountainYametaroBefore': mountainYametaroBefore,
    'mountainYametaroAfter': mountainYametaroAfter,
    'mountainTakosanAfter': mountainTakosanAfter,
  };
  // Query the actual state getter as well: it can replace a whole conversation
  // in chapter 3, or replace individual lines according to evidence/difficulty.
  // Contexts express resolution inputs, not promises that every topic is unlocked.
  final variants = <String, Map<String, Object?>>{};
  final objectives = <Map<String, Object?>>[];
  for (final region in maps.keys) {
    for (final bossAlive in [true, false]) {
      for (final difficulty in [
        HazardDifficulty.standard,
        HazardDifficulty.tense,
      ]) {
        for (final readEvidence in [false, true]) {
          for (final otherEnemiesDefeated in [
            false,
            if (region == 'mountain' && !bossAlive) true,
          ]) {
            final state = HazardGameState(
              maps[region]!,
              difficulty: difficulty,
            );
            setCampaignBossState(state, bossAlive);
            if (otherEnemiesDefeated) {
              for (final enemy in state.enemies.where((e) => !e.boss)) {
                enemy.alive = false;
              }
            }
            if (readEvidence) {
              state.foundMemos.addAll(villageMemos.map((m) => m.id));
            }
            for (final owner in ['yametaro', 'takosan']) {
              final topics = {
                ...(owner == 'yametaro' ? yametaroDialogue : takosanDialogue)
                    .keys,
                if (region == 'mountain' && !bossAlive)
                  ...(owner == 'yametaro'
                          ? mountainYametaroAfter
                          : mountainTakosanAfter)
                      .keys,
                if (region == 'mountain' && bossAlive && owner == 'yametaro')
                  ...mountainYametaroBefore.keys,
              };
              for (final topic in topics) {
                state.dialogueOwner = owner;
                state.dialogueTopic = topic;
                final lines = state.dialogueLines.map(line).toList();
                final signature = '$owner:$topic:${jsonEncode(lines)}';
                final entry = variants.putIfAbsent(
                  signature,
                  () => {
                    'owner': owner,
                    'topic': topic,
                    'lines': lines,
                    'contexts': <Map<String, Object?>>[],
                  },
                );
                final npcPresent = state.npcs.any((n) => n['id'] == owner);
                final topicUnlocked = state.availableDialogueTopics.contains(
                  topic,
                );
                (entry['contexts'] as List).add({
                  'zone': region,
                  'bossAlive': bossAlive,
                  'evacuationStarted': state.evacuationStarted,
                  'difficulty': difficulty.name,
                  'allMemosFound': readEvidence,
                  'otherEnemiesDefeated': otherEnemiesDefeated,
                  'npcPresent': npcPresent,
                  'topicUnlockedByDialogueState': topicUnlocked,
                  'topicSelectable': npcPresent && topicUnlocked,
                  'topicLabel': state.dialogueTopicLabel(topic),
                });
              }
            }
            if (readEvidence) continue;
            objectives.add({
              'zone': region,
              'bossAlive': bossAlive,
              'evacuationStarted': state.evacuationStarted,
              'difficulty': difficulty.name,
              'otherEnemiesDefeated': otherEnemiesDefeated,
              'text': state.objective,
            });
          }
        }
      }
    }
  }
  final starts = <Map<String, Object?>>[];
  for (final region in maps.keys) {
    for (final bossAlive in [true, false]) {
      for (final previouslyMet in [false, true]) {
        for (final reunionSeen in [false, true]) {
          for (final owner in ['yametaro', 'takosan']) {
            final state = HazardGameState(maps[region]!);
            for (final enemy in state.enemies) {
              enemy.alerted = false;
            }
            setCampaignBossState(state, bossAlive);
            final npc = state.npcs.where((n) => n['id'] == owner).firstOrNull;
            if (npc == null) continue;
            state.phase = PlayPhase.playing;
            state.x = (npc['x'] as num).toDouble();
            state.z = (npc['z'] as num).toDouble();
            state.y = 0;
            state.metYametaro = state.metTakosan = previouslyMet;
            if (reunionSeen) state.seenEvents.add('reunion_$owner');
            state.startDialogue(owner);
            if (state.phase != PlayPhase.dialogue) {
              throw StateError('Dialogue setup did not open: $region/$owner');
            }
            starts.add({
              'id':
                  'dialogue-start:$region:$owner:$bossAlive:$previouslyMet:$reunionSeen',
              'context': {
                'zone': region,
                'owner': owner,
                'bossAlive': bossAlive,
                'evacuationStarted': state.evacuationStarted,
                'previouslyMet': previouslyMet,
                'reunionSeen': reunionSeen,
              },
              'topic': state.dialogueTopic,
              'lines': state.dialogueLines.map(line).toList(),
              'choices': [
                for (final topic in state.availableDialogueTopics)
                  {'topic': topic, 'label': state.dialogueTopicLabel(topic)},
              ],
            });
          }
        }
      }
    }
  }
  stdout.writeln(
    jsonEncode({
      'dialogueTableSourceNames': [
        'yametaroDialogue',
        'takosanDialogue',
        'companionReactions',
        'purchaseReplies',
        'mountainYametaroBefore',
        'mountainYametaroAfter',
        'mountainTakosanAfter',
      ],
      'events': [
        for (final event in hazardEvents.entries)
          {
            'id': event.key,
            'shots': [
              for (var i = 0; i < event.value.length; i++)
                {
                  'id': 'event:${event.key}:$i',
                  'order': i,
                  'speaker': event.value[i].voiceSpeaker,
                  'text': event.value[i].text,
                  'seconds': event.value[i].seconds,
                  'readMemo': event.value[i].readMemo,
                  if (event.value[i].unreadText.isNotEmpty)
                    'unreadText': event.value[i].unreadText,
                  'actor': event.value[i].actor,
                  'cuts': event.value[i].cuts.map(cut).toList(),
                  if (event.value[i].unreadCuts != null)
                    'unreadCuts': event.value[i].unreadCuts!.map(cut).toList(),
                },
            ],
          },
      ],
      'dialogueTrees': {
        for (final owner in dialogueTrees.entries)
          owner.key: {
            for (final topic in owner.value.entries)
              topic.key: topic.value.map(line).toList(),
          },
      },
      'resolvedDialogueVariants': variants.values.toList(),
      'dialogueStarts': starts,
      'specialDialogue': {
        'hardSuppliesLine': line(hardSuppliesLine),
        'unreadKeeperReply': line(unreadKeeperReply),
        'mountainRemainingLine': line(mountainRemainingLine),
        'mountainRemainingTakoLine': line(mountainRemainingTakoLine),
        for (final purchase in purchaseLines.entries)
          'purchase:${purchase.key}': line(purchase.value),
      },
      'memos': [
        for (final memo in villageMemos)
          {
            'id': memo.id,
            'zone': memo.zone,
            'title': memo.title,
            'author': memo.author,
            'text': memo.text,
          },
      ],
      'posterEvidence': posterEvidence,
      'itemNames': itemNames,
      'shopOffers': [
        for (final offer in [...tradeOffers, rocketOffer])
          {
            'id': offer.id,
            'item': offer.kind,
            'name': itemNames[offer.kind],
            'amount': offer.amount,
            'beerPrice': offer.price,
            'initialStock': offer.stock,
            'hidden': offer.id == 'rocket',
          },
      ],
      'difficultyLabels': {
        for (final difficulty in HazardDifficulty.values)
          difficulty.name: HazardSettings(difficulty: difficulty)
              .difficultyLabel,
      },
      'objectiveExamples': objectives,
    }),
  );
}
