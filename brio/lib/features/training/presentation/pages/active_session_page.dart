import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/brio_colors.dart';
import '../../../../core/theme/brio_text_styles.dart';
import '../../../../features/auth/presentation/notifiers/auth_notifier.dart';
import '../../domain/entities/active_session.dart';
import '../../domain/entities/routine_detail.dart';
import '../providers/active_session_provider.dart';
import '../providers/training_providers.dart';
import '../widgets/exercise_picker.dart';

class ActiveSessionPage extends ConsumerStatefulWidget {
  const ActiveSessionPage({super.key});

  @override
  ConsumerState<ActiveSessionPage> createState() => _ActiveSessionPageState();
}

class _ActiveSessionPageState extends ConsumerState<ActiveSessionPage> {
  Timer? _elapsedTimer;
  Duration _elapsed = Duration.zero;

  // Rest timer.
  Timer? _restTimer;
  int _restRemaining = 0;
  int _restTotal = 0;

  // Rest adjusted during the session, keyed by exerciseId.
  final Map<int, int> _restOverride = {};

  // Session exercises (editable: can be added/removed on the fly).
  List<RoutineExerciseDetail>? _exercises;

  @override
  void initState() {
    super.initState();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final started = ref.read(activeSessionProvider).valueOrNull?.startedAt;
      if (started != null && mounted) {
        setState(() => _elapsed = DateTime.now().difference(started));
      }
    });
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _restTimer?.cancel();
    super.dispose();
  }

  void _startRest(int seconds) {
    _restTimer?.cancel();
    setState(() { _restTotal = seconds; _restRemaining = seconds; });
    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_restRemaining <= 1) {
        t.cancel();
        if (mounted) setState(() => _restRemaining = 0);
        HapticFeedback.mediumImpact();
      } else {
        if (mounted) setState(() => _restRemaining--);
      }
    });
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _addExercise() async {
    final picked = await ExercisePicker.show(context);
    if (picked == null || !mounted) return;
    // Avoid duplicates.
    if (_exercises!.any((e) => e.exercise.id == picked.id)) return;
    setState(() {
      _exercises!.add(RoutineExerciseDetail(
        exercise: picked, sets: 3, reps: 10, restSeconds: 90,
      ));
    });
  }

  Future<void> _removeExercise(int exId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: BrioColors.bgElevated,
        title: Text('Eliminar ejercicio', style: BrioTextStyles.h3),
        content: Text('Se quitará de esta sesión (y sus series registradas).',
            style: BrioTextStyles.bodySmall),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar', style: TextStyle(color: BrioColors.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    // Delete this exercise's logged sets from the backend.
    final session = ref.read(activeSessionProvider).valueOrNull;
    if (session != null) {
      for (final s in session.setsFor(exId)) {
        await ref.read(activeSessionProvider.notifier).deleteSet(s.id);
      }
    }
    if (!mounted) return;
    setState(() => _exercises!.removeWhere((e) => e.exercise.id == exId));
  }

  Future<void> _confirmFinish(ActiveSessionState s) async {
    final hasRoutine = s.routine != null;
    bool saveRoutine = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: BrioColors.bgElevated,
          title: Text('Finalizar entreno', style: BrioTextStyles.h3),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${s.sets.length} series · ${s.totalVolume.toInt()} kg de volumen'
                '${s.prCount > 0 ? ' · ${s.prCount} PR' : ''}',
                style: BrioTextStyles.bodySmall,
              ),
              if (hasRoutine) ...[
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => setLocal(() => saveRoutine = !saveRoutine),
                  child: Row(
                    children: [
                      Icon(
                        saveRoutine ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                        color: saveRoutine ? BrioColors.green : BrioColors.textTertiary, size: 22,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Guardar los cambios en la rutina',
                          style: BrioTextStyles.bodySmall.copyWith(color: BrioColors.textPrimary))),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Seguir')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Finalizar')),
          ],
        ),
      ),
    );

    if (ok == true) {
      if (!mounted) return;
      final router = GoRouter.of(context);
      if (saveRoutine && hasRoutine) await _saveAsRoutine(s);
      await ref.read(activeSessionProvider.notifier).finish();
      router.pop();
    }
  }

  /// Saves the current exercises (order, rest, set count) into the routine.
  Future<void> _saveAsRoutine(ActiveSessionState s) async {
    final routineId = s.routine!.id;
    final exercises = <Map<String, dynamic>>[];
    for (var i = 0; i < _exercises!.length; i++) {
      final ex = _exercises![i];
      final done = s.setsFor(ex.exercise.id).length;
      exercises.add({
        'exercise_id':  ex.exercise.id,
        'sets':         done > 0 ? done : ex.sets,
        'reps':         ex.reps,
        'rest_seconds': _restOverride[ex.exercise.id] ?? ex.restSeconds,
        'order':        i,
      });
    }
    try {
      final api = ref.read(apiClientProvider);
      await api.put('/training/routines/$routineId/',
          data: {'name': s.routine!.name, 'exercises': exercises});
      ref.invalidate(routinesProvider);
      ref.invalidate(routineDetailProvider(routineId));
    } catch (_) {}
  }

  Future<void> _confirmCancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: BrioColors.bgElevated,
        title: Text('Cancelar entreno', style: BrioTextStyles.h3),
        content: Text('Se descartará la sesión actual.', style: BrioTextStyles.bodySmall),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Seguir')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Descartar', style: TextStyle(color: BrioColors.error)),
          ),
        ],
      ),
    );
    if (ok == true) {
      if (!mounted) return;
      final router = GoRouter.of(context);
      await ref.read(activeSessionProvider.notifier).cancel();
      router.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(activeSessionProvider);
    final session = sessionAsync.valueOrNull;

    if (session == null) {
      return Scaffold(
        backgroundColor: BrioColors.bgBase,
        body: const Center(child: Text('Sin sesión activa')),
      );
    }

    // Lazy init of the editable exercise list.
    _exercises ??= List.of(session.routine?.exercises ?? const []);
    final exercises = _exercises!;

    return Scaffold(
      backgroundColor: BrioColors.bgBase,
      body: SafeArea(
        child: Column(
          children: [
            // Header.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _confirmCancel,
                    icon: Icon(Icons.close_rounded, color: BrioColors.textSecondary),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(session.routine?.name ?? 'Entreno', style: BrioTextStyles.h3),
                        Text(_fmt(_elapsed),
                            style: BrioTextStyles.metricSmall.copyWith(color: BrioColors.green)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: session.finishing ? null : () => _confirmFinish(session),
                    child: Text('Finalizar',
                        style: BrioTextStyles.button.copyWith(color: BrioColors.green, fontSize: 14)),
                  ),
                ],
              ),
            ),

            // Rest timer.
            if (_restRemaining > 0) _RestBanner(
              remaining: _restRemaining, total: _restTotal,
              onSkip: () { _restTimer?.cancel(); setState(() => _restRemaining = 0); },
              onAdd:  () => setState(() { _restRemaining += 15; _restTotal += 15; }),
              onSubtract: () => setState(() {
                _restRemaining = (_restRemaining - 15).clamp(5, 36000);
                if (_restTotal < _restRemaining) _restTotal = _restRemaining;
              }),
            ),

            // Exercise list (reorderable).
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                buildDefaultDragHandles: false,
                itemCount: exercises.length,
                onReorder: (oldI, newI) => setState(() {
                  if (newI > oldI) newI--;
                  final item = exercises.removeAt(oldI);
                  exercises.insert(newI, item);
                }),
                itemBuilder: (_, i) {
                  final exId = exercises[i].exercise.id;
                  final rest = _restOverride[exId] ?? exercises[i].restSeconds;
                  return _ExerciseBlock(
                    key: ValueKey('ex_$exId'),
                    dragIndex: i,
                    routineExercise: exercises[i],
                    initialLogged: session.setsFor(exId),
                    restSeconds: rest,
                    onRestChanged: (sec) => setState(() => _restOverride[exId] = sec),
                    onStartRest: () => _startRest(rest),
                    onRemoveExercise: () => _removeExercise(exId),
                  );
                },
              ),
            ),

            // Add exercise (pinned at the bottom).
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: GestureDetector(
                onTap: _addExercise,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: BrioColors.bgCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: BrioColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_rounded, size: 20, color: BrioColors.green),
                      const SizedBox(width: 6),
                      Text('Añadir ejercicio',
                          style: BrioTextStyles.body.copyWith(
                              color: BrioColors.green, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Rest banner.

class _RestBanner extends StatelessWidget {
  final int remaining, total;
  final VoidCallback onSkip;
  final VoidCallback onAdd;
  final VoidCallback onSubtract;
  const _RestBanner({
    required this.remaining, required this.total,
    required this.onSkip, required this.onAdd, required this.onSubtract,
  });

  String _fmt(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: BrioColors.green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BrioColors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: BrioColors.green, size: 20),
          const SizedBox(width: 8),
          Text('Descanso', style: BrioTextStyles.body.copyWith(fontSize: 13)),
          const Spacer(),
          _adjChip('−15s', onSubtract),
          SizedBox(
            width: 58,
            child: Text(_fmt(remaining), textAlign: TextAlign.center,
                style: BrioTextStyles.metric.copyWith(fontSize: 18, color: BrioColors.green)),
          ),
          _adjChip('+15s', onAdd),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onSkip,
            child: Text('Saltar', style: BrioTextStyles.bodySmall.copyWith(color: BrioColors.green)),
          ),
        ],
      ),
    );
  }

  Widget _adjChip(String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 46, height: 30, alignment: Alignment.center,
          decoration: BoxDecoration(
            color: BrioColors.green.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(label, style: BrioTextStyles.label.copyWith(color: BrioColors.green, fontSize: 11)),
        ),
      );
}

