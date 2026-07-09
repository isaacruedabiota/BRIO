import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/auth/presentation/notifiers/auth_notifier.dart';
import '../../domain/entities/routine.dart';
import '../../domain/entities/routine_detail.dart';
import '../../domain/entities/training_plan.dart';
import '../../domain/entities/workout_summary.dart';

final routinesProvider = FutureProvider.autoDispose<List<RoutineSummary>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final data = await api.get('/training/routines/') as List<dynamic>;
    return data.map((r) {
      final map = r as Map<String, dynamic>;
      final exercises = (map['exercises'] as List? ?? []);

      // Main muscles + estimated duration, derived from the exercises.
      final tally = <String, int>{};
      var seconds = 0;
      for (final e in exercises) {
        final em = e as Map<String, dynamic>;
        final sets = (em['sets'] as int?) ?? 3;
        final rest = (em['rest_seconds'] as int?) ?? 90;
        seconds += sets * (40 + rest); // ~40s work + rest per set
        final ex = em['exercise'] as Map<String, dynamic>?;
        for (final mg in (ex?['muscle_groups'] as List? ?? [])) {
          final es = _muscleEs(mg.toString());
          if (es.isNotEmpty) tally[es] = (tally[es] ?? 0) + 1;
        }
      }
      final top = tally.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return RoutineSummary(
        id:            map['id'] as int,
        name:          map['name'] as String,
        exerciseCount: exercises.length,
        muscleGroups:  top.take(3).map((e) => e.key).toList(),
        estimatedMin:  (seconds / 60).round(),
      );
    }).toList();
  } catch (_) {
    return [];
  }
});

String _muscleEs(String m) => switch (m) {
      'chest' => 'Pecho', 'back' => 'Espalda', 'shoulders' => 'Hombros',
      'biceps' => 'Bíceps', 'triceps' => 'Tríceps', 'quads' => 'Cuádriceps',
      'hamstrings' => 'Femoral', 'glutes' => 'Glúteo', 'calves' => 'Gemelos',
      'core' => 'Core', 'forearms' => 'Antebrazo', 'full_body' => 'Cuerpo completo',
      _ => '',
    };

/// Full detail of a routine (with exercises, sets and target reps).
final routineDetailProvider =
    FutureProvider.autoDispose.family<RoutineDetail?, int>((ref, routineId) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get('/training/routines/') as List<dynamic>;
  for (final r in data) {
    final map = r as Map<String, dynamic>;
    if (map['id'] == routineId) return RoutineDetail.fromJson(map);
  }
  return null;
});

/// Full history of completed sessions (most recent first).
final workoutHistoryProvider =
    FutureProvider.autoDispose<List<WorkoutSummary>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final data = await api.get('/training/sessions/') as List<dynamic>;
    return data.map((s) {
      final map = s as Map<String, dynamic>;
      final routine = map['routine'] as Map<String, dynamic>?;
      return WorkoutSummary(
        id:            map['id'] as int,
        routineName:   routine?['name'] as String?,
        finishedAtIso: (map['finished_at'] as String?) ?? '',
        durationMin:   (map['duration_min'] as int?) ?? 0,
        totalVolumeKg: ((map['total_volume_kg'] as num?) ?? 0).toDouble(),
        prCount:       (map['pr_count'] as int?) ?? 0,
        setCount:      (map['sets'] as List?)?.length ?? 0,
      );
    }).toList();
  } catch (_) {
    return [];
  }
});

/// Workout session(s) for a specific day ('yyyy-MM-dd').
final workoutsForDateProvider = FutureProvider.autoDispose
    .family<List<WorkoutSummary>, String>((ref, date) async {
  final history = await ref.watch(workoutHistoryProvider.future);
  return history.where((w) => w.dateOnly == date).toList();
});

/// Exercise library for adding during a session (with search).
final exerciseLibraryProvider = FutureProvider.autoDispose
    .family<List<ExerciseRef>, String>((ref, query) async {
  final api = ref.watch(apiClientProvider);
  final params = query.trim().isEmpty ? null : {'q': query.trim()};
  final data = await api.get('/training/exercises/', params: params) as List<dynamic>;
  return data.map((e) => ExerciseRef.fromJson(e as Map<String, dynamic>)).toList();
});

/// Info for one exercise (description, gif) for its detail screen.
final exerciseInfoProvider =
    FutureProvider.autoDispose.family<ExerciseRef?, int>((ref, exerciseId) async {
  final api = ref.watch(apiClientProvider);
  try {
    final data = await api.get('/training/exercises/$exerciseId/') as Map<String, dynamic>;
    return ExerciseRef.fromJson(data);
  } catch (_) {
    return null;
  }
});

