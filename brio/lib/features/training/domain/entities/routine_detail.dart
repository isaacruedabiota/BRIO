import 'package:equatable/equatable.dart';

class ExerciseRef extends Equatable {
  final int id;
  final String name;
  final List<String> muscleGroups;
  final String equipment;
  final String? instructions;
  final String? gifUrl;

  const ExerciseRef({
    required this.id,
    required this.name,
    required this.muscleGroups,
    required this.equipment,
    this.instructions,
    this.gifUrl,
  });

  factory ExerciseRef.fromJson(Map<String, dynamic> j) => ExerciseRef(
        id:           j['id'] as int,
        name:         j['name'] as String,
        muscleGroups: (j['muscle_groups'] as List? ?? []).map((e) => e.toString()).toList(),
        equipment:    (j['equipment'] as String?) ?? '',
        instructions: j['instructions'] as String?,
        gifUrl:       j['gif_url'] as String?,
      );

  String get equipmentLabel => switch (equipment) {
        'barbell' => 'Barra', 'dumbbell' => 'Mancuerna', 'machine' => 'Máquina',
        'cable' => 'Polea', 'bodyweight' => 'Peso corporal', 'kettlebell' => 'Kettlebell',
        'bands' => 'Bandas', _ => 'Otro',
      };

  String get muscleLabel => muscleGroups
      .map(_muscleEs)
      .where((s) => s.isNotEmpty)
      .join(' · ');

  static String _muscleEs(String m) => switch (m) {
        'chest' => 'Pecho', 'back' => 'Espalda', 'shoulders' => 'Hombros',
        'biceps' => 'Bíceps', 'triceps' => 'Tríceps', 'quads' => 'Cuádriceps',
        'hamstrings' => 'Femoral', 'glutes' => 'Glúteo', 'calves' => 'Gemelos',
        'core' => 'Core', 'forearms' => 'Antebrazo', 'full_body' => 'Cuerpo completo',
        _ => '',
      };

  @override
  List<Object?> get props => [id];
}

class RoutineExerciseDetail extends Equatable {
  final ExerciseRef exercise;
  final int sets;
  final int reps;
  final int restSeconds;

  const RoutineExerciseDetail({
    required this.exercise,
    required this.sets,
    required this.reps,
    required this.restSeconds,
  });

  factory RoutineExerciseDetail.fromJson(Map<String, dynamic> j) => RoutineExerciseDetail(
        exercise:    ExerciseRef.fromJson(j['exercise'] as Map<String, dynamic>),
        sets:        (j['sets'] as int?) ?? 3,
        reps:        (j['reps'] as int?) ?? 10,
        restSeconds: (j['rest_seconds'] as int?) ?? 90,
      );

  @override
  List<Object?> get props => [exercise, sets, reps];
}

class RoutineDetail extends Equatable {
  final int id;
  final String name;
  final List<RoutineExerciseDetail> exercises;

  const RoutineDetail({required this.id, required this.name, required this.exercises});

  factory RoutineDetail.fromJson(Map<String, dynamic> j) => RoutineDetail(
        id:        j['id'] as int,
        name:      j['name'] as String,
        exercises: (j['exercises'] as List? ?? [])
            .map((e) => RoutineExerciseDetail.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  @override
  List<Object?> get props => [id, name, exercises];
}