// Set row (editable local state).

class _SetRowData {
  int? loggedId;            // null = not confirmed
  SetType type;
  bool isPr;
  final TextEditingController reps;
  final TextEditingController weight;

  _SetRowData({
    this.loggedId,
    this.type = SetType.normal,
    this.isPr = false,
    String reps = '',
    String weight = '',
  })  : reps = TextEditingController(text: reps),
        weight = TextEditingController(text: weight);

  bool get done => loggedId != null;

  void dispose() { reps.dispose(); weight.dispose(); }
}

// Exercise block.

class _ExerciseBlock extends ConsumerStatefulWidget {
  final int dragIndex;
  final RoutineExerciseDetail routineExercise;
  final List<LoggedSet> initialLogged;
  final int restSeconds;
  final ValueChanged<int> onRestChanged;
  final VoidCallback onStartRest;
  final VoidCallback onRemoveExercise;

  const _ExerciseBlock({
    super.key,
    required this.dragIndex,
    required this.routineExercise,
    required this.initialLogged,
    required this.restSeconds,
    required this.onRestChanged,
    required this.onStartRest,
    required this.onRemoveExercise,
  });

  @override
  ConsumerState<_ExerciseBlock> createState() => _ExerciseBlockState();
}

class _ExerciseBlockState extends ConsumerState<_ExerciseBlock> {
  late List<_SetRowData> _rows;
  bool _prefilled = false;

