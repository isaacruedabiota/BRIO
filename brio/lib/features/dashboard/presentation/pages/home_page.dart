import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../features/training/presentation/providers/active_session_provider.dart';
import '../../../../core/theme/brio_colors.dart';
import '../../../../core/theme/brio_text_styles.dart';
import '../../../../features/auth/presentation/notifiers/auth_notifier.dart';
import '../../../../features/auth/domain/entities/user.dart';
import '../../../../features/nutrition/domain/entities/daily_log.dart';
import '../../../../features/nutrition/presentation/providers/nutrition_providers.dart';
import '../../../../features/training/domain/entities/workout_summary.dart';
import '../../../../features/training/presentation/providers/training_providers.dart';
import '../../../../features/training/presentation/providers/activity_providers.dart';
import '../../../../shared/widgets/brio_loader.dart';
import '../providers/selected_date_provider.dart';
import '../providers/month_summary_provider.dart';
import '../widgets/brio_calendar.dart';

const _meses = ['', 'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState     = ref.watch(authNotifierProvider).valueOrNull;
    final dateStr       = ref.watch(selectedDateStringProvider);
    final selected      = ref.watch(selectedDateProvider);
    final logAsync      = ref.watch(dailyLogProvider(dateStr));
    final workoutsAsync = ref.watch(workoutsForDateProvider(dateStr));
    final routinesAsync = ref.watch(routinesProvider);
    final burnedKcal    = ref.watch(burnedCaloriesProvider(dateStr)).valueOrNull?.total ?? 0;
    final streak        = ref.watch(currentStreakProvider).valueOrNull ?? 0;
    final user          = authState?.user;
    final targets       = user?.profile?.macroTargets;
    final isToday       = _isToday(selected);

    final consumed = logAsync.valueOrNull?.totals.kcal.toInt() ?? 0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,   // light icons over the blue header
      child: Scaffold(
        backgroundColor: BrioColors.bgBase,
        body: RefreshIndicator(
          color:           BrioColors.blue,
          backgroundColor: BrioColors.bgCard,
          onRefresh: () async {
            ref.invalidate(dailyLogProvider(dateStr));
            ref.invalidate(workoutHistoryProvider);
            ref.invalidate(routinesProvider);
            ref.invalidate(highlightsProvider);
            ref.invalidate(currentPlanProvider);
            ref.invalidate(todayPlanProvider);
            ref.invalidate(activityHistoryProvider);
          },
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _Header(
                greeting: _greeting(DateTime.now().hour),
                name:     user?.name.split(' ').first ?? '',
                date:     selected,
                streak:   streak,
                consumed: consumed,
                burned:   burnedKcal,
                onPickDate: () => _pickDate(context, ref),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                child: Column(
                  children: [
                    logAsync.when(
                      loading: () => const _RingSkeleton(),
                      error:   (_, __) => const _RingSkeleton(),
                      data:    (log) => _RingBlock(log: log, targets: targets, burnedKcal: burnedKcal),
                    ),
                    const SizedBox(height: 16),
                    workoutsAsync.when(
                      loading: () => const _WorkoutSkeleton(),
                      error:   (_, __) => const _WorkoutSkeleton(),
                      data: (workouts) {
                        // If today's plan has activities, show a swipeable carousel to
                        // start any of them (cardio included), even if one is already done.
                        final todayPlan = isToday
                            ? (ref.watch(todayPlanProvider).valueOrNull ?? const <TodayActivity>[])
                            : const <TodayActivity>[];
                        if (todayPlan.isNotEmpty) {
                          return _TodayPlanCarousel(activities: todayPlan, completed: workouts);
                        }
                        if (workouts.isNotEmpty) {
                          return _CompletedWorkoutCard(workout: workouts.first);
                        }
                        if (isToday) {
                          return routinesAsync.when(
                            loading: () => const _WorkoutSkeleton(),
                            error:   (_, __) => const _WorkoutSkeleton(),
                            data:    (routines) => _AvailableWorkoutCard(routines: routines),
                          );
                        }
                        return const _NoWorkoutCard();
                      },
                    ),
                    const _HighlightsSection(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context, WidgetRef ref) async {
    final kcalGoal = ref.read(authNotifierProvider).valueOrNull
            ?.user?.profile?.macroTargets.kcal.toDouble() ?? 2000.0;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => BrioCalendar(
        selected: ref.read(selectedDateProvider),
        kcalGoal: kcalGoal,
        onPick: (date) {
          ref.read(selectedDateProvider.notifier).state =
              DateTime(date.year, date.month, date.day);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  String _greeting(int hour) {
    if (hour < 13) return 'Buenos días';
    if (hour < 20) return 'Buenas tardes';
    return 'Buenas noches';
  }

  bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }
}

// Curved blue header + avatar + greeting + pills + stats.

class _Header extends StatelessWidget {
  final String greeting, name;
  final DateTime date;
  final int streak, consumed, burned;
  final VoidCallback onPickDate;
  const _Header({
    required this.greeting, required this.name, required this.date,
    required this.streak, required this.consumed, required this.burned,
    required this.onPickDate,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final dateLabel = '${date.day} ${_meses[date.month]}';

    return SizedBox(
      height: top + 320,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Blue background with a downward-curved bottom edge.
          Positioned.fill(child: CustomPaint(painter: _HeaderPainter(top: top))),

          // Greeting, top-left.
          Positioned(
            top: top + 16, left: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(greeting,
                    style: BrioTextStyles.bodySmall.copyWith(color: Colors.white.withValues(alpha: 0.9))),
                Text(name, style: BrioTextStyles.h2.copyWith(color: Colors.white)),
              ],
            ),
          ),

          // Date + streak pills, top-right.
          Positioned(
            top: top + 20, right: 18,
            child: Row(
              children: [
                _WhitePill(
                  icon: Icons.calendar_today_rounded,
                  text: dateLabel,
                  onTap: onPickDate,
                ),
                const SizedBox(width: 8),
                _WhitePill(
                  icon: Icons.local_fire_department_rounded,
                  iconColor: const Color(0xFFFF7A2F),
                  text: '$streak',
                ),
              ],
            ),
          ),

          // Centered avatar.
          Positioned(
            top: top + 96, left: 0, right: 0,
            child: const Center(child: _Avatar()),
          ),

          // Stats straddling the semicircle edge.
          Positioned(
            top: top + 232, left: 20, right: 20,
            child: Row(
              children: [
                Expanded(child: _StatCard(
                  icon: Icons.restaurant_rounded, value: '$consumed',
                  label: 'consumidas', accent: BrioColors.blue)),
                const SizedBox(width: 10),
                Expanded(child: _StatCard(
                  icon: Icons.local_fire_department_rounded, value: '$burned',
                  label: 'quemadas', accent: BrioColors.carbs)),
                const SizedBox(width: 10),
                Expanded(child: _StatCard(
                  icon: Icons.bolt_rounded, value: '$streak',
                  label: 'racha', accent: BrioColors.blue)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderPainter extends CustomPainter {
  final double top;
  const _HeaderPainter({required this.top});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final peakY = top + 250;   // center (higher)
    final sideY = top + 286;   // sides (lower)
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(0, sideY)
      ..quadraticBezierTo(w / 2, 2 * peakY - sideY, w, sideY)
      ..lineTo(w, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = BrioColors.blue);
  }

  @override
  bool shouldRepaint(_HeaderPainter old) => old.top != top;
}

class _WhitePill extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String text;
  final VoidCallback? onTap;
  const _WhitePill({required this.icon, required this.text, this.iconColor, this.onTap});

  @override
  Widget build(BuildContext context) {
    // The pills float over the blue header. In light mode they're white with
    // navy text; in dark mode the text is white, so the background must be dark
    // to stay visible (otherwise it would be white-on-white).
    final dark = BrioColors.brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: dark ? BrioColors.bgElevated : Colors.white,
          borderRadius: BorderRadius.circular(99),
          boxShadow: [BoxShadow(color: BrioColors.blueDeep.withValues(alpha: 0.18), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: iconColor ?? (dark ? BrioColors.blueBright : BrioColors.blueDeep)),
            const SizedBox(width: 5),
            Text(text, style: BrioTextStyles.metric.copyWith(fontSize: 13, color: BrioColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar();

  // Gym placeholder (editable from Profile in the future).
  static const _photoUrl =
      'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?auto=format&fit=crop&w=240&q=80';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92, height: 92,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFDFEEFF),
        border: Border.all(color: Colors.white, width: 5),
        boxShadow: [BoxShadow(color: BrioColors.blueDeep.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: ClipOval(
        child: Image.network(
          _photoUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.person_rounded, size: 48, color: Color(0xFF9AB4DA)),
          loadingBuilder: (ctx, child, prog) =>
              prog == null ? child : const Icon(Icons.fitness_center_rounded, size: 36, color: Color(0xFF9AB4DA)),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final Color accent;
  const _StatCard({required this.icon, required this.value, required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: BrioColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BrioColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(height: 5),
          Text(value, style: BrioTextStyles.metric.copyWith(fontSize: 18, color: BrioColors.textPrimary)),
          Text(label, style: BrioTextStyles.label.copyWith(fontSize: 9)),
        ],
      ),
    );
  }
}

// Concentric macro rings + legend.

class _RingBlock extends StatelessWidget {
  final DailyLog log;
  final MacroTargets? targets;
  final int burnedKcal;
  const _RingBlock({required this.log, required this.targets, this.burnedKcal = 0});

  @override
  Widget build(BuildContext context) {
    // Target in effect on THAT day (historized); if absent, the profile's current one.
    final dt = log.targets;
    final baseGoal    = (dt?.kcal     ?? targets?.kcal     ?? 2000).toDouble();
    final kcalGoal    = baseGoal + burnedKcal;
    final proteinGoal = (dt?.proteinG ?? targets?.proteinG ?? 150).toDouble();
    final carbsGoal   = (dt?.carbsG   ?? targets?.carbsG   ?? 250).toDouble();
    final fatGoal     = (dt?.fatG     ?? targets?.fatG     ?? 70).toDouble();

    final consumed  = log.totals.kcal;
    final available = kcalGoal - consumed;
    final over      = available < 0;

    double pct(double v, double g) => g > 0 ? (v / g).clamp(0.0, 1.0) : 0.0;

    return Column(
      children: [
        SizedBox(
          width: 224, height: 224,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(224, 224),
                painter: _RingsPainter(
                  kcal:    pct(consumed, kcalGoal),
                  protein: pct(log.totals.proteinG, proteinGoal),
                  carbs:   pct(log.totals.carbsG, carbsGoal),
                  fat:     pct(log.totals.fatG, fatGoal),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(over ? available.abs().toInt().toString() : available.toInt().toString(),
                      style: BrioTextStyles.metricLarge.copyWith(fontSize: 28)),
                  Text(over ? 'kcal de más' : 'kcal restantes',
                      style: BrioTextStyles.label.copyWith(
                        fontSize: 10,
                        color: over ? BrioColors.warning : BrioColors.textSecondary)),
                ],
              ),
            ],
          ),
        ),
        if (burnedKcal > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: BrioColors.blue.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_fire_department_rounded, size: 14, color: BrioColors.blue),
                const SizedBox(width: 5),
                Text('${baseGoal.toInt()} + $burnedKcal por ejercicio',
                    style: BrioTextStyles.label.copyWith(fontSize: 10, color: BrioColors.blue)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _Legend(label: 'Calorías', value: consumed, goal: kcalGoal, unit: '', color: BrioColors.blue),
            _Legend(label: 'Proteína', value: log.totals.proteinG, goal: proteinGoal, unit: 'g', color: BrioColors.protein),
            _Legend(label: 'Carbos', value: log.totals.carbsG, goal: carbsGoal, unit: 'g', color: BrioColors.carbs),
            _Legend(label: 'Grasas', value: log.totals.fatG, goal: fatGoal, unit: 'g', color: BrioColors.fat),
          ],
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final String label, unit;
  final double value, goal;
  final Color color;
  const _Legend({required this.label, required this.value, required this.goal, required this.unit, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 6),
        Text('${value.toInt()}$unit', style: BrioTextStyles.metric.copyWith(fontSize: 14, color: color)),
        Text('/ ${goal.toInt()}$unit', style: BrioTextStyles.label.copyWith(fontSize: 9)),
        const SizedBox(height: 2),
        Text(label, style: BrioTextStyles.label.copyWith(fontSize: 9)),
      ],
    );
  }
}

class _RingsPainter extends CustomPainter {
  final double kcal, protein, carbs, fat;
  const _RingsPainter({required this.kcal, required this.protein, required this.carbs, required this.fat});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const stroke = 10.0;
    const gap    = 6.0;
    final r1 = size.width / 2 - stroke / 2;          // kcal (outermost)
    final r2 = r1 - stroke - gap;                    // protein
    final r3 = r2 - stroke - gap;                    // carbs
    final r4 = r3 - stroke - gap;                    // fat (innermost)
    _ring(canvas, center, r1, stroke, kcal,    BrioColors.blue);
    _ring(canvas, center, r2, stroke, protein, BrioColors.protein);
    _ring(canvas, center, r3, stroke, carbs,   BrioColors.carbs);
    _ring(canvas, center, r4, stroke, fat,     BrioColors.fat);
  }

  void _ring(Canvas c, Offset center, double r, double stroke, double progress, Color color) {
    c.drawCircle(center, r, Paint()
      ..style = PaintingStyle.stroke ..strokeWidth = stroke ..color = BrioColors.border);
    if (progress > 0) {
      c.drawArc(Rect.fromCircle(center: center, radius: r), -math.pi / 2, 2 * math.pi * progress, false,
        Paint()..style = PaintingStyle.stroke ..strokeWidth = stroke ..strokeCap = StrokeCap.round ..color = color);
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) =>
      old.kcal != kcal || old.protein != protein || old.carbs != carbs || old.fat != fat;
}

// Workout cards.

class _CompletedWorkoutCard extends StatelessWidget {
  final WorkoutSummary workout;
  const _CompletedWorkoutCard({required this.workout});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('${AppRoutes.workoutDetail}/${workout.id}'),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: _cardDeco(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('ENTRENO COMPLETADO · VER', style: BrioTextStyles.label.copyWith(color: BrioColors.blue)),
                if (workout.prCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: BrioColors.warning.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(99)),
                    child: Text('${workout.prCount} PR${workout.prCount > 1 ? 's' : ''}',
                        style: BrioTextStyles.label.copyWith(color: BrioColors.warning)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(children: [
              _iconBox(Icons.fitness_center_rounded),
              const SizedBox(width: 12),
              Expanded(child: Text(workout.routineName ?? 'Entreno libre', style: BrioTextStyles.h3)),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              _WorkoutStat(value: '${workout.setCount}', label: 'series'),
              _dot(),
              _WorkoutStat(value: '${workout.totalVolumeKg.toInt()} kg', label: 'volumen'),
              _dot(),
              _WorkoutStat(value: '${workout.durationMin} min', label: 'duración'),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _dot() => Container(width: 4, height: 4, margin: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: BrioColors.textTertiary, shape: BoxShape.circle));
}

class _WorkoutStat extends StatelessWidget {
  final String value, label;
  const _WorkoutStat({required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: BrioTextStyles.metric.copyWith(fontSize: 16)),
          Text(label, style: BrioTextStyles.label),
        ],
      );
}

class _AvailableWorkoutCard extends ConsumerWidget {
  final List routines;
  const _AvailableWorkoutCard({required this.routines});

  Future<void> _start(BuildContext context, WidgetRef ref, int routineId) async {
    await ref.read(activeSessionProvider.notifier).start(routineId: routineId);
    if (!context.mounted) return;
    if (ref.read(activeSessionProvider).hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.read(activeSessionProvider).error.toString()), backgroundColor: BrioColors.error));
      return;
    }
    context.push(AppRoutes.activeSession);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (routines.isEmpty) {
      return const _InfoCard(icon: Icons.add_circle_outline_rounded, title: 'Sin rutinas aún',
          subtitle: 'Crea tu primera rutina en la pestaña Entreno.');
    }
    final routine = routines.first;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: BrioColors.bgCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: BrioColors.blue.withValues(alpha: 0.25)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ENTRENO DE HOY', style: BrioTextStyles.label.copyWith(color: BrioColors.blue)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: BrioColors.blue.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
                child: Text('${routine.exerciseCount} ejercicios', style: BrioTextStyles.label.copyWith(color: BrioColors.blue)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(routine.name, style: BrioTextStyles.h3),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity, height: 48,
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: BrioColors.gradient, borderRadius: BorderRadius.circular(99)),
              child: ElevatedButton(
                onPressed: () => _start(context, ref, routine.id),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: const StadiumBorder()),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.play_arrow_rounded, size: 20, color: Colors.white),
                    const SizedBox(width: 6),
                    Text('Empezar entreno', style: BrioTextStyles.button),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Carousel of activities planned for today.

class _TodayPlanCarousel extends ConsumerStatefulWidget {
  final List<TodayActivity> activities;
  final List<WorkoutSummary> completed;
  const _TodayPlanCarousel({required this.activities, required this.completed});

  @override
  ConsumerState<_TodayPlanCarousel> createState() => _TodayPlanCarouselState();
}

class _TodayPlanCarouselState extends ConsumerState<_TodayPlanCarousel> {
  final _pc = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  String get _todayStr {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}-${two(n.month)}-${two(n.day)}';
  }

  /// Session completed today matching this routine (or null).
  WorkoutSummary? _doneSession(TodayActivity a) {
    for (final w in widget.completed) {
      if (w.routineName == a.name) return w;
    }
    return null;
  }

  Future<void> _startStrength(int routineId) async {
    await ref.read(activeSessionProvider.notifier).start(routineId: routineId);
    if (!mounted) return;
    if (ref.read(activeSessionProvider).hasError) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ref.read(activeSessionProvider).error.toString()),
        backgroundColor: BrioColors.error));
      return;
    }
    context.push(AppRoutes.activeSession);
  }

  void _startCardio(TodayActivity a) {
    final catalog = ref.read(activityCatalogProvider).valueOrNull ?? const <ActivityType>[];
    ActivityType? type;
    for (final t in catalog) {
      if (t.key == a.activityKey) { type = t; break; }
    }
    if (type != null && type.usesDistance) {
      context.push(AppRoutes.gpsTracking, extra: type);
    } else {
      context.push(AppRoutes.logActivity);
    }
  }

  @override
  Widget build(BuildContext context) {
    final acts = ref.watch(activityHistoryProvider).valueOrNull ?? const <ActivityLogEntry>[];
    bool cardioDone(TodayActivity a) =>
        acts.any((e) => e.performedAt == _todayStr && e.key == a.activityKey);

    final items = widget.activities;
    return Column(
      children: [
        SizedBox(
          height: 196,
          child: PageView.builder(
            controller: _pc,
            onPageChanged: (i) => setState(() => _page = i),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final a = items[i];
              final done = a.kind == 'strength' ? _doneSession(a) != null : cardioDone(a);
              return _PlanActivityCard(
                activity: a,
                done: done,
                doneSession: a.kind == 'strength' ? _doneSession(a) : null,
                onStart: () => a.kind == 'strength'
                    ? _startStrength(a.routineId!)
                    : _startCardio(a),
              );
            },
          ),
        ),
        if (items.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < items.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 20 : 7, height: 7,
                  decoration: BoxDecoration(
                    color: i == _page ? BrioColors.blue : BrioColors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _PlanActivityCard extends StatelessWidget {
  final TodayActivity activity;
  final bool done;
  final WorkoutSummary? doneSession;
  final VoidCallback onStart;
  const _PlanActivityCard({
    required this.activity, required this.done, required this.doneSession, required this.onStart,
  });

  IconData _cardioIcon(String? key) => switch (key) {
        'running' => Icons.directions_run_rounded,
        'walking' => Icons.directions_walk_rounded,
        'cycling' => Icons.directions_bike_rounded,
        _ => Icons.favorite_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final strength = activity.kind == 'strength';
    final label = strength ? 'ENTRENO DE HOY' : 'CARDIO DE HOY';
    final icon = strength ? Icons.fitness_center_rounded : _cardioIcon(activity.activityKey);
    final meta = strength
        ? '${activity.exerciseCount} ejercicios · ~${activity.estMin} min'
        : '${activity.durationMin} min';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: BrioColors.bgCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: done
            ? BrioColors.success.withValues(alpha: 0.35)
            : BrioColors.blue.withValues(alpha: 0.25)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: BrioTextStyles.label.copyWith(
                  color: done ? BrioColors.success : BrioColors.blue)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (done ? BrioColors.success : BrioColors.blue).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99)),
                child: Text(done ? '✓ Hecho' : (strength ? 'fuerza' : 'cardio'),
                    style: BrioTextStyles.label.copyWith(
                        color: done ? BrioColors.success : BrioColors.blue)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: BrioColors.blue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 22, color: BrioColors.blueDeep),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(strength ? activity.name : 'Cardio · ${activity.name}',
                  style: BrioTextStyles.h3, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(meta, style: BrioTextStyles.label.copyWith(fontSize: 10)),
            ])),
          ]),
          const Spacer(),
          if (done && strength && doneSession != null)
            SizedBox(
              width: double.infinity, height: 44,
              child: OutlinedButton.icon(
                onPressed: () => context.push('${AppRoutes.workoutDetail}/${doneSession!.id}'),
                icon: const Icon(Icons.check_circle_rounded, size: 18, color: BrioColors.success),
                label: const Text('Completado · ver'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: BrioColors.success,
                  side: BorderSide(color: BrioColors.success.withValues(alpha: 0.5)),
                  shape: const StadiumBorder()),
              ),
            )
          else if (done)
            Container(
              width: double.infinity, height: 44, alignment: Alignment.center,
              decoration: BoxDecoration(
                color: BrioColors.success.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: BrioColors.success.withValues(alpha: 0.4))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.check_circle_rounded, size: 18, color: BrioColors.success),
                const SizedBox(width: 6),
                Text('Completado', style: BrioTextStyles.buttonSecondary.copyWith(color: BrioColors.success)),
              ]),
            )
          else
            SizedBox(
              width: double.infinity, height: 48,
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: BrioColors.gradient, borderRadius: BorderRadius.circular(99)),
                child: ElevatedButton.icon(
                  onPressed: onStart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                    shape: const StadiumBorder()),
                  icon: const Icon(Icons.play_arrow_rounded, size: 20, color: Colors.white),
                  label: Text(strength ? 'Empezar entreno' : 'Empezar cardio', style: BrioTextStyles.button),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NoWorkoutCard extends StatelessWidget {
  const _NoWorkoutCard();
  @override
  Widget build(BuildContext context) => const _InfoCard(
        icon: Icons.bedtime_rounded, title: 'Día de descanso', subtitle: 'Sin entreno registrado este día.');
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const _InfoCard({required this.icon, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: _cardDeco(),
        child: Row(children: [
          _iconBox(icon),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: BrioTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(subtitle, style: BrioTextStyles.bodySmall),
            ],
          )),
        ]),
      );
}

BoxDecoration _cardDeco() => BoxDecoration(
      color: BrioColors.bgCard,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: BrioColors.border),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))],
    );

