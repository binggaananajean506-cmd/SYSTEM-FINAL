import 'package:esugid/app/theme/esugid_clay_theme.dart';
import 'package:esugid/app/theme/semantic_colors.dart';
import 'package:esugid/auth_service.dart';
import 'package:esugid/features/bayanihan_messages/presentation/widgets/bayanihan_card_action.dart';
import 'package:esugid/marketplace_service.dart';
import 'package:esugid/pages/my_listings_page.dart';
import 'package:esugid/widgets/adaptive_action_content.dart';
import 'package:esugid/widgets/marketplace_seller_byline.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

double _contrast(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
}

Widget _app(Widget child, Brightness brightness, {double scale = 1}) =>
    MaterialApp(
      theme: buildESugidClayTheme(brightness),
      builder: (context, body) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: body!,
      ),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final brightness in Brightness.values) {
    for (final tone in BayanihanActionTone.values) {
      testWidgets(
        '$brightness $tone action text and icon contrast on its fill',
        (tester) async {
          await tester.pumpWidget(
            _app(
              BayanihanCardAction(
                label: 'View Conversation',
                icon: Icons.forum_rounded,
                tone: tone,
                onTap: () {},
              ),
              brightness,
            ),
          );
          final label = tester.widget<Text>(find.text('VIEW CONVERSATION'));
          final icon = tester.widget<Icon>(find.byIcon(Icons.forum_rounded));
          final boxes = tester.widgetList<Container>(
            find.descendant(
              of: find.byType(BayanihanCardAction),
              matching: find.byType(Container),
            ),
          );
          final fill = boxes
              .map((box) => box.decoration)
              .whereType<BoxDecoration>()
              .firstWhere((decoration) => decoration.gradient != null)
              .gradient!;
          for (final color in fill.colors) {
            expect(
              _contrast(label.style!.color!, color),
              greaterThanOrEqualTo(4.5),
            );
            expect(_contrast(icon.color!, color), greaterThanOrEqualTo(3));
          }
        },
      );
    }

    testWidgets(
      '$brightness conversation action wraps at large text without clipping',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          _app(
            SizedBox(
              width: 240,
              child: BayanihanCardAction(
                label: 'View Conversation',
                icon: Icons.forum_rounded,
                tone: BayanihanActionTone.info,
                onTap: () => taps++,
              ),
            ),
            brightness,
            scale: 2,
          ),
        );
        expect(tester.takeException(), isNull);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text('VIEW CONVERSATION'),
        );
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(
          tester.getSize(find.byType(BayanihanCardAction)).height,
          greaterThan(48),
        );
        await tester.tap(find.text('VIEW CONVERSATION'));
        expect(taps, 1);
      },
    );

    testWidgets(
      '$brightness owner action pair keeps complete labels on a compact phone',
      (tester) async {
        final colors = brightness == Brightness.dark
            ? ESugidColors.dark
            : ESugidColors.light;
        Widget button(String label, IconData icon) => Container(
          constraints: const BoxConstraints(minHeight: 48),
          child: AdaptiveActionLabel(
            label: label,
            icon: icon,
            style: TextStyle(color: colors.textPrimary, fontSize: 13),
          ),
        );
        await tester.pumpWidget(
          _app(
            SizedBox(
              width: 280,
              child: AdaptiveActionPair(
                primary: button('MANAGE', Icons.tune_rounded),
                secondary: button('MAKE AVAILABLE', Icons.refresh_rounded),
                secondaryFlex: 2,
              ),
            ),
            brightness,
            scale: 2,
          ),
        );
        expect(tester.takeException(), isNull);
        for (final label in ['MANAGE', 'MAKE AVAILABLE']) {
          expect(
            tester
                .renderObject<RenderParagraph>(find.text(label))
                .didExceedMaxLines,
            isFalse,
          );
        }
        expect(
          tester.getTopLeft(find.text('MAKE AVAILABLE')).dy,
          greaterThan(tester.getBottomLeft(find.text('MANAGE')).dy),
        );
      },
    );

    testWidgets(
      '$brightness long seller names wrap fully and keep the profile action',
      (tester) async {
        var profileTaps = 0;
        const byline = 'Offered by Ana Jean Atamosa Binggaan';
        for (final width in [240.0, 320.0, 600.0]) {
          await tester.pumpWidget(
            _app(
              SizedBox(
                width: width,
                child: MarketplaceSellerByline(
                  sellerName: 'Ana Jean Atamosa Binggaan',
                  age: 'Just now',
                  avatar: const SizedBox(width: 28, height: 28),
                  onSellerTap: () => profileTaps++,
                ),
              ),
              brightness,
              scale: 2,
            ),
          );
          expect(tester.takeException(), isNull);
          expect(
            tester
                .renderObject<RenderParagraph>(find.text(byline))
                .didExceedMaxLines,
            isFalse,
          );
          expect(
            tester.getTopRight(find.text('Just now')).dx,
            lessThanOrEqualTo(
              tester.getTopRight(find.byType(MarketplaceSellerByline)).dx,
            ),
          );
          await tester.tap(find.text(byline));
        }
        expect(profileTaps, 3);
      },
    );

    testWidgets(
      '$brightness My Listings renders usable owner actions at 360px',
      (tester) async {
        tester.view.physicalSize = const Size(360, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        AuthService.currentUser = User(
          uid: 'seller',
          email: 'seller@example.com',
          role: UserRole.resident,
          name: 'Ana',
        );
        addTearDown(() => AuthService.currentUser = null);
        final item = MarketplaceItem(
          id: 'tool',
          name: 'Garden Tool',
          price: '100',
          description: 'Local tool',
          imageUrl: '',
          sellerId: 'seller',
          sellerName: 'Ana',
          category: 'Tools',
          location: 'Barili',
          createdAt: DateTime.now(),
        );
        await tester.pumpWidget(
          _app(
            MyListingsPage(itemsStream: Stream.value([item])),
            brightness,
            scale: 1.3,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('MANAGE'), findsOneWidget);
        expect(find.text('MARK AS SOLD'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('MANAGE'));
        await tester.pumpAndSettle();
        expect(find.text('Manage "Garden Tool"'), findsOneWidget);
        expect(
          tester.widget<BottomSheet>(find.byType(BottomSheet)).showDragHandle,
          isFalse,
        );
        expect(find.text('Edit Listing'), findsOneWidget);
        expect(find.text('Delete Listing'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
