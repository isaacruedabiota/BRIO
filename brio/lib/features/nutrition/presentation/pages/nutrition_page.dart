import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/brio_colors.dart';
import '../../../../core/theme/brio_text_styles.dart';
import '../../../../features/auth/presentation/notifiers/auth_notifier.dart';
import '../../../../features/dashboard/presentation/providers/selected_date_provider.dart';
import '../../../../shared/widgets/brio_loader.dart';
import '../../../../shared/widgets/brio_snack.dart';
import '../../domain/entities/daily_log.dart';
import '../providers/nutrition_providers.dart';
import '../widgets/food_icon.dart';
import 'food_search_page.dart';

/// Data carried when dragging an entry: its id and which meal it came from.
class _EntryDrag {
  final int entryId;
  final MealType fromMeal;
  const _EntryDrag(this.entryId, this.fromMeal);
}

const _meses = ['', 'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
const _dows = ['', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];

class NutritionPage extends ConsumerWidget {
  const NutritionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date    = ref.watch(selectedDateProvider);
    final dateStr = ref.watch(selectedDateStringProvider);
    final logAsync = ref.watch(dailyLogProvider(dateStr));
    final targets  = ref.watch(authNotifierProvider).valueOrNull?.user?.profile?.macroTargets;

    return Scaffold(
      backgroundColor: BrioColors.bgBase,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: BrioColors.blue,
          backgroundColor: BrioColors.bgCard,
          onRefresh: () async => ref.invalidate(dailyLogProvider(dateStr)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 120),
            children: [
              _DateNav(date: date, ref: ref),
              const SizedBox(height: 14),
              logAsync.when(
                loading: () => const SizedBox(height: 240, child: Center(child: BrioLoader(size: 40))),
                error:   (_, __) => const _ErrorBox(),
                data:    (log) => _Diary(log: log, targets: targets, dateStr: dateStr),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Date navigator.

class _DateNav extends StatelessWidget {
  final DateTime date;
  final WidgetRef ref;
  const _DateNav({required this.date, required this.ref});

  void _shift(int days) {
    ref.read(selectedDateProvider.notifier).state = date.add(Duration(days: days));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = date.difference(today).inDays;
    final rel = switch (diff) {
      0  => 'HOY',
      -1 => 'AYER',
      1  => 'MAÑANA',
      _  => _dows[date.weekday].toUpperCase(),
    };
    return Row(
      children: [
        _arrow(Icons.chevron_left_rounded, () => _shift(-1)),
        Expanded(
          child: Column(
            children: [
              Text(rel, style: BrioTextStyles.label.copyWith(color: BrioColors.blue, fontSize: 10)),
              Text('${date.day} ${_meses[date.month]}',
                  style: BrioTextStyles.h3.copyWith(fontSize: 18)),
            ],
          ),
        ),
        _arrow(Icons.chevron_right_rounded, () => _shift(1)),
      ],
    );
  }

  Widget _arrow(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            border: Border.all(color: BrioColors.border),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: BrioColors.textSecondary),
        ),
      );
}

// Diary (header + meals).

class _Diary extends StatelessWidget {
  final DailyLog log;
  final dynamic targets; // MacroTargets? — accessed via kcal/proteinG/... fields
  final String dateStr;
  const _Diary({required this.log, required this.targets, required this.dateStr});

  @override
  Widget build(BuildContext context) {
    // Prefer the target in effect on THAT day (historized); if absent, fall back
    // to the profile's current target.
    final dt = log.targets;
    final kcalGoal = (dt?.kcal     ?? (targets?.kcal     as num?) ?? 2000).toDouble();
    final pGoal    = (dt?.proteinG ?? (targets?.proteinG as num?) ?? 150).toDouble();
    final cGoal    = (dt?.carbsG   ?? (targets?.carbsG   as num?) ?? 250).toDouble();
    final fGoal    = (dt?.fatG     ?? (targets?.fatG     as num?) ?? 70).toDouble();
    final t = log.totals;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CalorieHero(consumed: t.kcal, goal: kcalGoal),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _MacroCard(label: 'Proteína', consumed: t.proteinG, goal: pGoal, color: BrioColors.protein)),
            const SizedBox(width: 8),
            Expanded(child: _MacroCard(label: 'Carbos', consumed: t.carbsG, goal: cGoal, color: BrioColors.carbs)),
            const SizedBox(width: 8),
            Expanded(child: _MacroCard(label: 'Grasas', consumed: t.fatG, goal: fGoal, color: BrioColors.fat)),
          ],
        ),
        const SizedBox(height: 22),
        for (final type in MealType.values) ...[
          _MealSection(meal: log.mealFor(type), dateStr: dateStr),
          const SizedBox(height: 18),
        ],
      ],
    );
  }
}

