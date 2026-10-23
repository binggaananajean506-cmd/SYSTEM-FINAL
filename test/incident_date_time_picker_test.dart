import 'package:esugid/app/theme/esugid_clay_theme.dart';
import 'package:esugid/auth_service.dart';
import 'package:esugid/pages/concern_center_page.dart';
import 'package:esugid/widgets/incident_date_time_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

double _contrast(Color foreground, Color background) {
  final a = foreground.computeLuminance();
  final b = background.computeLuminance();
  return ((a > b ? a : b) + .05) / ((a > b ? b : a) + .05);
}

Future<void> _openPicker(WidgetTester tester, Brightness brightness) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildESugidClayTheme(brightness),
      home: ConcernCenterPage(
        formOnly: true,
        draft: const {
          'version': 8,
          'id': 'calendar-draft',
          'createdAt': '2026-09-05T08:30:00.000',
          'updatedAt': '2026-09-05T08:30:00.000',
          'recipientType': 'barangay',
          'handlerType': 'barangay',
          'incidentDate': '2026-09-05T08:30:00.000',
        },
        categoryLoader: () async => [],
        organizationLoader: (_, _) async => [],
      ),
    ),
  );
  await tester.pumpAndSettle();
  final style = tester.binding.renderViews.single.debugLayer!
      .find<SystemUiOverlayStyle>(
        Offset(tester.view.physicalSize.width / 2, 12),
      );
  expect(style?.statusBarIconBrightness, Brightness.light);
  expect(style?.statusBarBrightness, Brightness.dark);
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
  final date = find.text('Sep 5, 2026 · 8:30 AM');
  await tester.ensureVisible(date);
  await tester.tap(date);
  await tester.pumpAndSettle();
  expect(
    tester.widget<BottomSheet>(find.byType(BottomSheet)).showDragHandle,
    isFalse,
  );
}

Finder _day(String day) =>
    find.descendant(of: find.byType(BottomSheet), matching: find.text(day));

