import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/brio_colors.dart';
import '../../../../core/theme/brio_text_styles.dart';
import '../../../../shared/widgets/brio_loader.dart';
import '../../../../shared/widgets/brio_snack.dart';
import '../../domain/entities/routine.dart';
import '../providers/training_providers.dart';

const _weekdayFull = ['LUNES', 'MARTES', 'MIÉRCOLES', 'JUEVES', 'VIERNES', 'SÁBADO', 'DOMINGO'];

/// An activity assigned to a specific day.
class _SItem {
  final String kind; // strength | cardio
  final int? routineId;
  final String? activityKey;
  final int? durationMin;
  final String? label;
  const _SItem.strength(this.routineId)
      : kind = 'strength', activityKey = null, durationMin = null, label = null;
  const _SItem.cardio(this.activityKey, this.durationMin, this.label)
      : kind = 'cardio', routineId = null;
}

/// Data carried when dragging an activity: which day and index it came from.
class _Drag {
  final int day;
  final int index;
  const _Drag(this.day, this.index);
}

const _cardioOptions = [
  ('running', 'Correr', Icons.directions_run_rounded),
  ('walking', 'Andar', Icons.directions_walk_rounded),
  ('cycling', 'Bici', Icons.directions_bike_rounded),
];

class WeeklySchedulePage extends ConsumerStatefulWidget {
  const WeeklySchedulePage({super.key});

  @override
  ConsumerState<WeeklySchedulePage> createState() => _WeeklySchedulePageState();
}

class _WeeklySchedulePageState extends ConsumerState<WeeklySchedulePage> {
  final Map<int, List<_SItem>> _days = {for (var i = 0; i < 7; i++) i: []};
  bool _seeded = false;
  bool _saving = false;
  bool _hadPlan = false;
  String _planName = 'Mi semana';

  void _seed(plan) {
    if (_seeded || plan == null) return;
    _seeded = true;
    _hadPlan = true;
    _planName = plan.title as String? ?? 'Mi semana';
    for (final d in plan.week) {
      if (d.kind == 'strength' && d.routineId != null) {
        _days[d.weekday]?.add(_SItem.strength(d.routineId as int));
      } else if (d.kind == 'cardio') {
        _days[d.weekday]?.add(
          _SItem.cardio(d.activityKey ?? 'running', d.durationMin ?? 30, d.name ?? ''),
        );
      }
    }
  }

  void _move(int fromDay, int fromIndex, int toDay) {
    if (fromDay == toDay) return;
    setState(() {
      final item = _days[fromDay]!.removeAt(fromIndex);
      _days[toDay]!.add(item);
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final days = <Map<String, dynamic>>[];
    for (var wd = 0; wd < 7; wd++) {
      final items = _days[wd]!;
      if (items.isEmpty) {
        days.add({'weekday': wd, 'kind': 'rest'});
        continue;
      }
      for (final it in items) {
        if (it.kind == 'strength') {
          days.add({'weekday': wd, 'kind': 'strength', 'routine_id': it.routineId});
        } else {
          days.add({
            'weekday': wd, 'kind': 'cardio',
            'activity_key': it.activityKey, 'duration_min': it.durationMin, 'label': it.label,
          });
        }
      }
    }
    final ok = await saveSchedule(ref, name: _planName, days: days);
    if (!mounted) return;
    if (ok) {
      context.go(AppRoutes.training);
      BrioSnack.success(context, '¡Semana guardada!', icon: Icons.event_available_rounded);
    } else {
      setState(() => _saving = false);
      BrioSnack.error(context, 'No se pudo guardar.');
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BrioColors.bgCard,
        title: Text('Eliminar plan', style: BrioTextStyles.h3),
        content: Text('Se borrará el plan semanal. Tus rutinas se conservan en "Mis rutinas".',
            style: BrioTextStyles.bodySmall),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Eliminar', style: BrioTextStyles.body.copyWith(
                color: BrioColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await deletePlan(ref);
    if (!mounted) return;
    context.go(AppRoutes.training);
    BrioSnack.info(context, 'Plan eliminado.', icon: Icons.delete_outline_rounded);
  }

  Future<void> _add(int weekday, List<RoutineSummary> routines) async {
    final item = await showModalBottomSheet<_SItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickerSheet(weekday: weekday, routines: routines),
    );
    if (item != null) setState(() => _days[weekday]!.add(item));
  }

  @override
  Widget build(BuildContext context) {
    final planAsync = ref.watch(currentPlanProvider);
    final routinesAsync = ref.watch(routinesProvider);

    return Scaffold(
      backgroundColor: BrioColors.bgBase,
      appBar: AppBar(
        title: const Text('Mi semana'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text('Guardar', style: BrioTextStyles.body.copyWith(
                fontWeight: FontWeight.w700,
                color: _saving ? BrioColors.textTertiary : BrioColors.blue)),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: BrioColors.textSecondary),
            color: BrioColors.bgCard,
            onSelected: (v) {
              if (v == 'gen') context.push(AppRoutes.planGenerator);
              if (v == 'del') _delete();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'gen', child: Text('Crear plan automático')),
              if (_hadPlan)
                PopupMenuItem(value: 'del', child: Text('Eliminar plan',
                    style: TextStyle(color: BrioColors.error))),
            ],
          ),
        ],
      ),
      body: planAsync.isLoading
          ? const Center(child: BrioLoader(size: 40))
          : Builder(builder: (_) {
              _seed(planAsync.valueOrNull);
              final routines = routinesAsync.valueOrNull ?? const <RoutineSummary>[];
              final byId = {for (final r in routines) r.id: r};
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                    child: Row(children: [
                      Icon(Icons.drag_indicator_rounded, size: 15, color: BrioColors.textTertiary),
                      const SizedBox(width: 6),
                      Expanded(child: Text(
                        'Mantén pulsada una actividad para moverla a otro día.',
                        style: BrioTextStyles.bodySmall.copyWith(fontSize: 11, color: BrioColors.textTertiary),
                      )),
                    ]),
                  ),
                  for (var wd = 0; wd < 7; wd++)
                    _DayBlock(
                      weekday: wd,
                      items: _days[wd]!,
                      byId: byId,
                      onAdd: () => _add(wd, routines),
                      onRemove: (i) => setState(() => _days[wd]!.removeAt(i)),
                      onAccept: (d) => _move(d.day, d.index, wd),
                    ),
                ],
              );
            }),
    );
  }
}

