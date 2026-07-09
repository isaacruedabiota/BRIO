import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../features/auth/presentation/notifiers/auth_notifier.dart';
import '../../domain/entities/daily_log.dart';
import '../../domain/entities/saved_meal.dart';

// Daily nutrition log (totals + meals).

final dailyLogProvider = AsyncNotifierProvider.autoDispose
    .family<DailyLogNotifier, DailyLog, String>(DailyLogNotifier.new);

class DailyLogNotifier extends AutoDisposeFamilyAsyncNotifier<DailyLog, String> {
  @override
  Future<DailyLog> build(String date) async {
    final api = ref.watch(apiClientProvider);
    try {
      final data = await api.get('/nutrition/entries/', params: {'date': date})
          as Map<String, dynamic>;
      return DailyLog.fromJson(data);
    } catch (_) {
      return DailyLog.empty(date);
    }
  }

  /// Moves/reorders an entry (drag & drop) with an OPTIMISTIC update: applied
  /// locally at once and synced in the background; if the server fails, it is
  /// reverted. [beforeEntryId] = the entry to insert before (null = at the end
  /// of the target meal).
  Future<bool> moveEntry({
    required int entryId,
    required MealType toMeal,
    int? beforeEntryId,
  }) async {
    if (beforeEntryId == entryId) return true; // dropped on itself: no-op
    final current = state.valueOrNull;
    if (current == null) return false;

    // Mutable lists per meal + locate the dragged entry.
    final byMeal = {for (final t in MealType.values) t: <MealEntry>[]};
    MealEntry? moved;
    for (final m in current.meals) {
      for (final e in m.entries) {
        if (e.id == entryId) moved = e;
        byMeal[m.mealType]!.add(e);
      }
    }
    if (moved == null) return false;

    for (final t in MealType.values) {
      byMeal[t]!.removeWhere((e) => e.id == entryId);
    }
    final tgt = byMeal[toMeal]!;
    var idx = beforeEntryId == null ? tgt.length : tgt.indexWhere((e) => e.id == beforeEntryId);
    if (idx < 0) idx = tgt.length;
    tgt.insert(idx, moved.copyWith(mealType: toMeal, position: idx));
    for (var i = 0; i < tgt.length; i++) {
      tgt[i] = tgt[i].copyWith(position: i);
    }

    final meals = [
      for (final t in MealType.values)
        MealGroup(
          mealType: t,
          entries: byMeal[t]!,
          totals: Macros.sum(byMeal[t]!.map((e) => e.macros)),
        ),
    ];
    final totals = Macros.sum(meals.expand((m) => m.entries).map((e) => e.macros));
    state = AsyncData(DailyLog(
      date: current.date, totals: totals, meals: meals, targets: current.targets));

    final api = ref.read(apiClientProvider);
    try {
      await api.patch('/nutrition/entries/$entryId/',
          data: {'meal_type': toMeal.key, 'position': idx});
      return true;
    } catch (_) {
      state = AsyncData(current); // revert
      return false;
    }
  }
}

// Shortcut for today's log.
final todayLogProvider = FutureProvider.autoDispose<DailyLog>((ref) {
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  return ref.watch(dailyLogProvider(today).future);
});

// Food search and recents.

/// Food search results for a query string.
final foodSearchProvider = FutureProvider.autoDispose
    .family<List<FoodItem>, String>((ref, query) async {
  final q = query.trim();
  if (q.length < 2) return const [];
  final api = ref.watch(apiClientProvider);
  try {
    final data = await api.get('/nutrition/foods/search/',
        params: {'q': q, 'limit': '30'}) as List<dynamic>;
    return data.map((e) => FoodItem.fromJson(e as Map<String, dynamic>)).toList();
  } catch (_) {
    return const [];
  }
});

/// Looks up a food by barcode (local DB → Open Food Facts).
/// Returns null if not found.
Future<FoodItem?> lookupBarcode(WidgetRef ref, String barcode) async {
  final api = ref.read(apiClientProvider);
  try {
    final data = await api.get('/nutrition/foods/barcode/$barcode/') as Map<String, dynamic>;
    return FoodItem.fromJson(data);
  } catch (_) {
    return null;
  }
}

