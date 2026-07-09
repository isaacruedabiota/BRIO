import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/brio_colors.dart';
import '../../../../core/theme/brio_text_styles.dart';
import '../../../../shared/widgets/brio_loader.dart';
import '../../domain/entities/workout_summary.dart';
import '../providers/activity_providers.dart';
import '../providers/training_providers.dart';

/// Unified history item: either a strength workout or an activity.
class _HistoryItem {
  final String dateOnly; // 'yyyy-MM-dd'
  final WorkoutSummary? workout;
  final ActivityLogEntry? activity;
  const _HistoryItem._(this.dateOnly, this.workout, this.activity);
}

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutsAsync   = ref.watch(workoutHistoryProvider);
    final activitiesAsync = ref.watch(activityHistoryProvider);

    return Scaffold(
      backgroundColor: BrioColors.bgBase,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Historial'),
      ),
      body: (workoutsAsync.isLoading || activitiesAsync.isLoading)
          ? const Center(child: BrioLoader(size: 44))
          : _buildList(
              context,
              workoutsAsync.valueOrNull ?? const [],
              activitiesAsync.valueOrNull ?? const [],
            ),
    );
  }

  Widget _buildList(
    BuildContext context,
    List<WorkoutSummary> workouts,
    List<ActivityLogEntry> activities,
  ) {
    final items = <_HistoryItem>[
      for (final w in workouts) _HistoryItem._(w.dateOnly, w, null),
      for (final a in activities) _HistoryItem._(a.performedAt, null, a),
    ]..sort((a, b) => b.dateOnly.compareTo(a.dateOnly));

    if (items.isEmpty) {
      return Center(child: Text('Sin actividad todavía.', style: BrioTextStyles.bodySmall));
    }

    // Group by month.
    final grouped = <String, List<_HistoryItem>>{};
    for (final it in items) {
      grouped.putIfAbsent(_monthKey(it.dateOnly), () => []).add(it);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        for (final entry in grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 10),
            child: Text(entry.key.toUpperCase(), style: BrioTextStyles.label),
          ),
          ...entry.value.map((it) => it.workout != null
              ? _WorkoutCard(workout: it.workout!)
              : _ActivityCard(activity: it.activity!)),
        ],
      ],
    );
  }

  String _monthKey(String iso) {
    final p = iso.split('-');
    if (p.length != 3) return iso;
    const meses = ['', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
    final m = int.tryParse(p[1]) ?? 0;
    return '${m < meses.length ? meses[m] : ''} ${p[0]}';
  }
}

// Strength workout card.
class _WorkoutCard extends StatelessWidget {
  final WorkoutSummary workout;
  const _WorkoutCard({required this.workout});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('${AppRoutes.workoutDetail}/${workout.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: BrioColors.bgCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: BrioColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _iconBox(Icons.fitness_center_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(workout.routineName ?? 'Entreno libre',
                      style: BrioTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                ),
                if (workout.prCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: BrioColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text('${workout.prCount} PR',
                        style: BrioTextStyles.label.copyWith(color: BrioColors.warning)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _Stat(value: _dateEs(workout.dateOnly), label: 'fecha'),
                _dot(),
                _Stat(value: '${workout.setCount}', label: 'series'),
                _dot(),
                _Stat(value: '${workout.totalVolumeKg.toInt()} kg', label: 'volumen'),
                _dot(),
                _Stat(value: '${workout.durationMin} min', label: 'tiempo'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Activity card (cardio/sport).
class _ActivityCard extends StatelessWidget {
  final ActivityLogEntry activity;
  const _ActivityCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    final hasDist = activity.distanceKm != null && activity.distanceKm! > 0;
    return GestureDetector(
      onTap: () => context.push(AppRoutes.activityDetail, extra: activity),
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BrioColors.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BrioColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBox(activity.iconData),
              const SizedBox(width: 12),
              Expanded(
                child: Text(activity.name,
                    style: BrioTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: BrioColors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text('${activity.calories} kcal',
                    style: BrioTextStyles.label.copyWith(color: BrioColors.green)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Stat(value: _dateEs(activity.performedAt), label: 'fecha'),
              _dot(),
              _Stat(value: '${activity.durationMin} min', label: 'tiempo'),
              if (hasDist) ...[
                _dot(),
                _Stat(value: '${activity.distanceKm!.toStringAsFixed(2)} km', label: 'distancia'),
                _dot(),
                _Stat(value: _pace(activity), label: 'ritmo /km'),
              ],
            ],
          ),
        ],
      ),
      ),
    );
  }

  String _pace(ActivityLogEntry a) {
    if (a.distanceKm == null || a.distanceKm! < 0.01) return '--:--';
    final secPerKm = (a.durationMin * 60) / a.distanceKm!;
    final m = (secPerKm ~/ 60).toString().padLeft(2, '0');
    final s = (secPerKm % 60).toInt().toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// Shared helpers.
Widget _iconBox(IconData icon) => Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        color: BrioColors.green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, size: 20, color: BrioColors.green),
    );

Widget _dot() => Container(
      width: 3, height: 3, margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: BrioColors.textTertiary, shape: BoxShape.circle),
    );

String _dateEs(String iso) {
  final p = iso.split('-');
  if (p.length != 3) return iso;
  const meses = ['', 'ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
  final m = int.tryParse(p[1]) ?? 0;
  return '${int.parse(p[2])} ${m < meses.length ? meses[m] : ''}';
}

class _Stat extends StatelessWidget {
  final String value, label;
  const _Stat({required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: BrioTextStyles.metric.copyWith(fontSize: 14)),
          Text(label, style: BrioTextStyles.label.copyWith(fontSize: 9)),
        ],
      );
}
