import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/brio_colors.dart';
import '../../../../core/theme/brio_text_styles.dart';
import '../../../../features/auth/presentation/notifiers/auth_notifier.dart';
import '../../../../shared/widgets/brio_loader.dart';
import '../providers/activity_providers.dart';

class LogActivityPage extends ConsumerStatefulWidget {
  const LogActivityPage({super.key});

  @override
  ConsumerState<LogActivityPage> createState() => _LogActivityPageState();
}

class _LogActivityPageState extends ConsumerState<LogActivityPage> {
  ActivityType? _selected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrioColors.bgBase,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => _selected == null ? context.pop() : setState(() => _selected = null),
        ),
        title: Text(_selected?.name ?? 'Registrar actividad'),
      ),
      body: _selected == null ? _catalog() : _ActivityForm(activity: _selected!),
    );
  }

  Widget _catalog() {
    final async = ref.watch(activityCatalogProvider);
    return async.when(
      loading: () => const Center(child: BrioLoader(size: 44)),
      error:   (_, __) => Center(child: Text('No se pudo cargar.', style: BrioTextStyles.bodySmall)),
      data: (acts) => GridView.count(
        crossAxisCount: 3,
        padding: const EdgeInsets.all(20),
        mainAxisSpacing: 12, crossAxisSpacing: 12,
        children: acts.map((a) => GestureDetector(
          onTap: () => setState(() => _selected = a),
          child: Container(
            decoration: BoxDecoration(
              color: BrioColors.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BrioColors.border),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(a.iconData, size: 30, color: BrioColors.green),
                const SizedBox(height: 8),
                Text(a.name, style: BrioTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        )).toList(),
      ),
    );
  }
}

class _ActivityForm extends ConsumerStatefulWidget {
  final ActivityType activity;
  const _ActivityForm({required this.activity});

  @override
  ConsumerState<_ActivityForm> createState() => _ActivityFormState();
}

class _ActivityFormState extends ConsumerState<_ActivityForm> {
  bool _liveMode = true;        // true = stopwatch, false = manual
  bool _saving = false;

  // Stopwatch.
  Timer? _timer;
  int _seconds = 0;
  bool _running = false;

  // Manual.
  final _durationCtrl = TextEditingController();
  final _distanceCtrl = TextEditingController();

  double get _weight =>
      ref.read(authNotifierProvider).valueOrNull?.user?.profile?.weightKg ?? 75.0;

  int get _durationMin => _liveMode
      ? (_seconds / 60).ceil()
      : (int.tryParse(_durationCtrl.text) ?? 0);

  int get _kcal => (widget.activity.met * _weight * (_durationMin / 60.0)).round();

  @override
  void dispose() {
    _timer?.cancel();
    _durationCtrl.dispose();
    _distanceCtrl.dispose();
    super.dispose();
  }

  void _toggleTimer() {
    if (_running) {
      _timer?.cancel();
      setState(() => _running = false);
    } else {
      setState(() => _running = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _seconds++));
    }
  }

  String _fmt(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  Future<void> _save() async {
    final mins = _durationMin;
    if (mins <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registra algo de tiempo primero')));
      return;
    }
    setState(() => _saving = true);
    final dist = double.tryParse(_distanceCtrl.text.replaceAll(',', '.'));
    final ok = await logActivity(ref,
        activityKey: widget.activity.key, durationMin: mins, distanceKm: dist);
    if (!mounted) return;
    if (ok) {
      context.pop();
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar'), backgroundColor: BrioColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Track with GPS (outdoor distance activities only).
        if (widget.activity.usesDistance)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 2),
            child: SizedBox(
              width: double.infinity, height: 56,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: BrioColors.gradient,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: [BoxShadow(
                    color: BrioColors.green.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: ElevatedButton.icon(
                  onPressed: () => context.push(AppRoutes.gpsTracking, extra: widget.activity),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                    shape: const StadiumBorder()),
                  icon: const Icon(Icons.my_location_rounded, color: BrioColors.textInverse, size: 22),
                  label: Text('Seguir con GPS', style: BrioTextStyles.button),
                ),
              ),
            ),
          ),
        if (widget.activity.usesDistance)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text('o registra manualmente', style: BrioTextStyles.label),
          ),

        // Mode toggle.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
          child: Container(
            decoration: BoxDecoration(
              color: BrioColors.bgElevated,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(3),
            child: Row(children: [
              _modeTab('Cronómetro', true),
              _modeTab('Manual', false),
            ]),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(widget.activity.iconData, size: 48, color: BrioColors.green),
                const SizedBox(height: 24),

                if (_liveMode) ...[
                  Text(_fmt(_seconds), style: BrioTextStyles.metricXL.copyWith(fontSize: 56)),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 160, height: 56,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: _running ? null : BrioColors.gradient,
                            color: _running ? BrioColors.bgElevated : null,
                            borderRadius: BorderRadius.circular(99),
                            border: _running ? Border.all(color: BrioColors.border) : null,
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _toggleTimer,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                              shape: const StadiumBorder(),
                            ),
                            icon: Icon(_running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: _running ? BrioColors.textPrimary : BrioColors.textInverse),
                            label: Text(_running ? 'Pausar' : 'Iniciar',
                                style: _running ? BrioTextStyles.buttonSecondary : BrioTextStyles.button),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  _field(_durationCtrl, 'Duración (minutos)', Icons.timer_outlined),
                  if (widget.activity.usesDistance) ...[
                    const SizedBox(height: 14),
                    _field(_distanceCtrl, 'Distancia (km, opcional)', Icons.straighten_rounded, decimal: true),
                  ],
                ],

                const SizedBox(height: 28),
                // Estimated kcal.
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: BrioColors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: BrioColors.green.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_fire_department_rounded, color: BrioColors.green, size: 22),
                      const SizedBox(width: 10),
                      Text('$_kcal kcal', style: BrioTextStyles.metric.copyWith(fontSize: 22, color: BrioColors.green)),
                      const SizedBox(width: 6),
                      Text('estimadas', style: BrioTextStyles.bodySmall),
                    ],
                  ),
                ),
                const Spacer(),

                // Save.
                SizedBox(
                  width: double.infinity, height: 54,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: BrioColors.gradient, borderRadius: BorderRadius.circular(99)),
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                        shape: const StadiumBorder()),
                      child: _saving ? const BrioLoader.button()
                          : Text('Guardar actividad', style: BrioTextStyles.button),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _modeTab(String label, bool live) {
    final sel = _liveMode == live;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _liveMode = live),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: sel ? BrioColors.green : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(label, textAlign: TextAlign.center,
              style: BrioTextStyles.bodySmall.copyWith(
                color: sel ? BrioColors.textInverse : BrioColors.textSecondary,
                fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, IconData icon, {bool decimal = false}) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      style: BrioTextStyles.body,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icon, color: BrioColors.textTertiary)),
    );
  }
}
