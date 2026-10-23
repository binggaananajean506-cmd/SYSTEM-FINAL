import 'dart:io';

import 'package:esugid/app/theme/esugid_clay_theme.dart';
import 'package:esugid/app/theme/semantic_colors.dart';
import 'package:esugid/app_theme_controller.dart';
import 'package:esugid/features/settings/pages/app_preferences_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

double contrast(Color foreground, Color background) {
  final a = foreground.computeLuminance();
  final b = background.computeLuminance();
  return ((a > b ? a : b) + .05) / ((a > b ? b : a) + .05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppThemeController.initialize();
  });

  test(
    'new installations and malformed preferences use the system theme',
    () async {
      expect(AppThemeController.mode.value, ThemeMode.system);
      SharedPreferences.setMockInitialValues({'esugid_theme_mode': 12});
      await AppThemeController.initialize();
      expect(AppThemeController.mode.value, ThemeMode.system);
    },
  );

  test(
    'all three choices survive reopening and rapid selections save the last choice',
    () async {
      for (final mode in ThemeMode.values) {
        await AppThemeController.setMode(mode);
        AppThemeController.mode.value = ThemeMode.light;
        await AppThemeController.initialize();
        expect(AppThemeController.mode.value, mode);
      }
      await Future.wait([
        AppThemeController.setMode(ThemeMode.dark),
        AppThemeController.setMode(ThemeMode.light),
        AppThemeController.setMode(ThemeMode.system),
      ]);
      await AppThemeController.initialize();
      expect(AppThemeController.mode.value, ThemeMode.system);
    },
  );

  test(
    'existing boolean preferences migrate without resetting the choice',
    () async {
      for (final oldValue in [true, false]) {
        SharedPreferences.setMockInitialValues({'esugid_dark_mode': oldValue});
        await AppThemeController.initialize();
        expect(
          AppThemeController.mode.value,
          oldValue ? ThemeMode.dark : ThemeMode.light,
        );
        await AppThemeController.setMode(ThemeMode.system);
        final preferences = await SharedPreferences.getInstance();
        expect(preferences.getString('esugid_theme_mode'), 'system');
        expect(preferences.containsKey('esugid_dark_mode'), isFalse);
      }
    },
  );

  for (final colors in [ESugidColors.light, ESugidColors.dark]) {
    test(
      'native emergency palette matches ${colors == ESugidColors.dark ? 'dark' : 'light'} Flutter colors',
      () {
        final directory = colors == ESugidColors.dark
            ? 'values-night'
            : 'values';
        final xml = File(
          'android/app/src/main/res/$directory/colors.xml',
        ).readAsStringSync();
        final roles = {
          'background': colors.background,
          'surface': colors.surface,
          'text_primary': colors.textPrimary,
          'text_secondary': colors.textSecondary,
          'error': colors.error,
          'error_surface': colors.errorSurface,
          'error_solid': colors.errorSolid,
          'on_accent': colors.onAccent,
        };
        for (final role in roles.entries) {
          final hex = role.value
              .toARGB32()
              .toRadixString(16)
              .substring(2)
              .toUpperCase();
          expect(
            xml,
            contains('<color name="esugid_${role.key}">#$hex</color>'),
          );
        }
      },
    );
    test(
      '${colors == ESugidColors.dark ? 'dark' : 'light'} semantic text and status pairs meet contrast',
      () {
        final pairs = [
          for (final surface in [
            colors.background,
            colors.surface,
            colors.surfaceAlt,
            colors.inputBackground,
          ]) ...[
            (colors.textPrimary, surface),
            (colors.textSecondary, surface),
            (colors.primaryGreen, surface),
          ],
          (colors.onPrimary, colors.primaryGreen),
          (colors.disabled, colors.disabledBackground),
          (colors.success, colors.successSurface),
          (colors.warning, colors.warningSurface),
          (colors.error, colors.errorSurface),
          (colors.info, colors.infoSurface),
          (colors.purple, colors.purpleSurface),
          for (final solid in [
            colors.brand,
            colors.brandStrong,
            colors.brandAlt,
            colors.successSolid,
            colors.warningSolid,
            colors.errorSolid,
            colors.infoSolid,
            colors.purpleSolid,
          ])
            (colors.onAccent, solid),
        ];
        for (final pair in pairs) {
          expect(
            contrast(pair.$1, pair.$2),
            greaterThanOrEqualTo(4.5),
            reason: '${pair.$1} on ${pair.$2}',
          );
        }
      },
    );
  }

  testWidgets(
    'System follows Android brightness; explicit choices override it immediately',
    (tester) async {
      final dispatcher = tester.binding.platformDispatcher;
      addTearDown(dispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(
        ValueListenableBuilder<ThemeMode>(
          valueListenable: AppThemeController.mode,
          builder: (context, mode, _) => MaterialApp(
            theme: buildESugidClayTheme(Brightness.light),
            darkTheme: buildESugidClayTheme(Brightness.dark),
            themeMode: mode,
            themeAnimationDuration: Duration.zero,
            home: const AppPreferencesPage(),
          ),
        ),
      );
      dispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(AppPreferencesPage))).brightness,
        Brightness.dark,
      );
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(AppPreferencesPage))).brightness,
        Brightness.light,
      );
      dispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(AppPreferencesPage))).brightness,
        Brightness.dark,
      );
      await tester.tap(find.text('System Default'));
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(AppPreferencesPage))).brightness,
        Brightness.light,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(320, 640),
    const Size(600, 960),
    const Size(1200, 800),
  ]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'appearance choices fit $size in $brightness with large text',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              theme: buildESugidClayTheme(brightness),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(1.3)),
                child: child!,
              ),
              home: const AppPreferencesPage(),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('System Default'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
