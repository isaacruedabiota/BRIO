import 'package:flutter/material.dart';
import '../../../core/theme/brio_colors.dart';
import '../../auth/domain/entities/user.dart';

/// Pure profile calculations (age, BMI, macro estimation) and labels.
///
/// The macro estimation **mirrors the backend formula** (Mifflin-St Jeor +
/// activity multipliers + goal delta) so the recalculation can be previewed in
/// the edit sheet before saving. The server remains the source of truth.
class ProfileMetrics {
  ProfileMetrics._();

  // Age.
  static int ageFromBirthDate(String iso) {
    final b = DateTime.tryParse(iso);
    if (b == null) return 0;
    final now = DateTime.now();
    var age = now.year - b.year;
    if (now.month < b.month || (now.month == b.month && now.day < b.day)) age--;
    return age;
  }

  // BMI.
  static double bmi(double weightKg, int heightCm) {
    if (heightCm <= 0) return 0;
    final m = heightCm / 100.0;
    return weightKg / (m * m);
  }

  static ({String label, Color color}) bmiCategory(double bmi) {
    if (bmi < 18.5) return (label: 'Bajo peso', color: BrioColors.info);
    if (bmi < 25)   return (label: 'Peso normal', color: BrioColors.success);
    if (bmi < 30)   return (label: 'Sobrepeso', color: BrioColors.warning);
    return (label: 'Obesidad', color: BrioColors.error);
  }

  // Macro estimation (mirror of the backend).
  static const _activityMultipliers = {
    'sedentary':      1.2,
    'lightly_active': 1.375,
    'active':         1.55,
    'very_active':    1.725,
  };
  static const _goalDelta = {
    'lose_fat':            -400,
    'gain_muscle':         300,
    'improve_performance': 0,
    'maintain':            0,
  };

  static MacroTargets estimateMacros({
    required String goal,
    required double weightKg,
    required int heightCm,
    required int age,
    required String gender,
    required String activityLevel,
  }) {
    final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
    final bmr = gender == 'M' ? base + 5 : base - 161;
    final tdee = bmr * (_activityMultipliers[activityLevel] ?? 1.55);
    final kcal = (tdee + (_goalDelta[goal] ?? 0)).toInt();

    final proteinG = (weightKg * 2.0).toInt();
    final fatG = (kcal * 0.25 / 9).toInt();
    final carbsG = ((kcal - proteinG * 4 - fatG * 9) / 4).toInt();

    return MacroTargets(kcal: kcal, proteinG: proteinG, carbsG: carbsG, fatG: fatG);
  }

  // Spanish labels.
  static const goalLabels = {
    'lose_fat':            'Perder grasa',
    'gain_muscle':         'Ganar músculo',
    'improve_performance': 'Mejorar rendimiento',
    'maintain':            'Mantener peso',
  };
  static const goalEmojis = {
    'lose_fat':            '🔥',
    'gain_muscle':         '💪',
    'improve_performance': '⚡',
    'maintain':            '⚖️',
  };
  static const activityLabels = {
    'sedentary':      'Sedentario',
    'lightly_active': 'Ligero',
    'active':         'Activo',
    'very_active':    'Muy activo',
  };
  static String genderLabel(String g) => g == 'F' ? 'Mujer' : 'Hombre';

  static String goalLabel(String g) => goalLabels[g] ?? g;
  static String goalEmoji(String g) => goalEmojis[g] ?? '🎯';
  static String activityLabel(String a) => activityLabels[a] ?? a;
}
