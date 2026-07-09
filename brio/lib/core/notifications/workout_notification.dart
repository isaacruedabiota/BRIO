import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../features/training/presentation/providers/active_session_provider.dart';

/// Persistent notification (Hevy-style) while a workout is in progress: shows
/// the next set/exercise and a live chronometer. Tapping it opens the session
/// screen.
class WorkoutNotification {
  WorkoutNotification._();
  static final WorkoutNotification instance = WorkoutNotification._();

  final _plugin = FlutterLocalNotificationsPlugin();
  static const _id = 1001;
  static const _channelId = 'workout_session';
  static const _channelName = 'Entreno en curso';
  static const _channelDesc = 'Muestra tu entreno activo y la siguiente serie';

  bool _ready = false;

  /// Action when the notification is tapped (set by the app: open the session).
  static VoidCallback? onOpenSession;

  Future<void> init() async {
    const android = AndroidInitializationSettings('ic_stat_brio');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (resp) {
        if (resp.payload == 'active_session') onOpenSession?.call();
      },
    );

    final android0 = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android0?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId, _channelName,
      description: _channelDesc,
      importance: Importance.low, // no sound or heads-up: informational only
      showBadge: false,
    ));
    await android0?.requestNotificationsPermission();
    _ready = true;
  }

  /// Syncs the notification with the active session state.
  Future<void> sync(ActiveSessionState? session) async {
    if (!_ready) return;
    if (session == null || session.finishing) {
      await cancel();
      return;
    }
    final (title, body) = _content(session);
    await _plugin.show(
      _id, title, body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId, _channelName,
          channelDescription: _channelDesc,
          icon: 'ic_stat_brio',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,        // cannot be swiped away
          autoCancel: false,
          onlyAlertOnce: true,  // updates don't re-alert (sound/vibration)
          showWhen: true,
          usesChronometer: true, // live chronometer from `when`
          when: session.startedAt.millisecondsSinceEpoch,
          color: const Color(0xFF329FFC),
        ),
        iOS: const DarwinNotificationDetails(presentSound: false),
      ),
      payload: 'active_session',
    );
  }

  Future<void> cancel() async {
    if (!_ready) return;
    await _plugin.cancel(_id);
  }

  /// (title, body) of the notification based on session progress.
  (String, String) _content(ActiveSessionState s) {
    final routine = s.routine;
    final title = routine != null ? 'Entreno · ${routine.name}' : 'Entreno en curso';

    if (routine == null || routine.exercises.isEmpty) {
      final n = s.sets.length;
      return (title, n == 1 ? '1 serie registrada' : '$n series registradas');
    }
    for (final ex in routine.exercises) {
      final done = s.setsFor(ex.exercise.id).length;
      if (done < ex.sets) {
        return (title, 'Siguiente: ${ex.exercise.name} · Serie ${done + 1}/${ex.sets}');
      }
    }
    return (title, '¡Entreno completado! Toca para terminar');
  }
}
