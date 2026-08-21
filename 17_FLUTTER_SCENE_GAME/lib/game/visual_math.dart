import 'dart:math' as math;

double normalizedTime(double timeOfDay) => timeOfDay - timeOfDay.floor();

double sunElevationForTime(double timeOfDay) =>
    math.sin((normalizedTime(timeOfDay) - 0.25) * math.pi * 2);

double daylightForTime(double timeOfDay) {
  final elevation = sunElevationForTime(timeOfDay);
  final t = ((elevation + 0.12) / 0.34).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

double twilightForTime(double timeOfDay) {
  final elevation = sunElevationForTime(timeOfDay).abs();
  return (1 - elevation / 0.42).clamp(0.0, 1.0);
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
  if (hour < 5 || hour >= 20) return '夜';
  if (hour < 8) return '朝';
  if (hour < 17) return '昼';
  return '夕方';
}
