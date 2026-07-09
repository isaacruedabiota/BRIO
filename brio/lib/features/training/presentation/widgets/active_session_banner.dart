import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/brio_colors.dart';
import '../../../../core/theme/brio_text_styles.dart';
import '../providers/active_session_provider.dart';

/// Floating bar shown above the tabs when a workout is in progress.
/// Tapping it resumes the session. Hevy-style "Workout in progress".
class ActiveSessionBanner extends ConsumerStatefulWidget {
  const ActiveSessionBanner({super.key});

  @override
  ConsumerState<ActiveSessionBanner> createState() => _ActiveSessionBannerState();
}

class _ActiveSessionBannerState extends ConsumerState<ActiveSessionBanner> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final started = ref.read(activeSessionProvider).valueOrNull?.startedAt;
      if (started != null && mounted) {
        setState(() => _elapsed = DateTime.now().difference(started));
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider).valueOrNull;

    // No session, or already on the session screen → don't show.
    final location = GoRouterState.of(context).matchedLocation;
    if (session == null || location == AppRoutes.activeSession) {
      return const SizedBox.shrink();
    }

    final completed = session.sets.length;

    return GestureDetector(
      onTap: () => context.push(AppRoutes.activeSession),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: BrioColors.gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: BrioColors.green.withValues(alpha: 0.3),
              blurRadius: 16, offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Pulsing dot + status.
            Container(
              width: 10, height: 10,
              decoration: const BoxDecoration(color: BrioColors.textInverse, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Entreno en curso${session.routine != null ? ' · ${session.routine!.name}' : ''}',
                    style: BrioTextStyles.button.copyWith(fontSize: 14),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${_fmt(_elapsed)}  ·  $completed ${completed == 1 ? 'serie' : 'series'}',
                    style: BrioTextStyles.bodySmall.copyWith(
                      color: BrioColors.textInverse.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: BrioColors.textInverse.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                children: [
                  const Icon(Icons.play_arrow_rounded, size: 16, color: BrioColors.textInverse),
                  const SizedBox(width: 2),
                  Text('Reanudar', style: BrioTextStyles.button.copyWith(fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
