import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/brio_colors.dart';
import '../../core/theme/brio_text_styles.dart';

/// Circular calorie progress ring.
/// The gradient is applied only here and in the logo — nowhere else.
class MacroRing extends StatelessWidget {
  final double consumed;
  final double goal;
  final double size;

  const MacroRing({
    super.key,
    required this.consumed,
    required this.goal,
    this.size = 100,
  });

  double get _progress => goal > 0 ? (consumed / goal).clamp(0.0, 1.2) : 0;

  @override
  Widget build(BuildContext context) {
    final remaining = (goal - consumed).clamp(0, goal);
    return SizedBox(
      width:  size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(progress: _progress),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                consumed.toInt().toString(),
                style: BrioTextStyles.metric.copyWith(fontSize: size * 0.26),
              ),
              const SizedBox(height: 1),
              Text(
                remaining.toInt().toString(),
                style: BrioTextStyles.metricSmall.copyWith(
                  fontSize: size * 0.13,
                  color: BrioColors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  const _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center   = Offset(size.width / 2, size.height / 2);
    final radius   = size.width / 2 - size.width * 0.07;
    final stroke   = size.width * 0.085;
    final rect     = Rect.fromCircle(center: center, radius: radius);

    // Track (grey background).
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi,
      false,
      Paint()
        ..style       = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color       = BrioColors.border,
    );

    if (progress <= 0) return;

    // Progress arc with brand gradient.
    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweepAngle,
      false,
      Paint()
        ..style       = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap   = StrokeCap.round
        ..shader      = SweepGradient(
            startAngle: -math.pi / 2,
            endAngle:   -math.pi / 2 + 2 * math.pi,
            colors: const [
              Color(0xFF1B6FD0),
              Color(0xFF329FFC),
              Color(0xFF7FC4FF),
              Color(0xFF1B6FD0),
            ],
            stops: const [0.0, 0.4, 0.75, 1.0],
          ).createShader(rect),
    );

    // Rounded end cap (solid color dot to hide the gradient seam artifact).
    if (sweepAngle > 0.1) {
      final endX = center.dx + radius * math.cos(-math.pi / 2 + sweepAngle);
      final endY = center.dy + radius * math.sin(-math.pi / 2 + sweepAngle);
      canvas.drawCircle(
        Offset(endX, endY),
        stroke / 2,
        Paint()..color = const Color(0xFF7FC4FF),
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}