class _DayBlock extends StatefulWidget {
  final int weekday;
  final List<_SItem> items;
  final Map<int, RoutineSummary> byId;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;
  final void Function(_Drag drag) onAccept;
  const _DayBlock({
    required this.weekday, required this.items, required this.byId,
    required this.onAdd, required this.onRemove, required this.onAccept,
  });

  @override
  State<_DayBlock> createState() => _DayBlockState();
}

class _DayBlockState extends State<_DayBlock> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return DragTarget<_Drag>(
      onWillAcceptWithDetails: (d) => d.data.day != widget.weekday,
      onAcceptWithDetails: (d) {
        setState(() => _hover = false);
        widget.onAccept(d.data);
      },
      onMove: (_) { if (!_hover) setState(() => _hover = true); },
      onLeave: (_) => setState(() => _hover = false),
      builder: (context, candidate, rejected) {
        final active = _hover && candidate.isNotEmpty;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          decoration: BoxDecoration(
            color: active ? BrioColors.blue.withValues(alpha: 0.08) : BrioColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active ? BrioColors.blue : BrioColors.border,
              width: active ? 1.6 : 1,
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(_weekdayFull[widget.weekday], style: BrioTextStyles.label.copyWith(
                  fontSize: 11, color: BrioColors.blueDeep, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Text(
                widget.items.isEmpty
                    ? 'descanso'
                    : '${widget.items.length} ${widget.items.length == 1 ? "actividad" : "actividades"}',
                style: BrioTextStyles.label.copyWith(fontSize: 10, color: BrioColors.textTertiary),
              ),
            ]),
            const SizedBox(height: 8),
            if (widget.items.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: active ? BrioColors.blue.withValues(alpha: 0.5) : BrioColors.border),
                ),
                child: Row(children: [
                  Text(active ? '⬇️' : '😴', style: const TextStyle(fontSize: 15)),
                  const SizedBox(width: 9),
                  Text(active ? 'Soltar aquí' : 'Descanso',
                      style: BrioTextStyles.bodySmall.copyWith(color: BrioColors.textTertiary)),
                ]),
              )
            else
              for (var i = 0; i < widget.items.length; i++)
                _DraggableRow(
                  item: widget.items[i],
                  drag: _Drag(widget.weekday, i),
                  byId: widget.byId,
                  onRemove: () => widget.onRemove(i),
                ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: widget.onAdd,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  const Icon(Icons.add_rounded, size: 18, color: BrioColors.blue),
                  const SizedBox(width: 6),
                  Text('Añadir actividad', style: BrioTextStyles.buttonSecondary.copyWith(
                      color: BrioColors.blue, fontSize: 13)),
                ]),
              ),
            ),
          ]),
        );
      },
    );
  }
}

class _DraggableRow extends StatelessWidget {
  final _SItem item;
  final _Drag drag;
  final Map<int, RoutineSummary> byId;
  final VoidCallback onRemove;
  const _DraggableRow({
    required this.item, required this.drag, required this.byId, required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final row = _RowCard(item: item, byId: byId, onRemove: onRemove);
    final width = MediaQuery.sizeOf(context).width - 60;
    return LongPressDraggable<_Drag>(
      data: drag,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: width,
          child: Opacity(opacity: 0.95, child: _RowCard(item: item, byId: byId, onRemove: onRemove, dragging: true)),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: row),
      child: row,
    );
  }
}

class _RowCard extends StatelessWidget {
  final _SItem item;
  final Map<int, RoutineSummary> byId;
  final VoidCallback onRemove;
  final bool dragging;
  const _RowCard({required this.item, required this.byId, required this.onRemove, this.dragging = false});

