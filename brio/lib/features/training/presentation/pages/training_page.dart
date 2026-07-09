import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/brio_colors.dart';
import '../../../../core/theme/brio_text_styles.dart';
import '../../../../features/dashboard/presentation/providers/month_summary_provider.dart';
import '../../../../shared/widgets/brio_loader.dart';
import '../../domain/entities/routine.dart';
import '../providers/active_session_provider.dart';
import '../providers/training_providers.dart';

class TrainingPage extends ConsumerWidget {
  const TrainingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routinesAsync = ref.watch(routinesProvider);
    final streak        = ref.watch(currentStreakProvider).valueOrNull ?? 0;
    final history       = ref.watch(workoutHistoryProvider).valueOrNull ?? const [];

    // Last time each routine (by name) was done → "X ago".
    final lastByName = <String, DateTime>{};
    for (final w in history) {
      final name = w.routineName;
      if (name == null) continue;
      final t = DateTime.tryParse(w.finishedAtIso);
      if (t == null) continue;
      final cur = lastByName[name];
      if (cur == null || t.isAfter(cur)) lastByName[name] = t;
    }

    return Scaffold(
      backgroundColor: BrioColors.bgBase,
      // bottom:false → content reaches the bottom edge and flows behind the
      // floating bar (like Home), instead of being clipped by the system inset
      // and leaving an opaque background strip behind the bar.
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: BrioColors.green,
          backgroundColor: BrioColors.bgCard,
          onRefresh: () async {
            ref.invalidate(routinesProvider);
            ref.invalidate(workoutHistoryProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
            children: [
              // Title + new.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Entreno', style: BrioTextStyles.h1.copyWith(fontSize: 30)),
                  _NewRoutineButton(),
                ],
              ),
              const SizedBox(height: 18),

              // Hero: start workout.
              _Hero(
                streak: streak,
                onStart: () => _showRoutinePicker(context, ref),
              ),

              // Automatic plan.
              const SizedBox(height: 12),
              const _PlanCard(),

              // Routines.
              const SizedBox(height: 24),
              Text('MIS RUTINAS', style: BrioTextStyles.label),
              const SizedBox(height: 12),
              routinesAsync.when(
                loading: () => const Center(
                  child: Padding(padding: EdgeInsets.all(24), child: BrioLoader(size: 40)),
                ),
                error: (_, __) => Text('No se pudieron cargar las rutinas.', style: BrioTextStyles.bodySmall),
                data: (routines) => routines.isEmpty
                    ? _EmptyRoutines()
                    : Column(
                        children: routines
                            .map((r) => _RoutineRichCard(
                                  routine: r,
                                  lastDone: lastByName[r.name],
                                ))
                            .toList(),
                      ),
              ),

              // More: activity and history.
              const SizedBox(height: 22),
              Text('MÁS', style: BrioTextStyles.label),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MoreTile(
                      icon: Icons.directions_run_rounded,
                      title: 'Actividad',
                      subtitle: 'Cardio / deporte',
                      accent: true,
                      onTap: () => context.push(AppRoutes.logActivity),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: _MoreTile(
                      icon: Icons.history_rounded,
                      title: 'Historial',
                      subtitle: 'Entrenos pasados',
                      onTap: () => context.push(AppRoutes.history),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Routine picker to start from the hero.
  Future<void> _showRoutinePicker(BuildContext context, WidgetRef ref) async {
    final routines = await ref.read(routinesProvider.future);
    if (!context.mounted) return;
    if (routines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Crea una rutina primero con "Nueva".')),
      );
      return;
    }
    await showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: BrioColors.bgBase,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: BrioColors.border, borderRadius: BorderRadius.circular(2)))),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
              child: Text('Empezar entreno', style: BrioTextStyles.h3),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final r in routines)
                    ListTile(
                      leading: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: BrioColors.bgElevated, borderRadius: BorderRadius.circular(11)),
                        child: const Icon(Icons.fitness_center_rounded, color: BrioColors.green, size: 19),
                      ),
                      title: Text(r.name, style: BrioTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                      subtitle: Text('${r.exerciseCount} ejercicios'
                          '${r.estimatedMin > 0 ? ' · ~${r.estimatedMin} min' : ''}',
                          style: BrioTextStyles.bodySmall),
                      trailing: const Icon(Icons.play_arrow_rounded, color: BrioColors.green),
                      onTap: () {
                        Navigator.pop(context);
                        startRoutine(context, ref, r.id);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Starts a session for the given routine and navigates to the session screen.
Future<void> startRoutine(BuildContext context, WidgetRef ref, int routineId) async {
  await ref.read(activeSessionProvider.notifier).start(routineId: routineId);
  if (!context.mounted) return;
  final state = ref.read(activeSessionProvider);
  if (state.hasError) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(state.error.toString()), backgroundColor: BrioColors.error),
    );
    return;
  }
  context.push(AppRoutes.activeSession);
}

// Hero.

