import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:esugid/models/emergency_agency.dart';
import 'package:esugid/pages/agency_details_page.dart';
import 'package:esugid/pages/emergency_hotlines_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void setupLargeTestViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(500, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget wrapWithScaffold(Widget child) {
    return MaterialApp(
      home: child,
    );
  }

  group('Emergency Agency Models & Verified Data', () {
    test('contains verified agencies with correct official logos', () {
      final agencies = EmergencyAgency.verifiedAgencies;
      expect(agencies.length, 6);

      final pnp = agencies.firstWhere((a) => a.id == 'pnp');
      expect(pnp.name, contains('Police'));
      expect(pnp.logoAsset, 'assets/images/resident_dashboard/pnp.png');
      expect(pnp.contactNumbers.length, greaterThanOrEqualTo(2));
      expect(pnp.officialPageUrl, 'https://www.facebook.com/BariliMPS');

      final bfp = agencies.firstWhere((a) => a.id == 'bfp');
      expect(bfp.name, contains('Fire'));
      expect(bfp.logoAsset, 'assets/images/resident_dashboard/bfp.png');
      expect(bfp.contactNumbers.length, greaterThanOrEqualTo(2));
      expect(bfp.officialPageUrl, 'https://www.facebook.com/barilifirestation');

      final mdrrmo = agencies.firstWhere((a) => a.id == 'mdrrmo');
      expect(mdrrmo.name, contains('MDRRMO'));
      expect(mdrrmo.logoAsset, 'assets/images/resident_dashboard/mdrrmo.png');
      expect(mdrrmo.contactNumbers.length, greaterThanOrEqualTo(3));
      expect(
        mdrrmo.officialPageUrl,
        'https://www.facebook.com/profile.php?id=100072055826084',
      );

      final rhu = agencies.firstWhere((a) => a.id == 'rhu');
      expect(rhu.name, contains('Primary Care Facility / RHU'));
      expect(rhu.primaryNumber?.number, '(032) 517-3472');
      expect(rhu.logoAsset, 'assets/images/resident_dashboard/rhu_logo.png');
      expect(rhu.officialPageUrl, 'https://www.facebook.com/barili.rhu');

      final infirmary = agencies.firstWhere((a) => a.id == 'infirmary');
      expect(infirmary.name, contains('Marlon F. Garcia Infirmary'));
      expect(infirmary.primaryNumber?.number, '0970-558-0536');
      expect(
        infirmary.logoAsset,
        'assets/images/resident_dashboard/infirmary_logo.png',
      );
      expect(
        infirmary.officialPageUrl,
        'https://www.facebook.com/profile.php?id=100092650336610',
      );

      expect(agencies.any((a) => a.id == 'district_hospital'), isFalse);

      final e911 = agencies.firstWhere((a) => a.id == '911');
      expect(e911.isUrgent911, isTrue);
      expect(e911.primaryNumber?.number, '911');
    });
  });

  group('EmergencyHotlinesPage UI Tests', () {
    testWidgets('renders all 6 verified agency cards without error', (tester) async {
      setupLargeTestViewport(tester);
      await tester.pumpWidget(wrapWithScaffold(const EmergencyHotlinesPage()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Emergency Hotlines'), findsOneWidget);

      // Verify agency names exist in the list
      expect(find.textContaining('911'), findsWidgets);
      expect(find.text('Barili MDRRMO / Rescue'), findsOneWidget);
      expect(find.text('Barili Fire Station (BFP)'), findsOneWidget);
      expect(find.text('Barili Municipal Police Station (PNP)'), findsOneWidget);
      expect(find.text('Barili Primary Care Facility / RHU'), findsOneWidget);
      expect(find.text('Marlon F. Garcia Infirmary – Barili'), findsOneWidget);
      expect(find.text('Barili District Hospital'), findsNothing);

      // Verify Call 911 button is present
      expect(find.text('Call 911'), findsOneWidget);

      // Verify View Details buttons are present
      expect(find.text('View Details'), findsNWidgets(6));
    });

    testWidgets('tapping View Details on MDRRMO navigates to AgencyDetailsPage', (
      tester,
    ) async {
      setupLargeTestViewport(tester);
      await tester.pumpWidget(wrapWithScaffold(const EmergencyHotlinesPage()));
      await tester.pumpAndSettle();

      // Find View Details for MDRRMO
      final viewDetailsButtons = find.text('View Details');
      // Tapping the second one (MDRRMO)
      await tester.tap(viewDetailsButtons.at(1));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Emergency Contact Numbers'), findsOneWidget);
      expect(find.text('0918-637-6365'), findsOneWidget);
      expect(find.text('0927-537-3136'), findsOneWidget);
      expect(find.text('(032) 517-0950'), findsOneWidget);
      expect(find.text('View Location'), findsOneWidget);
      expect(find.text('Visit Official Page'), findsOneWidget);
      expect(find.textContaining('Verified & updated:'), findsNothing);
    });

    testWidgets('tapping Call on MDRRMO opens modal bottom sheet with lines', (
      tester,
    ) async {
      setupLargeTestViewport(tester);
      await tester.pumpWidget(wrapWithScaffold(const EmergencyHotlinesPage()));
      await tester.pumpAndSettle();

      // Tap 'Call' button on MDRRMO (first 'Call' button on page; 911 is 'Call 911')
      final callButtons = find.text('Call');
      await tester.tap(callButtons.first);
      await tester.pumpAndSettle();

      expect(find.text('Select a contact line to call'), findsOneWidget);
      expect(find.text('Barili MDRRMO / Rescue Mobile'), findsOneWidget);
      expect(find.text('Barili MDRRMO Office Landline'), findsOneWidget);
      expect(find.text('Alternative Mobile (Globe / TM)'), findsOneWidget);
    });

    testWidgets('official agency logos are rendered with BoxFit.contain', (
      tester,
    ) async {
      setupLargeTestViewport(tester);
      await tester.pumpWidget(wrapWithScaffold(const EmergencyHotlinesPage()));
      await tester.pumpAndSettle();

      final images = tester.widgetList<Image>(find.byType(Image));
      final assetNames = images.map((img) {
        if (img.image is AssetImage) {
          return (img.image as AssetImage).assetName;
        }
        return '';
      }).toList();

      expect(assetNames, contains('assets/images/resident_dashboard/mdrrmo.png'));
      expect(assetNames, contains('assets/images/resident_dashboard/bfp.png'));
      expect(assetNames, contains('assets/images/resident_dashboard/pnp.png'));
      expect(assetNames, contains('assets/images/resident_dashboard/rhu_logo.png'));
      expect(assetNames, contains('assets/images/resident_dashboard/infirmary_logo.png'));

      for (final img in images) {
        expect(img.fit, BoxFit.contain);
      }
    });
  });

  group('AgencyDetailsPage UI Tests', () {
    testWidgets('hides empty fields when optional attributes are omitted', (
      tester,
    ) async {
      setupLargeTestViewport(tester);
      const minimalAgency = EmergencyAgency(
        id: 'test_agency',
        name: 'Test Agency',
        shortPurpose: 'Emergency testing response',
        category: 'Testing Category',
        contactNumbers: [
          EmergencyContactNumber(label: 'Direct Line', number: '12345'),
        ],
        // address is null
        // officialPageUrl is null
      );

      await tester.pumpWidget(
        wrapWithScaffold(const AgencyDetailsPage(agency: minimalAgency)),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Test Agency'), findsWidgets);
      expect(find.text('Direct Line'), findsOneWidget);
      expect(find.text('12345'), findsOneWidget);

      // Ensure empty fields are completely hidden rather than showing 'No Data'
      expect(find.text('No Data'), findsNothing);
      expect(find.text('View Location'), findsNothing);
      expect(find.text('Visit Official Page'), findsNothing);
    });

    testWidgets('displays Call buttons for each individual grouped number', (
      tester,
    ) async {
      setupLargeTestViewport(tester);
      final pnp = EmergencyAgency.verifiedAgencies.firstWhere(
        (a) => a.id == 'pnp',
      );

      await tester.pumpWidget(
        wrapWithScaffold(AgencyDetailsPage(agency: pnp)),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Barili Municipal Police Station (PNP)'), findsWidgets);
      expect(find.text('Police Hotline Mobile'), findsOneWidget);
      expect(find.text('Station Landline'), findsOneWidget);

      // Verify each phone number row has its own Call button
      expect(find.text('Call'), findsNWidgets(2));
      expect(find.text('View Location'), findsOneWidget);
      expect(find.text('Visit Official Page'), findsOneWidget);
    });
  });
}
