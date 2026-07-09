import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Persistent notification while a cardio activity is in progress: shows a live
/// summary (time · distance · pace · kcal). Informational only (cannot be
/// swiped away while the activity lasts).
class CardioNotification {
  CardioNotification._();
  static final CardioNotification instance = CardioNotification._();

  final _plugin = FlutterLocalNotificationsPlugin();
  static const _id = 1002;
  static const _channelId = 'cardio_activity';
  static const _channelName = 'Cardio en curso';
  static const _channelDesc = 'Muestra el resumen de tu actividad de cardio activa';

  bool _ready = false;

  Future<void> init() async {
    // WorkoutNotification already initializes the native plugin; here we only
    // create our own channel so cardio and workout can coexist.
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId, _channelName,
      description: _channelDesc,
      importance: Importance.low,
      showBadge: false,
    ));
    _ready = true;
  }

  /// Shows/updates the notification with the activity summary.
  Future<void> show({
    required String activityName,
    required int seconds,
    required double distanceKm,
    required String pace,
    required int kcal,
    required bool paused,
  }) async {
    if (!_ready) return;
    final time = _fmt(seconds);
    final dist = distanceKm >= 0.01 ? ' · ${distanceKm.toStringAsFixed(2)} km' : '';
    final paceStr = distanceKm >= 0.01 ? ' · $pace/km' : '';
    final prefix = paused ? '⏸ Pausado · ' : '';
    final body = '$prefix⏱ $time$dist$paceStr · $kcal kcal';

    await _plugin.show(
      _id,
      'Cardio · $activityName',
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId, _channelName,
          channelDescription: _channelDesc,
          icon: 'ic_stat_brio',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: !paused,      // cannot be dismissed while running
          autoCancel: false,
          onlyAlertOnce: true,   // updates don't re-alert (sound/vibration)
          showWhen: false,
          color: const Color(0xFF329FFC),
        ),
        iOS: const DarwinNotificationDetails(presentSound: false),
      ),
      payload: 'active_cardio',
    );
  }

  Future<void> cancel() async {
    if (!_ready) return;
    await _plugin.cancel(_id);
  }

  String _fmt(int s) {
    final h = s ~/ 3600;
    final m = (s % 3600 ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$sec' : '$m:$sec';
  }
}
