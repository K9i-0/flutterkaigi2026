import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/campaign_audit.dart';
import 'package:sobaya_hazard_lab/game/game_campaign.dart';
import 'package:sobaya_hazard_lab/game/game_controller.dart';
import 'package:sobaya_hazard_lab/game/game_native_audit.dart';
import 'package:sobaya_hazard_lab/game/game_state.dart';

class AuditStartController extends Fake implements HazardGameController {
  final loaded = Completer<bool>();
  @override
  bool disposed = false;
  @override
  int runEpoch = 1;
  @override
  HazardGameState? state = HazardGameState(
    jsonDecode(File('assets/village.json').readAsStringSync()),
  );
  int starts = 0;
  bool? skippedTutorial;

  @override
  Future<bool> startRun({bool skipTutorial = false}) {
    starts++;
    skippedTutorial = skipTutorial;
    return loaded.future;
  }
}

class ExitAudit extends CampaignAudit {
  ExitAudit(super.campaign, {super.transitionRegion});

  // The test isolates transport after the real route has requested an exit.
  @override
  Future<void> walk(
    double x,
    double z, {
    double y = 0,
    double radius = .7,
    bool reach = false,
  }) async {}
}

HazardCampaign campaignAtExit() {
  final campaign = HazardCampaign({
    for (final id in ['village', 'farm', 'mountain'])
      id: jsonDecode(
        File('assets/$id.json').readAsStringSync(),
      ) as Map<String, dynamic>,
  });
  final state = campaign.state;
  state.exitRequested = Map<String, dynamic>.from(
    (state.map['exits'] as List).last,
  );
  state.phase = PlayPhase.transition;
  return campaign;
}

void main() {
  test(
    'native exit awaits environment transport before recording arrival',
    () async {
      final campaign = campaignAtExit(), ready = Completer<bool>();
      final audit = ExitAudit(
        campaign,
        transitionRegion: () async {
          if (!await ready.future) return false;
          return campaign.traverse();
        },
      );
      final exit = audit.exit();
      await Future<void>.delayed(Duration.zero);
      expect(campaign.state.zoneId, 'village');
      expect(audit.events, isEmpty);
      ready.complete(true);
      await exit;
      expect(campaign.state.zoneId, 'farm');
      expect(audit.events.single['event'], 'arrive');
    },
  );

  test(
    'failed native transport does not advance pure campaign state',
    () async {
      final campaign = campaignAtExit();
      final audit = ExitAudit(campaign, transitionRegion: () async => false);
      await expectLater(audit.exit(), throwsStateError);
      expect(campaign.state.zoneId, 'village');
      expect(audit.events, isEmpty);
    },
  );

  test('pure state audit retains synchronous campaign traversal', () async {
    final campaign = campaignAtExit(), audit = ExitAudit(campaign);
    await audit.exit();
    expect(campaign.state.zoneId, 'farm');
    expect(audit.events.single['event'], 'arrive');
  });

  test(
    'audit remains inspectable and stoppable while its region loads',
    () async {
      final game = AuditStartController();
      final audit = NativeCampaignAudit(game, completionist: true);
      final start = audit.start();
      expect(identical(start, audit.start()), true);
      expect(game.starts, 1);
      expect(game.skippedTutorial, true);
      expect(audit.isActive, true);
      expect(audit.inspect()['frames'], 0);
      audit.stop();
      expect(audit.isActive, false);
      game.loaded.complete(true);
      await start;
      expect(audit.status, 'stopped');
      expect(audit.inspect()['frames'], 0);
    },
  );

  test('a failed start reports failure without starting the driver', () async {
    final game = AuditStartController();
    final audit = NativeCampaignAudit(game, completionist: false);
    final start = audit.start();
    game.loaded.complete(false);
    await start;
    expect(audit.status, 'failed');
    expect(audit.error, contains('starting region'));
    expect(audit.inspect()['frames'], 0);
  });

  test(
    'disposal during startup cannot access the campaign or start a driver',
    () async {
      final game = AuditStartController();
      final audit = NativeCampaignAudit(game, completionist: false);
      final start = audit.start();
      game.disposed = true;
      game.loaded.complete(true);
      await start;
      expect(audit.status, 'failed');
      expect(audit.isActive, false);
    },
  );
}
