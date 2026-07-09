import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/brio_colors.dart';
import '../../../../core/theme/brio_text_styles.dart';
import '../../../../features/auth/presentation/notifiers/auth_notifier.dart';
import '../../../../shared/widgets/brio_loader.dart';
import '../../domain/entities/routine_detail.dart';
import '../providers/active_session_provider.dart';
import '../providers/training_providers.dart';
import '../widgets/exercise_picker.dart';

const _restPresets = [45, 60, 90, 120, 150, 180, 240];

/// Routine editor. routineId == null → create new.
class RoutineDetailPage extends ConsumerStatefulWidget {
  final int? routineId;
  const RoutineDetailPage({super.key, this.routineId});

  bool get isNew => routineId == null;

  @override
  ConsumerState<RoutineDetailPage> createState() => _RoutineDetailPageState();
}

class _RoutineDetailPageState extends ConsumerState<RoutineDetailPage> {
  final _nameCtrl = TextEditingController();
  List<_EditExercise>? _exercises;   // null until loaded
  bool _saving = false;
  bool _dirty = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _markDirty() => setState(() => _dirty = true);

  void _loadFrom(RoutineDetail r) {
    _nameCtrl.text = r.name;
    _exercises = r.exercises.map((e) => _EditExercise(
      exercise: e.exercise, sets: e.sets, reps: e.reps, rest: e.restSeconds,
    )).toList();
  }

