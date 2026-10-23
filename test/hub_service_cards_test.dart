import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:esugid/features/home/presentation/hub_service_cards.dart';

void main() {
  Future<void> pumpCards(
    WidgetTester tester, {
    required double width,
    required double textScale,
  }) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  HubPrimaryServiceCard(
                    icon: Icons.handshake_rounded,
                    title: 'Bayanihan Works',
                    subtitle: 'Pangayo og tabang o paghalad og serbisyo.',
                    actions: const ['Ask for Help', 'Offer Help'],
                    onTap: () {},
                  ),
                  const SizedBox(height: 16),
                  HubActivityCard(onTap: () {}),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: HubShortcutCard(
                          icon: Icons.account_balance_rounded,
                          label: 'Government\nDirectory',
                          onTap: () {},
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: HubShortcutCard(
                          icon: Icons.call_rounded,
                          label: 'Emergency\nHotlines',
                          onTap: () {},
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const HubSafetyNotice(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  for (final width in <double>[240, 320, 360, 390, 600]) {
    testWidgets('Hub cards fit at ${width.toInt()}px', (tester) async {
      await pumpCards(tester, width: width, textScale: 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Hub cards grow for enlarged text without overflowing', (
    tester,
  ) async {
    await pumpCards(tester, width: 320, textScale: 2);
    expect(tester.takeException(), isNull);
  });

  Future<void> pumpServicesDesign(
    WidgetTester tester, {
    required double width,
    required double textScale,
    double height = 1100,
    VoidCallback? onFeaturedTap,
    VoidCallback? onQuickAccessTap,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ServiceSectionHeader(title: 'Featured Services'),
                  const SizedBox(height: 12),
                  FeaturedServicesLayout(
                    primary: FeaturedServiceCard(
                      icon: Icons.handshake_rounded,
                      title: 'Bayanihan Works',
                      subtitle: 'Tabang pinaagi sa komunidad.',
                      action: 'Open',
                      color: Colors.green,
                      onTap: onFeaturedTap ?? () {},
                    ),
                    secondary: FeaturedServiceCard(
                      icon: Icons.storefront_rounded,
                      title: 'Local Market',
                      subtitle: 'Palit ug baligya lokal sa Barili.',
                      action: 'Open',
                      color: Colors.teal,
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(height: 24),
                  const ServiceSectionHeader(title: 'Quick Access'),
                  const SizedBox(height: 12),
                  ServiceQuickAccessTile(
                    icon: Icons.calendar_month_rounded,
                    title: 'Community Calendar',
                    subtitle: 'Mga kalihokan ug iskedyul sa komunidad.',
                    onTap: onQuickAccessTap ?? () {},
                  ),
                  const SizedBox(height: 10),
                  ServiceQuickAccessTile(
                    icon: Icons.history_rounded,
                    title: 'My Service Activity',
                    subtitle: 'Your requests, offers, messages, and listings.',
                    onTap: () {},
                  ),
                  const SizedBox(height: 24),
                  const ServiceSectionHeader(title: 'Impormasyon sa Munisipyo'),
                  const SizedBox(height: 12),
                  ServiceQuickAccessTile(
                    icon: Icons.account_balance_rounded,
                    title: 'Municipal Officials',
                    subtitle: 'Tan-awa ang mga opisyal ug ilang opisina.',
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  for (final width in <double>[240, 320, 360, 390, 600]) {
    testWidgets('Redesigned services fit at ${width.toInt()}px', (
      tester,
    ) async {
      await pumpServicesDesign(tester, width: width, textScale: 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Featured cards have equal height in the two-column layout', (
    tester,
  ) async {
    await pumpServicesDesign(tester, width: 390, textScale: 1);

    final cards = find.byType(FeaturedServiceCard);
    expect(cards, findsNWidgets(2));
    expect(
      tester.getSize(cards.first).height,
      tester.getSize(cards.last).height,
    );
  });

  testWidgets('Featured cards stack for accessibility text sizing', (
    tester,
  ) async {
    await pumpServicesDesign(tester, width: 390, textScale: 2);

    final cards = find.byType(FeaturedServiceCard);
    final firstBottom = tester.getBottomLeft(cards.first).dy;
    final secondTop = tester.getTopLeft(cards.last).dy;
    expect(secondTop, greaterThan(firstBottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Featured cards and quick access tiles remain tappable', (
    tester,
  ) async {
    var featuredTapped = false;
    var quickAccessTapped = false;
    await pumpServicesDesign(
      tester,
      width: 390,
      textScale: 1,
      onFeaturedTap: () => featuredTapped = true,
      onQuickAccessTap: () => quickAccessTapped = true,
    );

    await tester.tap(find.text('Bayanihan Works'));
    await tester.tap(find.text('Community Calendar'));

    expect(featuredTapped, isTrue);
    expect(quickAccessTapped, isTrue);
  });

  testWidgets('Municipal information remains reachable on a short phone', (
    tester,
  ) async {
    await pumpServicesDesign(tester, width: 320, height: 480, textScale: 1);

    await tester.ensureVisible(find.text('Municipal Officials'));
    await tester.pumpAndSettle();

    expect(find.text('Municipal Officials'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact municipal officials card remains clear and tappable', (
    tester,
  ) async {
    var tapped = false;
    tester.view.physicalSize = const Size(240, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(18),
            child: HubMunicipalOfficialsCard(onTap: () => tapped = true),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Municipal Officials'));

    expect(tapped, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'QuickAccessRow renders all 4 icon buttons and responds to taps',
    (tester) async {
      var calendarTapped = false;
      var mapTapped = false;
      var exploreTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickAccessRow(
              items: [
                QuickAccessIconButton(
                  icon: Icons.calendar_month_rounded,
                  label: 'Calendar',
                  onTap: () => calendarTapped = true,
                ),
                QuickAccessIconButton(
                  icon: Icons.history_rounded,
                  label: 'Activity',
                  onTap: () {},
                ),
                QuickAccessIconButton(
                  icon: Icons.map_rounded,
                  label: 'Maps',
                  onTap: () => mapTapped = true,
                ),
                QuickAccessIconButton(
                  icon: Icons.explore_rounded,
                  label: 'Explore',
                  onTap: () => exploreTapped = true,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Calendar'), findsOneWidget);
      expect(find.text('Activity'), findsOneWidget);
      expect(find.text('Maps'), findsOneWidget);
      expect(find.text('Explore'), findsOneWidget);

      await tester.tap(find.text('Calendar'));
      await tester.tap(find.text('Maps'));
      await tester.tap(find.text('Explore'));

      expect(calendarTapped, isTrue);
      expect(mapTapped, isTrue);
      expect(exploreTapped, isTrue);
    },
  );
}
