import 'game_checkpoint.dart';
import 'game_state.dart';

/// Region-local worlds survive backtracking; only the traveller's inventory,
/// health, collection and run statistics cross a boundary.
class HazardCampaign {
  HazardCampaign(this.maps, {Set<String>? collection}) {
    catalog = [
      for (final map in maps.values)
        ...((map['collection'] as List).cast<Map<String, dynamic>>()),
    ];
    state = _fresh('village', collection ?? {});
    regions['village'] = state;
  }
  final Map<String, Map<String, dynamic>> maps;
  late final List<Map<String, dynamic>> catalog;
  final regions = <String, HazardGameState>{};
  late HazardGameState state;

  HazardGameState _fresh(String id, Set<String> collection) => HazardGameState(
    maps[id] ?? (throw FormatException('Unknown region $id')),
    savedCollection: collection,
    catalog: catalog,
  );

  void restart() {
    final collection = state.collected;
    regions.clear();
    state = _fresh('village', collection);
    regions['village'] = state;
  }

  bool traverse() {
    final from = state, exit = from.exitRequested;
    if (exit == null || from.phase != PlayPhase.transition) return false;
    final id = exit['target'] as String;
    final arrival = exit['arrival'] as Map;
    final to = regions[id] ?? _fresh(id, from.collected);
    _carry(from, to);
    to.x = (arrival['x'] as num).toDouble();
    to.z = (arrival['z'] as num).toDouble();
    to.y = 0;
    to.yaw = (arrival['yaw'] as num).toDouble();
    to.heading = to.yaw + 3.141592653589793;
    if (to.blocked(to.x, to.z, to.y)) throw StateError('Blocked arrival: $id');
    to.stopInput();
    to.reloading = to.hurtTime = to.evadeTime = to.kickTime = 0;
    to.fireCooldown = to.recoil = to.damageFlash = to.noiseTime = 0;
    to.invulnerable = 1;
    to.exitRequested = null;
    to.phase = PlayPhase.playing;
    to.say('${to.subtitle}\n${to.objective}');
    to.checkpointRequested = true;
    from.exitRequested = null;
    from.phase = PlayPhase.playing;
    regions[id] = to;
    state = to;
    return true;
  }

  void _carry(HazardGameState from, HazardGameState to) {
    to.bag
      ..clear()
      ..addAll(
        from.bag.map(
          (i) => BagItem(i.id, i.kind, i.count, i.col, i.row, i.w, i.h),
        ),
      );
    to.nextBagId = from.nextBagId;
    to.health = from.health;
    to.maxHealth = from.maxHealth;
    to.weapon = from.weapon;
    to.pistolLoaded = from.pistolLoaded;
    to.shotgunLoaded = from.shotgunLoaded;
    to.beers = from.beers;
    to.kills = from.kills;
    to.shots = from.shots;
    to.hits = from.hits;
    to.time = from.time;
    to.metYametaro = from.metYametaro;
    to.receivedYametaroAmmo = from.receivedYametaroAmmo;
    to.metTakosan = from.metTakosan;
    to.tradePurchases
      ..clear()
      ..addAll(from.tradePurchases);
    to.collected
      ..clear()
      ..addAll(from.collected);
    to.seenEvents
      ..clear()
      ..addAll(from.seenEvents);
    to.medallions
      ..clear()
      ..addAll(from.medallions);
  }

  Map<String, dynamic> checkpoint() => {
    'version': 2,
    'region': state.zoneId,
    'regions': regions.map((id, s) => MapEntry(id, s.checkpoint())),
  };

  static HazardCampaign restore(
    Map<String, dynamic> data,
    Map<String, Map<String, dynamic>> maps,
    Set<String> collection,
  ) {
    final campaign = HazardCampaign(maps, collection: collection);
    if (data['version'] == 1) {
      campaign.state = restoreHazardCheckpoint(
        data,
        maps['village']!,
        collection,
        catalog: campaign.catalog,
      );
      campaign.regions['village'] = campaign.state;
      return campaign;
    }
    if (data['version'] != 2) throw const FormatException('Invalid campaign');
    final regionData = data['regions'] as Map<String, dynamic>;
    if (!regionData.containsKey('village') ||
        !regionData.containsKey(data['region']) ||
        regionData.length > maps.length) {
      throw const FormatException('Incomplete campaign');
    }
    campaign.regions.clear();
    for (final entry in regionData.entries) {
      final map = maps[entry.key];
      if (map == null) throw const FormatException('Unknown region');
      campaign.regions[entry.key] = restoreHazardCheckpoint(
        entry.value,
        map,
        collection,
        catalog: campaign.catalog,
      );
    }
    campaign.state = campaign.regions[data['region']]!;
    final kills = campaign.regions.values.fold<int>(
      0,
      (n, s) => n + s.enemies.where((e) => !e.alive).length,
    );
    if (kills != campaign.state.kills) {
      throw const FormatException('Invalid defeat total');
    }
    return campaign;
  }
}