  int get _exId => widget.routineExercise.exercise.id;

  @override
  void initState() {
    super.initState();
    // Initial rows from already-logged sets (restored session).
    _rows = widget.initialLogged
        .map((s) => _SetRowData(
              loggedId: s.id,
              type: s.setType,
              isPr: s.isPr,
              reps: '${s.reps}',
              weight: s.weightKg.toStringAsFixed(s.weightKg % 1 == 0 ? 0 : 1),
            ))
        .toList();
    if (_rows.isEmpty) _rows = [_SetRowData()];

    // If nothing is logged yet, preload as many rows as the last session.
    if (!widget.initialLogged.any((s) => true) || widget.initialLogged.isEmpty) {
      ref.read(lastExerciseSetsProvider(_exId).future).then((refs) {
        if (!mounted || _prefilled) return;
        final hasDone = _rows.any((r) => r.done);
        if (!hasDone && refs.length > 1) {
          setState(() {
            _prefilled = true;
            _rows = List.generate(refs.length, (_) => _SetRowData());
          });
        }
      });
    }
  }

  @override
  void dispose() {
    for (final r in _rows) { r.dispose(); }
    super.dispose();
  }

  ReferenceSet? _refFor(List<ReferenceSet> refs, int index) {
    if (refs.isEmpty) return null;
    return index < refs.length ? refs[index] : refs.last;
  }

