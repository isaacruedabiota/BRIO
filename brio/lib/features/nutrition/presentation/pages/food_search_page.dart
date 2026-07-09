import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/brio_colors.dart';
import '../../../../core/theme/brio_text_styles.dart';
import '../../../../shared/widgets/brio_loader.dart';
import '../../../../core/router/app_router.dart';
import '../../domain/entities/daily_log.dart';
import '../../domain/entities/saved_meal.dart';
import '../providers/nutrition_providers.dart';
import '../widgets/food_icon.dart';

/// Arguments to open the search from a specific meal of the diary.
class FoodSearchArgs {
  final MealType mealType;
  final String date; // 'yyyy-MM-dd'
  /// In "pick" mode nothing is logged: the quantity sheet returns (food, grams)
  /// to the caller (used when creating a saved meal from scratch).
  final bool pick;
  const FoodSearchArgs({required this.mealType, required this.date, this.pick = false});
}

class FoodSearchPage extends ConsumerStatefulWidget {
  final FoodSearchArgs args;
  const FoodSearchPage({super.key, required this.args});

  @override
  ConsumerState<FoodSearchPage> createState() => _FoodSearchPageState();
}

class _FoodSearchPageState extends ConsumerState<FoodSearchPage> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  int _tab = 0; // 0 = foods · 1 = my meals

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  /// Opens the scanner and, if a product is found, shows the quantity sheet.
  Future<void> _scan() async {
    final food = await context.push<FoodItem?>(AppRoutes.barcodeScanner);
    if (food != null && mounted) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _QuantitySheet(food: food, args: widget.args),
      );
    }
  }

  /// Opens the custom-food form; if one is created, offers to add it right away.
  Future<void> _createFood() async {
    final food = await context.push<FoodItem?>(AppRoutes.createFood);
    if (food == null || !mounted) return;
    ref.invalidate(recentFoodsProvider);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuantitySheet(food: food, args: widget.args),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pick = widget.args.pick;

    return Scaffold(
      backgroundColor: BrioColors.bgBase,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(pick ? 'Elegir alimento' : 'Añadir a ${widget.args.mealType.label}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Escanear código de barras',
            onPressed: _scan,
          ),
        ],
      ),
      body: Column(
        children: [
          if (!pick) _tabBar(),
          Expanded(
            child: (pick || _tab == 0)
                ? _foodsTab()
                : _SavedMealsTab(args: widget.args),
          ),
        ],
      ),
    );
  }

  Widget _foodsTab() {
    final searching = _query.length >= 2;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
          child: TextField(
            controller: _controller,
            autofocus: true,
            onChanged: _onChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Buscar alimento…',
              prefixIcon: Icon(Icons.search_rounded, color: BrioColors.textTertiary),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(Icons.close_rounded, color: BrioColors.textTertiary),
                      onPressed: () {
                        _controller.clear();
                        _onChanged('');
                      },
                    ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
          child: GestureDetector(
            onTap: _createFood,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: BrioColors.blue.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: BrioColors.blue.withValues(alpha: 0.30)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, color: BrioColors.blue, size: 19),
                  const SizedBox(width: 6),
                  Text('Crear alimento',
                      style: BrioTextStyles.buttonSecondary.copyWith(color: BrioColors.blue, fontSize: 13.5)),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: searching ? _SearchResults(query: _query, args: widget.args) : _Recents(args: widget.args),
        ),
      ],
    );
  }

  Widget _tabBar() => Padding(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: BrioColors.bgElevated, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [_tabSeg('Alimentos', 0), _tabSeg('Mis comidas', 1)]),
        ),
      );

  Widget _tabSeg(String label, int i) {
    final on = _tab == i;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = i),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? BrioColors.bgBase : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(label,
              style: BrioTextStyles.label.copyWith(
                fontSize: 12.5, color: on ? BrioColors.blue : BrioColors.textSecondary)),
        ),
      ),
    );
  }
}

class _SearchResults extends ConsumerWidget {
  final String query;
  final FoodSearchArgs args;
  const _SearchResults({required this.query, required this.args});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(foodSearchProvider(query));
    return results.when(
      loading: () => const Center(child: BrioLoader(size: 38)),
      error:   (_, __) => _Empty(text: 'Error al buscar.'),
      data: (foods) => foods.isEmpty
          ? _Empty(text: 'Sin resultados para "$query".')
          : _FoodList(foods: foods, args: args),
    );
  }
}

