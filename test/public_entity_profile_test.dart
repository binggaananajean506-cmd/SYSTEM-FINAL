import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:esugid/community_service.dart';
import 'package:esugid/models/public_civic_entity.dart';
import 'package:esugid/models/private_organization.dart';
import 'package:esugid/pages/public_entity_profile_page.dart';
import 'package:esugid/widgets/community_post_widgets.dart';

void main() {
  group('PublicCivicEntity & Profile Tests', () {
    test('PublicCivicEntity.municipalDepartments has all core Barili departments', () {
      final depts = PublicCivicEntity.municipalDepartments;
      expect(depts.isNotEmpty, isTrue);
      expect(depts.any((d) => d.id == 'mdrrmo'), isTrue);
      expect(depts.any((d) => d.id == 'rhu'), isTrue);
      expect(depts.any((d) => d.id == 'engineering'), isTrue);
      expect(depts.any((d) => d.id == 'pnp'), isTrue);
      expect(depts.any((d) => d.id == 'bfp'), isTrue);
    });

    test('PublicCivicEntity.forBarangay builds valid entity for any Barili barangay', () {
      final cabcaban = PublicCivicEntity.forBarangay('Cabcaban');
      expect(cabcaban.name, 'Barangay Cabcaban');
      expect(cabcaban.badgeLabel, 'OFFICIAL BARANGAY GOVERNMENT UNIT');
      expect(cabcaban.type, CivicEntityType.barangay);

      final poblacion = PublicCivicEntity.forBarangay('Poblacion');
      expect(poblacion.name, 'Barangay Poblacion');
    });

    test('PublicCivicEntity.findByNameOrId resolves departments and barangays accurately', () {
      final mdrrmo = PublicCivicEntity.findByNameOrId('Barili MDRRMO / Rescue');
      expect(mdrrmo, isNotNull);
      expect(mdrrmo!.id, 'mdrrmo');

      final bgy = PublicCivicEntity.findByNameOrId('Cabcaban');
      expect(bgy, isNotNull);
      expect(bgy!.name, 'Barangay Cabcaban');

      // Specifically verify Barangay Vito queries NEVER return MDRRMO
      final vito1 = PublicCivicEntity.findByNameOrId('Barangay Vito');
      expect(vito1, isNotNull);
      expect(vito1!.name, 'Barangay Vito');
      expect(vito1.type, CivicEntityType.barangay);

      final vito2 = PublicCivicEntity.findByNameOrId('Vito');
      expect(vito2, isNotNull);
      expect(vito2!.name, 'Barangay Vito');

      final vito3 = PublicCivicEntity.findByNameOrId('Brgy Vito');
      expect(vito3, isNotNull);
      expect(vito3!.name, 'Barangay Vito');

      final vito4 = PublicCivicEntity.findByNameOrId('Brgy. Vito');
      expect(vito4, isNotNull);
      expect(vito4!.name, 'Barangay Vito');
    });

    testWidgets('PublicEntityProfilePage displays hero identity, Facebook badge, and map button for department', (tester) async {
      final mdrrmo = PublicCivicEntity.municipalDepartments.first;

      await tester.pumpWidget(
        MaterialApp(
          home: PublicEntityProfilePage(entity: mdrrmo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Barili MDRRMO / Rescue'), findsOneWidget);
      expect(find.byIcon(Icons.verified), findsOneWidget);
      expect(find.text('Open in Google Maps'), findsOneWidget);
      expect(find.byIcon(Icons.share_rounded), findsOneWidget);
    });

    testWidgets('PublicEntityProfilePage displays Facebook verified badge and clean profile for barangay', (tester) async {
      final cabcaban = PublicCivicEntity.forBarangay('Cabcaban');

      await tester.pumpWidget(
        MaterialApp(
          home: PublicEntityProfilePage(entity: cabcaban),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Barangay Cabcaban'), findsOneWidget);
      expect(find.byIcon(Icons.verified), findsOneWidget);
      expect(find.text('Open in Google Maps'), findsOneWidget);
      expect(find.textContaining('serves and supports all residents'), findsOneWidget);
    });

    testWidgets('Barangay Vito profile renders with basic words and Facebook verified badge', (tester) async {
      final vito = PublicCivicEntity.forBarangay('Vito');

      await tester.pumpWidget(
        MaterialApp(
          home: PublicEntityProfilePage(entity: vito),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Barangay Vito'), findsOneWidget);
      expect(find.byIcon(Icons.verified), findsOneWidget);
      expect(find.text('Open in Google Maps'), findsOneWidget);
      expect(find.textContaining('Barangay Vito serves and supports all residents'), findsOneWidget);
    });

    testWidgets('Clicking Barangay Vito publisher routes to Barangay Vito and NEVER MDRRMO', (tester) async {
      final post = CommunityPost(
        id: 'post_vito_1',
        title: 'Barangay Vito Community Meeting',
        content: 'Agenda on upcoming barangay fiesta and clean up.',
        authorName: 'Barangay Vito',
        authorId: 'vito_admin_1',
        authorRole: 'barangay',
        authorBarangay: 'Vito',
        authorOrganizationName: 'Barangay Vito',
        targetAudience: 'barangay',
        targetBarangay: 'Vito',
        visibility: 'public',
        targetBarangays: const ['Vito'],
        createdAt: DateTime.now(),
        status: 'approved',
        tag: 'OFFICIAL',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ModernPostCard.openPublisherProfile(
                  context,
                  post,
                  'Barangay Vito',
                ),
                child: const Text('Open Vito Profile'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Vito Profile'));
      await tester.pumpAndSettle();

      // Verify that Barangay Vito profile was opened
      expect(find.text('Barangay Vito'), findsOneWidget);
      expect(find.byIcon(Icons.verified), findsOneWidget);

      // Verify it is NOT Barili MDRRMO
      expect(find.text('Barili MDRRMO / Rescue'), findsNothing);
    });

    test('Department of Agriculture and LGU IT Department resolve correctly and never default to Mayor', () {
      final agri = PublicCivicEntity.findByNameOrId('Department of agriculture');
      expect(agri, isNotNull);
      expect(agri!.id, 'agriculture');
      expect(agri.name, contains('Agriculture'));
      expect(agri.name, isNot(contains('Mayor')));

      final it = PublicCivicEntity.findByNameOrId('LGU It deapartment');
      expect(it, isNotNull);
      expect(it!.id, 'it_department');
      expect(it.name, contains('IT Department'));
      expect(it.name, isNot(contains('Mayor')));

      final dynamicDept = PublicCivicEntity.forDepartment('Barili Water District');
      expect(dynamicDept.name, 'Barili Water District');
      expect(dynamicDept.type, CivicEntityType.department);
      expect(dynamicDept.name, isNot(contains('Mayor')));
    });

    testWidgets('Clicking Department of Agriculture routes to Agriculture and NOT Mayor', (tester) async {
      final post = CommunityPost(
        id: 'post_agri_1',
        title: 'Fertilizer Distribution Notice',
        content: 'Distribution of certified rice seeds and fertilizer assistance.',
        authorName: 'Department of agriculture',
        authorId: 'agri_staff_1',
        authorRole: 'lgu',
        authorBarangay: 'Poblacion',
        authorOrganizationName: 'Department of agriculture',
        publisherEntityName: 'Department of agriculture',
        targetAudience: 'All Residents',
        targetBarangay: 'All Barangays',
        visibility: 'public',
        targetBarangays: const [],
        createdAt: DateTime.now(),
        status: 'approved',
        tag: 'OFFICIAL',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ModernPostCard.openPublisherProfile(
                  context,
                  post,
                  'Department of agriculture',
                ),
                child: const Text('Open Agri Profile'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Agri Profile'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Agriculture'), findsWidgets);
      expect(find.text('Office of the Municipal Mayor'), findsNothing);
    });

    testWidgets('Clicking LGU It deapartment routes to IT Department and NOT Mayor', (tester) async {
      final post = CommunityPost(
        id: 'post_it_1',
        title: 'System Upgrade Advisory',
        content: 'Server maintenance scheduled tonight.',
        authorName: 'LGU It deapartment',
        authorId: 'it_staff_1',
        authorRole: 'lgu',
        authorBarangay: 'Poblacion',
        authorOrganizationName: 'LGU It deapartment',
        publisherEntityName: 'LGU It deapartment',
        targetAudience: 'All Residents',
        targetBarangay: 'All Barangays',
        visibility: 'public',
        targetBarangays: const [],
        createdAt: DateTime.now(),
        status: 'approved',
        tag: 'OFFICIAL',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ModernPostCard.openPublisherProfile(
                  context,
                  post,
                  'LGU It deapartment',
                ),
                child: const Text('Open IT Profile'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open IT Profile'));
      await tester.pumpAndSettle();

      expect(find.textContaining('IT Department'), findsWidgets);
      expect(find.text('Office of the Municipal Mayor'), findsNothing);
    });

    test('CTU resolves as a Public Organization and is excluded from PrivateOrganization', () {
      final ctu = PublicCivicEntity.findByNameOrId('CTU');
      expect(ctu, isNotNull);
      expect(ctu!.id, 'ctu');
      expect(ctu.name, 'CTU');
      expect(ctu.type, CivicEntityType.publicOrganization);
      expect(ctu.category, 'School & Education');
      expect(ctu.officialPageUrl, 'https://www.ctu.edu.ph');

      final ctuBarili = PublicCivicEntity.findByNameOrId('ctu barili');
      expect(ctuBarili, isNotNull);
      expect(ctuBarili!.id, 'ctu');

      final cebuTech = PublicCivicEntity.findByNameOrId('cebu technological university');
      expect(cebuTech, isNotNull);
      expect(cebuTech!.id, 'ctu');

      // Verify PrivateOrganization does NOT classify CTU as a private partner
      final privateCtu = PrivateOrganization.findByNameOrId('CTU');
      expect(privateCtu, isNull);
    });

    testWidgets('Clicking CTU routes to PublicEntityProfilePage and has NO followers', (tester) async {
      final post = CommunityPost(
        id: 'post_ctu_1',
        title: 'CTU Admission Test Announcement',
        content: 'Registration for freshmen admission test is now open.',
        authorName: 'CTU',
        authorId: 'ctu_admin_1',
        authorRole: 'organization',
        authorBarangay: 'Cagay',
        authorOrganizationName: 'CTU',
        publisherEntityName: 'CTU',
        targetAudience: 'All Residents',
        targetBarangay: 'All Barangays',
        visibility: 'public',
        targetBarangays: const [],
        createdAt: DateTime.now(),
        status: 'approved',
        tag: 'PARTNER',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ModernPostCard.openPublisherProfile(
                  context,
                  post,
                  'CTU',
                ),
                child: const Text('Open CTU Profile'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open CTU Profile'));
      await tester.pumpAndSettle();

      // Verify that CTU Public Entity Profile is opened (similar to LGU/Barangay)
      expect(find.byType(PublicEntityProfilePage), findsOneWidget);
      expect(find.text('Public Organization'), findsOneWidget);
      expect(find.text('CTU'), findsWidgets);
      expect(find.byIcon(Icons.verified), findsOneWidget);
      expect(find.text('Open in Google Maps'), findsOneWidget);
      expect(find.text('Official Portal'), findsNothing);

      // Verify ONLY private organizations have followers; CTU as a public org must NEVER have followers
      expect(find.textContaining('Followers'), findsNothing);
      expect(find.textContaining('Follow'), findsNothing);
      expect(find.text('BARILI PRIVATE PARTNER'), findsNothing);
      expect(find.text('Resident Profile'), findsNothing);
      expect(find.text('Bayanihan Works'), findsNothing);
    });
  });
}