  String _fmtRest(int s) => s >= 60
      ? '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}'
      : '${s}s';

  // Actions.

  void _addRow() => setState(() => _rows.add(_SetRowData()));

  Future<void> _removeRow(int i) async {
    final row = _rows[i];
    if (row.done && row.loggedId != null) {
      await ref.read(activeSessionProvider.notifier).deleteSet(row.loggedId!);
    }
    if (!mounted) return;
    setState(() { row.dispose(); _rows.removeAt(i); });
  }

  Future<void> _toggleDone(int i, ReferenceSet? ref) async {
    final row = _rows[i];
    if (row.done) {
      // Untick → delete from the backend and make it editable again.
      final id = row.loggedId!;
      await this.ref.read(activeSessionProvider.notifier).deleteSet(id);
      if (!mounted) return;
      setState(() => row.loggedId = null);
      return;
    }

    // Confirm: use what's typed or the reference.
    final reps = int.tryParse(row.reps.text) ?? ref?.reps;
    final weight = double.tryParse(row.weight.text.replaceAll(',', '.')) ?? ref?.weightKg;
    if (reps == null || reps <= 0 || weight == null || weight < 0) return;

    final messenger = ScaffoldMessenger.of(context);
    final logged = await this.ref.read(activeSessionProvider.notifier).logSet(
      exerciseId: _exId, reps: reps, weightKg: weight, setType: row.type,
    );
    if (logged == null || !mounted) return;

    setState(() {
      row.loggedId = logged.id;
      row.isPr = logged.isPr;
      if (row.reps.text.isEmpty) row.reps.text = '$reps';
      if (row.weight.text.isEmpty) row.weight.text = weight.toStringAsFixed(weight % 1 == 0 ? 0 : 1);
    });
    FocusScope.of(context).unfocus();

    // Rest: skip for warm-ups or when the NEXT set is a dropset.
    final nextIsDropset = (i + 1 < _rows.length) && _rows[i + 1].type == SetType.dropset;
    if (row.type != SetType.warmup && !nextIsDropset) {
      widget.onStartRest();
    }

    if (logged.isPr) {
      messenger.showSnackBar(SnackBar(
        content: Text('🏆 ¡Nuevo récord! 1RM estimado ${logged.estimated1rm.toInt()} kg'),
        backgroundColor: BrioColors.green, duration: const Duration(seconds: 2),
      ));
    }
  }