class _Recents extends ConsumerWidget {
  final FoodSearchArgs args;
  const _Recents({required this.args});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recents = ref.watch(recentFoodsProvider);
    return recents.when(
      loading: () => const Center(child: BrioLoader(size: 38)),
      error:   (_, __) => _Empty(text: 'Escribe para buscar un alimento.'),
      data: (foods) => foods.isEmpty
          ? _Empty(text: 'Escribe para buscar un alimento.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: Text('RECIENTES', style: BrioTextStyles.label),
                ),
                Expanded(child: _FoodList(foods: foods, args: args)),
              ],
            ),
    );
  }
}

class _FoodList extends StatelessWidget {
  final List<FoodItem> foods;
  final FoodSearchArgs args;
  const _FoodList({required this.foods, required this.args});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
      itemCount: foods.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _FoodTile(food: foods[i], args: args),
    );
  }
}

class _FoodTile extends StatelessWidget {
  final FoodItem food;
  final FoodSearchArgs args;
  const _FoodTile({required this.food, required this.args});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _QuantitySheet(food: food, args: args),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: BrioColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: BrioColors.border),
        ),
        child: Row(
          children: [
            FoodIcon(food: food, size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(food.displayName,
                      style: BrioTextStyles.body.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text('${food.kcalPer100g.round()} kcal · P ${food.proteinPer100g.round()} · '
                      'C ${food.carbsPer100g.round()} · G ${food.fatPer100g.round()}  / 100g',
                      style: BrioTextStyles.label.copyWith(fontSize: 10)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.add_circle_outline_rounded, color: BrioColors.blue, size: 22),
          ],
        ),
      ),
    );
  }
}

// Quantity sheet.

class _QuantitySheet extends ConsumerStatefulWidget {
  final FoodItem food;
  final FoodSearchArgs args;
  const _QuantitySheet({required this.food, required this.args});

  @override
  ConsumerState<_QuantitySheet> createState() => _QuantitySheetState();
}

enum _Unit { grams, ounces, serving }

class _QuantitySheetState extends ConsumerState<_QuantitySheet> {
  final _controller = TextEditingController(text: '100');
  _Unit _unit = _Unit.grams;
  bool _saving = false;

  /// The food's own serving/unit: (label, grams).
  late final (String, double) _serving = servingFor(widget.food.name);

  double get _value => double.tryParse(_controller.text.replaceAll(',', '.')) ?? 0;

  double _factor(_Unit u) => switch (u) {
        _Unit.grams   => 1.0,
        _Unit.ounces  => 28.3495,
        _Unit.serving => _serving.$2,
      };

  double get _grams => _value * _factor(_unit);

