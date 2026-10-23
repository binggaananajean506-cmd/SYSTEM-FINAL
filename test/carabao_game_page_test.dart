import 'package:esugid/pages/carabao_game_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Carabao Runner exposes a single jump control', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: CarabaoGamePage()));
    await tester.pumpAndSettle();

    expect(find.text('Tap to Jump'), findsOneWidget);
    expect(find.text('JUMP'), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_left_rounded), findsNothing);
    expect(find.byIcon(Icons.keyboard_arrow_right_rounded), findsNothing);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);
    expect(find.textContaining('Swipe'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('Carabao runner renders background, carabao, and visible texts in $brightness', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: const CarabaoGamePage(),
        ),
      );
      await tester.pumpAndSettle();

      // Check header text
      expect(find.text('CARABAO RUNNER'), findsOneWidget);
      expect(find.text('// BARILI COUNTRYSIDE RUNNER'), findsOneWidget);

      // Check ready dialog text
      expect(find.text('Ready to Run?'), findsOneWidget);
      expect(find.text('Tap to Jump'), findsOneWidget);
      expect(find.text('Clear Every Obstacle'), findsOneWidget);
      expect(find.text('START RUNNING'), findsOneWidget);

      // Check bottom jump button
      expect(find.text('JUMP'), findsOneWidget);

      // Check background terrain image is present in viewport
      final bgFinder = find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is AssetImage &&
            (widget.image as AssetImage).assetName.contains('forest-runner-background-terrain'),
      );
      expect(bgFinder, findsWidgets);

      // Check Carabao sprite is present in viewport before running
      final carabaoFinder = find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is AssetImage &&
            (widget.image as AssetImage).assetName.contains('carabao-3d-run-1'),
      );
      expect(carabaoFinder, findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  }
}