class _Hero extends StatelessWidget {
  final int streak;
  final VoidCallback onStart;
  const _Hero({required this.streak, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: BrioColors.gradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('¿List@ para entrenar?',
                    style: BrioTextStyles.bodySmall.copyWith(color: Colors.white.withValues(alpha: 0.92))),
              ),
              if (streak > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text('🔥 $streak ${streak == 1 ? 'día' : 'días'}',
                      style: BrioTextStyles.bodySmall.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text('Empieza tu sesión',
              style: BrioTextStyles.h2.copyWith(color: Colors.white, fontSize: 22)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onStart,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.play_arrow_rounded, color: BrioColors.blueDeep, size: 22),
                  const SizedBox(width: 6),
                  Text('Empezar entreno',
                      style: BrioTextStyles.button.copyWith(color: BrioColors.blueDeep)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// New routine button.

class _NewRoutineButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => context.push(AppRoutes.routineNew),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: BrioColors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: BrioColors.green.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            const Icon(Icons.add_rounded, size: 16, color: BrioColors.green),
            const SizedBox(width: 4),
            Text('Nueva', style: BrioTextStyles.bodySmall.copyWith(
                color: BrioColors.green, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}

// Automatic plan card.

class _PlanCard extends ConsumerWidget {
  const _PlanCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(currentPlanProvider).valueOrNull;
    final hasPlan = plan != null;

    return Column(children: [
    GestureDetector(
      onTap: () => context
          .push(hasPlan ? AppRoutes.weeklySchedule : AppRoutes.planGenerator)
          .then((_) => ref.invalidate(currentPlanProvider)),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: BrioColors.blue.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: BrioColors.blue.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: BrioColors.blue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: BrioColors.blueDeep, size: 21),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(hasPlan ? 'Mi plan semanal' : 'Crear plan automático',
                  style: BrioTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                hasPlan ? '${plan.title} · ${plan.days} días' : 'Rutina de la semana según tu objetivo',
                style: BrioTextStyles.bodySmall.copyWith(color: BrioColors.textSecondary),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: BrioColors.blue),
        ]),
      ),
    ),
    if (!hasPlan)
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => context
              .push(AppRoutes.weeklySchedule)
              .then((_) => ref.invalidate(currentPlanProvider)),
          icon: const Icon(Icons.edit_calendar_rounded, size: 16),
          label: const Text('o configura tu semana a mano'),
          style: TextButton.styleFrom(
            foregroundColor: BrioColors.textSecondary,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
    ]);
  }
}

// Routine card (rich).

class _RoutineRichCard extends ConsumerWidget {
  final RoutineSummary routine;
  final DateTime? lastDone;
  const _RoutineRichCard({required this.routine, this.lastDone});

  String _last() {
    if (lastDone == null) return '';
    final now = DateTime.now();
    final diff = DateTime(now.year, now.month, now.day)
        .difference(DateTime(lastDone!.year, lastDone!.month, lastDone!.day))
        .inDays;
    if (diff <= 0) return 'hoy';
    if (diff == 1) return 'ayer';
    if (diff < 7) return 'hace $diff d';
    return 'hace ${(diff / 7).floor()} sem';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subParts = <String>[
      '${routine.exerciseCount} ejercicios',
      if (routine.estimatedMin > 0) '~${routine.estimatedMin} min',
      if (lastDone != null) _last(),
    ];

    return GestureDetector(
      onTap: () => context.push('${AppRoutes.routineDetail}/${routine.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 11),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: BrioColors.bgCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: BrioColors.border),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: BrioColors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.fitness_center_rounded, size: 21, color: BrioColors.greenDeep),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(routine.name, style: BrioTextStyles.h3.copyWith(fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(subParts.join(' · '), style: BrioTextStyles.metricSmall),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => startRoutine(context, ref, routine.id),
                  child: Container(
                    width: 44, height: 44,
                    decoration: const BoxDecoration(gradient: BrioColors.gradient, shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow_rounded, size: 22, color: Colors.white),
                  ),
                ),
              ],
            ),
            if (routine.muscleGroups.isNotEmpty) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 6, runSpacing: 6,
                  children: [
                    for (final m in routine.muscleGroups)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: BrioColors.bgElevated,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(m, style: BrioTextStyles.bodySmall.copyWith(
                            fontSize: 11, fontWeight: FontWeight.w600, color: BrioColors.textSecondary)),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// "More" tile.

class _MoreTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool accent;
  final VoidCallback onTap;
  const _MoreTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.accent = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: BrioColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent ? BrioColors.green.withValues(alpha: 0.3) : BrioColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: accent ? BrioColors.green.withValues(alpha: 0.12) : BrioColors.bgElevated,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 19, color: accent ? BrioColors.green : BrioColors.textSecondary),
              ),
              const SizedBox(height: 10),
              Text(title, style: BrioTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(subtitle, style: BrioTextStyles.bodySmall),
            ],
          ),
        ),
      );
}

class _EmptyRoutines extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: BrioColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: BrioColors.border),
        ),
        child: Column(
          children: [
            Icon(Icons.fitness_center_rounded, size: 28, color: BrioColors.textTertiary),
            const SizedBox(height: 10),
            Text('Aún no tienes rutinas', style: BrioTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text('Toca "Nueva" para crear tu primera rutina.',
                style: BrioTextStyles.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      );
}