  String _capLabel() {
    final l = _serving.$1;
    return l.isEmpty ? l : l[0].toUpperCase() + l.substring(1);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setUnit(_Unit u) {
    if (u == _unit) return;
    final grams = _grams;
    setState(() {
      _unit = u;
      _controller.text = _fmt(grams / _factor(u));
    });
  }

  void _step(int sign) {
    final delta = _unit == _Unit.grams ? 10.0 : 0.5;
    final v = _value + sign * delta;
    setState(() => _controller.text = _fmt(v < 0 ? 0 : v));
  }

  String _fmt(double v) {
    if (_unit == _Unit.grams) return v.round().toString();
    final s = v.toStringAsFixed(2);
    return s.contains('.')
        ? s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')
        : s;
  }

  String get _suffix => switch (_unit) {
        _Unit.grams   => 'g',
        _Unit.ounces  => 'oz',
        _Unit.serving => _serving.$1,
      };

  Future<void> _add() async {
    final g = _grams;
    if (g <= 0) return;
    final qty = double.parse(g.toStringAsFixed(1));
    if (widget.args.pick) {
      Navigator.of(context).pop();        // close the sheet
      context.pop((widget.food, qty));    // return the chosen food
      return;
    }
    setState(() => _saving = true);
    final ok = await logMeal(ref,
        foodId: widget.food.id, mealType: widget.args.mealType,
        quantityG: qty, date: widget.args.date);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();          // close the sheet
      context.pop();                        // back to the diary
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo añadir'), backgroundColor: BrioColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.food.macrosFor(_grams);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: BoxDecoration(
          color: BrioColors.bgSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: BrioColors.border, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),

            // Header.
            Row(
              children: [
                FoodIcon(food: widget.food, size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.food.displayName, style: BrioTextStyles.h3.copyWith(fontSize: 18),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      Text('${widget.food.kcalPer100g.round()} kcal / 100 g',
                          style: BrioTextStyles.label.copyWith(fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Macro ring + legend.
            Center(child: _MacroDonut(macros: m)),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legend(BrioColors.protein, 'P ${m.proteinG.round()}g'),
                _sep(),
                _legend(BrioColors.carbs, 'C ${m.carbsG.round()}g'),
                _sep(),
                _legend(BrioColors.fat, 'G ${m.fatG.round()}g'),
              ],
            ),
            const SizedBox(height: 18),

            // Unit selector.
            Row(
              children: [
                _unitBtn(_Unit.grams, 'Gramos'),
                const SizedBox(width: 8),
                _unitBtn(_Unit.ounces, 'Onzas'),
                const SizedBox(width: 8),
                _unitBtn(_Unit.serving, _capLabel()),
              ],
            ),
            const SizedBox(height: 14),

            // Unified stepper with numeric keyboard.
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: BrioColors.bgElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: BrioColors.border),
              ),
              child: Row(
                children: [
                  _stepZone(Icons.remove_rounded, () => _step(-1)),
                  _vsep(),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      onChanged: (_) => setState(() {}),
                      style: BrioTextStyles.metricLarge.copyWith(fontSize: 24),
                      decoration: const InputDecoration(
                        isCollapsed: true,
                        filled: false,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  _vsep(),
                  _stepZone(Icons.add_rounded, () => _step(1)),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                _unit == _Unit.grams ? 'gramos' : '$_suffix · ≈ ${_grams.round()} g',
                style: BrioTextStyles.label.copyWith(fontSize: 10, color: BrioColors.textTertiary)),
            ),
            const SizedBox(height: 18),

            // Add button → to the meal the sheet was opened from.
            SizedBox(
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: BrioColors.gradient, borderRadius: BorderRadius.circular(99)),
                child: ElevatedButton(
                  onPressed: (_grams <= 0 || _saving) ? null : _add,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent, shape: const StadiumBorder()),
                  child: _saving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Text(widget.args.pick ? 'Añadir a la comida' : 'Añadir a ${widget.args.mealType.label}',
                          style: BrioTextStyles.button),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _unitBtn(_Unit u, String label) {
    final on = _unit == u;
    return Expanded(
      child: GestureDetector(
        onTap: () => _setUnit(u),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? BrioColors.blue : BrioColors.bgElevated,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: BrioTextStyles.label.copyWith(
                fontSize: 12,
                color: on ? BrioColors.textInverse : BrioColors.textSecondary)),
        ),
      ),
    );
  }

  Widget _stepZone(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 54, height: 54, alignment: Alignment.center,
          child: Icon(icon, color: BrioColors.blueDeep, size: 24),
        ),
      );

  Widget _vsep() => Container(width: 1, height: 28, color: BrioColors.border);

  Widget _legend(Color c, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(text, style: BrioTextStyles.metricSmall.copyWith(fontSize: 12, color: BrioColors.textPrimary)),
        ],
      );

  Widget _sep() => Container(width: 4, height: 4, margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: BrioColors.textTertiary, shape: BoxShape.circle));
}

// Macro composition ring.

class _MacroDonut extends StatelessWidget {
  final Macros macros;
  const _MacroDonut({required this.macros});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140, height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(size: const Size(140, 140), painter: _DonutPainter(macros)),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(macros.kcal.round().toString(),
                  style: BrioTextStyles.metricLarge.copyWith(fontSize: 28)),
              Text('kcal', style: BrioTextStyles.label.copyWith(fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final Macros m;
  _DonutPainter(this.m);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final r = (size.width - stroke) / 2;
    final c = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: c, radius: r);

    canvas.drawCircle(c, r, Paint()
      ..style = PaintingStyle.stroke ..strokeWidth = stroke ..color = BrioColors.bgElevated);

    final pk = m.proteinG * 4, ck = m.carbsG * 4, fk = m.fatG * 9;
    final total = pk + ck + fk;
    if (total <= 0) return;

    var start = -math.pi / 2;
    void seg(double kcal, Color color) {
      if (kcal <= 0) return;
      final sweep = 2 * math.pi * (kcal / total);
      canvas.drawArc(rect, start, sweep, false, Paint()
        ..style = PaintingStyle.stroke ..strokeWidth = stroke ..strokeCap = StrokeCap.butt ..color = color);
      start += sweep;
    }

    seg(pk, BrioColors.protein);
    seg(ck, BrioColors.carbs);
    seg(fk, BrioColors.fat);
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.m != m;
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty({required this.text});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(text, textAlign: TextAlign.center, style: BrioTextStyles.bodySmall),
        ),
      );
}

// "My meals" tab.

