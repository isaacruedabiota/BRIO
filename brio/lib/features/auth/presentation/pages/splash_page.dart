import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/brio_colors.dart';
import '../../../../core/theme/brio_text_styles.dart';

// Navigation away from the splash is handled by the router's redirect as soon
// as authNotifierProvider finishes resolving. Here we only animate.
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>    _scaleAnim;
  late final Animation<double>    _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _scaleAnim = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fadeAnim  = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: BrioColors.bgBase,
        body: Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo — the BRIO arc drawn in code.
                ScaleTransition(
                  scale: _scaleAnim,
                  child: _BrioLogo(size: 100),
                ),
                const SizedBox(height: 24),
                ScaleTransition(
                  scale: _scaleAnim,
                  child: ShaderMask(
                    shaderCallback: (bounds) =>
                        BrioColors.gradient.createShader(bounds),
                    child: Text(
                      'BRIO',
                      style: BrioTextStyles.h1.copyWith(
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FadeTransition(
                  opacity: _fadeAnim,
                  child: Text(
                    'Tu energía, tu ritmo.',
                    style: BrioTextStyles.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

// The BRIO icon (arc) drawn with a CustomPainter.
class _BrioLogo extends StatelessWidget {
  final double size;
  const _BrioLogo({required this.size});

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size(size, size),
        painter: _ArcPainter(),
      );
}

class _ArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect   = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint  = Paint()
      ..style      = PaintingStyle.stroke
      ..strokeWidth= size.width * 0.17
      ..strokeCap  = StrokeCap.round
      ..shader     = const LinearGradient(
          begin:  Alignment.bottomLeft,
          end:    Alignment.topRight,
          colors: [Color(0xFF1B6FD0), Color(0xFF329FFC), Color(0xFF7FC4FF)],
          stops:  [0.0, 0.55, 1.0],
        ).createShader(rect);

    // 270° arc (gap in the bottom-right corner).
    canvas.drawArc(
      rect.deflate(size.width * 0.085),
      2.356,   // 135° in radians (start point)
      4.712,   // 270° in radians (sweep)
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
