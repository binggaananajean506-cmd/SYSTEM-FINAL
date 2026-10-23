import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:esugid/widgets/home_header_status_bar.dart';

void main() {
  test('notification badge labels follow the compact count rules', () {
    expect(unreadNotificationBadgeLabel(0), isNull);
    expect(unreadNotificationBadgeLabel(-1), isNull);
    expect(unreadNotificationBadgeLabel(1), '1');
    expect(unreadNotificationBadgeLabel(9), '9');
    expect(unreadNotificationBadgeLabel(10), '9+');
  });

  Widget buildStatusBar({required double width, double textScale = 1}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 800),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          backgroundColor: const Color(0xFF126646),
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: width,
              child: HomeHeaderStatusBar(
                locationLabel: 'Barili, Cebu',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.wb_sunny_rounded, size: 22),
                    SizedBox(width: 7),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [Text('28°C'), Text('Sunny')],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  for (final width in <double>[240, 320, 360, 375, 390, 412, 430, 600]) {
    testWidgets('status bar does not overflow at ${width.toInt()}px', (
      tester,
    ) async {
      await tester.pumpWidget(buildStatusBar(width: width));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('status bar supports enlarged accessibility text', (
    tester,
  ) async {
    await tester.pumpWidget(buildStatusBar(width: 320, textScale: 2));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  test('header extent grows with accessibility text scaling', () {
    final normal = responsiveHomeHeaderExtent(
      const MediaQueryData(padding: EdgeInsets.only(top: 24)),
    );
    final enlarged = responsiveHomeHeaderExtent(
      const MediaQueryData(
        padding: EdgeInsets.only(top: 24),
        textScaler: TextScaler.linear(2),
      ),
    );

    expect(normal, greaterThan(180));
    expect(enlarged, greaterThan(normal));
  });

  test('compact header saves space and respects accessibility scaling', () {
    const normalMedia = MediaQueryData(
      size: Size(390, 800),
      padding: EdgeInsets.only(top: 24),
    );
    const enlargedMedia = MediaQueryData(
      size: Size(390, 800),
      padding: EdgeInsets.only(top: 24),
      textScaler: TextScaler.linear(2),
    );

    final expanded = responsiveHomeHeaderExtent(normalMedia);
    final compact = responsiveCompactHomeHeaderExtent(normalMedia);
    final enlargedCompact = responsiveCompactHomeHeaderExtent(enlargedMedia);

    expect(compact, lessThan(expanded));
    expect(compact, greaterThanOrEqualTo(80));
    expect(enlargedCompact, greaterThan(compact));
  });

  test('banner height follows width and accessibility content', () {
    final compact = responsiveResidentBannerHeight(
      availableWidth: 296,
      textScaler: const TextScaler.linear(1),
    );
    final largeText = responsiveResidentBannerHeight(
      availableWidth: 296,
      textScaler: const TextScaler.linear(2),
    );
    final wide = responsiveResidentBannerHeight(
      availableWidth: 398,
      textScaler: const TextScaler.linear(1),
    );

    expect(compact, greaterThan(80));
    expect(largeText, greaterThan(compact));
    expect(wide, greaterThanOrEqualTo(compact));
  });

  test('home padding adapts without stretching larger phones', () {
    expect(responsiveHomeHorizontalPadding(320), 12);
    expect(responsiveHomeHorizontalPadding(360), 14);
    expect(responsiveHomeHorizontalPadding(430), 16);
    expect(responsiveHomeHorizontalPadding(600), 40);
  });
}
