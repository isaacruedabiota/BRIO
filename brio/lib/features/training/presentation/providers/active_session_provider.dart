import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../features/auth/presentation/notifiers/auth_notifier.dart';
import '../../domain/entities/active_session.dart';
import '../../domain/entities/routine_detail.dart';
import 'training_providers.dart';

/// State of the in-progress workout session.
class ActiveSessionState {
  final int sessionId;
  final RoutineDetail? routine;
  final List<LoggedSet> sets;
  final DateTime startedAt;
  final bool finishing;

  const ActiveSessionState({
    required this.sessionId,
    required this.routine,
    required this.sets,
    required this.startedAt,
    this.finishing = false,
  });

  ActiveSessionState copyWith({List<LoggedSet>? sets, bool? finishing}) =>
      ActiveSessionState(
        sessionId: sessionId,
        routine:   routine,
        sets:      sets ?? this.sets,
        startedAt: startedAt,
        finishing: finishing ?? this.finishing,
      );

  List<LoggedSet> setsFor(int exerciseId) =>
      sets.where((s) => s.exerciseId == exerciseId).toList();

  double get totalVolume =>
      sets.fold(0, (sum, s) => sum + s.weightKg * s.reps);

  int get prCount => sets.where((s) => s.isPr).length;
}

/// Manages the active session lifecycle: start → logSet* → finish.
class ActiveSessionNotifier extends AsyncNotifier<ActiveSessionState?> {
  ApiClient get _api => ref.read(apiClientProvider);

  @override
  Future<ActiveSessionState?> build() async {
    // On startup, restore any active session from the backend
    // (survives closing the app or accidentally leaving the screen).
    try {
      final data = await _api.get('/training/sessions/active/');
      if (data == null) return null;
      return _stateFromJson(data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<ActiveSessionState> _stateFromJson(Map<String, dynamic> map) async {
    final routineJson = map['routine'] as Map<String, dynamic>?;
    RoutineDetail? routine;
    if (routineJson != null) {
      routine = await ref.read(routineDetailProvider(routineJson['id'] as int).future);
    }
    final sets = (map['sets'] as List? ?? [])
        .map((s) => LoggedSet.fromJson(s as Map<String, dynamic>))
        .toList();
    final started = DateTime.tryParse(map['started_at'] as String? ?? '')?.toLocal()
        ?? DateTime.now();
    return ActiveSessionState(
      sessionId: map['id'] as int,
      routine:   routine,
      sets:      sets,
      startedAt: started,
    );
  }

  Future<void> start({required int routineId}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final routine = await ref.read(routineDetailProvider(routineId).future);
      final data = await _api.post('/training/sessions/', data: {'routine_id': routineId})
          as Map<String, dynamic>;
      return ActiveSessionState(
        sessionId: data['id'] as int,
        routine:   routine,
        sets:      const [],
        startedAt: DateTime.now(),
      );
    });
  }

  Future<LoggedSet?> logSet({
    required int exerciseId,
    required int reps,
    required double weightKg,
    SetType setType = SetType.normal,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return null;

    final setNumber = current.setsFor(exerciseId).length + 1;
    final data = await _api.post(
      '/training/sessions/${current.sessionId}/sets/',
      data: {
        'exercise_id': exerciseId,
        'reps':        reps,
        'weight_kg':   weightKg,
        'set_number':  setNumber,
        'set_type':    setType.apiValue,
      },
    ) as Map<String, dynamic>;

    final logged = LoggedSet.fromJson(data);
    state = AsyncData(current.copyWith(sets: [...current.sets, logged]));
    return logged;
  }

  /// Removes an already-logged set (undo the tick).
  Future<void> deleteSet(int setId) async {
    final current = state.valueOrNull;
    if (current == null) return;
    await _api.delete('/training/sessions/${current.sessionId}/sets/$setId/');
    state = AsyncData(current.copyWith(
      sets: current.sets.where((s) => s.id != setId).toList(),
    ));
  }

  Future<void> finish() async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(finishing: true));
    await _api.post('/training/sessions/${current.sessionId}/finish/', data: {});
    // Invalidate providers that depend on the history.
    ref.invalidate(workoutHistoryProvider);
    state = const AsyncData(null);
  }

  /// Discards the session: deletes it from the backend so it's no longer active.
  Future<void> cancel() async {
    final current = state.valueOrNull;
    if (current != null) {
      try {
        await _api.delete('/training/sessions/${current.sessionId}/');
      } catch (_) {}
    }
    state = const AsyncData(null);
  }
}

final activeSessionProvider =
    AsyncNotifierProvider<ActiveSessionNotifier, ActiveSessionState?>(
  ActiveSessionNotifier.new,
);
