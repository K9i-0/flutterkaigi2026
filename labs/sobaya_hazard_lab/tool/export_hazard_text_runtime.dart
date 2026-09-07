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
void setCampaignBossState(
  HazardGameState state,
  bool bossAlive,
  bool otherEnemiesDefeated,
) {
  for (final enemy in state.enemies.where((e) => e.boss)) {
    enemy.alive = bossAlive;
  }
  if (!bossAlive) state.seenEvents.add('giant_defeated');
  if (!bossAlive && (!state.hardest || otherEnemiesDefeated)) {
    state.seenEvents.add('refuge_ready');
  }
}

Map<String, Object?> refugeState(HazardGameState state) => {
  'hasRefuge': state.hasRefuge,
  'refugeUnlocked': state.refugeUnlocked,
  'insideRefuge': state.insideRefuge,
  'refugeReports': state.refugeReports.toList()..sort(),
  'refugeComplete': state.refugeComplete,
};

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
          for (final otherEnemiesDefeated in [false, if (!bossAlive) true]) {
            final state = HazardGameState(
              maps[region]!,
              difficulty: difficulty,
            );
            setCampaignBossState(state, bossAlive, otherEnemiesDefeated);
            if (otherEnemiesDefeated) {
              for (final enemy in state.enemies.where((e) => !e.boss)) {
                enemy.alive = false;
              }
            }
            if (readEvidence) {
              state.foundMemos.addAll(villageMemos.map((m) => m.id));
            }
            state.refreshRefuge();
            final arrival = (state.x, state.y, state.z);
            for (final owner in ['yametaro', 'takosan']) {
              final npc = state.npcs.where((n) => n['id'] == owner).firstOrNull;
              state.x = npc == null ? arrival.$1 : (npc['x'] as num).toDouble();
              state.y = npc == null ? arrival.$2 : 0;
              state.z = npc == null ? arrival.$3 : (npc['z'] as num).toDouble();
              final topics = {
                ...(owner == 'yametaro' ? yametaroDialogue : takosanDialogue)
                    .keys,
                if (state.postBossReunion)
                  ...(owner == 'yametaro'
                          ? mountainYametaroAfter
                          : mountainTakosanAfter)
                      .keys,
                if (region == 'mountain' &&
                    !state.postBossReunion &&
                    owner == 'yametaro')
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
                  ...refugeState(state),
                  'difficulty': difficulty.name,
                  'allMemosFound': readEvidence,
                  'otherEnemiesDefeated': otherEnemiesDefeated,
                  'npcPresent': npcPresent,
                  'evaluationPosition': npcPresent
                      ? 'visible_npc'
                      : 'region_arrival',
                  'topicUnlockedByDialogueState': topicUnlocked,
                  'topicSelectable':
                      npcPresent &&
                      topicUnlocked &&
                      (!state.hasRefuge || state.insideRefuge),
                  'topicLabel': state.dialogueTopicLabel(topic),
                });
              }
            }
            state.x = arrival.$1;
            state.y = arrival.$2;
            state.z = arrival.$3;
            if (readEvidence) continue;
            objectives.add({
              'zone': region,
              'bossAlive': bossAlive,
              'evacuationStarted': state.evacuationStarted,
              ...refugeState(state),
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
  final attempts = <Map<String, Object?>>[];
  for (final region in maps.keys) {
    for (final bossAlive in [true, false]) {
      for (final difficulty in [
        HazardDifficulty.standard,
        HazardDifficulty.tense,
      ]) {
        for (final otherEnemiesDefeated in [false, if (!bossAlive) true]) {
          for (final previouslyMet in [false, true]) {
            for (final priorProgress in [
              'none',
              'legacyReunion',
              'refugeReport',
            ]) {
              for (final owner in ['yametaro', 'takosan']) {
                final state = HazardGameState(
                  maps[region]!,
                  difficulty: difficulty,
                );
                for (final enemy in state.enemies) {
                  enemy.alerted = false;
                  if (otherEnemiesDefeated && !enemy.boss) enemy.alive = false;
                }
                setCampaignBossState(state, bossAlive, otherEnemiesDefeated);
                state.refreshRefuge();
                final npc = state.npcs
                    .where((n) => n['id'] == owner)
                    .firstOrNull;
                state.phase = PlayPhase.playing;
                if (npc != null) {
                  state.x = (npc['x'] as num).toDouble();
                  state.z = (npc['z'] as num).toDouble();
                } else if (state.hasRefuge) {
                  state.x = 13;
                  state.z = 7.7;
                }
                state.y = 0;
                state.metYametaro = state.metTakosan = previouslyMet;
                if (priorProgress == 'legacyReunion') {
                  state.seenEvents.add('reunion_$owner');
                }
                if (priorProgress == 'refugeReport') {
                  state.seenEvents.add('refuge_report_$owner');
                }
                state.startDialogue(owner);
                final opened = state.phase == PlayPhase.dialogue;
                final row = <String, Object?>{
                  'id':
                      'dialogue-start:$region:$owner:$bossAlive:${difficulty.name}:$otherEnemiesDefeated:$previouslyMet:$priorProgress',
                  'context': {
                    'zone': region,
                    'owner': owner,
                    'bossAlive': bossAlive,
                    'evacuationStarted': state.evacuationStarted,
                    'npcPresent': npc != null,
                    'evaluationPosition': npc != null
                        ? 'visible_npc'
                        : state.hasRefuge
                        ? 'refuge_front'
                        : 'region_arrival',
                    ...refugeState(state),
                    'difficulty': difficulty.name,
                    'otherEnemiesDefeated': otherEnemiesDefeated,
                    'previouslyMet': previouslyMet,
                    'priorConversationProgress': priorProgress,
                    'legacyReunionSeen': state.seenEvents.contains(
                      'reunion_$owner',
                    ),
                  },
                  'opened': opened,
                  if (!opened)
                    'rejectionReason': npc == null
                        ? 'npc_not_present'
                        : state.hasRefuge && !state.insideRefuge
                        ? 'refuge_not_entered'
                        : 'startDialogue_guard',
                  if (!opened) 'stateMessage': state.message,
                  if (opened) 'topic': state.dialogueTopic,
                  if (opened) 'lines': state.dialogueLines.map(line).toList(),
                  if (opened)
                    'choices': [
                      for (final topic in state.availableDialogueTopics)
                        {
                          'topic': topic,
                          'label': state.dialogueTopicLabel(topic),
                        },
                    ],
                };
                attempts.add(row);
                if (opened) starts.add(row);
              }
            }
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
      'dialogueStartAttempts': attempts,
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
