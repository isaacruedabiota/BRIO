import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../../../features/auth/presentation/notifiers/auth_notifier.dart';

/// An activity type from the catalog.
class ActivityType {
  final String key;
  final String name;
  final double met;
  final bool usesDistance;
  final String icon;
  final String category;
  const ActivityType({
    required this.key, required this.name, required this.met,
    required this.usesDistance, required this.icon, required this.category,
  });

  factory ActivityType.fromJson(Map<String, dynamic> j) => ActivityType(
        key:          j['key'] as String,
        name:         j['name'] as String,
        met:          (j['met'] as num).toDouble(),
        usesDistance: j['uses_distance'] as bool,
        icon:         j['icon'] as String,
        category:     j['category'] as String,
      );

  /// Matching Material icon.
  IconData get iconData => switch (icon) {
        'directions_run'    => Icons.directions_run_rounded,
        'directions_walk'   => Icons.directions_walk_rounded,
        'directions_bike'   => Icons.directions_bike_rounded,
        'sports_soccer'     => Icons.sports_soccer_rounded,
        'sports_basketball' => Icons.sports_basketball_rounded,
        'sports_tennis'     => Icons.sports_tennis_rounded,
        'pool'              => Icons.pool_rounded,
        'rowing'            => Icons.rowing_rounded,
        'fitness_center'    => Icons.fitness_center_rounded,
        'bolt'              => Icons.bolt_rounded,
        'sports_mma'        => Icons.sports_mma_rounded,
        _                   => Icons.more_horiz_rounded,
      };
}

/// Catalog of available activities.
final activityCatalogProvider = FutureProvider<List<ActivityType>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final data = await api.get('/training/activities/catalog/') as List<dynamic>;
    return data.map((e) => ActivityType.fromJson(e as Map<String, dynamic>)).toList();
  } catch (_) {
    return [];
  }
});

/// A logged activity (cardio/sport) from the history.
class ActivityLogEntry {
  final int id;
  final String key;
  final String name;
  final String icon;
  final String category;   // 'run' | 'bike' | 'sport' | 'other'
  final int durationMin;
  final double? distanceKm;
  final int calories;
  final List<LatLng> route;   // GPS points; empty if not GPS-tracked
  final String performedAt; // 'yyyy-MM-dd'

  const ActivityLogEntry({
    required this.id, required this.key, required this.name, required this.icon,
    this.category = 'other', required this.durationMin, this.distanceKm,
    required this.calories, this.route = const [], required this.performedAt,
  });

  /// Court/field sports → shown as a heat map (not a route).
  bool get isCourtSport => category == 'sport';

  factory ActivityLogEntry.fromJson(Map<String, dynamic> j) => ActivityLogEntry(
        id:          j['id'] as int,
        key:         j['activity_key'] as String,
        name:        (j['name'] as String?) ?? (j['activity_key'] as String),
        icon:        (j['icon'] as String?) ?? 'more_horiz',
        category:    (j['category'] as String?) ?? 'other',
        durationMin: (j['duration_min'] as num?)?.toInt() ?? 0,
        distanceKm:  (j['distance_km'] as num?)?.toDouble(),
        calories:    (j['calories'] as num?)?.toInt() ?? 0,
        route:       _parseRoute(j['route']),
        performedAt: j['performed_at'] as String,
      );

  /// Converts the JSON list `[[lat,lng], ...]` into `List<LatLng>`.
  static List<LatLng> _parseRoute(dynamic raw) {
    if (raw is! List) return const [];
    final out = <LatLng>[];
    for (final p in raw) {
      if (p is List && p.length >= 2) {
        out.add(LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()));
      }
    }
    return out;
  }

  /// Average pace as mm:ss per km (or '--:--' if not applicable).
  String get pace {
    if (distanceKm == null || distanceKm! < 0.01 || durationMin <= 0) return '--:--';
    final secPerKm = (durationMin * 60) / distanceKm!;
    final m = (secPerKm ~/ 60).toString().padLeft(2, '0');
    final s = (secPerKm % 60).toInt().toString().padLeft(2, '0');
    return '$m:$s';
  }

  IconData get iconData => switch (icon) {
        'directions_run'    => Icons.directions_run_rounded,
        'directions_walk'   => Icons.directions_walk_rounded,
        'directions_bike'   => Icons.directions_bike_rounded,
        'sports_soccer'     => Icons.sports_soccer_rounded,
        'sports_basketball' => Icons.sports_basketball_rounded,
        'sports_tennis'     => Icons.sports_tennis_rounded,
        'pool'              => Icons.pool_rounded,
        'rowing'            => Icons.rowing_rounded,
        'fitness_center'    => Icons.fitness_center_rounded,
        'bolt'              => Icons.bolt_rounded,
        'sports_mma'        => Icons.sports_mma_rounded,
        _                   => Icons.more_horiz_rounded,
      };
}

/// Full activity history (most recent first).
final activityHistoryProvider =
    FutureProvider.autoDispose<List<ActivityLogEntry>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final data = await api.get('/training/activities/') as List<dynamic>;
    return data.map((e) => ActivityLogEntry.fromJson(e as Map<String, dynamic>)).toList();
  } catch (_) {
    return [];
  }
});

/// Calories burned (cardio + strength) for a 'yyyy-MM-dd' date.
class BurnedCalories {
  final int cardio;
  final int strength;
  final int total;
  const BurnedCalories({this.cardio = 0, this.strength = 0, this.total = 0});
}

final burnedCaloriesProvider =
    FutureProvider.autoDispose.family<BurnedCalories, String>((ref, date) async {
  final api = ref.watch(apiClientProvider);
  try {
    final data = await api.get('/training/burned/', params: {'date': date}) as Map<String, dynamic>;
    return BurnedCalories(
      cardio:   (data['cardio'] as num?)?.toInt() ?? 0,
      strength: (data['strength'] as num?)?.toInt() ?? 0,
      total:    (data['total'] as num?)?.toInt() ?? 0,
    );
  } catch (_) {
    return const BurnedCalories();
  }
});

/// Calories burned today.
final burnedTodayProvider = FutureProvider.autoDispose<BurnedCalories>((ref) {
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  return ref.watch(burnedCaloriesProvider(today).future);
});

/// Logs an activity. Returns true on success.
Future<bool> logActivity(
  WidgetRef ref, {
  required String activityKey,
  required int durationMin,
  double? distanceKm,
  List<LatLng> route = const [],
}) async {
  final api = ref.read(apiClientProvider);
  try {
    await api.post('/training/activities/', data: {
      'activity_key': activityKey,
      'duration_min': durationMin,
      if (distanceKm != null) 'distance_km': distanceKm,
      if (route.isNotEmpty)
        'route': [for (final p in route) [p.latitude, p.longitude]],
    });
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    ref.invalidate(burnedCaloriesProvider(today));
    ref.invalidate(burnedTodayProvider);
    ref.invalidate(activityHistoryProvider);
    return true;
  } catch (_) {
    return false;
  }
}
