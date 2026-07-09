import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../features/auth/presentation/notifiers/auth_notifier.dart';
import '../../../../features/training/presentation/providers/training_providers.dart';

/// Summary of one day of the month for the calendar.
class DaySummary {
  final double kcal;
  final bool trained;
  const DaySummary({required this.kcal, required this.trained});
}

/// Map 'yyyy-MM-dd' -> DaySummary for a month (nutrition kcal + whether trained).
/// Combines the monthly nutrition summary with the workout history.
final monthSummaryProvider = FutureProvider.autoDispose
    .family<Map<String, DaySummary>, ({int year, int month})>((ref, ym) async {
  final api = ref.watch(apiClientProvider);

  Map<String, double> kcalByDay = {};
  try {
    final data = await api.get(
      '/nutrition/monthly-summary/',
      params: {'year': ym.year, 'month': ym.month},
    ) as Map<String, dynamic>;
    kcalByDay = data.map((k, v) => MapEntry(k, (v as num).toDouble()));
  } catch (_) {}

  // Days with a workout, from the history (filtered by year/month).
  final history = await ref.watch(workoutHistoryProvider.future);
  final prefix  = '${ym.year.toString().padLeft(4, '0')}-'
                  '${ym.month.toString().padLeft(2, '0')}';
  final trainedDays = history
      .where((w) => w.dateOnly.startsWith(prefix))
      .map((w) => w.dateOnly)
      .toSet();

  final allDays = {...kcalByDay.keys, ...trainedDays};
  return {
    for (final day in allDays)
      day: DaySummary(
        kcal:    kcalByDay[day] ?? 0,
        trained: trainedDays.contains(day),
      ),
  };
});

/// Current streak: consecutive "active" days (with food or workout) up to today/yesterday.
final currentStreakProvider = FutureProvider.autoDispose<int>((ref) async {
  final now = DateTime.now();

  // Gather active days from this month and the previous one (enough for the visible streak).
  final thisMonth = await ref.watch(
    monthSummaryProvider((year: now.year, month: now.month)).future,
  );
  final prev = DateTime(now.year, now.month - 1, 1);
  final prevMonth = await ref.watch(
    monthSummaryProvider((year: prev.year, month: prev.month)).future,
  );

  final active = <String>{};
  for (final e in {...thisMonth.entries, ...prevMonth.entries}) {
    if (e.value.kcal > 0 || e.value.trained) active.add(e.key);
  }

  // Count backwards from today (allowing today to have no record yet).
  int streak = 0;
  var cursor = DateTime(now.year, now.month, now.day);
  // If today has no activity, the streak can still count from yesterday.
  if (!active.contains(DateFormat('yyyy-MM-dd').format(cursor))) {
    cursor = cursor.subtract(const Duration(days: 1));
  }
  while (active.contains(DateFormat('yyyy-MM-dd').format(cursor))) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
});
