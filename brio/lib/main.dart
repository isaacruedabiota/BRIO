import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'core/notifications/cardio_notification.dart';
import 'core/notifications/workout_notification.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:          Colors.transparent,
    statusBarBrightness:     Brightness.dark,
    statusBarIconBrightness: Brightness.light,
  ));

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Hive.initFlutter();
  await Hive.openBox('settings');   // preferences (theme mode, etc.)

  // Spanish date formatting data (DateFormat with locale 'es_ES').
  await initializeDateFormatting('es_ES', null);

  // Persistent workout notification (channel + permission).
  await WorkoutNotification.instance.init();
  // Ongoing cardio notification channel.
  await CardioNotification.instance.init();

  runApp(const ProviderScope(child: BrioApp()));
}
