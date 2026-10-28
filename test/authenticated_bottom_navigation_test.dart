import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:esugid/auth_service.dart';
import 'package:esugid/features/home/presentation/authenticated_bottom_navigation.dart';

void main() {
  final resident = User(
    uid: 'resident',
    email: 'resident@example.com',
    role: UserRole.resident,
    name: 'Resident',
  );

  for (final width in <double>[240, 320, 360, 375, 390, 412, 430, 600]) {
    testWidgets('bottom navigation fits at ${width.toInt()}px', (tester) async {
      tester.view.physicalSize = Size(width, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                AuthenticatedBottomNavigation(
                  selectedIndex: 0,
                  user: resident,
                  onSelect: (_) {},
                  onPrimaryAction: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('REPORT'), findsOneWidget);
      expect(find.text('CONCERN'), findsNothing);
    });
  }

  testWidgets('bottom navigation supports large accessibility text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: Stack(
              children: [
                AuthenticatedBottomNavigation(
                  selectedIndex: 1,
                  user: resident,
                  onSelect: (_) {},
                  onPrimaryAction: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  for (final size in <Size>[const Size(320, 480), const Size(430, 980)]) {
    testWidgets('bottom navigation fits ${size.width}x${size.height}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                AuthenticatedBottomNavigation(
                  selectedIndex: 0,
                  user: resident,
                  onSelect: (_) {},
                  onPrimaryAction: () {},
                ),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('bottom navigation reserves the system gesture inset', (
    tester,
  ) async {
    late double reservedHeight;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            viewPadding: EdgeInsets.only(bottom: 24),
          ),
          child: Builder(
            builder: (context) {
              reservedHeight = authenticatedBottomNavigationReservedHeight(
                context,
              );
              return Scaffold(
                body: Stack(
                  children: [
                    AuthenticatedBottomNavigation(
                      selectedIndex: 0,
                      user: resident,
                      onSelect: (_) {},
                      onPrimaryAction: () {},
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );

    expect(reservedHeight, greaterThan(100));
    expect(tester.takeException(), isNull);
  });
}
