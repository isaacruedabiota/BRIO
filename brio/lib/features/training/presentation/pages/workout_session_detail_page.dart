import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/brio_colors.dart';
import '../../../../core/theme/brio_text_styles.dart';
import '../../../../shared/widgets/brio_loader.dart';
import '../providers/training_providers.dart';

/// Detail of a completed workout (exercises + sets).
class WorkoutSessionDetailPage extends ConsumerWidget {
  final int sessionId;
  const WorkoutSessionDetailPage({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sessionDetailProvider(sessionId));

    return Scaffold(
      backgroundColor: BrioColors.bgBase,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop()),
        title: const Text('Entreno'),
      ),
      body: async.when(
        loading: () => const Center(child: BrioLoader(size: 44)),
        error:   (_, __) => Center(child: Text('No se pudo cargar.', style: BrioTextStyles.bodySmall)),
        data: (data) {
          if (data == null) {
            return Center(child: Text('Entreno no encontrado.', style: BrioTextStyles.bodySmall));
          }
          final routine = data['routine'] as Map<String, dynamic>?;
          final sets = (data['sets'] as List? ?? []).cast<Map<String, dynamic>>();

          // Group sets by exercise (keeping order of appearance).
          final byExercise = <int, List<Map<String, dynamic>>>{};
          final exNames = <int, String>{};
          final order = <int>[];
          for (final s in sets) {
            final ex = s['exercise'] as Map<String, dynamic>;
            final id = ex['id'] as int;
            if (!byExercise.containsKey(id)) { byExercise[id] = []; order.add(id); exNames[id] = ex['name'] as String; }
            byExercise[id]!.add(s);
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              // Summary.
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [BrioColors.green.withValues(alpha: 0.1), BrioColors.bgCard],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: BrioColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(routine?['name'] as String? ?? 'Entreno libre', style: BrioTextStyles.h2),
                    const SizedBox(height: 14),
                    Row(children: [
                      _Stat(value: '${(data['total_volume_kg'] as num?)?.toInt() ?? 0} kg', label: 'volumen'),
                      _Stat(value: '${data['duration_min'] ?? 0} min', label: 'duración'),
                      _Stat(value: '${sets.length}', label: 'series'),
                      _Stat(value: '${data['pr_count'] ?? 0}', label: 'PRs', color: BrioColors.warning),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Exercises.
              for (final id in order) ...[
                _ExerciseDetail(name: exNames[id] ?? '', sets: byExercise[id]!),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value, label;
  final Color? color;
  const _Stat({required this.value, required this.label, this.color});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: BrioTextStyles.metric.copyWith(fontSize: 16, color: color ?? BrioColors.textPrimary)),
            Text(label, style: BrioTextStyles.label.copyWith(fontSize: 9)),
          ],
        ),
      );
}

class _ExerciseDetail extends StatelessWidget {
  final String name;
  final List<Map<String, dynamic>> sets;
  const _ExerciseDetail({required this.name, required this.sets});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BrioColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BrioColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: BrioTextStyles.h3.copyWith(fontSize: 16)),
          const SizedBox(height: 10),
          for (var i = 0; i < sets.length; i++) _row(i, sets[i]),
        ],
      ),
    );
  }

  Widget _row(int i, Map<String, dynamic> s) {
    final reps = s['reps'];
    final weight = (s['weight_kg'] as num).toDouble();
    final isPr = (s['is_pr'] as bool?) ?? false;
    final type = (s['set_type'] as String?) ?? 'normal';
    final badge = switch (type) { 'warmup' => 'C', 'dropset' => 'D', 'failure' => 'F', _ => '${i + 1}' };
    final badgeColor = switch (type) {
      'warmup'  => BrioColors.warning,
      'dropset' => BrioColors.protein,
      'failure' => BrioColors.error,
      _         => BrioColors.textSecondary,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(width: 28, child: Text(badge, style: BrioTextStyles.metric.copyWith(fontSize: 13, color: badgeColor))),
        Expanded(child: Text('${weight.toStringAsFixed(weight % 1 == 0 ? 0 : 1)} kg × $reps',
            style: BrioTextStyles.body.copyWith(fontSize: 14))),
        if (isPr) const Icon(Icons.emoji_events_rounded, size: 16, color: BrioColors.warning),
      ]),
    );
  }
}