/// A single estimated-1RM progress point (date, value).
class ProgressPoint {
  final String date;
  final double oneRm;
  const ProgressPoint(this.date, this.oneRm);
}

/// Estimated-1RM history for an exercise (for chart and history).
final exerciseProgressProvider =
    FutureProvider.autoDispose.family<List<ProgressPoint>, int>((ref, exerciseId) async {
  final api = ref.watch(apiClientProvider);
  try {
    final data = await api.get('/training/exercises/$exerciseId/progress/') as List<dynamic>;
    // The backend returns most recent first; reverse for a chronological chart.
    final points = data.map((p) {
      final m = p as Map<String, dynamic>;
      return ProgressPoint(m['date'] as String, (m['estimated_1rm'] as num).toDouble());
    }).toList();
    return points.reversed.toList();
  } catch (_) {
    return [];
  }
});

/// Full detail of a session (exercises + sets) for viewing a past workout.
final sessionDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, int>((ref, sessionId) async {
  final api = ref.watch(apiClientProvider);
  try {
    return await api.get('/training/sessions/$sessionId/') as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
});

/// A reference set from the last session (Hevy-style).
class ReferenceSet {
  final int setNumber;
  final int reps;
  final double weightKg;
  const ReferenceSet({required this.setNumber, required this.reps, required this.weightKg});
}

/// Sets from the last session that included this exercise (shown in grey).
final lastExerciseSetsProvider = FutureProvider.autoDispose
    .family<List<ReferenceSet>, int>((ref, exerciseId) async {
  final api = ref.watch(apiClientProvider);
  try {
    final data = await api.get('/training/exercises/$exerciseId/last-sets/') as List<dynamic>;
    return data.map((s) {
      final m = s as Map<String, dynamic>;
      return ReferenceSet(
        setNumber: m['set_number'] as int,
        reps:      m['reps'] as int,
        weightKg:  (m['weight_kg'] as num).toDouble(),
      );
    }).toList();
  } catch (_) {
    return [];
  }
});

/// Current-week training summary (Mon→Sun) derived from the history.
class WeekTrainingSummary {
  final int sessions;
  final double totalVolume;
  final int prs;
  /// Volume per weekday, index 0 = Monday … 6 = Sunday.
  final List<double> volumeByDay;
  const WeekTrainingSummary({
    required this.sessions,
    required this.totalVolume,
    required this.prs,
    required this.volumeByDay,
  });
}

final weekTrainingSummaryProvider =
    FutureProvider.autoDispose<WeekTrainingSummary>((ref) async {
  final history = await ref.watch(workoutHistoryProvider.future);
  final now = DateTime.now();
  final monday = DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: (now.weekday + 6) % 7));

  final volumeByDay = List<double>.filled(7, 0);
  int sessions = 0, prs = 0;
  double total = 0;

  for (final w in history) {
    final parts = w.dateOnly.split('-');
    if (parts.length != 3) continue;
    final d = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    final idx = d.difference(monday).inDays;
    if (idx < 0 || idx > 6) continue;
    volumeByDay[idx] += w.totalVolumeKg;
    total += w.totalVolumeKg;
    prs  += w.prCount;
    sessions++;
  }

  return WeekTrainingSummary(
    sessions: sessions, totalVolume: total, prs: prs, volumeByDay: volumeByDay,
  );
});

// Highlights (dashboard).

/// A featured user stat, ready to render.
class Highlight {
  final String key;       // lift|volume|run|streak|workouts
  final String icon;      // trophy|chart|run|fire|dumbbell
  final String label;
  final String value;     // already formatted
  final String unit;
  final String name;
  final String context;
  final bool hero;

  const Highlight({
    required this.key, required this.icon, required this.label,
    required this.value, required this.unit, required this.name,
    required this.context, required this.hero,
  });

  factory Highlight.fromJson(Map<String, dynamic> j) {
    final v = j['value'];
    final value = (v is double)
        ? (v == v.roundToDouble() ? v.toInt().toString() : v.toString())
        : v.toString();
    return Highlight(
      key:     (j['key'] as String?) ?? '',
      icon:    (j['icon'] as String?) ?? 'trophy',
      label:   (j['label'] as String?) ?? '',
      value:   value,
      unit:    (j['unit'] as String?) ?? '',
      name:    (j['name'] as String?) ?? '',
      context: (j['context'] as String?) ?? '',
      hero:    (j['hero'] as bool?) ?? false,
    );
  }
}