class _SavedMealsTab extends ConsumerWidget {
  final FoodSearchArgs args;
  const _SavedMealsTab({required this.args});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealsAsync = ref.watch(savedMealsProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
          child: GestureDetector(
            onTap: () => context.push(AppRoutes.createMeal),
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
                  Text('Crear comida',
                      style: BrioTextStyles.buttonSecondary.copyWith(color: BrioColors.blue, fontSize: 14)),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: mealsAsync.when(
            loading: () => const Center(child: BrioLoader(size: 38)),
            error:   (_, __) => const _Empty(text: 'No se pudieron cargar.'),
            data: (meals) => meals.isEmpty
                ? const _Empty(text: 'Aún no tienes comidas guardadas.\nCrea una, o guárdala desde tu diario.')
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                    itemCount: meals.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _SavedMealCard(meal: meals[i], args: args),
                  ),
          ),
        ),
      ],
    );
  }
}

class _SavedMealCard extends StatelessWidget {
  final SavedMeal meal;
  final FoodSearchArgs args;
  const _SavedMealCard({required this.meal, required this.args});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _SavedMealSheet(meal: meal, args: args),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: BrioColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: BrioColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: BrioColors.blue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.bookmark_rounded, color: BrioColors.blue, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(meal.name,
                      style: BrioTextStyles.body.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('${meal.itemCount} alimentos · ${meal.totals.kcal.round()} kcal',
                      style: BrioTextStyles.label.copyWith(fontSize: 10),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Icon(Icons.add_circle_outline_rounded, color: BrioColors.blue, size: 22),
          ],
        ),
      ),
    );
  }
}

/// Preview sheet for a saved meal: foods, totals and apply.
class _SavedMealSheet extends ConsumerStatefulWidget {
  final SavedMeal meal;
  final FoodSearchArgs args;
  const _SavedMealSheet({required this.meal, required this.args});

  @override
  ConsumerState<_SavedMealSheet> createState() => _SavedMealSheetState();
}

class _SavedMealSheetState extends ConsumerState<_SavedMealSheet> {
  bool _busy = false;

  Future<void> _apply() async {
    setState(() => _busy = true);
    final ok = await applySavedMeal(ref,
        mealId: widget.meal.id, mealType: widget.args.mealType, date: widget.args.date);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();   // close the sheet
      context.pop();                 // back to the diary
    } else {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo añadir'), backgroundColor: BrioColors.error));
    }
  }

  Future<void> _delete() async {
    final ok = await deleteSavedMeal(ref, id: widget.meal.id);
    if (!mounted) return;
    Navigator.of(context).pop();
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo borrar'), backgroundColor: BrioColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.meal;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      decoration: BoxDecoration(
        color: BrioColors.bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: BrioColors.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Text(m.name, style: BrioTextStyles.h3.copyWith(fontSize: 19),
                maxLines: 2, overflow: TextOverflow.ellipsis)),
            IconButton(
              onPressed: _busy ? null : _delete,
              icon: Icon(Icons.delete_outline_rounded, color: BrioColors.error)),
          ]),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: m.items.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: BrioColors.border),
              itemBuilder: (_, i) {
                final it = m.items[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(children: [
                    FoodIcon(food: it.food, size: 34),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(it.food.name, style: BrioTextStyles.body.copyWith(fontSize: 13.5),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('${it.quantityG.round()} g', style: BrioTextStyles.label.copyWith(fontSize: 9)),
                    ])),
                    Text('${it.macros.kcal.round()} kcal', style: BrioTextStyles.metricSmall.copyWith(fontSize: 11)),
                  ]),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: BrioColors.bgCard, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: BrioColors.border)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _mini('${m.totals.kcal.round()}', 'kcal', BrioColors.blue),
              _mini('${m.totals.proteinG.round()}g', 'P', BrioColors.protein),
              _mini('${m.totals.carbsG.round()}g', 'C', BrioColors.carbs),
              _mini('${m.totals.fatG.round()}g', 'G', BrioColors.fat),
            ]),
          ),
          const SizedBox(height: 16),
          SizedBox(height: 52, child: DecoratedBox(
            decoration: BoxDecoration(gradient: BrioColors.gradient, borderRadius: BorderRadius.circular(99)),
            child: ElevatedButton(
              onPressed: _busy ? null : _apply,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent, shape: const StadiumBorder()),
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : Text('Añadir a ${widget.args.mealType.label}', style: BrioTextStyles.button),
            ),
          )),
        ],
      ),
    );
  }

  Widget _mini(String v, String l, Color c) => Column(mainAxisSize: MainAxisSize.min, children: [
        Text(v, style: BrioTextStyles.metric.copyWith(fontSize: 14, color: c)),
        Text(l, style: BrioTextStyles.label.copyWith(fontSize: 9)),
      ]);
}
