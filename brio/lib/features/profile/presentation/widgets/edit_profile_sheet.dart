import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/settings/app_preferences.dart';
import '../../../../core/theme/brio_colors.dart';
import '../../../../core/theme/brio_text_styles.dart';
import '../../../../shared/widgets/brio_button.dart';
import '../../../auth/presentation/notifiers/auth_notifier.dart';
import '../../domain/profile_metrics.dart';

Future<void> showEditProfileSheet(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true, // above the floating navigation bar
      backgroundColor: Colors.transparent,
      builder: (_) => const _EditProfileSheet(),
    );

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet();

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _heightCtrl;   // cm (metric mode)
  late final TextEditingController _ftCtrl;       // feet (imperial mode)
  late final TextEditingController _inCtrl;       // inches (imperial mode)

  late String _goal;
  late String _gender;
  late String _activity;
  late int _days;
  late DateTime _birthDate;
  late int _originalKcal;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authNotifierProvider).valueOrNull!.user!;
    final p = user.profile!;
    final units = ref.read(unitSystemProvider);

    _nameCtrl = TextEditingController(text: user.name);
    _weightCtrl = TextEditingController(
      text: _trim(units.weightToDisplay(p.weightKg)),
    );
    final (ft, inch) = UnitSystem.cmToFeetInches(p.heightCm);
    _heightCtrl = TextEditingController(text: '${p.heightCm}');
    _ftCtrl = TextEditingController(text: '$ft');
    _inCtrl = TextEditingController(text: '$inch');

    _goal = p.goal;
    _gender = p.gender;
    _activity = p.activityLevel;
    _days = p.trainingDaysPerWeek;
    _birthDate = DateTime.tryParse(p.birthDate) ?? DateTime(2000, 1, 1);
    _originalKcal = p.macroTargets.kcal;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _ftCtrl.dispose();
    _inCtrl.dispose();
    super.dispose();
  }

  String _trim(double v) => v.toStringAsFixed(v % 1 == 0 ? 0 : 1).replaceAll('.', ',');

  double _parse(String s) => double.tryParse(s.trim().replaceAll(',', '.')) ?? 0;

  // Converts the current fields to kg/cm for calculation and submission.
  double get _weightKg {
    final units = ref.read(unitSystemProvider);
    return units.weightToKg(_parse(_weightCtrl.text));
  }

  int get _heightCm {
    final units = ref.read(unitSystemProvider);
    if (units == UnitSystem.metric) {
      return int.tryParse(_heightCtrl.text.trim()) ?? 0;
    }
    return UnitSystem.feetInchesToCm(
      int.tryParse(_ftCtrl.text.trim()) ?? 0,
      int.tryParse(_inCtrl.text.trim()) ?? 0,
    );
  }

  int get _previewKcal {
    final w = _weightKg, h = _heightCm;
    if (w < 30 || h < 100) return _originalKcal;
    return ProfileMetrics.estimateMacros(
      goal: _goal,
      weightKg: w,
      heightCm: h,
      age: ProfileMetrics.ageFromBirthDate(DateFormat('yyyy-MM-dd').format(_birthDate)),
      gender: _gender,
      activityLevel: _activity,
    ).kcal;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate,
      firstDate: DateTime(1920),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 13)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: BrioColors.blue,
            brightness: BrioColors.brightness,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _save() async {
    final w = _weightKg, h = _heightCm;
    if (_nameCtrl.text.trim().isEmpty) return _err('Escribe tu nombre.');
    if (w < 30 || w > 300) return _err('Peso fuera de rango.');
    if (h < 100 || h > 250) return _err('Altura fuera de rango.');

    setState(() => _saving = true);
    try {
      await ref.read(authNotifierProvider.notifier).updateProfile(
            name: _nameCtrl.text.trim(),
            goal: _goal,
            weightKg: double.parse(w.toStringAsFixed(1)),
            heightCm: h,
            birthDate: DateFormat('yyyy-MM-dd').format(_birthDate),
            gender: _gender,
            activityLevel: _activity,
            trainingDaysPerWeek: _days,
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _err(e is Failure ? e.message : 'No se pudo guardar. Inténtalo de nuevo.');
    }
  }

  void _err(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: BrioColors.error),
      );

  @override
  Widget build(BuildContext context) {
    final units = ref.watch(unitSystemProvider);
    final newKcal = _previewKcal;
    final delta = newKcal - _originalKcal;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: BrioColors.bgBase,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(child: _handle()),
              const SizedBox(height: 14),
              Text('Editar perfil', style: BrioTextStyles.h3),
              const SizedBox(height: 18),

              _label('Nombre'),
              _TextBox(controller: _nameCtrl, hint: 'Tu nombre'),
              const SizedBox(height: 14),

              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _label('Peso'),
                    _TextBox(
                      controller: _weightCtrl,
                      hint: '0',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      suffix: units.weightUnit,
                      onChanged: (_) => setState(() {}),
                    ),
                  ]),
                ),
                const SizedBox(width: 12),
                Expanded(child: _heightField(units)),
              ]),
              const SizedBox(height: 14),

              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _label('Sexo'),
                    Row(children: [
                      _genderBtn('Hombre', 'M'),
                      const SizedBox(width: 8),
                      _genderBtn('Mujer', 'F'),
                    ]),
                  ]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _label('Nacimiento'),
                    GestureDetector(
                      onTap: _pickDate,
                      child: _box(child: Row(children: [
                        Expanded(child: Text(DateFormat('dd/MM/yyyy').format(_birthDate), style: BrioTextStyles.body)),
                        Icon(Icons.calendar_today_outlined, size: 16, color: BrioColors.textTertiary),
                      ])),
                    ),
                  ]),
                ),
              ]),
              const SizedBox(height: 16),

              _label('Objetivo'),
              ...ProfileMetrics.goalLabels.entries.map((e) => _goalRow(e.key, e.value)),
              const SizedBox(height: 14),

              _label('Nivel de actividad'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final a in ProfileMetrics.activityLabels.entries)
                  _chip(a.value, selected: _activity == a.key, onTap: () => setState(() => _activity = a.key)),
              ]),
              const SizedBox(height: 16),

              _label('Días de entreno / semana'),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var d = 1; d <= 7; d++) _dayBox(d),
                ],
              ),
              const SizedBox(height: 18),

              _recalcBox(_originalKcal, newKcal, delta),
              const SizedBox(height: 16),

              BrioGradientButton(
                label: 'Guardar cambios',
                isLoading: _saving,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Sub-widgets.

  Widget _handle() => Container(
        width: 40, height: 4,
        decoration: BoxDecoration(color: BrioColors.border, borderRadius: BorderRadius.circular(2)),
      );

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Text(t.toUpperCase(), style: BrioTextStyles.label),
      );

  Widget _box({required Widget child}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: BrioColors.bgElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BrioColors.border, width: 1.5),
        ),
        child: child,
      );

  Widget _heightField(UnitSystem units) {
    if (units == UnitSystem.metric) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label('Altura'),
        _TextBox(
          controller: _heightCtrl,
          hint: '0',
          keyboardType: TextInputType.number,
          suffix: 'cm',
          onChanged: (_) => setState(() {}),
        ),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('Altura'),
      Row(children: [
        Expanded(child: _TextBox(controller: _ftCtrl, hint: '0', keyboardType: TextInputType.number, suffix: 'ft', onChanged: (_) => setState(() {}))),
        const SizedBox(width: 8),
        Expanded(child: _TextBox(controller: _inCtrl, hint: '0', keyboardType: TextInputType.number, suffix: 'in', onChanged: (_) => setState(() {}))),
      ]),
    ]);
  }

  Widget _genderBtn(String label, String value) {
    final sel = _gender == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _gender = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: sel ? BrioColors.blue.withValues(alpha: 0.10) : BrioColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: sel ? BrioColors.blue : BrioColors.border, width: sel ? 1.5 : 1),
          ),
          child: Text(label, textAlign: TextAlign.center, style: BrioTextStyles.body.copyWith(
            fontWeight: FontWeight.w600,
            color: sel ? BrioColors.blue : BrioColors.textSecondary,
          )),
        ),
      ),
    );
  }

  Widget _goalRow(String value, String label) {
    final sel = _goal == value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => setState(() => _goal = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: sel ? BrioColors.blue.withValues(alpha: 0.08) : BrioColors.bgCard,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: sel ? BrioColors.blue : BrioColors.border, width: sel ? 1.5 : 1),
          ),
          child: Row(children: [
            Text(ProfileMetrics.goalEmoji(value), style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: BrioTextStyles.body.copyWith(
              fontWeight: FontWeight.w600,
              color: sel ? BrioColors.blueDeep : BrioColors.textPrimary,
            ))),
            if (sel) const Icon(Icons.check_circle_rounded, color: BrioColors.blue, size: 20),
          ]),
        ),
      ),
    );
  }

  Widget _chip(String label, {required bool selected, required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? BrioColors.blue.withValues(alpha: 0.12) : BrioColors.bgCard,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: selected ? BrioColors.blue : BrioColors.border),
          ),
          child: Text(label, style: BrioTextStyles.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: selected ? BrioColors.blue : BrioColors.textSecondary,
          )),
        ),
      );

  Widget _dayBox(int d) {
    final sel = _days == d;
    return GestureDetector(
      onTap: () => setState(() => _days = d),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 38, height: 42,
        decoration: BoxDecoration(
          color: sel ? BrioColors.blue.withValues(alpha: 0.12) : BrioColors.bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sel ? BrioColors.blue : BrioColors.border, width: sel ? 1.5 : 1),
        ),
        child: Center(child: Text('$d', style: BrioTextStyles.body.copyWith(
          fontWeight: FontWeight.w700,
          color: sel ? BrioColors.blue : BrioColors.textSecondary,
        ))),
      ),
    );
  }

  Widget _recalcBox(int oldK, int newK, int delta) {
    final changed = delta != 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: BrioColors.blue.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BrioColors.blue.withValues(alpha: 0.22)),
      ),
      child: Row(children: [
        const Text('⚡', style: TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(style: BrioTextStyles.bodySmall.copyWith(color: BrioColors.blueDeep), children: [
              const TextSpan(text: 'Al guardar recalcularemos tus calorías: '),
              if (changed) ...[
                TextSpan(text: '$oldK', style: const TextStyle(decoration: TextDecoration.lineThrough)),
                TextSpan(text: ' → $newK kcal', style: const TextStyle(fontWeight: FontWeight.w700)),
              ] else
                TextSpan(text: '$newK kcal', style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ]),
    );
  }
}

// Text field with a unit suffix (uses the theme's global decoration).

class _TextBox extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? suffix;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const _TextBox({
    required this.controller,
    required this.hint,
    this.suffix,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: BrioTextStyles.body,
      inputFormatters: keyboardType == TextInputType.number
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      decoration: InputDecoration(
        hintText: hint,
        suffixText: suffix,
        suffixStyle: BrioTextStyles.metricSmall.copyWith(color: BrioColors.textTertiary),
      ),
    );
  }
}
