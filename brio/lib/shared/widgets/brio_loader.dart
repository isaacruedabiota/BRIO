import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Official BRIO loading indicator: the spinning logo arc.
/// Replaces CircularProgressIndicator across the whole app.
class BrioLoader extends StatefulWidget {
  final double size;
  final double strokeWidth;

  /// If true uses the brand gradient; if false, a solid color (useful over
  /// gradient-filled buttons, where the gradient wouldn't be visible).
  final bool gradient;
  final Color? solidColor;

  const BrioLoader({
    super.key,
    this.size = 48,
    this.strokeWidth = 0,
    this.gradient = true,
    this.solidColor,
  });

  /// Small variant for use inside buttons.
  const BrioLoader.button({super.key})
      : size = 22,
        strokeWidth = 3,
        gradient = false,
        solidColor = const Color(0xFF0F0F14);

  @override
  State<BrioLoader> createState() => _BrioLoaderState();
}

class _BrioLoaderState extends State<BrioLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: RotationTransition(
        turns: _ctrl,
        child: CustomPaint(
          painter: _BrioArcPainter(
            strokeWidth: widget.strokeWidth == 0
                ? widget.size * 0.17
                : widget.strokeWidth,
            gradient:   widget.gradient,
            solidColor: widget.solidColor,
          ),
        ),
      ),
    );
  }
}

class _BrioArcPainter extends CustomPainter {
  final double strokeWidth;
  final bool gradient;
  final Color? solidColor;

  _BrioArcPainter({
    required this.strokeWidth,
    required this.gradient,
    this.solidColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect  = Rect.fromLTWH(0, 0, size.width, size.height)
        .deflate(strokeWidth / 2 + 1);
    final paint = Paint()
      ..style       = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap   = StrokeCap.round;

    if (gradient) {
      paint.shader = const LinearGradient(
        begin:  Alignment.bottomLeft,
        end:    Alignment.topRight,
        colors: [Color(0xFF1B6FD0), Color(0xFF329FFC), Color(0xFF7FC4FF)],
      ).createShader(rect);
    } else {
      paint.color = solidColor ?? const Color(0xFF329FFC);
    }

    // Same arc as the logo: 270° open, starting at 135°.
    canvas.drawArc(rect, math.pi * 0.75, math.pi * 1.5, false, paint);
  }

  @override
  bool shouldRepaint(_BrioArcPainter old) =>
      old.strokeWidth != strokeWidth ||
      old.gradient    != gradient    ||
      old.solidColor  != solidColor;
}
