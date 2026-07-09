import 'package:equatable/equatable.dart';

/// Summary of a completed workout session, for the dashboard.
class WorkoutSummary extends Equatable {
  final int id;
  final String? routineName;
  final String finishedAtIso;
  final int durationMin;
  final double totalVolumeKg;
  final int prCount;
  final int setCount;

  const WorkoutSummary({
    required this.id,
    required this.routineName,
    required this.finishedAtIso,
    required this.durationMin,
    required this.totalVolumeKg,
    required this.prCount,
    required this.setCount,
  });

  /// 'yyyy-MM-dd' of finished_at, for filtering by day.
  String get dateOnly =>
      finishedAtIso.length >= 10 ? finishedAtIso.substring(0, 10) : finishedAtIso;

  @override
  List<Object?> get props => [id, finishedAtIso];
}
