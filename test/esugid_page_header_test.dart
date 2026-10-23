import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:esugid/widgets/esugid_page_header.dart';
import 'package:esugid/app/theme/esugid_clay_theme.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('green header keeps light system icons in $brightness', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildESugidClayTheme(brightness),
          home: MediaQuery(
            data: const MediaQueryData(padding: EdgeInsets.only(top: 24)),
            child: AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle.dark,
              child: Scaffold(
                body: CustomScrollView(
                  controller: scrollController,
                  slivers: const [
                    ESugidSliverPageHeader(title: 'My Barangay'),
                    SliverToBoxAdapter(child: SizedBox(height: 1200)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final offset in [0.0, 300.0]) {
        scrollController.jumpTo(offset);
        await tester.pumpAndSettle();
        final style = tester.binding.renderViews.single.debugLayer!
            .find<SystemUiOverlayStyle>(const Offset(195, 12));
        expect(style?.statusBarIconBrightness, Brightness.light);
        expect(style?.statusBarBrightness, Brightness.dark);
        expect(style?.statusBarColor, Colors.transparent);
      }
      expect(tester.takeException(), isNull);
    });

    for (final override in [false, true]) {
      testWidgets(
        'header follows page canvas in $brightness, override $override',
        (tester) async {
          final theme = buildESugidClayTheme(brightness);
          final color = override
              ? theme.colorScheme.surfaceContainerHigh
              : theme.scaffoldBackgroundColor;
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: Scaffold(
                backgroundColor: override ? color : null,
                body: const Column(
                  children: [ESugidPageHeader(title: 'Community Updates')],
                ),
              ),
            ),
          );
          final container = tester.widget<Container>(
            find.descendant(
              of: find.byType(ESugidBodyCrown),
              matching: find.byType(Container),
            ),
          );
          expect((container.decoration! as BoxDecoration).color, color);
          expect(tester.takeException(), isNull);
        },
      );
    }
    testWidgets('Services curved edge matches its body in $brightness', (
      tester,
    ) async {
      final colors = brightness == Brightness.dark
          ? ESugidColors.dark
          : ESugidColors.light;
      final bodyColor = brightness == Brightness.dark
          ? colors.disabledBackground
          : colors.surfaceAlt;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildESugidClayTheme(brightness),
          home: Scaffold(
            backgroundColor: bodyColor,
            body: CustomScrollView(
              slivers: [
                ESugidSliverPageHeader(
                  title: 'Barili Services',
                  bodyColor: brightness == Brightness.dark ? bodyColor : null,
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 900)),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final crownContainer = find.descendant(
        of: find.byType(ESugidBodyCrown),
        matching: find.byType(Container),
      );
      final decoration =
          tester.widget<Container>(crownContainer).decoration! as BoxDecoration;
      expect(decoration.color, bodyColor);
      expect(tester.takeException(), isNull);
    });
  }

  Widget buildHeader({required double width, double textScale = 1}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 800),
          padding: const EdgeInsets.only(top: 24),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: SizedBox(
            width: width,
            child: const ESugidPageHeader(
              title: 'Community Services and Information',
              subtitle: 'Everything you need in your community.',
              icon: Icons.grid_view_rounded,
              showBackButton: true,
            ),
          ),
        ),
      ),
    );
  }

  for (final width in <double>[240, 320, 390, 600]) {
    testWidgets('page header does not overflow at ${width.toInt()}px', (
      tester,
    ) async {
      await tester.pumpWidget(buildHeader(width: width));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Community Services and Information'), findsOneWidget);
    });
  }

  testWidgets('page header supports enlarged accessibility text', (
    tester,
  ) async {
    await tester.pumpWidget(buildHeader(width: 320, textScale: 2));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('page body owns the rounded leading edge', (tester) async {
    await tester.pumpWidget(buildHeader(width: 390));

    expect(esugidHeaderBorderRadius, BorderRadius.zero);
    expect(find.byType(ESugidBodyCrown), findsOneWidget);
    expect(
      tester.getSize(find.byType(ESugidBodyCrown)).height,
      esugidBodyCrownHeight,
    );
  });

  testWidgets('sliver header retains the page title after collapse', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              ESugidSliverPageHeader(
                sectionLabel: 'Services',
                title: 'Citizen Helpdesk',
                subtitle: 'Create and track requests.',
                icon: Icons.support_agent_rounded,
                showBackButton: true,
              ),
              SliverToBoxAdapter(child: SizedBox(height: 1200)),
            ],
          ),
        ),
      ),
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.text('Citizen Helpdesk'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Citizen Helpdesk')).dy, lessThan(100));
    expect(tester.takeException(), isNull);
  });

  testWidgets('sliver header supports enlarged accessibility text', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(320, 800),
            padding: EdgeInsets.only(top: 24),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: CustomScrollView(
              slivers: [
                ESugidSliverPageHeader(
                  sectionLabel: 'Community Services',
                  title: 'Citizen Helpdesk and Information',
                  subtitle:
                      'Create a ticket and track local government replies.',
                  icon: Icons.support_agent_rounded,
                  showBackButton: true,
                ),
                SliverToBoxAdapter(child: SizedBox(height: 900)),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('floating tabs switch selection without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DefaultTabController(
          length: 2,
          child: Scaffold(
            body: Column(
              children: [
                ESugidFloatingTabBar(
                  tabs: [
                    Tab(text: 'Active Alerts'),
                    Tab(text: 'Emergency Hotlines'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      Text('Alerts content'),
                      Text('Hotlines content'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Emergency Hotlines'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Hotlines content'), findsOneWidget);
  });

  testWidgets(
    'sliver header with back button and trailing actions does not overflow at 360px',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 800),
              padding: EdgeInsets.only(top: 24),
            ),
            child: Scaffold(
              body: CustomScrollView(
                slivers: [
                  ESugidSliverPageHeader(
                    sectionLabel: 'Local Services',
                    title: 'Local Market',
                    subtitle: "Experience Barili's finest produce.",
                    icon: Icons.storefront_rounded,
                    showBackButton: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.mail),
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.inventory),
                        ),
                      ],
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 500)),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Local Market'), findsOneWidget);
      expect(find.text("Experience Barili's finest produce."), findsOneWidget);
      // Suppresses redundant storefront icon when back button and trailing actions are present
      expect(find.byIcon(Icons.storefront_rounded), findsNothing);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    },
  );
}
