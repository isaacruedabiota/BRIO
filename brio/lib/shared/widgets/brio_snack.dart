import 'package:flutter/material.dart';
import '../../core/theme/brio_colors.dart';

/// BRIO's eye-catching floating notifications (replace the grey SnackBar).
/// Rounded pill with a gradient, an icon that "bounces" in, and a colored glow
/// shadow. Usage: `BrioSnack.success(context, 'Guardado')`.
enum _SnackType { success, error, info }

class BrioSnack {
  static void success(BuildContext c, String m, {IconData icon = Icons.check_rounded}) =>
      _show(c, m, _SnackType.success, icon);
  static void error(BuildContext c, String m, {IconData icon = Icons.error_outline_rounded}) =>
      _show(c, m, _SnackType.error, icon);
  static void info(BuildContext c, String m, {IconData icon = Icons.bolt_rounded}) =>
      _show(c, m, _SnackType.info, icon);

  static void _show(BuildContext context, String message, _SnackType type, IconData icon) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
      duration: const Duration(milliseconds: 2800),
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 16),
      padding: EdgeInsets.zero,
      content: _BrioSnackContent(message: message, type: type, icon: icon),
    ));
  }
}

class _BrioSnackContent extends StatefulWidget {
  final String message;
  final _SnackType type;
  final IconData icon;
  const _BrioSnackContent({required this.message, required this.type, required this.icon});

  @override
  State<_BrioSnackContent> createState() => _BrioSnackContentState();
}

class _BrioSnackContentState extends State<_BrioSnackContent> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 620))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Gradient get _gradient => switch (widget.type) {
        _SnackType.success => BrioColors.gradient,
        _SnackType.error => const LinearGradient(
            begin: Alignment.bottomLeft, end: Alignment.topRight,
            colors: [Color(0xFFC81E1E), Color(0xFFFF4D4D), Color(0xFFFF8A8A)], stops: [0, 0.6, 1]),
        _SnackType.info => const LinearGradient(
            begin: Alignment.bottomLeft, end: Alignment.topRight,
            colors: [Color(0xFF1B6FD0), Color(0xFF329FFC), Color(0xFF7FC4FF)], stops: [0, 0.55, 1]),
      };

  Color get _glow => switch (widget.type) {
        _SnackType.error => const Color(0xFFFF4D4D),
        _ => BrioColors.blue,
      };

  @override
  Widget build(BuildContext context) {
    final slide = Tween<Offset>(begin: const Offset(0, 0.6), end: Offset.zero)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    final fade = CurvedAnimation(parent: _c, curve: const Interval(0, 0.5));
    final pop = CurvedAnimation(parent: _c, curve: const Interval(0.15, 1, curve: Curves.elasticOut));

    return SlideTransition(
      position: slide,
      child: FadeTransition(
        opacity: fade,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            gradient: _gradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: _glow.withValues(alpha: 0.45), blurRadius: 22, offset: const Offset(0, 8)),
              BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 10, offset: const Offset(0, 3)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: pop,
                child: Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.icon, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  widget.message,
                  style: const TextStyle(
                    color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700, height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
