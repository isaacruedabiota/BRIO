import 'package:equatable/equatable.dart';

class RoutineSummary extends Equatable {
  final int id;
  final String name;
  final int exerciseCount;

  /// Main muscle groups (Spanish labels, max 3) derived from the routine's
  /// exercises.
  final List<String> muscleGroups;

  /// Estimated duration in minutes (from sets and rests).
  final int estimatedMin;

  const RoutineSummary({
    required this.id,
    required this.name,
    required this.exerciseCount,
    this.muscleGroups = const [],
    this.estimatedMin = 0,
  });

  @override
  List<Object> get props => [id, name, exerciseCount, muscleGroups, estimatedMin];
}
