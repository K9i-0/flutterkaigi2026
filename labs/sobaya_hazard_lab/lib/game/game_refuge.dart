part of 'game_state.dart';

/// The final house replaces the old eastern exit. Reports deliberately use
/// new keys so optional conversations in older saves cannot finish the game.
extension HazardRefuge on HazardGameState {
  bool get hasRefuge => zoneId == 'mountain';
  bool get refugeUnlocked => hasRefuge && !bossAlive && chapterSecured;
  bool refugeContains(double px, double pz, {double padding = 0}) =>
      hasRefuge &&
      px > 7 - padding &&
      px < 19 + padding &&
      pz > 9.5 - padding &&
      pz < 18.5 + padding;
  bool get insideRefuge =>
      refugeUnlocked && y < 1 && refugeContains(x, z, padding: -.35);
  Set<String> get refugeReports => {
    for (final id in HazardGameState.companionNames.keys)
      if (seenEvents.contains('refuge_report_$id')) id,
  };
  bool get refugeComplete =>
      refugeUnlocked && seenEvents.contains('refuge_complete');
  String get refugeObjective =>
      bossAlive ? '神社の巨大そば屋を倒し、村の異変を調べる' : '祠に異常は見つからない — 神社の東の管理道を調べる';
  String get dialogueLeaveLabel => 'E  探索へ戻る';
  Iterable<HazardWindow> get usableWindows => hasRefuge ? const [] : windows;
  Iterable<Obstacle> get collisionObstacles sync* {
    for (final o in obstacles) {
      if (hasRefuge && o.id == 'gate') continue;
      yield o;
    }
    if (hasRefuge) {
      yield Obstacle({
        'x': 9.52,
        'z': 9.5,
        'w': 1.56,
        'd': .25,
        'bottom': .82,
        'top': 2.42,
      });
      if (!refugeUnlocked) {
        yield Obstacle({
          'x': 13,
          'z': 9.5,
          'w': 1.72,
          'd': .25,
          'bottom': 0,
          'top': 2.2,
        });
      }
    }
  }

  void refreshRefuge() {
    if (!hasRefuge) return;
    if (!bossAlive) seenEvents.add('giant_defeated');
    if (refugeUnlocked) {
      if (seenEvents.add('refuge_ready')) {
        checkpointRequested = true;
        say('境内が静まった。神社の裏手から機械の音が聞こえる。');
        emitSound('gate', x: 13, z: 9.5);
      }
    } else {
      seenEvents.remove('refuge_ready');
    }
    clearAbsentCompanionTargets();
  }

  void _rememberRefugeReport() {
    if (insideRefuge && dialogueTopic == 'reunion' && dialogueChoices) {
      _refugeReportPending = true;
    }
  }

  /// Migrate old indoor/window saves and keep live enemies outside the refuge.
  void normalizeRefugeOccupants() {
    if (!hasRefuge) return;
    if ((!refugeUnlocked && refugeContains(x, z, padding: .3)) ||
        vault != null) {
      x = 13;
      z = 7.7;
      y = 0;
      climb = null;
      vault = null;
      grapple = null;
      breakFreeTime = 0;
      stopInput();
    }
    for (final e in enemies) {
      if (e.alive &&
          (refugeContains(e.x, e.z, padding: e.collisionRadius) ||
              e.vault != null)) {
        final row = (map['enemies'] as List).firstWhere(
          (row) => row['id'] == e.id,
        );
        e.x = (row['x'] as num).toDouble();
        e.z = (row['z'] as num).toDouble();
        e.y = 0;
        e.vault = null;
        e.climb = null;
        e.companionTarget = null;
        e.attackPending = e.grabPending = false;
        e.windup = 0;
        if (grapple?.enemyId == e.id) {
          grapple = null;
          breakFreeTime = 0;
        }
      }
    }
    refreshRefuge();
  }
}