Future<void> _openSheet(
  WidgetTester tester,
  Brightness brightness, {
  ValueChanged<DateTime>? onApply,
  DateTime? initialDateTime,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildESugidClayTheme(brightness),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => IncidentDateTimePicker(
                initialDateTime: initialDateTime ?? DateTime(2026, 9, 5, 8, 30),
                onApply: (value) {
                  onApply?.call(value);
                  Navigator.of(context).pop();
                },
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = User(
      uid: 'calendar-resident',
      email: 'resident@example.com',
      role: UserRole.resident,
      name: 'Resident',
      barangay: 'Cabcaban',
      barangayId: 'cabcaban',
      accountStatus: AccountStatus.active,
      verificationStatus: VerificationStatus.verified,
    );
  });
  tearDown(() => AuthService.currentUser = null);

  for (final brightness in Brightness.values) {
    testWidgets('incident days have readable contrast in $brightness', (
      tester,
    ) async {
      await _openSheet(tester, brightness);
      final theme = Theme.of(tester.element(_day('6')));
      final day = tester.widget<Text>(_day('6'));
      expect(
        _contrast(day.style!.color!, theme.colorScheme.surface),
        greaterThanOrEqualTo(4.5),
        reason: 'Ordinary dates must remain readable on the calendar surface.',
      );
      final selected = tester.widget<Text>(_day('5'));
      final selectedCell = tester
          .widgetList<Container>(
            find.ancestor(of: _day('5'), matching: find.byType(Container)),
          )
          .firstWhere(
            (widget) =>
                widget.decoration is BoxDecoration &&
                (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
          );
      expect(
        _contrast(
          selected.style!.color!,
          (selectedCell.decoration! as BoxDecoration).color!,
        ),
        greaterThanOrEqualTo(4.5),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'today and future incident dates remain distinct in $brightness',
      (tester) async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day, 9, 15);
        DateTime? selected;
        await _openSheet(
          tester,
          brightness,
          initialDateTime: today,
          onApply: (value) => selected = value,
        );
        final nextMonth = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.chevron_right_rounded),
        );
        expect(nextMonth.onPressed, isNull);
        final lastDay = DateTime(now.year, now.month + 1, 0).day;
        if (now.day < lastDay) {
          final future = _day('${now.day + 1}');
          final button = tester.widget<InkWell>(
            find.ancestor(of: future, matching: find.byType(InkWell)).first,
          );
          expect(button.onTap, isNull);
          final color = tester.widget<Text>(future).style!.color!;
          final theme = Theme.of(tester.element(future));
          expect(
            _contrast(color, theme.colorScheme.surface),
            greaterThanOrEqualTo(4.5),
          );
          await tester.tap(future);
        }
        if (now.day > 1) {
          await tester.tap(_day('1'));
          await tester.pumpAndSettle();
          final outlinedToday = tester.widget<Text>(_day('${now.day}'));
          expect(
            _contrast(
              outlinedToday.style!.color!,
              Theme.of(tester.element(_day('${now.day}'))).colorScheme.surface,
            ),
            greaterThanOrEqualTo(4.5),
          );
          await tester.tap(find.text('Today'));
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(find.text('Apply Date & Time'));
        await tester.tap(find.text('Apply Date & Time'));
        await tester.pumpAndSettle();
        expect(selected, today);
        expect(tester.takeException(), isNull);
      },
    );

    for (final scenario in [(320.0, 1.0), (360.0, 1.5), (390.0, 2.0)]) {
      testWidgets(
        'incident picker fits ${scenario.$1}px at ${scenario.$2}x in $brightness',
        (tester) async {
          tester.view.physicalSize = Size(scenario.$1, 700);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          tester.platformDispatcher.textScaleFactorTestValue = scenario.$2;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          DateTime? selected;
          await _openSheet(
            tester,
            brightness,
            onApply: (value) => selected = value,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(_day('6'));
          await tester.tap(_day('6'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Morning (8 AM)'));
          await tester.tap(find.text('Morning (8 AM)'));
          await tester.pumpAndSettle();
          final apply = find.text('Apply Date & Time');
          await tester.ensureVisible(apply);
          await tester.tap(apply);
          await tester.pumpAndSettle();
          expect(find.byType(BottomSheet), findsNothing);
          expect(selected, DateTime(2026, 9, 6, 8));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('applying incident date and time updates the concern form', (
    tester,
  ) async {
    await _openPicker(tester, Brightness.light);
    await tester.tap(_day('6'));
    await tester.ensureVisible(find.text('Morning (8 AM)'));
    await tester.tap(find.text('Morning (8 AM)'));
    await tester.ensureVisible(find.text('Apply Date & Time'));
    await tester.tap(find.text('Apply Date & Time'));
    await tester.pumpAndSettle();
    expect(find.text('Sep 6, 2026 · 8:00 AM'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('incident picker cannot navigate before January 2021', (
    tester,
  ) async {
    await _openSheet(
      tester,
      Brightness.light,
      initialDateTime: DateTime(2021, 1, 1, 10),
    );
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.chevron_left_rounded),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('January 2021'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dismissing edited incident date preserves the concern date', (
    tester,
  ) async {
    await _openPicker(tester, Brightness.light);
    await tester.tap(_day('6'));
    Navigator.of(tester.element(find.byType(IncidentDateTimePicker))).pop();
    await tester.pumpAndSettle();
    expect(find.text('Sep 5, 2026 · 8:30 AM'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('time dialog opens at the selected incident time', (
    tester,
  ) async {
    await _openSheet(tester, Brightness.light);
    final edit = find.byKey(const ValueKey('incident-time-edit'));
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TimePickerDialog>(find.byType(TimePickerDialog))
          .initialTime,
      const TimeOfDay(hour: 8, minute: 30),
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('8:30 AM'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('concern header and labels fit with large text', (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _openPicker(tester, Brightness.light);
    expect(tester.takeException(), isNull);
  });
}