  Future<void> _addExercise() async {
    final picked = await ExercisePicker.show(context);
    if (picked == null || !mounted) return;
    if (_exercises!.any((e) => e.exercise.id == picked.id)) return;
    setState(() {
      _exercises!.add(_EditExercise(exercise: picked, sets: 3, reps: 10, rest: 90));
      _dirty = true;
    });
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ponle un nombre a la rutina')));
      return;
    }
    setState(() => _saving = true);
    final api = ref.read(apiClientProvider);
    final payload = {
      'name': _nameCtrl.text.trim(),
      'exercises': [
        for (var i = 0; i < _exercises!.length; i++)
          {
            'exercise_id': _exercises![i].exercise.id,
            'sets': _exercises![i].sets,
            'reps': _exercises![i].reps,
            'rest_seconds': _exercises![i].rest,
            'order': i,
          }
      ],
    };
    try {
      if (widget.isNew) {
        await api.post('/training/routines/', data: payload);
      } else {
        await api.put('/training/routines/${widget.routineId}/', data: payload);
        ref.invalidate(routineDetailProvider(widget.routineId!));
      }
      ref.invalidate(routinesProvider);
      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: BrioColors.error));
      }
    }
  }

  Future<void> _deleteRoutine() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: BrioColors.bgElevated,
        title: Text('Eliminar rutina', style: BrioTextStyles.h3),
        content: Text('Esta acción no se puede deshacer.', style: BrioTextStyles.bodySmall),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar', style: TextStyle(color: BrioColors.error))),
        ],
      ),
    );
    if (ok != true) return;
    final api = ref.read(apiClientProvider);
    try {
      await api.delete('/training/routines/${widget.routineId}/');
      ref.invalidate(routinesProvider);
      if (!mounted) return;
      context.pop();
    } catch (_) {}
  }

  Future<void> _start() async {
    await ref.read(activeSessionProvider.notifier).start(routineId: widget.routineId!);
    if (!mounted) return;
    if (ref.read(activeSessionProvider).hasError) return;
    context.push(AppRoutes.activeSession);
  }

  @override
  Widget build(BuildContext context) {
    // Load data the first time (edit mode only).
    if (_exercises == null) {
      if (widget.isNew) {
        _exercises = [];
      } else {
        final detailAsync = ref.watch(routineDetailProvider(widget.routineId!));
        return detailAsync.when(
          loading: () => Scaffold(
            backgroundColor: BrioColors.bgBase,
            body: const Center(child: BrioLoader(size: 44)),
          ),
          error: (_, __) => Scaffold(
            backgroundColor: BrioColors.bgBase,
            appBar: AppBar(),
            body: Center(child: Text('No se pudo cargar.', style: BrioTextStyles.bodySmall)),
          ),
          data: (r) {
            if (r == null) {
              return Scaffold(
                backgroundColor: BrioColors.bgBase, appBar: AppBar(),
                body: Center(child: Text('Rutina no encontrada.', style: BrioTextStyles.bodySmall)),
              );
            }
            _loadFrom(r);
            return _buildEditor();
          },
        );
      }
    }
    return _buildEditor();
  }

  Widget _buildEditor() {
    final exercises = _exercises!;
    return Scaffold(
      backgroundColor: BrioColors.bgBase,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop()),
        title: Text(widget.isNew ? 'Nueva rutina' : 'Editar rutina'),
        actions: [
          if (!widget.isNew)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: BrioColors.error),
              onPressed: _deleteRoutine,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              children: [
                // Name.
                TextField(
                  controller: _nameCtrl,
                  style: BrioTextStyles.h2.copyWith(fontSize: 22),
                  onChanged: (_) => _markDirty(),
                  decoration: const InputDecoration(
                    hintText: 'Nombre de la rutina',
                    border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                    filled: false,
                  ),
                ),
                const SizedBox(height: 8),
                Text('${exercises.length} EJERCICIOS · ARRASTRA PARA REORDENAR', style: BrioTextStyles.label),
                const SizedBox(height: 10),

                // Reorderable list.
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: exercises.length,
                  onReorder: (oldI, newI) => setState(() {
                    if (newI > oldI) newI--;
                    final item = exercises.removeAt(oldI);
                    exercises.insert(newI, item);
                    _dirty = true;
                  }),
                  itemBuilder: (_, i) => _ExerciseEditCard(
                    key: ValueKey(exercises[i].exercise.id),
                    index: i,
                    data: exercises[i],
                    onChanged: _markDirty,
                    onRemove: () => setState(() { exercises.removeAt(i); _dirty = true; }),
                  ),
                ),

                const SizedBox(height: 8),
                // Add exercise.
                GestureDetector(
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
                            style: BrioTextStyles.body.copyWith(color: BrioColors.green, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom button bar.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: (_dirty || widget.isNew) ? BrioColors.gradient : null,
                          color: (_dirty || widget.isNew) ? null : BrioColors.bgElevated,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                            shape: const StadiumBorder(),
                          ),
                          child: _saving
                              ? const BrioLoader.button()
                              : Text(widget.isNew ? 'Crear rutina' : 'Guardar', style: BrioTextStyles.button),
                        ),
                      ),
                    ),
                  ),
                  if (!widget.isNew) ...[
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 52, width: 52,
                      child: OutlinedButton(
                        onPressed: _start,
                        style: OutlinedButton.styleFrom(
                          shape: const CircleBorder(),
                          side: const BorderSide(color: BrioColors.green),
                          padding: EdgeInsets.zero,
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: BrioColors.green),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Editable data for a routine exercise.
class _EditExercise {
  final ExerciseRef exercise;
  int sets;
  int reps;
  int rest;
  _EditExercise({required this.exercise, required this.sets, required this.reps, required this.rest});
}

class _ExerciseEditCard extends StatelessWidget {
  final int index;
  final _EditExercise data;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _ExerciseEditCard({
    super.key,
    required this.index,
    required this.data,
    required this.onChanged,
    required this.onRemove,
  });

  String _fmtRest(int s) => s >= 60 ? '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}' : '${s}s';

  Future<void> _editRest(BuildContext context) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: BrioColors.bgSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Descanso · ${data.exercise.name}', style: BrioTextStyles.h3),
              const SizedBox(height: 16),
              Wrap(spacing: 10, runSpacing: 10, children: _restPresets.map((s) {
                final sel = s == data.rest;
                return GestureDetector(
                  onTap: () => Navigator.pop(context, s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      color: sel ? BrioColors.green.withValues(alpha: 0.15) : BrioColors.bgElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: sel ? BrioColors.green : BrioColors.border, width: sel ? 1.5 : 1),
                    ),
                    child: Text(_fmtRest(s), style: BrioTextStyles.metric.copyWith(
                      fontSize: 15, color: sel ? BrioColors.green : BrioColors.textPrimary)),
                  ),
                );
              }).toList()),
            ],
          ),
        ),
      ),
    );
    if (picked != null) { data.rest = picked; onChanged(); }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BrioColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BrioColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: Icon(Icons.drag_indicator_rounded, color: BrioColors.textTertiary, size: 22),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => context.push('${AppRoutes.exerciseDetail}/${data.exercise.id}'),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(child: Text(data.exercise.name, style: BrioTextStyles.body.copyWith(fontWeight: FontWeight.w600))),
                        const SizedBox(width: 5),
                        Icon(Icons.info_outline_rounded, size: 14, color: BrioColors.textTertiary),
                      ]),
                      Text(data.exercise.muscleLabel, style: BrioTextStyles.bodySmall),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: onRemove,
                child: Icon(Icons.close_rounded, color: BrioColors.textTertiary, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Pill(label: 'Descanso ${_fmtRest(data.rest)}', icon: Icons.timer_outlined, highlight: true,
                onTap: () => _editRest(context)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool highlight;
  final VoidCallback onTap;
  const _Pill({required this.label, required this.icon, this.highlight = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = highlight ? BrioColors.green : BrioColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: highlight ? BrioColors.green.withValues(alpha: 0.1) : BrioColors.bgElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: highlight ? BrioColors.green.withValues(alpha: 0.3) : BrioColors.border),
        ),
        child: Row(children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label, style: BrioTextStyles.bodySmall.copyWith(color: color, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}