/// Creates a user's own food (private). Returns the created FoodItem or null on
/// failure.
Future<FoodItem?> createFood(
  WidgetRef ref, {
  required String name,
  String? brand,
  required double kcalPer100g,
  required double proteinPer100g,
  required double carbsPer100g,
  required double fatPer100g,
  double fiberPer100g = 0,
}) async {
  final api = ref.read(apiClientProvider);
  try {
    final data = await api.post('/nutrition/foods/', data: {
      'name': name,
      if (brand != null && brand.trim().isNotEmpty) 'brand': brand.trim(),
      'kcal_per_100g':    kcalPer100g,
      'protein_per_100g': proteinPer100g,
      'carbs_per_100g':   carbsPer100g,
      'fat_per_100g':     fatPer100g,
      'fiber_per_100g':   fiberPer100g,
    }) as Map<String, dynamic>;
    ref.invalidate(recentFoodsProvider);
    return FoodItem.fromJson(data);
  } catch (_) {
    return null;
  }
}

/// Foods recently used by the user.
final recentFoodsProvider = FutureProvider.autoDispose<List<FoodItem>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final data = await api.get('/nutrition/foods/recent/') as List<dynamic>;
    return data.map((e) => FoodItem.fromJson(e as Map<String, dynamic>)).toList();
  } catch (_) {
    return const [];
  }
});

// Log / delete entries.

/// Adds a food to a meal of the day. Returns true on success.
Future<bool> logMeal(
  WidgetRef ref, {
  required int foodId,
  required MealType mealType,
  required double quantityG,
  required String date, // 'yyyy-MM-dd'
}) async {
  final api = ref.read(apiClientProvider);
  try {
    await api.post('/nutrition/entries/', data: {
      'food_id':    foodId,
      'meal_type':  mealType.key,
      'quantity_g': quantityG,
      'logged_at':  date,
    });
    ref.invalidate(dailyLogProvider(date));
    return true;
  } catch (_) {
    return false;
  }
}

/// Deletes a diary entry. Returns true on success.
Future<bool> deleteMealEntry(
  WidgetRef ref, {
  required int entryId,
  required String date,
}) async {
  final api = ref.read(apiClientProvider);
  try {
    await api.delete('/nutrition/entries/$entryId/');
    ref.invalidate(dailyLogProvider(date));
    return true;
  } catch (_) {
    return false;
  }
}

// Saved meals (recipes).

/// The user's saved meals.
final savedMealsProvider = FutureProvider.autoDispose<List<SavedMeal>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final data = await api.get('/nutrition/meals/') as List<dynamic>;
    return data.map((e) => SavedMeal.fromJson(e as Map<String, dynamic>)).toList();
  } catch (_) {
    return const [];
  }
});

/// Creates a saved meal by copying an already-logged meal from a day.
Future<bool> saveMealFromDay(
  WidgetRef ref, {
  required String name,
  required MealType mealType,
  required String date,
}) async {
  final api = ref.read(apiClientProvider);
  try {
    await api.post('/nutrition/meals/', data: {
      'name': name,
      'from_date': date,
      'from_meal_type': mealType.key,
    });
    ref.invalidate(savedMealsProvider);
    return true;
  } catch (_) {
    return false;
  }
}

/// Creates a saved meal from a list of (foodId, grams).
Future<bool> createSavedMeal(
  WidgetRef ref, {
  required String name,
  required List<({int foodId, double grams})> items,
}) async {
  final api = ref.read(apiClientProvider);
  try {
    await api.post('/nutrition/meals/', data: {
      'name': name,
      'items': [for (final it in items) {'food_id': it.foodId, 'quantity_g': it.grams}],
    });
    ref.invalidate(savedMealsProvider);
    return true;
  } catch (_) {
    return false;
  }
}

/// Applies a saved meal: adds all its foods to a meal of the day.
Future<bool> applySavedMeal(
  WidgetRef ref, {
  required int mealId,
  required MealType mealType,
  required String date,
}) async {
  final api = ref.read(apiClientProvider);
  try {
    await api.post('/nutrition/meals/$mealId/log/', data: {
      'date': date,
      'meal_type': mealType.key,
    });
    ref.invalidate(dailyLogProvider(date));
    return true;
  } catch (_) {
    return false;
  }
}

/// Deletes a saved meal.
Future<bool> deleteSavedMeal(WidgetRef ref, {required int id}) async {
  final api = ref.read(apiClientProvider);
  try {
    await api.delete('/nutrition/meals/$id/');
    ref.invalidate(savedMealsProvider);
    return true;
  } catch (_) {
    return false;
  }
}
