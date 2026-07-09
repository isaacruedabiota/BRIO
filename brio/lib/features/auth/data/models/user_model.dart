import '../../domain/entities/user.dart';

class MacroTargetsModel {
  final int kcal;
  final int proteinG;
  final int carbsG;
  final int fatG;

  const MacroTargetsModel({
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  factory MacroTargetsModel.fromJson(Map<String, dynamic> json) => MacroTargetsModel(
        kcal:      json['kcal']      as int,
        proteinG:  json['protein_g'] as int,
        carbsG:    json['carbs_g']   as int,
        fatG:      json['fat_g']     as int,
      );

  MacroTargets toDomain() => MacroTargets(
        kcal:      kcal,
        proteinG:  proteinG,
        carbsG:    carbsG,
        fatG:      fatG,
      );
}

class UserProfileModel {
  final String goal;
  final double weightKg;
  final int heightCm;
  final String birthDate;
  final String gender;
  final String activityLevel;
  final int trainingDaysPerWeek;
  final bool isPublic;
  final MacroTargetsModel macroTargets;

  const UserProfileModel({
    required this.goal,
    required this.weightKg,
    required this.heightCm,
    required this.birthDate,
    required this.gender,
    required this.activityLevel,
    required this.trainingDaysPerWeek,
    required this.isPublic,
    required this.macroTargets,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) => UserProfileModel(
        goal:                json['goal']                   as String,
        weightKg:            (json['weight_kg'] as num).toDouble(),
        heightCm:            json['height_cm']              as int,
        birthDate:           json['birth_date']             as String,
        gender:              json['gender']                 as String,
        activityLevel:       json['activity_level']         as String,
        trainingDaysPerWeek: json['training_days_per_week'] as int,
        isPublic:            json['is_public'] as bool? ?? true,
        macroTargets:        MacroTargetsModel.fromJson(
                               json['macro_targets'] as Map<String, dynamic>,
                             ),
      );

  UserProfile toDomain() => UserProfile(
        goal:                goal,
        weightKg:            weightKg,
        heightCm:            heightCm,
        birthDate:           birthDate,
        gender:              gender,
        activityLevel:       activityLevel,
        trainingDaysPerWeek: trainingDaysPerWeek,
        isPublic:            isPublic,
        macroTargets:        macroTargets.toDomain(),
      );
}

class UserModel {
  final int id;
  final String email;
  final String name;
  final UserProfileModel? profile;

  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.profile,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id:      json['id']    as int,
        email:   json['email'] as String,
        name:    json['name']  as String,
        profile: json['profile'] != null
            ? UserProfileModel.fromJson(json['profile'] as Map<String, dynamic>)
            : null,
      );

  User toDomain() => User(
        id:      id,
        email:   email,
        name:    name,
        profile: profile?.toDomain(),
      );
}
