import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeController {
  static const _preferenceKey = 'esugid_dark_mode';
  static const _themeModeKey = 'esugid_theme_mode';
  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.system);
  static Future<void> _writes = Future<void>.value();

  static Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    final savedMode = preferences.get(_themeModeKey);
    if (savedMode == 'system') {
      mode.value = ThemeMode.system;
    } else if (savedMode == 'dark') {
      mode.value = ThemeMode.dark;
    } else if (savedMode == 'light') {
      mode.value = ThemeMode.light;
    } else {
      final legacy = preferences.get(_preferenceKey);
      mode.value = legacy is bool
          ? (legacy ? ThemeMode.dark : ThemeMode.light)
          : ThemeMode.system;
    }
  }

  static bool get isDark =>
      mode.value == ThemeMode.dark ||
      (mode.value == ThemeMode.system &&
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark);

  static Future<void> setMode(ThemeMode newMode) {
    mode.value = newMode;
    // Serialize quick successive selections so an older write cannot win.
    final operation = _writes.then((_) => _persist(newMode));
    _writes = operation.catchError((Object error) {
      debugPrint('Could not save the appearance preference: $error');
    });
    return operation;
  }

  static Future<void> _persist(ThemeMode newMode) async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setString(_themeModeKey, newMode.name)) {
      throw StateError('The appearance preference could not be stored.');
    }
    await preferences.remove(_preferenceKey);
  }

  static Future<void> toggle() async {
    final next = isDark ? ThemeMode.light : ThemeMode.dark;
    await setMode(next);
  }
}
