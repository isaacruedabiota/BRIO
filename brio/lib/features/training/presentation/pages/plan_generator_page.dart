import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/brio_colors.dart';
import '../../../../core/theme/brio_text_styles.dart';
import '../../../../shared/widgets/brio_button.dart';
import '../../../../shared/widgets/brio_snack.dart';
import '../../../auth/presentation/notifiers/auth_notifier.dart';
import '../providers/training_providers.dart';

const _goalOptions = [
  (k: 'lose_fat',       e: '🔥', l: 'Perder grasa'),
  (k: 'gain_muscle',    e: '💪', l: 'Ganar músculo'),
  (k: 'gain_strength',  e: '🏋️', l: 'Ganar fuerza'),
  (k: 'gain_endurance', e: '🏃', l: 'Ganar resistencia'),
  (k: 'mobility',       e: '🤸', l: 'Movilidad'),
  (k: 'maintain',       e: '⚖️', l: 'Mantener'),
];

const _equipOptions = [
  (k: 'gym',        e: '🏋️', l: 'Gimnasio'),
  (k: 'dumbbell',   e: '🏠', l: 'Mancuernas'),
  (k: 'bands',      e: '🪢', l: 'Bandas'),
  (k: 'kettlebell', e: '🔔', l: 'Kettlebells'),
  (k: 'bodyweight', e: '🤸', l: 'Peso corporal'),
];

const _levelOptions = [
  (k: 'beginner',     l: 'Principiante'),
  (k: 'intermediate', l: 'Intermedio'),
  (k: 'advanced',     l: 'Avanzado'),
];

class PlanGeneratorPage extends ConsumerStatefulWidget {
  const PlanGeneratorPage({super.key});

  @override
  ConsumerState<PlanGeneratorPage> createState() => _PlanGeneratorPageState();
}

class _PlanGeneratorPageState extends ConsumerState<PlanGeneratorPage> {
  final Set<String> _goals = {};
  int _days = 3;
  String _level = 'intermediate';
  final Set<String> _equip = {'gym'};
  bool _cardio = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final p = ref.read(authNotifierProvider).valueOrNull?.user?.profile;
    if (p != null) {
      _days = p.trainingDaysPerWeek.clamp(1, 7);
      switch (p.goal) {
        case 'lose_fat':            _goals.add('lose_fat'); break;
        case 'gain_muscle':         _goals.add('gain_muscle'); break;
        case 'maintain':            _goals.add('maintain'); break;
        case 'improve_performance': _goals.addAll(['gain_strength', 'gain_endurance']); break;
      }
    }
    if (_goals.isEmpty) _goals.add('gain_muscle');
  }

  Future<void> _generate() async {
    if (_goals.isEmpty) {
      _err('Elige al menos un objetivo.');
      return;
    }
    if (_equip.isEmpty) {
      _err('Elige dónde entrenas.');
      return;
    }
    setState(() => _loading = true);
    final plan = await generatePlan(
      ref,
      goals: _goals.toList(),
      days: _days,
      level: _level,
      equipment: _equip.toList(),
      includeCardio: _cardio,
    );
    if (!mounted) return;
    if (plan == null) {
      setState(() => _loading = false);
      _err('No se pudo generar el plan. Inténtalo de nuevo.');
      return;
    }
    // Save directly (creates routines + plan) and open the week editor.
    final ok = await savePlan(ref, plan);
    if (!mounted) return;
    setState(() => _loading = false);
    if (!ok) {
      _err('No se pudo crear el plan. Inténtalo de nuevo.');
      return;
    }
    BrioSnack.success(context, '¡Plan creado! Ajústalo a tu gusto.', icon: Icons.auto_awesome_rounded);
    context.pushReplacement(AppRoutes.weeklySchedule);
  }

  void _err(String msg) => BrioSnack.error(context, msg);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrioColors.bgBase,
      appBar: AppBar(title: const Text('Crear plan automático')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          _label('Objetivo · uno o varios'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final g in _goalOptions)
              _chip('${g.e} ${g.l}', _goals.contains(g.k), () => setState(() {
                    _goals.contains(g.k) ? _goals.remove(g.k) : _goals.add(g.k);
                  })),
          ]),
          const SizedBox(height: 20),

          _label('Días por semana'),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var d = 1; d <= 7; d++) _dayBox(d),
            ],
          ),
          const SizedBox(height: 20),

          _label('Nivel'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final lv in _levelOptions)
              _chip(lv.l, _level == lv.k, () => setState(() => _level = lv.k)),
          ]),
          const SizedBox(height: 20),

          _label('¿Dónde / con qué entrenas? · uno o varios'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final eq in _equipOptions)
              _chip('${eq.e} ${eq.l}', _equip.contains(eq.k), () => setState(() {
                    _equip.contains(eq.k) ? _equip.remove(eq.k) : _equip.add(eq.k);
                  })),
          ]),
          const SizedBox(height: 20),

          _label('Cardio'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
            decoration: BoxDecoration(
              color: BrioColors.bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: BrioColors.border),
            ),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Incluir cardio', style: BrioTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                  Text('Correr, andar, bici… según tu objetivo',
                      style: BrioTextStyles.bodySmall.copyWith(color: BrioColors.textTertiary, fontSize: 11)),
                ]),
              ),
              Switch.adaptive(
                value: _cardio,
                activeTrackColor: BrioColors.blue,
                onChanged: (v) => setState(() => _cardio = v),
              ),
            ]),
          ),
          const SizedBox(height: 28),

          BrioGradientButton(
            label: '✨  Generar plan',
            isLoading: _loading,
            onPressed: _loading ? null : _generate,
          ),
        ],
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 2),
        child: Text(t.toUpperCase(), style: BrioTextStyles.label),
      );

  Widget _chip(String label, bool selected, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? BrioColors.blue.withValues(alpha: 0.12) : BrioColors.bgCard,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: selected ? BrioColors.blue : BrioColors.border, width: selected ? 1.5 : 1),
          ),
          child: Text(label, style: BrioTextStyles.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: selected ? BrioColors.blueDeep : BrioColors.textSecondary,
          )),
        ),
      );

  Widget _dayBox(int d) {
    final sel = _days == d;
    return GestureDetector(
      onTap: () => setState(() => _days = d),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        width: 40, height: 44,
        decoration: BoxDecoration(
          color: sel ? BrioColors.blue.withValues(alpha: 0.12) : BrioColors.bgCard,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: sel ? BrioColors.blue : BrioColors.border, width: sel ? 1.5 : 1),
        ),
        child: Center(child: Text('$d', style: BrioTextStyles.body.copyWith(
          fontWeight: FontWeight.w700,
          color: sel ? BrioColors.blueDeep : BrioColors.textSecondary,
        ))),
      ),
    );
  }
}