Widget _iconBox(IconData icon) => Container(
      width: 42, height: 42,
      decoration: BoxDecoration(color: BrioColors.blue.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, size: 22, color: BrioColors.blue),
    );

// Highlights section.

class _HighlightsSection extends ConsumerWidget {
  const _HighlightsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(highlightsProvider).valueOrNull ?? const <Highlight>[];
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Row(children: [
            const Text('⭐', style: TextStyle(fontSize: 13)),
            const SizedBox(width: 6),
            Text('TUS DESTACADOS', style: BrioTextStyles.label.copyWith(fontSize: 10)),
          ]),
        ),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: _HighlightCard(item: items[i])),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _HighlightCard extends StatelessWidget {
  final Highlight item;
  const _HighlightCard({required this.item});

  static IconData _icon(String key) => switch (key) {
        'trophy' => Icons.emoji_events_rounded,
        'chart' => Icons.bar_chart_rounded,
        'run' => Icons.directions_run_rounded,
        'fire' => Icons.local_fire_department_rounded,
        'dumbbell' => Icons.fitness_center_rounded,
        _ => Icons.star_rounded,
      };

  static String _badge(String key) => switch (key) {
        'lift' => 'RÉCORD',
        'volume' => 'TOTAL',
        'run' => 'DISTANCIA',
        'streak' => 'RACHA',
        'workouts' => 'TOTAL',
        _ => '',
      };

  @override
  Widget build(BuildContext context) {
    final hero = item.hero;
    final fg = hero ? Colors.white : BrioColors.blueDeep;
    final sub = hero ? Colors.white.withValues(alpha: 0.88) : BrioColors.textSecondary;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        gradient: hero ? BrioColors.gradient : null,
        color: hero ? null : BrioColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: hero ? null : Border.all(color: BrioColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(_icon(item.icon), size: 20, color: hero ? Colors.white : BrioColors.blue),
            const Spacer(),
            if (hero && _badge(item.key).isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(_badge(item.key),
                    style: BrioTextStyles.label.copyWith(fontSize: 8, color: Colors.white)),
              ),
          ]),
          const SizedBox(height: 14),
          Text(item.label.toUpperCase(),
              style: BrioTextStyles.label.copyWith(fontSize: 9, color: sub)),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              text: item.value,
              style: BrioTextStyles.metricLarge.copyWith(fontSize: 26, color: fg),
              children: [
                if (item.unit.isNotEmpty)
                  TextSpan(text: ' ${item.unit}',
                      style: BrioTextStyles.metric.copyWith(fontSize: 14, color: fg)),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Text(item.name,
              style: BrioTextStyles.body.copyWith(fontSize: 13, fontWeight: FontWeight.w700, color: fg),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(item.context,
              style: BrioTextStyles.label.copyWith(fontSize: 9.5, color: sub),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// Skeletons.

class _RingSkeleton extends StatelessWidget {
  const _RingSkeleton();
  @override
  Widget build(BuildContext context) => Container(
        height: 300, decoration: _cardDeco(), child: const Center(child: BrioLoader(size: 40)));
}

class _WorkoutSkeleton extends StatelessWidget {
  const _WorkoutSkeleton();
  @override
  Widget build(BuildContext context) => Container(height: 100, decoration: _cardDeco());
}
