import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../theme/theme_mode_provider.dart' show settingsBoxName;

/// User preferences persisted in the Hive `settings` box (shared with the
/// theme): unit system, language and notifications.

// Unit system.

enum UnitSystem {
  metric,   // kg · cm
  imperial; // lb · ft/in

  String get label => this == UnitSystem.metric ? 'kg · cm' : 'lb · ft';

  // Weight.
  String get weightUnit => this == UnitSystem.metric ? 'kg' : 'lb';

  /// kg → value shown in the active unit.
  double weightToDisplay(double kg) =>
      this == UnitSystem.metric ? kg : kg * 2.20462;

  /// value in the active unit → kg (to send to the backend).
  double weightToKg(double value) =>
      this == UnitSystem.metric ? value : value / 2.20462;

  String formatWeight(double kg) => this == UnitSystem.metric
      ? '${kg.toStringAsFixed(kg % 1 == 0 ? 0 : 1)} kg'
      : '${(kg * 2.20462).round()} lb';

  // Height.
  String formatHeight(int cm) {
    if (this == UnitSystem.metric) return '$cm cm';
    final totalInches = cm / 2.54;
    final ft = totalInches ~/ 12;
    final inch = (totalInches - ft * 12).round();
    return "$ft' $inch\"";
  }

  static (int feet, int inches) cmToFeetInches(int cm) {
    final totalInches = (cm / 2.54).round();
    return (totalInches ~/ 12, totalInches % 12);
  }

  static int feetInchesToCm(int feet, int inches) =>
      ((feet * 12 + inches) * 2.54).round();
}

class UnitSystemNotifier extends Notifier<UnitSystem> {
  static const _key = 'unitSystem';
  Box get _box => Hive.box(settingsBoxName);

  @override
  UnitSystem build() {
    final s = _box.get(_key, defaultValue: UnitSystem.metric.name) as String;
    return UnitSystem.values.firstWhere((e) => e.name == s,
        orElse: () => UnitSystem.metric);
  }

  void set(UnitSystem u) {
    state = u;
    _box.put(_key, u.name);
  }
}

final unitSystemProvider =
    NotifierProvider<UnitSystemNotifier, UnitSystem>(UnitSystemNotifier.new);

// Language.

enum AppLanguage {
  es,
  en;

  String get label => this == AppLanguage.es ? 'Español' : 'English';
  String get flag => this == AppLanguage.es ? '🇪🇸' : '🇬🇧';
}

class AppLanguageNotifier extends Notifier<AppLanguage> {
  static const _key = 'language';
  Box get _box => Hive.box(settingsBoxName);

  @override
  AppLanguage build() {
    final s = _box.get(_key, defaultValue: AppLanguage.es.name) as String;
    return AppLanguage.values.firstWhere((e) => e.name == s,
        orElse: () => AppLanguage.es);
  }

  void set(AppLanguage l) {
    state = l;
    _box.put(_key, l.name);
  }
}

final appLanguageProvider =
    NotifierProvider<AppLanguageNotifier, AppLanguage>(AppLanguageNotifier.new);

// Notifications.

class NotificationsEnabledNotifier extends Notifier<bool> {
  static const _key = 'notificationsEnabled';
  Box get _box => Hive.box(settingsBoxName);

  @override
  bool build() => _box.get(_key, defaultValue: true) as bool;

  void set(bool enabled) {
    state = enabled;
    _box.put(_key, enabled);
  }
}

final notificationsEnabledProvider =
    NotifierProvider<NotificationsEnabledNotifier, bool>(
        NotificationsEnabledNotifier.new);
