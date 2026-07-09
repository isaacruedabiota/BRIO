import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/brio_colors.dart';
import '../../../../core/theme/brio_text_styles.dart';
import '../../domain/entities/daily_log.dart';
import '../providers/nutrition_providers.dart';
import '../widgets/food_icon.dart';
import 'food_search_page.dart';

/// Create a saved meal from scratch: name + foods with their quantities.
class CreateMealPage extends ConsumerStatefulWidget {
  const CreateMealPage({super.key});

  @override
  ConsumerState<CreateMealPage> createState() => _CreateMealPageState();
}

class _CreateMealPageState extends ConsumerState<CreateMealPage> {
  final _nameController = TextEditingController();
  final List<({FoodItem food, double grams})> _items = [];
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Macros get _totals {
    var kcal = 0.0, p = 0.0, c = 0.0, f = 0.0;
    for (final it in _items) {
      final m = it.food.macrosFor(it.grams);
      kcal += m.kcal; p += m.proteinG; c += m.carbsG; f += m.fatG;
    }
    return Macros(kcal: kcal, proteinG: p, carbsG: c, fatG: f);
  }

  Future<void> _addFood() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final picked = await context.push<(FoodItem, double)?>(
      AppRoutes.foodSearch,
      extra: FoodSearchArgs(mealType: MealType.breakfast, date: today, pick: true),
    );
    if (picked != null && mounted) {
      setState(() => _items.add((food: picked.$1, grams: picked.$2)));
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _items.isEmpty) return;
    setState(() => _saving = true);
    final ok = await createSavedMeal(ref,
        name: name,
        items: [for (final it in _items) (foodId: it.food.id, grams: it.grams)]);
    if (!mounted) return;
    if (ok) {
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Comida "$name" guardada'), backgroundColor: BrioColors.success));
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar'), backgroundColor: BrioColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _totals;
    final canSave = _nameController.text.trim().isNotEmpty && _items.isNotEmpty && !_saving;

    return Scaffold(
      backgroundColor: BrioColors.bgBase,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Crear comida'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 120),
        children: [
          // Name.
          TextField(
            controller: _nameController,
            onChanged: (_) => setState(() {}),
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Nombre (p. ej. Desayuno típico)'),
          ),
          const SizedBox(height: 18),

          Row(
            children: [
              Text('ALIMENTOS', style: BrioTextStyles.label),
              const Spacer(),
              if (_items.isNotEmpty)
                Text('${t.kcal.round()} kcal', style: BrioTextStyles.metricSmall),
            ],
          ),
          const SizedBox(height: 8),

          if (_items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 22),
              decoration: BoxDecoration(
                color: BrioColors.bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: BrioColors.border),
              ),
              child: Text('Añade alimentos a esta comida',
                  textAlign: TextAlign.center,
                  style: BrioTextStyles.bodySmall.copyWith(color: BrioColors.textTertiary)),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: BrioColors.bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: BrioColors.border),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < _items.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: BrioColors.border, indent: 14, endIndent: 14),
                    _ItemRow(
                      food: _items[i].food,
                      grams: _items[i].grams,
                      onRemove: () => setState(() => _items.removeAt(i)),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 12),

          // Add food.
          GestureDetector(
            onTap: _addFood,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: BrioColors.blue.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: BrioColors.blue.withValues(alpha: 0.30)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, color: BrioColors.blue, size: 20),
                  const SizedBox(width: 6),
                  Text('Añadir alimento',
                      style: BrioTextStyles.buttonSecondary.copyWith(color: BrioColors.blue, fontSize: 14)),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
          child: SizedBox(
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: canSave ? BrioColors.gradient : null,
                color: canSave ? null : BrioColors.bgElevated,
                borderRadius: BorderRadius.circular(99),
              ),
              child: ElevatedButton(
                onPressed: canSave ? _save : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent, shape: const StadiumBorder()),
                child: _saving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Text('Guardar comida',
                        style: BrioTextStyles.button.copyWith(
                          color: canSave ? BrioColors.textInverse : BrioColors.textTertiary)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final FoodItem food;
  final double grams;
  final VoidCallback onRemove;
  const _ItemRow({required this.food, required this.grams, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final m = food.macrosFor(grams);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Row(
        children: [
          FoodIcon(food: food, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(food.name, style: BrioTextStyles.body.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${grams.round()} g · ${m.kcal.round()} kcal',
                    style: BrioTextStyles.label.copyWith(fontSize: 10)),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
            icon: Icon(Icons.close_rounded, color: BrioColors.textTertiary, size: 20),
          ),
        ],
      ),
    );
  }
}
