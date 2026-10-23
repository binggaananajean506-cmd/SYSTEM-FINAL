import 'package:esugid/auth_service.dart';
import 'package:esugid/pages/concern_center_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<List<Map<String, String>>> loadCategories() async => [
    {'id': 'public_safety', 'name': 'Public Safety', 'sector': 'public'},
    {
      'id': 'private_school_education',
      'name': 'School & Education',
      'sector': 'private',
    },
  ];

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = User(
      uid: 'resident-1',
      email: 'resident@example.com',
      role: UserRole.resident,
      name: 'Resident',
      barangay: 'Cabcaban',
      barangayId: 'barili_cabcaban',
      accountStatus: AccountStatus.active,
      verificationStatus: VerificationStatus.verified,
    );
  });

  tearDown(() => AuthService.currentUser = null);

  testWidgets('Barangay continues to Details without an organization picker', (
    tester,
  ) async {
    var organizationLoads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ConcernCenterPage(
          formOnly: true,
          categoryLoader: loadCategories,
          organizationLoader: (_, _) async {
            organizationLoads++;
            return [];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Barangay').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Step 1 of 4'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Step 2 of 4'), findsOneWidget);
    expect(find.text('Concern Type'), findsOneWidget);
    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);
    expect(find.text('Incident Date'), findsOneWidget);
    expect(find.text('Specific Location'), findsOneWidget);
    expect(find.text('LOCATION'), findsNothing);
    expect(
      find.text(
        'Provide title, description, incident date, location, and photos',
      ),
      findsNothing,
    );
    expect(find.text('Send To'), findsNothing);
    expect(find.text('Select barangay'), findsNothing);
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    expect(find.text('Public Safety').last, findsOneWidget);
    expect(find.text('School & Education'), findsNothing);
    await tester.tap(find.text('Public Safety').last);
    await tester.pumpAndSettle();
    expect(find.text('Select Organization'), findsNothing);
    expect(organizationLoads, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Public Organization requires a confirmed active recipient', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ConcernCenterPage(
          formOnly: true,
          categoryLoader: loadCategories,
          organizationLoader: (category, sector) async {
            expect(category, 'public_safety');
            expect(sector, 'public');
            return [
              {'id': 'pnp', 'name': 'PNP'},
              {'id': 'bfp', 'name': 'BFP'},
            ];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Organization').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Public Agency').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Public Agency').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Step 2 of 4'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    expect(find.text('School & Education'), findsNothing);
    await tester.tap(find.text('Public Safety').last);
    await tester.pumpAndSettle();
    expect(find.text('Select Organization'), findsWidgets);
    expect(find.text('Where should this concern go?'), findsOneWidget);
    expect(find.text('PNP'), findsOneWidget);
    expect(find.text('BFP'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Confirm'))
          .onPressed,
      isNull,
    );

    await tester.tap(find.text('PNP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('Send To'), findsOneWidget);
    expect(find.text('PNP'), findsOneWidget);

    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BFP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('BFP'), findsOneWidget);
    expect(find.text('PNP'), findsNothing);

    await tester.enterText(find.byType(TextField).at(0), 'Broken streetlight');
    await tester.enterText(
      find.byType(TextField).at(1),
      'The streetlight beside the school has been broken for a week.',
    );
    await tester.enterText(
      find.byType(TextField).at(2),
      'Near the school gate',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Step 3 of 4'), findsOneWidget);
    await tester.tap(find.text('Private Report'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review Concern'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Step 4 of 4'), findsOneWidget);
    expect(find.text('BFP'), findsWidgets);
    expect(find.text('Public Safety'), findsWidgets);
    expect(find.text('Broken streetlight'), findsWidgets);
    expect(find.text('Near the school gate'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Private sector uses private types and handles no active account',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ConcernCenterPage(
            formOnly: true,
            categoryLoader: loadCategories,
            organizationLoader: (category, sector) async {
              expect(category, 'private_school_education');
              expect(sector, 'private');
              return [];
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Organization').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Private Organization').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Private Organization').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      expect(find.text('Public Safety'), findsNothing);
      await tester.tap(find.text('School & Education').last);
      await tester.pumpAndSettle();
      expect(find.text('No Organization Available'), findsOneWidget);
      expect(
        find.textContaining('no active organization available'),
        findsOneWidget,
      );
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Select Organization'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Step 2 of 4'), findsOneWidget);
      expect(
        find.text('Select an active organization before continuing.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Private Organization lists matching active accounts', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ConcernCenterPage(
          formOnly: true,
          categoryLoader: loadCategories,
          organizationLoader: (category, sector) async {
            expect(category, 'private_school_education');
            expect(sector, 'private');
            return [
              {'id': 'lyceum', 'name': 'Lyceum'},
              {'id': 'sta-ana', 'name': 'Sta. Ana Academy'},
            ];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Organization').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Private Organization').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Private Organization').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('School & Education').last);
    await tester.pumpAndSettle();
    expect(find.text('Lyceum'), findsOneWidget);
    expect(find.text('Sta. Ana Academy'), findsOneWidget);
    expect(find.text('PNP'), findsNothing);
    await tester.tap(find.text('Sta. Ana Academy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('Sta. Ana Academy'), findsOneWidget);
    expect(find.text('Send To'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('LGU Department keeps the public concern-type route', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ConcernCenterPage(
          formOnly: true,
          categoryLoader: loadCategories,
          organizationLoader: (category, sector) async {
            expect(category, 'public_safety');
            expect(sector, 'public');
            return [
              {'id': 'lgu-public-safety', 'name': 'LGU Public Safety Office'},
            ];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('LGU Department'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Step 2 of 4'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    expect(find.text('School & Education'), findsNothing);
    await tester.tap(find.text('Public Safety').last);
    await tester.pumpAndSettle();
    expect(find.text('LGU Public Safety Office'), findsOneWidget);
    await tester.tap(find.text('LGU Public Safety Office'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('LGU Public Safety Office'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
