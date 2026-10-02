import 'dart:math' as math;

import 'surface_fluid.dart';

enum PourPhase { ready, approach, pouring, settling, result }

/// Deterministic, fixed-step volume model. Units are fractions of one mug.
/// Foam occupies volume; collapse transfers volume to beer to keep the game
/// readable. This is a tuned game model, not a fluid dynamics solver.
class PourGame {
  final surface = SurfaceFluid();
  static const duration = 18.0, flightTime = .24, idealFoam = .30;
  PourPhase phase = PourPhase.ready;
  double beer = 0, foam = 0, time = 0, phaseTime = 0;
  double tilt = 0, flow = 0, agitation = 0, slope = 0, slopeVelocity = 0;
  double lastTilt = 0, arrival = 0;
  bool spilled = false;
  final List<({double at, double volume, double foamRatio})> _air = [];
  double get fill => beer + foam;
  double get foamRatio => fill > 0 ? foam / fill : 0;
  double get airborne => _air.fold(0, (v, p) => v + p.volume);
  double get remaining => math.max(0, duration - time);
  double get ratioQuality =>
      (1 - math.max(0, (foamRatio - idealFoam).abs() - .01) / .30).clamp(0, 1);
  int get score =>
      spilled ? 0 : (fill.clamp(0, 1) * 100 * ratioQuality).round();
  bool get angry => spilled || score < 80;
  String get verdict => spilled
      ? '何こぼしとんねん！'
      : score >= 100
      ? '……完璧やな。'
      : score >= 90
      ? 'ええ一杯や。'
      : score >= 80
      ? 'あと一息やな。'
      : fill < .8
      ? '足りんやろが！'
      : '泡の量、おかしいやろ！';

  void start() {
    phase = PourPhase.approach;
    beer = foam = time = phaseTime = tilt = flow = agitation = slope =
        slopeVelocity = lastTilt = arrival = 0;
    spilled = false;
    _air.clear();
    surface.reset();
  }

  void serve() {
    if (phase != PourPhase.pouring) return;
    phase = PourPhase.settling;
    phaseTime = 0;
    tilt = flow = 0;
  }

  void tick(double dt, {double input = 0}) {
    if (!dt.isFinite || dt <= 0 || dt > 1 / 30 + 1e-8) {
      throw ArgumentError('Use a fixed simulation step <= 1/30 second');
    }
    if (!input.isFinite) throw ArgumentError('Tilt must be finite');
    phaseTime += dt;
    if (phase == PourPhase.ready || phase == PourPhase.result) return;
    if (phase == PourPhase.approach) {
      if (phaseTime >= 1.6) {
        phase = PourPhase.pouring;
        phaseTime = 0;
      }
      return;
    }
    time += dt;
    tilt = phase == PourPhase.pouring ? input.clamp(0, 1) : 0;
    final speed = (tilt - lastTilt).abs() / dt;
    agitation +=
        ((speed * .10).clamp(0, 1) - agitation) * (1 - math.exp(-dt * 6));
    lastTilt = tilt;
    flow = ((tilt - .08) / .92).clamp(0, 1);
    if (flow > 0) {
      _air.add((
        at: time + flightTime,
        volume: flow * .145 * dt,
        foamRatio: (.10 + .48 * flow * flow + agitation * .16).clamp(.1, .8),
      ));
    }
    arrival = 0;
    while (_air.isNotEmpty && _air.first.at <= time + 1e-8) {
      final p = _air.removeAt(0);
      beer += p.volume * (1 - p.foamRatio);
      foam += p.volume * p.foamRatio;
      arrival += p.volume / dt;
    }
    final collapse = math.min(foam, foam * .004 * dt);
    foam -= collapse;
    beer += collapse;
    final targetSlope = math.sin(time * 7) * arrival * .018 + agitation * .004;
    slopeVelocity += ((targetSlope - slope) * 100 - slopeVelocity * 11) * dt;
    slope += slopeVelocity * dt;
    surface.step(
      dt,
      flow: arrival / .145,
      agitation: agitation,
      depth: fill * .18,
    );
    // The highest rim point also spills, so violent movement matters at full.
    if (fill + math.max(slope.abs(), surface.peak / .18) > 1 + 1e-8) {
      spilled = true;
      phase = PourPhase.result;
      phaseTime = 0;
      flow = 0;
      _air.clear();
      return;
    }
    if (phase == PourPhase.pouring && time >= duration) serve();
    if (phase == PourPhase.settling && phaseTime >= .8 && _air.isEmpty) {
      phase = PourPhase.result;
      phaseTime = 0;
    }
  }

  Map<String, Object> inspect() => {
    'phase': phase.name,
    'beer': beer,
    'foam': foam,
    'fill': fill,
    'foamRatio': foamRatio,
    'score': score,
    'spilled': spilled,
    'remaining': remaining,
    'airborne': airborne,
    'flow': flow,
    'slope': slope,
    'wavePeakMetres': surface.peak,
    'verdict': verdict,
  };
}
