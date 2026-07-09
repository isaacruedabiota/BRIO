import 'package:equatable/equatable.dart';

class MacroTargets extends Equatable {
  final int kcal;
  final int proteinG;
  final int carbsG;
  final int fatG;

  const MacroTargets({
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  @override
  List<Object> get props => [kcal, proteinG, carbsG, fatG];
}

class UserProfile extends Equatable {
  final String goal;
  final double weightKg;
  final int heightCm;
  final String birthDate;
  final String gender;
  final String activityLevel;
  final int trainingDaysPerWeek;
  final bool isPublic;
  final MacroTargets macroTargets;

  const UserProfile({
    required this.goal,
    required this.weightKg,
    required this.heightCm,
    required this.birthDate,
    required this.gender,
    required this.activityLevel,
    required this.trainingDaysPerWeek,
    this.isPublic = true,
    required this.macroTargets,
  });

  @override
  List<Object> get props => [goal, weightKg, heightCm, gender, activityLevel, isPublic];
}

class User extends Equatable {
  final int id;
  final String email;
  final String name;
  final UserProfile? profile;

  const User({
    required this.id,
    required this.email,
    required this.name,
    this.profile,
  });

  bool get hasProfile => profile != null;

  @override
  List<Object?> get props => [id, email, name, profile];
}
