import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/brio_colors.dart';
import '../../../../core/theme/brio_text_styles.dart';
import '../../../../shared/widgets/brio_button.dart';
import '../../../../shared/widgets/progress_dots.dart';

const _goals = [
  (value: 'lose_fat',            icon: '🔥', label: 'Perder grasa',        sub: 'Déficit calórico controlado'),
  (value: 'gain_muscle',         icon: '💪', label: 'Ganar músculo',        sub: 'Superávit + alta proteína'),
  (value: 'improve_performance', icon: '⚡', label: 'Mejorar rendimiento',  sub: 'Maximizar fuerza y resistencia'),
  (value: 'maintain',            icon: '⚖️', label: 'Mantener peso',        sub: 'Hábitos saludables sostenibles'),
];

class OnboardingGoalPage extends StatefulWidget {
  const OnboardingGoalPage({super.key});

  @override
  State<OnboardingGoalPage> createState() => _OnboardingGoalPageState();
}

class _OnboardingGoalPageState extends State<OnboardingGoalPage> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProgressDots(current: 0, total: 2),
              const SizedBox(height: 32),

              Text('¿Cuál es tu objetivo?', style: BrioTextStyles.h1),
              const SizedBox(height: 8),
              Text(
                'Personalizamos tu plan en función de tu meta.',
                style: BrioTextStyles.bodySmall,
              ),
              const SizedBox(height: 32),

              Expanded(
                child: ListView.separated(
                  itemCount: _goals.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final goal     = _goals[i];
                    final selected = _selected == goal.value;
                    return _GoalCard(
                      icon:     goal.icon,
                      label:    goal.label,
                      sub:      goal.sub,
                      selected: selected,
                      onTap:    () => setState(() => _selected = goal.value),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),
              BrioGradientButton(
                label:     'Continuar',
                onPressed: _selected == null
                    ? null
                    : () => context.go('${AppRoutes.onboardingStats}?goal=$_selected'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final String icon, label, sub;
  final bool selected;
  final VoidCallback onTap;

  const _GoalCard({
    required this.icon,
    required this.label,
    required this.sub,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        selected ? BrioColors.green.withValues(alpha: 0.1) : BrioColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? BrioColors.green : BrioColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: BrioTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(sub, style: BrioTextStyles.bodySmall),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded, color: BrioColors.green, size: 22),
          ],
        ),
      ),
    );
  }
}
