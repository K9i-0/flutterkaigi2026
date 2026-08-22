import 'dart:math' as math;

double normalizedTime(double timeOfDay) => timeOfDay - timeOfDay.floor();

double sunElevationForTime(double timeOfDay) =>
    math.sin((normalizedTime(timeOfDay) - 0.25) * math.pi * 2);

/// Maps the game clock to a longer 05:00–21:00 daylight arc.
double solarTimeForClock(double timeOfDay) {
  final hour = normalizedTime(timeOfDay) * 24;
  if (hour >= 5 && hour < 12) {
    return 0.25 + (hour - 5) / 7 * 0.25;
  }
  if (hour >= 12 && hour < 21) {
    return 0.5 + (hour - 12) / 9 * 0.25;
  }
  final nightHour = hour < 5 ? hour + 24 : hour;
  return normalizedTime(0.75 + (nightHour - 21) / 8 * 0.5);
}

double _smoothStep(double edge0, double edge1, double value) {
  final t = ((value - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

double daylightForTime(double timeOfDay) {
  final elevation = sunElevationForTime(timeOfDay);
  return _smoothStep(-0.2, 0.3, elevation);
}

double twilightForTime(double timeOfDay) {
  final elevation = sunElevationForTime(timeOfDay).abs();
  return 1 - _smoothStep(0.04, 0.56, elevation);
}

double moonlightForTime(double timeOfDay) {
  final nightDepth = -sunElevationForTime(timeOfDay);
  return _smoothStep(0.02, 0.72, nightDepth);
}

/// Slows the visually important golden hour while keeping a brisk game day.
double timeFlowRate(double timeOfDay) {
  final hour = normalizedTime(timeOfDay) * 24;
  if (hour >= 16 && hour < 21) return 0.62;
  if (hour >= 5 && hour < 8) return 0.8;
  if (hour >= 8 && hour < 16) return 1.08;
  return 1.12;
}

double advanceTimeOfDay(
  double timeOfDay,
  double realDeltaSeconds, {
  double nominalDaySeconds = 720,
}) {
  if (realDeltaSeconds <= 0 || nominalDaySeconds <= 0) {
    return normalizedTime(timeOfDay);
  }
  return normalizedTime(
    timeOfDay + realDeltaSeconds * timeFlowRate(timeOfDay) / nominalDaySeconds,
  );
}

String clockLabelForTime(double timeOfDay) {
  final totalMinutes =
      (normalizedTime(timeOfDay) * 24 * 60).round() % (24 * 60);
  final hour = totalMinutes ~/ 60;
  final minute = totalMinutes % 60;
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

String phaseLabelForTime(double timeOfDay) {
  final hour = normalizedTime(timeOfDay) * 24;
  if (hour < 5 || hour >= 21) return '夜';
  if (hour < 8) return '朝';
  if (hour < 16) return '昼';
  return '夕方';
}