class _CalorieHero extends StatelessWidget {
  final double consumed, goal;
  const _CalorieHero({required this.consumed, required this.goal});

  @override
  Widget build(BuildContext context) {
    final remaining = (goal - consumed).round();
    final over = remaining < 0;
    final pct = goal > 0 ? (consumed / goal).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [BrioColors.blue.withValues(alpha: 0.10), BrioColors.bgCard],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BrioColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CALORÍAS DE HOY', style: BrioTextStyles.label),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(_fmt(consumed.round()),
                  style: BrioTextStyles.metricLarge.copyWith(fontSize: 34)),
              const SizedBox(width: 8),
              Text(over ? '${_fmt(-remaining)} de más' : '${_fmt(remaining)} restantes',
                  style: BrioTextStyles.body.copyWith(
                    color: over ? BrioColors.warning : BrioColors.blue,
                    fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: pct.toDouble(), minHeight: 7,
              backgroundColor: BrioColors.bgElevated,
              valueColor: AlwaysStoppedAnimation(over ? BrioColors.warning : BrioColors.blue),
            ),
          ),
          const SizedBox(height: 5),
          Text('de ${_fmt(goal.round())} kcal',
              style: BrioTextStyles.label.copyWith(fontSize: 10, color: BrioColors.textTertiary)),
        ],
      ),
    );
  }
}

/// Macro card: "120 /150g" (consumed in color + goal in grey).
class _MacroCard extends StatelessWidget {
  final String label;
  final double consumed, goal;
  final Color color;
  const _MacroCard({required this.label, required this.consumed, required this.goal, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = consumed.round();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
      decoration: BoxDecoration(
        color: BrioColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BrioColors.border),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.0))],
      ),
      child: Column(
        children: [
          Container(width: 22, height: 3, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(children: [
              TextSpan(text: '$c',
                  style: BrioTextStyles.metric.copyWith(fontSize: 15, color: color)),
              TextSpan(text: ' /${goal.round()}g',
                  style: BrioTextStyles.metric.copyWith(fontSize: 11, color: BrioColors.textTertiary)),
            ]),
          ),
          const SizedBox(height: 6),
          Text(label.toUpperCase(),
              style: BrioTextStyles.label.copyWith(fontSize: 8.5, color: BrioColors.textSecondary)),
        ],
      ),
    );
  }
}

// Meal section.

class _MealSection extends ConsumerWidget {
  final MealGroup meal;
  final String dateStr;
  const _MealSection({required this.meal, required this.dateStr});

  void _addFood(BuildContext context) {
    context.push(AppRoutes.foodSearch,
        extra: FoodSearchArgs(mealType: meal.mealType, date: dateStr));
  }

  Future<void> _saveAsMeal(BuildContext context, WidgetRef ref) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(initial: meal.mealType.label),
    );
    if (name == null || name.isEmpty) return;
    final ok = await saveMealFromDay(ref, name: name, mealType: meal.mealType, date: dateStr);
    if (context.mounted) {
      ok
          ? BrioSnack.success(context, 'Comida "$name" guardada', icon: Icons.bookmark_added_rounded)
          : BrioSnack.error(context, 'No se pudo guardar');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(meal.mealType.icon, size: 17, color: BrioColors.blue),
            const SizedBox(width: 8),
            Text(meal.mealType.label.toUpperCase(),
                style: BrioTextStyles.label.copyWith(fontSize: 12, color: BrioColors.textPrimary, letterSpacing: 0.5)),
            const Spacer(),
            Text('${meal.totals.kcal.round()} kcal', style: BrioTextStyles.metricSmall),
            const SizedBox(width: 8),
            if (meal.entries.isNotEmpty) ...[
              GestureDetector(
                onTap: () => _saveAsMeal(context, ref),
                child: Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    color: BrioColors.bgElevated,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(Icons.bookmark_add_outlined, size: 16, color: BrioColors.textSecondary),
                ),
              ),
              const SizedBox(width: 8),
            ],
            GestureDetector(
              onTap: () => _addFood(context),
              child: Container(
                width: 26, height: 26,
                decoration: BoxDecoration(
                  color: BrioColors.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.add_rounded, size: 18, color: BrioColors.blue),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DragTarget<_EntryDrag>(
          // Dropping on the meal's empty area → to the end of that meal.
          // (Dropping onto an entry is handled by the row's DragTarget.)
          onAcceptWithDetails: (d) async {
            final ok = await ref.read(dailyLogProvider(dateStr).notifier).moveEntry(
                entryId: d.data.entryId, toMeal: meal.mealType, beforeEntryId: null);
            if (!ok && context.mounted) BrioSnack.error(context, 'No se pudo mover');
          },
          builder: (context, candidate, rejected) {
            final active = candidate.isNotEmpty;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: double.infinity,
              decoration: BoxDecoration(
                color: active ? BrioColors.blue.withValues(alpha: 0.08) : BrioColors.bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: active ? BrioColors.blue : BrioColors.border,
                  width: active ? 1.6 : 1,
                ),
              ),
              child: meal.entries.isEmpty
                  ? GestureDetector(
                      onTap: () => _addFood(context),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                        child: Text(active ? 'Soltar aquí' : 'Añade un alimento',
                            style: BrioTextStyles.bodySmall.copyWith(
                                color: active ? BrioColors.blue : BrioColors.textTertiary)),
                      ),
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < meal.entries.length; i++) ...[
                          if (i > 0) Divider(height: 1, color: BrioColors.border, indent: 14, endIndent: 14),
                          _EntryRow(entry: meal.entries[i], dateStr: dateStr, ref: ref),
                        ],
                      ],
                    ),
            );
          },
        ),
      ],
    );
  }
}

