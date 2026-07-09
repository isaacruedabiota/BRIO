import 'package:equatable/equatable.dart';

class PlanExercise extends Equatable {
  final int exerciseId;
  final String name;
  final List<String> muscleGroups;
  final int sets;
  final int reps;
  final int restSeconds;

  const PlanExercise({
    required this.exerciseId,
    required this.name,
    required this.muscleGroups,
    required this.sets,
    required this.reps,
    required this.restSeconds,
  });

  factory PlanExercise.fromJson(Map<String, dynamic> j) => PlanExercise(
        exerciseId:   j['exercise_id'] as int,
        name:         j['name'] as String,
        muscleGroups: (j['muscle_groups'] as List? ?? []).map((e) => e.toString()).toList(),
        sets:         (j['sets'] as int?) ?? 3,
        reps:         (j['reps'] as int?) ?? 10,
        restSeconds:  (j['rest_seconds'] as int?) ?? 90,
      );

  Map<String, dynamic> toJson() => {
        'exercise_id':  exerciseId,
        'name':         name,
        'muscle_groups': muscleGroups,
        'sets':         sets,
        'reps':         reps,
        'rest_seconds': restSeconds,
      };

  @override
  List<Object?> get props => [exerciseId, sets, reps, restSeconds];
}

class PlanRoutine extends Equatable {
  final String key;
  final String name;
  final List<String> muscleGroups;
  final int estMin;
  final List<PlanExercise> exercises;

  const PlanRoutine({
    required this.key,
    required this.name,
    required this.muscleGroups,
    required this.estMin,
    required this.exercises,
  });

  factory PlanRoutine.fromJson(Map<String, dynamic> j) => PlanRoutine(
        key:          j['key'] as String,
        name:         j['name'] as String,
        muscleGroups: (j['muscle_groups'] as List? ?? []).map((e) => e.toString()).toList(),
        estMin:       (j['est_min'] as int?) ?? 0,
        exercises:    (j['exercises'] as List? ?? [])
            .map((e) => PlanExercise.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'key':           key,
        'name':          name,
        'muscle_groups': muscleGroups,
        'est_min':       estMin,
        'exercises':     exercises.map((e) => e.toJson()).toList(),
      };

  @override
  List<Object?> get props => [key, name, exercises];
}

class PlanDay extends Equatable {
  final int weekday;          // 0=Monday … 6=Sunday
  final String kind;          // strength | cardio | mobility | rest
  final String? routineKey;
  final int? routineId;       // id of the existing routine (for the manual editor)
  final String? name;         // label (cardio/mobility)
  final String? activityKey;
  final int? durationMin;

  const PlanDay({
    required this.weekday,
    required this.kind,
    this.routineKey,
    this.routineId,
    this.name,
    this.activityKey,
    this.durationMin,
  });

  factory PlanDay.fromJson(Map<String, dynamic> j) => PlanDay(
        weekday:     (j['weekday'] as int?) ?? 0,
        kind:        (j['kind'] as String?) ?? 'rest',
        routineKey:  j['routine_key'] as String?,
        routineId:   j['routine_id'] as int?,
        name:        j['name'] as String?,
        activityKey: j['activity_key'] as String?,
        durationMin: j['duration_min'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'weekday':      weekday,
        'kind':         kind,
        if (routineKey != null)  'routine_key':  routineKey,
        if (name != null)        'name':         name,
        if (activityKey != null) 'activity_key': activityKey,
        if (durationMin != null) 'duration_min': durationMin,
      };

  @override
  List<Object?> get props => [weekday, kind, routineKey, routineId, activityKey, durationMin];
}

class TrainingPlan extends Equatable {
  final int? id;
  final String title;
  final String subtitle;
  final List<String> goals;
  final String level;
  final int days;
  final List<PlanRoutine> routines;
  final List<PlanDay> week;

  const TrainingPlan({
    this.id,
    required this.title,
    required this.subtitle,
    required this.goals,
    required this.level,
    required this.days,
    required this.routines,
    required this.week,
  });

  PlanRoutine? routineByKey(String? key) {
    if (key == null) return null;
    for (final r in routines) {
      if (r.key == key) return r;
    }
    return null;
  }

  factory TrainingPlan.fromJson(Map<String, dynamic> j) => TrainingPlan(
        id:       j['id'] as int?,
        title:    (j['title'] as String?) ?? 'Plan de entreno',
        subtitle: (j['subtitle'] as String?) ?? '',
        goals:    (j['goals'] as List? ?? []).map((e) => e.toString()).toList(),
        level:    (j['level'] as String?) ?? 'intermediate',
        days:     (j['days'] as int?) ?? 0,
        routines: (j['routines'] as List? ?? [])
            .map((e) => PlanRoutine.fromJson(e as Map<String, dynamic>))
            .toList(),
        week: (j['week'] as List? ?? [])
            .map((e) => PlanDay.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// For sending on save (the backend recreates routines + plan).
  Map<String, dynamic> toJson() => {
        'title':    title,
        'goals':    goals,
        'level':    level,
        'routines': routines.map((r) => r.toJson()).toList(),
        'week':     week.map((d) => d.toJson()).toList(),
      };

  @override
  List<Object?> get props => [id, title, routines, week];
}
