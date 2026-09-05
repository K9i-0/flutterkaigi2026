import 'dart:convert';
import 'dart:io';

import 'package:sobaya_hazard_lab/game/campaign_audit.dart';
import 'package:sobaya_hazard_lab/game/game_campaign.dart';
import 'package:sobaya_hazard_lab/game/game_state.dart';

Future<void> main(List<String> args) async {
  final maps = {
    for (final id in ['village', 'farm', 'mountain'])
      id: Map<String, dynamic>.from(
        jsonDecode(File('assets/$id.json').readAsStringSync()),
      ),
  };
  final audit = CampaignAudit(
    HazardCampaign(maps),
    onRecord: (row) => stdout.writeln(jsonEncode(row)),
  );
  audit.completionist = args.contains('--complete');
  var success = false;
  String? error;
  try {
    await audit.run();
    success = audit.s.phase == PlayPhase.clear;
  } catch (e, st) {
    error = '$e\n$st';
    stderr.writeln(error);
  }
  final report = {
    'success': success,
    'error': error,
    'scope': 'Rules and collision simulation, not rendered UI or human full playthrough',
    'completionist': audit.completionist,
    'weaponsUsed': audit.weaponsUsed.toList(),
    'events': audit.events,
    'final': audit.s.inspect(),
  };
  File(args.firstOrNull ?? 'evidence/campaign-audit.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(report)}\n',
  );
  if (!success) exitCode = 1;
}
