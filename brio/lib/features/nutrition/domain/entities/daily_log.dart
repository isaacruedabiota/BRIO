import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class Macros extends Equatable {
  final double kcal;
  final double proteinG;
  final double carbsG;
  final double fatG;

  const Macros({
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  static const zero = Macros(kcal: 0, proteinG: 0, carbsG: 0, fatG: 0);

  Macros operator +(Macros o) => Macros(
        kcal: kcal + o.kcal,
        proteinG: proteinG + o.proteinG,
        carbsG: carbsG + o.carbsG,
        fatG: fatG + o.fatG,
      );

  static Macros sum(Iterable<Macros> xs) =>
      xs.fold(zero, (a, b) => a + b);

  factory Macros.fromJson(Map<String, dynamic> j) => Macros(
        kcal:     (j['kcal']      as num?)?.toDouble() ?? 0,
        proteinG: (j['protein_g'] as num?)?.toDouble() ?? 0,
        carbsG:   (j['carbs_g']   as num?)?.toDouble() ?? 0,
        fatG:     (j['fat_g']     as num?)?.toDouble() ?? 0,
      );

  @override
  List<Object> get props => [kcal, proteinG, carbsG, fatG];
}

// Meal types.

enum MealType {
  breakfast('breakfast', 'Desayuno', Icons.wb_twilight_rounded),
  midmorning('midmorning', 'Almuerzo', Icons.bakery_dining_rounded),
  lunch('lunch', 'Comida', Icons.lunch_dining_rounded),
  merienda('merienda', 'Merienda', Icons.cookie_rounded),
  dinner('dinner', 'Cena', Icons.dinner_dining_rounded);

  final String key;
  final String label;
  final IconData icon;
  const MealType(this.key, this.label, this.icon);

  static MealType fromKey(String k) =>
      MealType.values.firstWhere((m) => m.key == k, orElse: () => MealType.merienda);
}

// Food item from the database.

class FoodItem extends Equatable {
  final int id;
  final String name;
  final String? brand;
  final String? barcode;
  final double kcalPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final double fiberPer100g;
  final bool verified;
  /// null = food from the shared database; if set, it's private to the user.
  final int? createdById;

  const FoodItem({
    required this.id,
    required this.name,
    this.brand,
    this.barcode,
    required this.kcalPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    this.fiberPer100g = 0,
    this.verified = false,
    this.createdById,
  });

  String get displayName => brand != null && brand!.isNotEmpty ? '$name · $brand' : name;

  /// Macros for a specific quantity in grams.
  Macros macrosFor(double quantityG) {
    final f = quantityG / 100;
    return Macros(
      kcal:     kcalPer100g * f,
      proteinG: proteinPer100g * f,
      carbsG:   carbsPer100g * f,
      fatG:     fatPer100g * f,
    );
  }

  factory FoodItem.fromJson(Map<String, dynamic> j) => FoodItem(
        id:             j['id'] as int,
        name:           j['name'] as String,
        brand:          j['brand'] as String?,
        barcode:        j['barcode'] as String?,
        kcalPer100g:    (j['kcal_per_100g']    as num).toDouble(),
        proteinPer100g: (j['protein_per_100g'] as num).toDouble(),
        carbsPer100g:   (j['carbs_per_100g']   as num).toDouble(),
        fatPer100g:     (j['fat_per_100g']     as num).toDouble(),
        fiberPer100g:   (j['fiber_per_100g']   as num?)?.toDouble() ?? 0,
        verified:       j['verified'] as bool? ?? false,
        createdById:    j['created_by_id'] as int?,
      );

  @override
  List<Object?> get props => [id, name, brand, barcode];
}

// Logged entry (one food in a meal).

class MealEntry extends Equatable {
  final int id;
  final FoodItem food;
  final MealType mealType;
  final double quantityG;
  final Macros macros;
  final int position;

  const MealEntry({
    required this.id,
    required this.food,
    required this.mealType,
    required this.quantityG,
    required this.macros,
    this.position = 0,
  });

  MealEntry copyWith({MealType? mealType, int? position}) => MealEntry(
        id: id,
        food: food,
        mealType: mealType ?? this.mealType,
        quantityG: quantityG,
        macros: macros,
        position: position ?? this.position,
      );

  factory MealEntry.fromJson(Map<String, dynamic> j) => MealEntry(
        id:        j['id'] as int,
        food:      FoodItem.fromJson(j['food_item'] as Map<String, dynamic>),
        mealType:  MealType.fromKey(j['meal_type'] as String),
        quantityG: (j['quantity_g'] as num).toDouble(),
        macros:    Macros.fromJson(j['macros'] as Map<String, dynamic>),
        position:  (j['position'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object> get props => [id, mealType, position];
}

// A meal of the day (with its entries and totals).

class MealGroup extends Equatable {
  final MealType mealType;
  final List<MealEntry> entries;
  final Macros totals;

  const MealGroup({required this.mealType, required this.entries, required this.totals});

  factory MealGroup.fromJson(Map<String, dynamic> j) => MealGroup(
        mealType: MealType.fromKey(j['meal_type'] as String),
        entries:  (j['entries'] as List<dynamic>)
            .map((e) => MealEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        totals:   Macros.fromJson(j['totals'] as Map<String, dynamic>),
      );

  @override
  List<Object> get props => [mealType, entries, totals];
}

// Full daily log.

class DailyLog extends Equatable {
  final String date;
  final Macros totals;
  final List<MealGroup> meals;

  /// Macro target in effect on THAT day (historized). Null if the backend
  /// doesn't send it; the UI then falls back to the profile's current target.
  final Macros? targets;

  const DailyLog({
    required this.date,
    required this.totals,
    this.meals = const [],
    this.targets,
  });

  static DailyLog empty(String date) =>
      DailyLog(date: date, totals: Macros.zero, meals: const []);

  factory DailyLog.fromJson(Map<String, dynamic> j) => DailyLog(
        date:   j['date'] as String,
        totals: Macros.fromJson(j['totals'] as Map<String, dynamic>),
        meals:  (j['meals'] as List<dynamic>? ?? [])
            .map((m) => MealGroup.fromJson(m as Map<String, dynamic>))
            .toList(),
        targets: j['targets'] != null
            ? Macros.fromJson(j['targets'] as Map<String, dynamic>)
            : null,
      );

  /// A specific meal (empty if there are no entries yet).
  MealGroup mealFor(MealType type) => meals.firstWhere(
        (m) => m.mealType == type,
        orElse: () => MealGroup(mealType: type, entries: const [], totals: Macros.zero),
      );

  @override
  List<Object?> get props => [date, totals, meals, targets];
}
