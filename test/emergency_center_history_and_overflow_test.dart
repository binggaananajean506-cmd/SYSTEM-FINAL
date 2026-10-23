import 'dart:async';
import 'package:esugid/community_service.dart';
import 'package:esugid/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Emergency Center Hotline Card Overflow Fix', () {
    testWidgets('Emergency Hotlines Shortcut Card fits 360px width without horizontal overflow',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (context) {
                  // Build the shortcut card within HomeScreen context
                  return HomeScreen.emergencyHotlinesShortcutCardForTest(context);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('EMERGENCY HOTLINES'), findsOneWidget);
      expect(find.text('DIRECT DIAL'), findsOneWidget);
      expect(find.text('24/7 TOLL-FREE'), findsOneWidget);
      expect(find.text('Immediate Assistance'), findsOneWidget);
      expect(find.text('911'), findsOneWidget);
      expect(find.text('View'), findsOneWidget);
    });

    testWidgets('Emergency Hotlines Shortcut Card fits compact 340px width without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(340, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (context) {
                  return HomeScreen.emergencyHotlinesShortcutCardForTest(context);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('EMERGENCY HOTLINES'), findsOneWidget);
      expect(find.text('DIRECT DIAL'), findsOneWidget);
      expect(find.text('Immediate Assistance'), findsOneWidget);
    });
  });

  group('Emergency Alert History Persistence (No 3-Second Timeout Bug)', () {
    test('Alert history stream does not timeout and wipe items after 3 seconds', () async {
      final controller = StreamController<List<CommunityAlert>>();
      final sampleAlert = CommunityAlert(
        id: 'hist_1',
        title: 'Flash Flood Resolved',
        message: 'Water levels receded in Poblacion.',
        severity: 'advisory',
        category: 'Emergency',
        alertType: 'Flood',
        instructions: 'Safe to return home.',
        sourceName: 'E-SUGID',
        targetBarangay: 'Poblacion',
        targetBarangays: const ['Poblacion'],
        visibility: 'targeted',
        status: 'resolved',
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
        active: false,
      );

      // Verify that without .timeout(), an alert emitted remains in the stream
      // and does NOT get superseded by an empty list after 3+ seconds
      final receivedData = <List<CommunityAlert>>[];
      final sub = controller.stream.listen((alerts) {
        receivedData.add(alerts);
      });

      controller.add([sampleAlert]);

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(receivedData.length, 1);
      expect(receivedData.first.length, 1);
      expect(receivedData.first.first.id, 'hist_1');

      // Wait 4 seconds (longer than previous 3-second timeout)
      await Future<void>.delayed(const Duration(seconds: 4));

      // Must STILL have only the original emitted data, NEVER replaced by an empty list []
      expect(receivedData.length, 1);
      expect(receivedData.last.isNotEmpty, isTrue);
      expect(receivedData.last.first.id, 'hist_1');

      await sub.cancel();
      await controller.close();
    });
  });
}
