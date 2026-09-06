part of 'game_state.dart';

enum ShotPart { body, head, mug }

extension HazardCombatBalance on HazardGameState {
  bool get hardest => difficulty == HazardDifficulty.tense;
  int get livingEnemies => enemies.where((e) => e.alive).length;
  bool get chapterSecured => !hardest || livingEnemies == 0;

  int pickupAmount(Pickup p) {
    if (!['ammo', 'shells'].contains(p.kind)) return p.amount;
    if (hardest) {
      // One loose handgun cartridge per chapter. All other ammunition is
      // supplied by Yame or paid for in beer; the shotgun starts empty.
      final first = pickups
          .where((i) => i.kind == 'ammo' && !i.id.endsWith('_loot'))
          .firstOrNull;
      return p == first ? 1 : 0;
    }
    if (difficulty == HazardDifficulty.casual || p.id.endsWith('_loot')) {
      return p.amount;
    }
    return math.max(1, (p.amount / (p.kind == 'ammo' ? 4 : 2)).ceil());
  }

  double bulletDamage(ShotPart part) {
    if (weapon == 'shotgun') {
      return switch (difficulty) {
        HazardDifficulty.tense => switch (part) {
          ShotPart.body => 45,
          ShotPart.head => 100,
          ShotPart.mug => 80,
        },
        HazardDifficulty.standard => switch (part) {
          ShotPart.body => 70,
          ShotPart.head => 120,
          ShotPart.mug => 100,
        },
        HazardDifficulty.casual => switch (part) {
          ShotPart.body => 100,
          ShotPart.head => 140,
          ShotPart.mug => 120,
        },
      };
    }
    return switch (difficulty) {
      HazardDifficulty.tense => switch (part) {
        ShotPart.body => 20,
        ShotPart.head => 35,
        ShotPart.mug => 40,
      },
      HazardDifficulty.standard => switch (part) {
        ShotPart.body => 30,
        ShotPart.head => 60,
        ShotPart.mug => 70,
      },
      HazardDifficulty.casual => switch (part) {
        ShotPart.body => 35,
        ShotPart.head => 70,
        ShotPart.mug => 80,
      },
    };
  }
}

double? _raySphere(
  vm.Vector3 origin,
  vm.Vector3 direction,
  vm.Vector3 centre,
  double radius,
  double limit,
) {
  final to = centre - origin, along = to.dot(direction);
  final perpendicular = to.length2 - along * along;
  if (along <= 0 || perpendicular > radius * radius) return null;
  final distance = math.max(
    0.0,
    along - math.sqrt(radius * radius - perpendicular),
  );
  return distance < limit ? distance : null;
}
