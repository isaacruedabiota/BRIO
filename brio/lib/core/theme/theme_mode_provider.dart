import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Settings box (opened in main.dart before runApp).
const settingsBoxName = 'settings';
const _key = 'themeMode';

/// User-selected theme mode: light / dark / system (default).
final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  Box get _box => Hive.box(settingsBoxName);

  @override
  ThemeMode build() {
    final s = _box.get(_key, defaultValue: ThemeMode.system.name) as String;
    return ThemeMode.values.firstWhere((e) => e.name == s, orElse: () => ThemeMode.system);
  }

  void setMode(ThemeMode mode) {
    state = mode;
    _box.put(_key, mode.name);
  }
}