class _EntryRow extends StatelessWidget {
  final MealEntry entry;
  final String dateStr;
  final WidgetRef ref;
  const _EntryRow({required this.entry, required this.dateStr, required this.ref});

  Widget _content({bool dragging = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
        child: Row(
          children: [
            if (dragging) ...[
              Icon(Icons.drag_indicator_rounded, size: 18, color: BrioColors.textTertiary),
              const SizedBox(width: 6),
            ],
            FoodIcon(food: entry.food, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.food.name, style: BrioTextStyles.body.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('${entry.quantityG.round()} g',
                      style: BrioTextStyles.label.copyWith(fontSize: 10)),
                ],
              ),
            ),
            Text('${entry.macros.kcal.round()}', style: BrioTextStyles.metric.copyWith(fontSize: 14)),
            Text(' kcal', style: BrioTextStyles.label.copyWith(fontSize: 9)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final dismissible = Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 18),
        decoration: BoxDecoration(
          color: BrioColors.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: BrioColors.error),
      ),
      onDismissed: (_) async {
        final ok = await deleteMealEntry(ref, entryId: entry.id, date: dateStr);
        if (!ok && context.mounted) BrioSnack.error(context, 'No se pudo borrar');
      },
      child: _content(),
    );

    final width = MediaQuery.sizeOf(context).width - 36;
    // Long press → drag to another meal or reorder. Swipe still deletes.
    final draggable = LongPressDraggable<_EntryDrag>(
      data: _EntryDrag(entry.id, entry.mealType),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: width,
          child: Container(
            decoration: BoxDecoration(
              color: BrioColors.bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: BrioColors.blue),
              boxShadow: [BoxShadow(color: BrioColors.blueDeep.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: _content(dragging: true),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: dismissible),
      child: dismissible,
    );

    // Dropping ONTO this row → insert the dragged entry right before it (used
    // to reorder within a meal and to place when moving between meals).
    return DragTarget<_EntryDrag>(
      onAcceptWithDetails: (d) async {
        final ok = await ref.read(dailyLogProvider(dateStr).notifier).moveEntry(
            entryId: d.data.entryId, toMeal: entry.mealType, beforeEntryId: entry.id);
        if (!ok && context.mounted) BrioSnack.error(context, 'No se pudo mover');
      },
      builder: (context, candidate, rejected) {
        final showLine = candidate.isNotEmpty && candidate.first?.entryId != entry.id;
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: showLine ? BrioColors.blue : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: draggable,
        );
      },
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox();
  @override
  Widget build(BuildContext context) => Container(
        height: 160, alignment: Alignment.center,
        child: Text('No se pudo cargar el diario.', style: BrioTextStyles.bodySmall),
      );
}

String _fmt(int n) {
  final s = n.abs().toString();
  final buf = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// Dialog to name a saved meal. Its own StatefulWidget so the
/// TextEditingController is disposed safely when the route unmounts.
class _NameDialog extends StatefulWidget {
  final String initial;
  const _NameDialog({required this.initial});

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: BrioColors.bgSurface,
        title: Text('Guardar como comida', style: BrioTextStyles.h3.copyWith(fontSize: 18)),
        content: TextField(
          controller: _c,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Nombre de la comida'),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, _c.text.trim()), child: const Text('Guardar')),
        ],
      );
}
