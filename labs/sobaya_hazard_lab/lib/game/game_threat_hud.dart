import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'game_state.dart';

Color threatColor(String phase) => switch (phase) {
  'chasing' => const Color(0xffff7866),
  'searching' => const Color(0xffffbd70),
  'returning' => const Color(0xffadbd9b),
  _ => const Color(0xffe5cf82),
};

class HazardThreatStatus extends StatelessWidget {
  const HazardThreatStatus({
    super.key,
    required this.feedback,
    this.compact = false,
  });
  final StealthFeedback feedback;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final f = feedback;
    if (f.phase == 'calm') return const SizedBox.shrink();
    final label = switch (f.phase) {
      'chasing' => '発見中 — 視界を切れ',
      'searching' => '追跡解除まで ${f.remaining.ceil()}秒',
      'returning' => '追跡解除 — 持ち場へ戻っている',
      _ => '疑われている',
    };
    return Semantics(
      label: label,
      child: Container(
        key: const ValueKey('game-threat-status'),
        padding: compact
            ? const EdgeInsets.only(top: 5)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: compact
            ? null
            : BoxDecoration(
                color: const Color(0xc5161c18),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: threatColor(f.phase).withValues(alpha: .4),
                ),
              ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  f.phase == 'chasing'
                      ? Icons.visibility
                      : f.phase == 'returning'
                      ? Icons.directions_walk
                      : Icons.hearing,
                  color: threatColor(f.phase),
                  size: compact ? 13 : 16,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 10 : 12,
                      color: threatColor(f.phase),
                    ),
                  ),
                ),
              ],
            ),
            if (f.phase == 'searching' || f.phase == 'suspicious') ...[
              const SizedBox(height: 5),
              LinearProgressIndicator(
                key: const ValueKey('game-search-progress'),
                minHeight: 3,
                value: f.phase == 'searching'
                    ? (f.remaining / math.max(1, f.duration)).clamp(0.0, 1.0)
                    : f.suspicion.clamp(0.0, 1.0),
                color: threatColor(f.phase),
                backgroundColor: Colors.white12,
              ),
              if (f.reason.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    f.reason,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 9 : 10,
                      color: const Color(0xffc8c8b4),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class HazardThreatOverlay extends StatelessWidget {
  const HazardThreatOverlay({
    super.key,
    required this.feedback,
    required this.time,
    required this.yaw,
    required this.strength,
  });
  final StealthFeedback feedback;
  final double time, yaw, strength;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      painter: _ThreatPainter(feedback, time, yaw, strength),
      size: Size.infinite,
    ),
  );
}

class _ThreatPainter extends CustomPainter {
  _ThreatPainter(this.f, this.time, this.yaw, this.strength);
  final StealthFeedback f;
  final double time, yaw, strength;
  @override
  void paint(Canvas canvas, Size size) {
    if (strength <= 0 || f.phase == 'calm' || f.phase == 'returning') return;
    final chase = f.phase == 'chasing';
    final amount = strength * (chase ? .12 + .035 * math.sin(time * 7) : .055);
    final color = threatColor(f.phase);
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: .8,
          colors: [
            Colors.transparent,
            color.withValues(alpha: amount),
          ],
          stops: const [.65, 1],
        ).createShader(rect),
    );
    if (f.bearing != null) {
      final angle = (yaw + math.pi) - f.bearing! - math.pi / 2;
      final centre = size.center(Offset.zero);
      final radius = math.min(size.width, size.height) * .24;
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: radius),
        angle - .12,
        .24,
        false,
        Paint()
          ..color = color.withValues(alpha: .7 * strength)
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ThreatPainter oldDelegate) => true;
}
