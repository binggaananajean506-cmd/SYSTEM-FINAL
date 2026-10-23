import 'package:esugid/app/theme/esugid_clay_theme.dart';
import 'package:esugid/auth_service.dart';
import 'package:esugid/features/app_assistant/app_assistant_dock.dart';
import 'package:esugid/features/app_assistant/app_assistant_launcher.dart';
import 'package:esugid/features/home/presentation/authenticated_bottom_navigation.dart';
import 'package:esugid/widgets/esugid_page_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const pageKey = ValueKey('page-viewport');
const targetKey = ValueKey('assistant-drag-target');
const iconKey = ValueKey('assistant-floating-icon');

final resident = User(
  uid: 'dock-resident',
  email: 'resident@example.com',
  role: UserRole.resident,
  name: 'Resident',
);

Widget shell({
  Brightness brightness = Brightness.dark,
  double scale = 1,
  bool visible = true,
  bool reserveRight = false,
  Widget? launcher,
}) {
  return MaterialApp(
    theme: buildESugidClayTheme(brightness),
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: Builder(
          builder: (context) {
            final inset = authenticatedBottomNavigationReservedHeight(context);
            return Scaffold(
              body: Stack(
                children: [
                  AppAssistantDock(
                    bottomInset: inset,
                    visible: visible,
                    reserveRightCorner: reserveRight,
                    launcher:
                        launcher ??
                        AppAssistantLauncher(
                          user: resident,
                          onNavigate: (_) {},
                        ),
                    child: SizedBox.expand(
                      key: pageKey,
                      child: CustomScrollView(
                        slivers: [
                          const ESugidSliverPageHeader(
                            title: 'Community Updates',
                          ),
                          SliverList.builder(
                            itemCount: 12,
                            itemBuilder: (_, i) => Card(
                              child: SizedBox(
                                height: 100,
                                child: Center(child: Text('Update $i')),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AuthenticatedBottomNavigation(
                    selectedIndex: 1,
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
}

void viewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets(
    'dock respects display cutouts and preserves scroll when hidden',
    (tester) async {
      viewport(tester, const Size(844, 390));
      tester.view.viewPadding = const FakeViewPadding(
        left: 30,
        right: 20,
        top: 24,
        bottom: 20,
      );
      addTearDown(tester.view.resetViewPadding);
      await tester.pumpWidget(shell());
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(targetKey)).right, 844 - 20 - 12);
      await tester.drag(find.byKey(targetKey), const Offset(-1000, -600));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(targetKey)).left, 30 + 12);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pumpAndSettle();
      final scroll = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      final offset = scroll.position.pixels;
      await tester.pumpWidget(shell(visible: false));
      await tester.pumpAndSettle();
      expect(
        identical(
          tester.state<ScrollableState>(find.byType(Scrollable).first),
          scroll,
        ),
        isTrue,
      );
      expect(scroll.position.pixels, offset);
      expect(find.byKey(targetKey), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  for (final brightness in Brightness.values) {
    for (final size in [
      const Size(320, 480),
      const Size(390, 844),
      const Size(600, 900),
      const Size(844, 390),
    ]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'floating logo preserves full page and clears navigation: $brightness $size text $scale',
          (tester) async {
            viewport(tester, size);
            await tester.pumpWidget(
              shell(brightness: brightness, scale: scale),
            );
            await tester.pumpAndSettle();
            final logo = find.descendant(
              of: find.byType(AppAssistantLauncher),
              matching: find.byType(Image),
            );
            expect(logo, findsOneWidget);
            expect(
              (tester.widget<Image>(logo).image as AssetImage).assetName,
              'assets/images/resident_dashboard/pinakafinal_backup.png',
            );
            expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);
            expect(find.text('AI'), findsNothing);
            final target = tester.getRect(find.byKey(targetKey));
            final page = tester.getRect(find.byKey(pageKey));
            final inset = authenticatedBottomNavigationReservedHeight(
              tester.element(find.byType(AppAssistantDock)),
            );
            expect(page, Offset.zero & size);
            expect(page.overlaps(target), isTrue);
            expect(target.bottom, lessThanOrEqualTo(size.height - inset));
            expect(size.width - target.right, AppAssistantDock.edgeSpacing);
            expect(tester.getSize(find.byKey(iconKey)), const Size(56, 56));
            await tester.scrollUntilVisible(
              find.text('Update 11'),
              220,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.pumpAndSettle();
            final last = tester.getRect(find.text('Update 11'));
            expect(last.bottom, lessThanOrEqualTo(page.bottom));
            expect(last.overlaps(target), isFalse);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    testWidgets('drag clamps and docks without triggering a tap: $brightness', (
      tester,
    ) async {
      viewport(tester, const Size(390, 844));
      var taps = 0;
      await tester.pumpWidget(
        shell(
          brightness: brightness,
          launcher: InkWell(
            onTap: () => taps++,
            child: const Icon(Icons.auto_awesome_rounded),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final initial = tester.getRect(find.byKey(targetKey));
      final gesture = await tester.startGesture(initial.center);
      await gesture.moveBy(const Offset(-700, -1200));
      await tester.pump();
      final dragging = tester.getRect(find.byKey(targetKey));
      expect(dragging.left, greaterThanOrEqualTo(12));
      expect(dragging.top, greaterThanOrEqualTo(8));
      await gesture.up();
      await tester.pumpAndSettle();
      final docked = tester.getRect(find.byKey(targetKey));
      expect(docked.left, 12);
      expect(docked.top, 8);
      expect(taps, 0);
      await tester.tap(find.byKey(targetKey));
      await tester.pump();
      expect(taps, 1);
      await tester.drag(find.byKey(targetKey), const Offset(800, 900));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(targetKey)), initial);
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'assistant opens on tap and minimizes after dismissal: $brightness',
      (tester) async {
        viewport(tester, const Size(390, 844));
        await tester.pumpWidget(shell(brightness: brightness));
        await tester.pumpAndSettle();
        expect(find.byType(AppAssistantSheet), findsNothing);
        final opacity = find.descendant(
          of: find.byType(AppAssistantLauncher),
          matching: find.byType(AnimatedOpacity),
        );
        expect(tester.widget<AnimatedOpacity>(opacity).opacity, .96);
        await tester.tap(find.byKey(targetKey));
        await tester.pumpAndSettle();
        expect(find.byType(AppAssistantSheet), findsOneWidget);
        expect(tester.getSize(find.byKey(iconKey)), const Size(60, 60));
        final route = ModalRoute.of(
          tester.element(find.byType(AppAssistantSheet)),
        )!;
        expect(
          route.barrierColor,
          ESugidColors.dark.shadow.withValues(alpha: .58),
        );
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        expect(find.byType(AppAssistantSheet), findsNothing);
        expect(tester.getSize(find.byKey(iconKey)), const Size(56, 56));
        expect(tester.widget<AnimatedOpacity>(opacity).opacity, .96);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'reserved action corner, keyboard hiding and rotation stay safe',
    (tester) async {
      viewport(tester, const Size(390, 844));
      await tester.pumpWidget(shell(reserveRight: true));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(targetKey)).left, 12);
      await tester.drag(find.byKey(targetKey), const Offset(500, -200));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(targetKey)).left, 12);
      final oldHeight = tester.getSize(find.byKey(pageKey)).height;
      await tester.pumpWidget(shell(visible: false));
      await tester.pumpAndSettle();
      expect(find.byKey(targetKey), findsNothing);
      expect(tester.getSize(find.byKey(pageKey)).height, oldHeight);
      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpWidget(shell());
      await tester.pumpAndSettle();
      final target = tester.getRect(find.byKey(targetKey));
      expect(target.right, lessThanOrEqualTo(832));
      expect(
        target.bottom,
        lessThanOrEqualTo(
          390 -
              authenticatedBottomNavigationReservedHeight(
                tester.element(find.byType(AppAssistantDock)),
              ),
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
