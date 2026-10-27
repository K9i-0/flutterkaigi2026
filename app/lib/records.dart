import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'character.dart';

/// One finished round. Difficulty differs per character, so ranks are per character.
class GameRecord {
  const GameRecord({
    required this.name,
    required this.score,
    required this.character,
    required this.caught,
    required this.bad,
    required this.missed,
    required this.at,
  });
  final String name;
  final int score, caught, bad, missed;
  final CatchCharacter character;
  final DateTime at;

  Map<String, Object> toMap() => {
    'name': name,
    'score': score,
    'character': character.id,
    'caught': caught,
    'bad': bad,
    'missed': missed,
    'at': at.toIso8601String(),
  };

  static GameRecord? fromMap(Object? data) {
    if (data is! Map) return null;
    final character = CatchCharacter.values
        .where((c) => c.id == data['character'])
        .firstOrNull;
    final at = DateTime.tryParse('${data['at']}');
    if (character == null || at == null || data['name'] is! String) return null;
    int n(String key) => data[key] is int ? data[key] as int : 0;
    return GameRecord(
      name: data['name'] as String,
      score: n('score'),
      character: character,
      caught: n('caught'),
      bad: n('bad'),
      missed: n('missed'),
      at: at,
    );
  }
}

/// Device-local records for the event booth. v2 scores out of 100; the raw
/// point records of v1 are left behind.
class RecordStore {
  static const key = 'yumemi.records.v2', maxRecords = 500, maxName = 12;
  final records = <GameRecord>[];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    records.clear();
    try {
      final data = jsonDecode(prefs.getString(key) ?? '[]') as List;
      records.addAll(data.map(GameRecord.fromMap).nonNulls);
    } catch (_) {
      /* Corrupt data starts an empty board. */
    }
  }

  Future<void> add(GameRecord record) async {
    records.add(record);
    // Keep the best scores when the cap is reached.
    if (records.length > maxRecords) {
      records.sort(compare);
      records.removeRange(maxRecords, records.length);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      key,
      jsonEncode(records.map((r) => r.toMap()).toList()),
    );
  }

  /// Higher score first; ties go to the earlier record.
  static int compare(GameRecord a, GameRecord b) =>
      a.score != b.score ? b.score.compareTo(a.score) : a.at.compareTo(b.at);

  List<GameRecord> ranking(CatchCharacter character) =>
      records.where((r) => r.character == character).toList()..sort(compare);

  /// 1-based rank; equal scores share the best rank.
  int rankOf(GameRecord record) =>
      ranking(record.character).where((r) => r.score > record.score).length + 1;
}
