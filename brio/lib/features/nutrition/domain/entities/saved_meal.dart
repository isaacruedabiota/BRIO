import 'package:equatable/equatable.dart';
import 'daily_log.dart';

/// A food (with quantity) inside a saved meal.
class SavedMealItem extends Equatable {
  final FoodItem food;
  final double quantityG;
  final Macros macros;

  const SavedMealItem({required this.food, required this.quantityG, required this.macros});

  factory SavedMealItem.fromJson(Map<String, dynamic> j) => SavedMealItem(
        food:      FoodItem.fromJson(j['food_item'] as Map<String, dynamic>),
        quantityG: (j['quantity_g'] as num).toDouble(),
        macros:    Macros.fromJson(j['macros'] as Map<String, dynamic>),
      );

  @override
  List<Object> get props => [food, quantityG];
}

/// A meal saved by the user (reusable recipe).
class SavedMeal extends Equatable {
  final int id;
  final String name;
  final List<SavedMealItem> items;
  final Macros totals;
  final int itemCount;

  const SavedMeal({
    required this.id,
    required this.name,
    required this.items,
    required this.totals,
    required this.itemCount,
  });

  factory SavedMeal.fromJson(Map<String, dynamic> j) => SavedMeal(
        id:        j['id'] as int,
        name:      j['name'] as String,
        items:     (j['items'] as List<dynamic>)
            .map((e) => SavedMealItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        totals:    Macros.fromJson(j['totals'] as Map<String, dynamic>),
        itemCount: (j['item_count'] as num?)?.toInt() ?? 0,
      );

  /// Summary of the foods: "Huevo, Avena, Plátano".
  String get foodsPreview => items.map((e) => e.food.name).join(', ');

  @override
  List<Object> get props => [id, name, items];
}
