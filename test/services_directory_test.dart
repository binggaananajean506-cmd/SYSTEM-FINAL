import 'package:esugid/app/theme/esugid_clay_theme.dart';
import 'package:esugid/features/home/presentation/services_directory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pumpDirectory(
    WidgetTester tester, {
    required Brightness brightness,
    double width = 390,
    double textScale = 1,
    ValueChanged<String>? onAction,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildESugidClayTheme(brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ServicesDirectory(
              onBayanihan: () => onAction?.call('Bayanihan Works'),
              onMarket: () => onAction?.call('Local Market'),
              onEmergency: () => onAction?.call('Emergency & Safety'),
              onOfficials: () => onAction?.call('Municipal Officials'),
              onMap: () => onAction?.call('Town Map'),
              onCalendar: () => onAction?.call('Town Calendar'),
              onWeather: () => onAction?.call('Weather'),
              onOrganizations: () => onAction?.call('Private Organizations'),
              onExplore: () => onAction?.call('Explore Barili'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    for (final width in [240.0, 320.0, 390.0, 600.0]) {
      testWidgets('Services fit $width pixels in $brightness', (tester) async {
        await pumpDirectory(tester, brightness: brightness, width: width);
        expect(tester.takeException(), isNull);
        if (width >= 320) {
          expect(
            tester.getTopLeft(find.text('Bayanihan Works')).dy,
            tester.getTopLeft(find.text('Local Market')).dy,
          );
        }
        expect(
          tester.getTopLeft(find.text('Emergency & Safety')).dy,
          greaterThan(tester.getBottomLeft(find.text('Bayanihan Works')).dy),
        );
      });
    }

    testWidgets('Services grow for accessible text in $brightness', (
      tester,
    ) async {
      await pumpDirectory(
        tester,
        brightness: brightness,
        width: 320,
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getTopLeft(find.text('Local Market')).dy,
        greaterThan(tester.getBottomLeft(find.text('Bayanihan Works')).dy),
      );
      final explore = find.text('Explore Barili');
      await tester.ensureVisible(explore);
      await tester.pumpAndSettle();
      expect(explore.hitTestable(), findsOneWidget);
    });

    testWidgets('Every Services action remains reachable in $brightness', (
      tester,
    ) async {
      final actions = <String>[];
      await pumpDirectory(
        tester,
        brightness: brightness,
        width: 320,
        onAction: actions.add,
      );
      const labels = [
        'Bayanihan Works',
        'Local Market',
        'Emergency & Safety',
        'Municipal Officials',
        'Town Map',
        'Town Calendar',
        'Weather',
        'Private Organizations',
        'Explore Barili',
      ];
      for (final label in labels) {
        final target = find.text(label);
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pumpAndSettle();
      }
      expect(actions, labels);
      expect(tester.takeException(), isNull);
    });
  }
}