/// The user's 2 most impressive stats (empty if there's no data).
final highlightsProvider = FutureProvider.autoDispose<List<Highlight>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final data = await api.get('/training/highlights/') as Map<String, dynamic>;
    return (data['highlights'] as List? ?? [])
        .map((e) => Highlight.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return const [];
  }
});

// Automatic plan (rule-based generator).

/// The user's current training plan (or null if none).
final currentPlanProvider = FutureProvider.autoDispose<TrainingPlan?>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final data = await api.get('/training/plan/');
    if (data == null) return null;
    return TrainingPlan.fromJson(data as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
});

/// An activity planned for TODAY (derived from the weekly plan).
class TodayActivity {
  final String kind;        // strength | cardio
  final int? routineId;
  final String name;
  final int exerciseCount;
  final int estMin;
  final String? activityKey;
  final int durationMin;
  const TodayActivity({
    required this.kind, this.routineId, required this.name,
    this.exerciseCount = 0, this.estMin = 0, this.activityKey, this.durationMin = 0,
  });
}

String _cardioEs(String? k) => switch (k) {
      'running' => 'Correr', 'walking' => 'Andar', 'cycling' => 'Bici', _ => 'Cardio',
    };

/// Plan activities for today (empty if there's no plan or it's a rest day).
final todayPlanProvider = FutureProvider.autoDispose<List<TodayActivity>>((ref) async {
  final plan = await ref.watch(currentPlanProvider.future);
  if (plan == null) return const [];
  final routines = await ref.watch(routinesProvider.future);
  final byId = {for (final r in routines) r.id: r};
  final todayIdx = DateTime.now().weekday - 1; // 0=Monday … 6=Sunday
  final out = <TodayActivity>[];
  for (final d in plan.week) {
    if (d.weekday != todayIdx) continue;
    if (d.kind == 'strength' && d.routineId != null) {
      final r = byId[d.routineId];
      final pr = plan.routineByKey(d.routineKey);
      out.add(TodayActivity(
        kind: 'strength',
        routineId: d.routineId,
        name: r?.name ?? pr?.name ?? 'Entreno',
        exerciseCount: r?.exerciseCount ?? pr?.exercises.length ?? 0,
        estMin: r?.estimatedMin ?? pr?.estMin ?? 0,
      ));
    } else if (d.kind == 'cardio') {
      out.add(TodayActivity(
        kind: 'cardio',
        activityKey: d.activityKey ?? 'running',
        name: (d.name != null && d.name!.isNotEmpty) ? d.name! : _cardioEs(d.activityKey),
        durationMin: d.durationMin ?? 30,
      ));
    }
  }
  return out;
});

/// Generates a plan (preview, doesn't save). Returns null on failure.
Future<TrainingPlan?> generatePlan(
  WidgetRef ref, {
  required List<String> goals,
  required int days,
  required String level,
  required List<String> equipment,
  required bool includeCardio,
}) async {
  final api = ref.read(apiClientProvider);
  try {
    final data = await api.post('/training/plan/generate/', data: {
      'goals':          goals,
      'days':           days,
      'level':          level,
      'equipment':      equipment,
      'include_cardio': includeCardio,
    }) as Map<String, dynamic>;
    return TrainingPlan.fromJson(data);
  } catch (_) {
    return null;
  }
}

/// Saves the plan (creates routines + plan). Returns true on success.
Future<bool> savePlan(WidgetRef ref, TrainingPlan plan) async {
  final api = ref.read(apiClientProvider);
  try {
    await api.post('/training/plan/', data: plan.toJson());
    ref.invalidate(currentPlanProvider);
    ref.invalidate(routinesProvider);
    return true;
  } catch (_) {
    return false;
  }
}

/// Saves the manual weekly schedule using EXISTING routines (doesn't create any).
/// `days` is already in API format. Returns true on success.
Future<bool> saveSchedule(
  WidgetRef ref, {
  required String name,
  required List<Map<String, dynamic>> days,
}) async {
  final api = ref.read(apiClientProvider);
  try {
    await api.put('/training/plan/schedule/', data: {'name': name, 'days': days});
    ref.invalidate(currentPlanProvider);
    return true;
  } catch (_) {
    return false;
  }
}

/// Deletes the current plan (keeps the routines). Returns true on success.
Future<bool> deletePlan(WidgetRef ref) async {
  final api = ref.read(apiClientProvider);
  try {
    await api.delete('/training/plan/');
    ref.invalidate(currentPlanProvider);
    return true;
  } catch (_) {
    return false;
  }
}