  Future<void> _pickType(int i) async {
    final picked = await showModalBottomSheet<SetType>(
      context: context,
      backgroundColor: BrioColors.bgSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: SetType.values.map((t) => ListTile(
            leading: _TypeBadge(type: t, size: 30),
            title: Text(t.label, style: BrioTextStyles.body),
            trailing: t == _rows[i].type ? const Icon(Icons.check_rounded, color: BrioColors.green) : null,
            onTap: () => Navigator.pop(context, t),
          )).toList(),
        ),
      ),
    );
    if (picked != null) setState(() => _rows[i].type = picked);
  }

  Future<void> _pickRest() async {
    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: BrioColors.bgSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _RestWheelPicker(initialSeconds: widget.restSeconds),
    );
    if (result != null) widget.onRestChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final ex = widget.routineExercise;
    final refs = ref.watch(lastExerciseSetsProvider(_exId)).valueOrNull ?? const [];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BrioColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BrioColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header + rest.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ReorderableDragStartListener(
                index: widget.dragIndex,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8, top: 2),
                  child: Icon(Icons.drag_indicator_rounded, color: BrioColors.textTertiary, size: 20),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => context.push('${AppRoutes.exerciseDetail}/${ex.exercise.id}'),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(child: Text(ex.exercise.name, style: BrioTextStyles.h3.copyWith(fontSize: 17))),
                        const SizedBox(width: 5),
                        Icon(Icons.info_outline_rounded, size: 15, color: BrioColors.textTertiary),
                      ]),
                      const SizedBox(height: 2),
                      Text(ex.exercise.muscleLabel, style: BrioTextStyles.bodySmall),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: _pickRest,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: BrioColors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: BrioColors.green.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.timer_outlined, size: 14, color: BrioColors.green),
                    const SizedBox(width: 4),
                    Text(_fmtRest(widget.restSeconds),
                        style: BrioTextStyles.bodySmall.copyWith(color: BrioColors.green, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
              // Exercise menu (remove).
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: BrioColors.textSecondary, size: 20),
                color: BrioColors.bgElevated,
                onSelected: (v) { if (v == 'remove') widget.onRemoveExercise(); },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'remove', child: Row(children: [
                    const Icon(Icons.delete_outline_rounded, size: 18, color: BrioColors.error),
                    const SizedBox(width: 8),
                    Text('Eliminar ejercicio', style: BrioTextStyles.bodySmall.copyWith(color: BrioColors.textPrimary)),
                  ])),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(children: const [
            _HCell('SERIE', flex: 14),
            _HCell('ANTERIOR', flex: 24),
            _HCell('REPS', flex: 17),
            _HCell('KG', flex: 17),
            _HCell('', flex: 14),
          ]),
          const SizedBox(height: 2),

          for (int i = 0; i < _rows.length; i++)
            _buildRow(i, _refFor(refs, i)),

          const SizedBox(height: 6),
          // Add set.
          GestureDetector(
            onTap: _addRow,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: BrioColors.bgElevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, size: 18, color: BrioColors.textSecondary),
                  const SizedBox(width: 4),
                  Text('Añadir serie', style: BrioTextStyles.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(int i, ReferenceSet? ref) {
    final row = _rows[i];
    final refLabel = ref != null
        ? '${ref.weightKg.toStringAsFixed(ref.weightKg % 1 == 0 ? 0 : 1)} × ${ref.reps}'
        : '—';
    final number = i + 1;

    return Dismissible(
      key: ValueKey('row_${row.hashCode}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _removeRow(i),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        margin: const EdgeInsets.symmetric(vertical: 3),
        decoration: BoxDecoration(
          color: BrioColors.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: BrioColors.error, size: 20),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        decoration: BoxDecoration(
          color: row.done ? BrioColors.green.withValues(alpha: 0.06) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          // Number/type — tappable to change type (always, done or not).
          Expanded(flex: 14, child: GestureDetector(
            onTap: () => _pickType(i),
            child: _SetNumberBadge(number: number, type: row.type, editable: true),
          )),
          Expanded(flex: 24, child: Text(refLabel, style: BrioTextStyles.metricSmall.copyWith(color: BrioColors.textTertiary))),
          Expanded(flex: 17, child: _MiniInput(controller: row.reps, hint: ref != null ? '${ref.reps}' : 'reps', enabled: !row.done)),
          const SizedBox(width: 6),
          Expanded(flex: 17, child: _MiniInput(controller: row.weight, hint: ref != null ? ref.weightKg.toStringAsFixed(0) : 'kg', decimal: true, enabled: !row.done)),
          const SizedBox(width: 6),
          // Tick: confirm / untick (toggle).
          Expanded(flex: 14, child: GestureDetector(
            onTap: () => _toggleDone(i, ref),
            child: row.done
                ? Icon(
                    row.isPr ? Icons.emoji_events_rounded : Icons.check_circle_rounded,
                    size: 26, color: row.isPr ? BrioColors.warning : BrioColors.green)
                : Container(
                    height: 38,
                    decoration: BoxDecoration(gradient: BrioColors.gradient, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.check_rounded, color: BrioColors.textInverse, size: 20),
                  ),
          )),
        ]),
      ),
    );
  }
}

