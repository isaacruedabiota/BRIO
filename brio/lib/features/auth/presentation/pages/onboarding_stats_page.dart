import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/brio_colors.dart';
import '../../../../core/theme/brio_text_styles.dart';
import '../../../../shared/widgets/brio_button.dart';
import '../../../../shared/widgets/progress_dots.dart';
import '../notifiers/auth_notifier.dart';
import '../widgets/brio_text_field.dart';

class OnboardingStatsPage extends ConsumerStatefulWidget {
  final String goal;
  const OnboardingStatsPage({super.key, required this.goal});

  @override
  ConsumerState<OnboardingStatsPage> createState() => _OnboardingStatsPageState();
}

class _OnboardingStatsPageState extends ConsumerState<OnboardingStatsPage> {
  final _formKey     = GlobalKey<FormState>();
  final _emailCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _nameCtrl    = TextEditingController();
  final _weightCtrl  = TextEditingController();
  final _heightCtrl  = TextEditingController();

  String _gender       = 'M';
  String _activity     = 'active';
  int    _trainingDays = 4;
  DateTime? _birthDate;

  static const _activities = [
    (value: 'sedentary',       label: 'Sedentario'),
    (value: 'lightly_active',  label: 'Ligero'),
    (value: 'active',          label: 'Activo'),
    (value: 'very_active',     label: 'Muy activo'),
  ];

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context:      context,
      initialDate:  DateTime(2000, 1, 1),
      firstDate:    DateTime(1920),
      lastDate:     DateTime.now().subtract(const Duration(days: 365 * 13)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(primary: BrioColors.green),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona tu fecha de nacimiento.')),
      );
      return;
    }

    await ref.read(authNotifierProvider.notifier).register(
          email:               _emailCtrl.text.trim(),
          password:            _passCtrl.text,
          name:                _nameCtrl.text.trim(),
          goal:                widget.goal,
          weightKg:            double.parse(_weightCtrl.text),
          heightCm:            int.parse(_heightCtrl.text),
          birthDate:           DateFormat('yyyy-MM-dd').format(_birthDate!),
          gender:              _gender,
          activityLevel:       _activity,
          trainingDaysPerWeek: _trainingDays,
        );

    if (!mounted) return;
    final error = ref.read(authNotifierProvider).error;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:         Text(error.toString().replaceAll('Exception: ', '')),
          backgroundColor: BrioColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authNotifierProvider).isLoading;

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            children: [
              ProgressDots(current: 1, total: 2),
              const SizedBox(height: 32),
              Text('Cuéntanos sobre ti', style: BrioTextStyles.h1),
              const SizedBox(height: 8),
              Text('Para calcular tus objetivos calóricos exactos.',
                   style: BrioTextStyles.bodySmall),
              const SizedBox(height: 32),

              // Account.
              BrioTextField(controller: _nameCtrl, label: 'Nombre', hint: 'Carlos',
                validator: (v) => v == null || v.isEmpty ? 'Requerido' : null),
              const SizedBox(height: 16),
              BrioTextField(controller: _emailCtrl, label: 'Email', hint: 'tu@email.com',
                keyboardType: TextInputType.emailAddress,
                validator: (v) => v == null || !v.contains('@') ? 'Email no válido' : null),
              const SizedBox(height: 16),
              BrioTextField(controller: _passCtrl, label: 'Contraseña', hint: '••••••••',
                obscureText: true,
                validator: (v) => v == null || v.length < 8 ? 'Mínimo 8 caracteres' : null),
              const SizedBox(height: 24),

              // Gender.
              Text('SEXO', style: BrioTextStyles.label),
              const SizedBox(height: 8),
              Row(children: [
                _GenderButton(label: '♂ Hombre', value: 'M', selected: _gender,
                  onTap: () => setState(() => _gender = 'M')),
                const SizedBox(width: 12),
                _GenderButton(label: '♀ Mujer', value: 'F', selected: _gender,
                  onTap: () => setState(() => _gender = 'F')),
              ]),
              const SizedBox(height: 16),

              // Birth date.
              Text('FECHA DE NACIMIENTO', style: BrioTextStyles.label),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color:        BrioColors.bgElevated,
                    borderRadius: BorderRadius.circular(12),
                    border:       Border.all(color: BrioColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _birthDate == null
                              ? 'Seleccionar fecha'
                              : DateFormat('dd/MM/yyyy').format(_birthDate!),
                          style: _birthDate == null
                              ? BrioTextStyles.body.copyWith(color: BrioColors.textTertiary)
                              : BrioTextStyles.body,
                        ),
                      ),
                      Icon(Icons.calendar_today_outlined,
                                 color: BrioColors.textTertiary, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Weight and height.
              Row(children: [
                Expanded(
                  child: BrioTextField(controller: _weightCtrl, label: 'Peso (kg)',
                    hint: '82.5', keyboardType: TextInputType.number,
                    validator: (v) {
                      final n = double.tryParse(v ?? '');
                      return (n == null || n < 30 || n > 300) ? 'Inválido' : null;
                    }),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BrioTextField(controller: _heightCtrl, label: 'Altura (cm)',
                    hint: '178', keyboardType: TextInputType.number,
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      return (n == null || n < 100 || n > 250) ? 'Inválido' : null;
                    }),
                ),
              ]),
              const SizedBox(height: 16),

              // Activity level.
              Text('NIVEL DE ACTIVIDAD', style: BrioTextStyles.label),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _activities.map((a) => ChoiceChip(
                  label:    Text(a.label),
                  selected: _activity == a.value,
                  selectedColor:    BrioColors.green.withValues(alpha: 0.15),
                  labelStyle: BrioTextStyles.bodySmall.copyWith(
                    color: _activity == a.value ? BrioColors.green : BrioColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide(
                    color: _activity == a.value ? BrioColors.green : BrioColors.border,
                  ),
                  backgroundColor: BrioColors.bgElevated,
                  onSelected: (_) => setState(() => _activity = a.value),
                )).toList(),
              ),
              const SizedBox(height: 16),

              // Training days.
              Text('DÍAS DE ENTRENO / SEMANA', style: BrioTextStyles.label),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) {
                  final day      = i + 1;
                  final selected = _trainingDays == day;
                  return GestureDetector(
                    onTap: () => setState(() => _trainingDays = day),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color:        selected ? BrioColors.green.withValues(alpha: 0.15) : BrioColors.bgElevated,
                        borderRadius: BorderRadius.circular(10),
                        border:       Border.all(
                          color: selected ? BrioColors.green : BrioColors.border,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text('$day',
                          style: BrioTextStyles.body.copyWith(
                            fontWeight: FontWeight.w700,
                            color: selected ? BrioColors.green : BrioColors.textSecondary,
                          )),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 40),

              BrioGradientButton(
                label:     'Crear cuenta',
                onPressed: isLoading ? null : _submit,
                isLoading: isLoading,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('¿Ya tienes cuenta? ', style: BrioTextStyles.bodySmall),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Iniciar sesión'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenderButton extends StatelessWidget {
  final String label, value, selected;
  final VoidCallback onTap;

  const _GenderButton({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color:        isSelected ? BrioColors.green.withValues(alpha: 0.1) : BrioColors.bgElevated,
            borderRadius: BorderRadius.circular(12),
            border:       Border.all(
              color: isSelected ? BrioColors.green : BrioColors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: BrioTextStyles.body.copyWith(
              fontWeight: FontWeight.w600,
              color: isSelected ? BrioColors.green : BrioColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
