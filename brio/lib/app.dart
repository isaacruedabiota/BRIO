import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/notifications/workout_notification.dart';
import 'core/router/app_router.dart';
import 'core/settings/app_preferences.dart';
import 'core/theme/brio_colors.dart';
import 'core/theme/brio_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'features/training/presentation/providers/active_session_provider.dart';

class BrioApp extends ConsumerWidget {
  const BrioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final mode   = ref.watch(themeModeProvider);

    // Persistent workout notification: tapping it opens the session, and it is
    // shown/updated/hidden based on the active session state, as long as the
    // user has notifications enabled in Preferences.
    WorkoutNotification.onOpenSession = () => router.push(AppRoutes.activeSession);
    ref.listen(activeSessionProvider, (_, next) {
      final enabled = ref.read(notificationsEnabledProvider);
      WorkoutNotification.instance.sync(enabled ? next.valueOrNull : null);
    });
    // If notifications are disabled mid-workout, hide it immediately.
    ref.listen(notificationsEnabledProvider, (_, enabled) {
      WorkoutNotification.instance
          .sync(enabled ? ref.read(activeSessionProvider).valueOrNull : null);
    });

    // Effective brightness for the chosen mode (system = the phone's).
    final platform = MediaQuery.platformBrightnessOf(context);
    final brightness = switch (mode) {
      ThemeMode.light  => Brightness.light,
      ThemeMode.dark   => Brightness.dark,
      ThemeMode.system => platform,
    };

    // Apply the background/text palette before building the tree.
    BrioColors.applyBrightness(brightness);

    return MaterialApp.router(
      title:            'BRIO',
      debugShowCheckedModeBanner: false,
      theme:            BrioTheme.build(brightness),
      routerConfig:     router,
    );
  }
}