/// Hevy-style rest wheel picker (minutes : seconds).
class _RestWheelPicker extends StatefulWidget {
  final int initialSeconds;
  const _RestWheelPicker({required this.initialSeconds});

  @override
  State<_RestWheelPicker> createState() => _RestWheelPickerState();
}

class _RestWheelPickerState extends State<_RestWheelPicker> {
  late int _min;
  late int _sec;

  @override
  void initState() {
    super.initState();
    _min = widget.initialSeconds ~/ 60;
    _sec = widget.initialSeconds % 60;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Tiempo de descanso', style: BrioTextStyles.h3),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: Row(
                children: [
                  Expanded(child: _wheel(
                    count: 11, value: _min, suffix: 'min', looping: false,
                    onChanged: (v) => setState(() => _min = v),
                  )),
                  Expanded(child: _wheel(
                    count: 60, value: _sec, suffix: 'seg', looping: true,
                    onChanged: (v) => setState(() => _sec = v),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: BrioColors.gradient, borderRadius: BorderRadius.circular(99)),
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, _min * 60 + _sec),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                    shape: const StadiumBorder(),
                  ),
                  child: Text('Listo', style: BrioTextStyles.button),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wheel({
    required int count,
    required int value,
    required String suffix,
    required bool looping,
    required ValueChanged<int> onChanged,
  }) {
    return CupertinoPicker(
      itemExtent: 40,
      looping: looping,
      scrollController: FixedExtentScrollController(initialItem: value),
      onSelectedItemChanged: onChanged,
      selectionOverlay: Container(
        decoration: BoxDecoration(
          border: Border.symmetric(
            horizontal: BorderSide(color: BrioColors.green.withValues(alpha: 0.4)),
          ),
        ),
      ),
      children: List.generate(count, (i) => Center(
        child: Text('$i $suffix',
            style: BrioTextStyles.metric.copyWith(fontSize: 20, color: BrioColors.textPrimary)),
      )),
    );
  }
}

class _SetNumberBadge extends StatelessWidget {
  final int number;
  final SetType type;
  final bool editable;
  const _SetNumberBadge({required this.number, required this.type, this.editable = false});

  @override
  Widget build(BuildContext context) {
    final color = switch (type) {
      SetType.normal  => BrioColors.textSecondary,
      SetType.warmup  => BrioColors.warning,
      SetType.dropset => BrioColors.protein,
      SetType.failure => BrioColors.error,
    };
    final text = type == SetType.normal ? '$number' : type.badge;
    return Row(children: [
      Text(text, style: BrioTextStyles.metric.copyWith(fontSize: 14, color: color)),
      if (editable) Icon(Icons.arrow_drop_down_rounded, size: 16, color: BrioColors.textTertiary),
    ]);
  }
}

class _TypeBadge extends StatelessWidget {
  final SetType type;
  final double size;
  const _TypeBadge({required this.type, required this.size});

  @override
  Widget build(BuildContext context) {
    final color = switch (type) {
      SetType.normal  => BrioColors.textSecondary,
      SetType.warmup  => BrioColors.warning,
      SetType.dropset => BrioColors.protein,
      SetType.failure => BrioColors.error,
    };
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
      child: Center(child: Text(
        type == SetType.normal ? '#' : type.badge,
        style: BrioTextStyles.metric.copyWith(fontSize: 13, color: color),
      )),
    );
  }
}

class _HCell extends StatelessWidget {
  final String text;
  final int flex;
  const _HCell(this.text, {required this.flex});
  @override
  Widget build(BuildContext context) =>
      Expanded(flex: flex, child: Text(text, style: BrioTextStyles.label.copyWith(fontSize: 9)));
}

class _MiniInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool decimal;
  final bool enabled;
  const _MiniInput({required this.controller, required this.hint, this.decimal = false, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      textAlign: TextAlign.center,
      style: BrioTextStyles.metric.copyWith(fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: enabled ? BrioColors.bgElevated : Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(vertical: 9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
    );
  }
}
