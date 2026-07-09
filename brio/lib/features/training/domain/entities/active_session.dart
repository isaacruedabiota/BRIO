import 'package:equatable/equatable.dart';

enum SetType { normal, warmup, dropset, failure }

SetType setTypeFromString(String s) => switch (s) {
      'warmup'  => SetType.warmup,
      'dropset' => SetType.dropset,
      'failure' => SetType.failure,
      _         => SetType.normal,
    };

extension SetTypeLabel on SetType {
  /// Short label for the set column.
  String get badge => switch (this) {
        SetType.normal  => '',
        SetType.warmup  => 'C',   // Warm-up
        SetType.dropset => 'D',   // Dropset
        SetType.failure => 'F',   // Failure
      };
  String get label => switch (this) {
        SetType.normal  => 'Normal',
        SetType.warmup  => 'Calentamiento',
        SetType.dropset => 'Dropset',
        SetType.failure => 'Al fallo',
      };
  String get apiValue => name;
}

class LoggedSet extends Equatable {
  final int id;
  final int exerciseId;
  final int reps;
  final double weightKg;
  final int setNumber;
  final double estimated1rm;
  final bool isPr;
  final SetType setType;

  const LoggedSet({
    required this.id,
    required this.exerciseId,
    required this.reps,
    required this.weightKg,
    required this.setNumber,
    required this.estimated1rm,
    required this.isPr,
    required this.setType,
  });

  factory LoggedSet.fromJson(Map<String, dynamic> j) => LoggedSet(
        id:           j['id'] as int,
        exerciseId:   (j['exercise'] as Map<String, dynamic>)['id'] as int,
        reps:         j['reps'] as int,
        weightKg:     (j['weight_kg'] as num).toDouble(),
        setNumber:    j['set_number'] as int,
        estimated1rm: (j['estimated_1rm'] as num?)?.toDouble() ?? 0,
        isPr:         (j['is_pr'] as bool?) ?? false,
        setType:      setTypeFromString((j['set_type'] as String?) ?? 'normal'),
      );

  @override
  List<Object?> get props => [id];
}