  static String _cardioName(String? key) => switch (key) {
        'running' => 'Correr', 'walking' => 'Andar', 'cycling' => 'Bici', _ => 'Cardio',
      };
  static IconData _cardioIcon(String? key) => switch (key) {
        'running' => Icons.directions_run_rounded,
        'walking' => Icons.directions_walk_rounded,
        'cycling' => Icons.directions_bike_rounded,
        _ => Icons.favorite_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final strength = item.kind == 'strength';
    final routine = strength ? byId[item.routineId] : null;
    final title = strength
        ? (routine?.name ?? 'Rutina')
        : 'Cardio · ${item.label?.isNotEmpty == true ? item.label : _cardioName(item.activityKey)}';
    final meta = strength
        ? '${routine?.exerciseCount ?? 0} ejercicios'
        : '${item.durationMin ?? 0} min';
    final icon = strength ? Icons.fitness_center_rounded : _cardioIcon(item.activityKey);
    final color = strength ? BrioColors.blueDeep : const Color(0xFFB7791F);
    final bg = strength
        ? BrioColors.blue.withValues(alpha: 0.12)
        : BrioColors.warning.withValues(alpha: 0.15);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: BrioColors.bgBase,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dragging ? BrioColors.blue : BrioColors.border),
        boxShadow: dragging
            ? [BoxShadow(color: BrioColors.blueDeep.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6))]
            : null,
      ),
      child: Row(children: [
        Icon(Icons.drag_indicator_rounded, size: 18, color: BrioColors.textTertiary),
        const SizedBox(width: 6),
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 17, color: color),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: BrioTextStyles.body.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(meta, style: BrioTextStyles.label.copyWith(fontSize: 10)),
          ]),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.close_rounded, size: 18, color: BrioColors.textTertiary),
          onPressed: onRemove,
        ),
      ]),
    );
  }
}

class _PickerSheet extends StatefulWidget {
  final int weekday;
  final List<RoutineSummary> routines;
  const _PickerSheet({required this.weekday, required this.routines});

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  int _dur = 30;
  static const _durations = [15, 20, 30, 45, 60];

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      decoration: BoxDecoration(
        color: BrioColors.bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: BrioColors.border, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 14),
        Text('Añadir a ${_titleCase(_weekdayFull[widget.weekday])}', style: BrioTextStyles.h3.copyWith(fontSize: 18)),
        const SizedBox(height: 8),
        Flexible(
          child: ListView(shrinkWrap: true, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 8, 2, 6),
              child: Text('MIS RUTINAS', style: BrioTextStyles.label.copyWith(fontSize: 10)),
            ),
            if (widget.routines.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Aún no tienes rutinas. Créalas en "Mis rutinas".',
                    style: BrioTextStyles.bodySmall),
              ),
            for (final r in widget.routines)
              _opt(
                icon: Icons.fitness_center_rounded,
                iconColor: BrioColors.blueDeep,
                iconBg: BrioColors.blue.withValues(alpha: 0.12),
                title: r.name,
                meta: '${r.exerciseCount} ejercicios',
                onTap: () => Navigator.pop(context, _SItem.strength(r.id)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 14, 2, 6),
              child: Text('CARDIO', style: BrioTextStyles.label.copyWith(fontSize: 10)),
            ),
            Row(children: [
              Text('Duración', style: BrioTextStyles.bodySmall.copyWith(color: BrioColors.textSecondary)),
              const SizedBox(width: 10),
              Expanded(
                child: Wrap(spacing: 6, children: [
                  for (final d in _durations)
                    GestureDetector(
                      onTap: () => setState(() => _dur = d),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                        decoration: BoxDecoration(
                          color: _dur == d ? BrioColors.blue : BrioColors.bgElevated,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text('$d', style: BrioTextStyles.label.copyWith(
                            fontSize: 12,
                            color: _dur == d ? BrioColors.textInverse : BrioColors.textSecondary)),
                      ),
                    ),
                  Text('min', style: BrioTextStyles.label.copyWith(fontSize: 11)),
                ]),
              ),
            ]),
            const SizedBox(height: 8),
            for (final c in _cardioOptions)
              _opt(
                icon: c.$3,
                iconColor: const Color(0xFFB7791F),
                iconBg: BrioColors.warning.withValues(alpha: 0.15),
                title: c.$2,
                meta: '$_dur min',
                onTap: () => Navigator.pop(context, _SItem.cardio(c.$1, _dur, c.$2)),
              ),
          ]),
        ),
      ]),
    );
  }

  Widget _opt({
    required IconData icon, required Color iconColor, required Color iconBg,
    required String title, required String meta, required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        decoration: BoxDecoration(
          color: BrioColors.bgBase,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BrioColors.border),
        ),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: BrioTextStyles.body.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(meta, style: BrioTextStyles.label.copyWith(fontSize: 10)),
          ])),
          const Icon(Icons.add_circle_outline_rounded, color: BrioColors.blue, size: 20),
        ]),
      ),
    );
  }

  String _titleCase(String s) => s.isEmpty ? s : s[0] + s.substring(1).toLowerCase();
}
