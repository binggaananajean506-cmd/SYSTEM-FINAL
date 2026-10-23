import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:esugid/models/private_organization.dart';
import 'package:esugid/services/private_organization_service.dart';
import 'package:esugid/community_service.dart';
import 'package:esugid/pages/discover_private_organizations_page.dart';
import 'package:esugid/pages/organization_profile_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PrivateOrganizationService.instance.init('test_resident_123');
  });

  group('PrivateOrganization & Service Unit Tests', () {
    test('Master list of approved organizations contains expected organizations', () {
      final orgs = PrivateOrganization.approvedOrganizations;
      expect(orgs.any((o) => o.name == 'LANDBANK'), isTrue);
      expect(orgs.any((o) => o.name == 'PLDT'), isTrue);
      expect(orgs.any((o) => o.name == 'Ste. Anne Academy'), isTrue);
      expect(orgs.any((o) => o.name == 'Cebu Pacific'), isTrue);
    });

    test('Follow and unfollow logic toggles state and persists', () async {
      final service = PrivateOrganizationService.instance;
      expect(service.isFollowed('landbank'), isFalse);

      final nowFollowed = await service.toggleFollow('landbank', userId: 'test_resident_123');
      expect(nowFollowed, isTrue);
      expect(service.isFollowed('landbank'), isTrue);
      expect(service.followedIds.contains('landbank'), isTrue);

      final nowUnfollowed = await service.toggleFollow('landbank', userId: 'test_resident_123');
      expect(nowUnfollowed, isFalse);
      expect(service.isFollowed('landbank'), isFalse);
      expect(service.followedIds.contains('landbank'), isFalse);
    });

    test('Feed filtering logic: public posts are always visible, private posts appear only if followed', () {
      final service = PrivateOrganizationService.instance;

      final publicPost = CommunityPost(
        id: 'pub_1',
        title: 'Municipal Notice',
        content: 'Town hall advisory',
        authorName: 'LGU IT DEPARTMENT',
        authorId: 'lgu_1',
        authorRole: 'lgu',
        authorBarangay: 'Poblacion',
        authorOrganizationName: '',
        targetAudience: 'All Residents',
        targetBarangay: 'All Barangays',
        visibility: 'public',
        targetBarangays: const [],
        createdAt: DateTime.now(),
        status: 'approved',
        tag: 'OFFICIAL',
      );

      final privateOrgPost = CommunityPost(
        id: 'pldt_1',
        title: 'Fiber Maintenance',
        content: 'Network maintenance',
        authorName: 'PLDT',
        authorId: 'pldt',
        authorRole: 'organization',
        authorBarangay: 'Barili',
        authorOrganizationName: 'PLDT',
        publisherEntityId: 'pldt',
        publisherEntityType: 'private_organization',
        targetAudience: 'All Residents',
        targetBarangay: 'All Barangays',
        visibility: 'public',
        targetBarangays: const [],
        createdAt: DateTime.now(),
        status: 'approved',
        tag: 'PARTNER',
      );

      // When no organizations are followed:
      final emptyFollowed = <String>{};
      expect(service.shouldShowPostInUpdates(publicPost, emptyFollowed), isTrue);
      expect(service.shouldShowPostInUpdates(privateOrgPost, emptyFollowed), isFalse);

      // When PLDT is followed:
      final followedPldt = <String>{'pldt'};
      expect(service.shouldShowPostInUpdates(publicPost, followedPldt), isTrue);
      expect(service.shouldShowPostInUpdates(privateOrgPost, followedPldt), isTrue);

      // When only Landbank is followed:
      final followedLandbank = <String>{'landbank'};
      expect(service.shouldShowPostInUpdates(publicPost, followedLandbank), isTrue);
      expect(service.shouldShowPostInUpdates(privateOrgPost, followedLandbank), isFalse);
    });

    test('Organization posts follow the directory: public sector always shows, private needs a follow', () {
      final service = PrivateOrganizationService.instance;
      CommunityPost orgPost(String orgId) => CommunityPost(
        id: 'post_$orgId',
        title: 'Service notice',
        content: 'Details',
        authorName: 'Staff',
        authorId: 'staff_$orgId',
        authorRole: 'organization',
        authorBarangay: '',
        authorOrganizationName: orgId,
        publisherEntityId: orgId,
        publisherEntityType: 'organization',
        targetAudience: 'All Residents',
        targetBarangay: 'All Barangays',
        visibility: 'public',
        targetBarangays: const [],
        createdAt: DateTime(2026, 10, 5),
        status: 'approved',
        tag: 'PARTNER',
      );
      final kawssco = orgPost('kawssco');
      final hospital = orgPost('district-hospital');

      // Until the directory loads, every organization post needs a follow.
      service.privateOrganizationIdsNotifier.value = null;
      expect(service.shouldShowPostInUpdates(hospital, const {}), isFalse);

      service.privateOrganizationIdsNotifier.value = {'kawssco'};
      addTearDown(() => service.privateOrganizationIdsNotifier.value = null);
      expect(service.shouldShowPostInUpdates(hospital, const {}), isTrue);
      expect(service.shouldShowPostInUpdates(kawssco, const {}), isFalse);
      expect(service.shouldShowPostInUpdates(kawssco, const {'kawssco'}), isTrue);
    });

    test('visiblePosts applies the current follows', () async {
      final service = PrivateOrganizationService.instance;
      final pldt = PrivateOrganization.approvedOrganizations.firstWhere(
        (o) => o.id == 'pldt',
      );
      final posts = [
        PrivateOrganizationUpdate(
          id: 'pldt_outage',
          organizationId: 'pldt',
          title: 'Fiber maintenance',
          content: 'Scheduled work',
          date: DateTime(2026, 10, 5),
        ).toCommunityPost(pldt),
      ];
      expect(service.visiblePosts(posts), isEmpty);
      await service.toggleFollow('pldt', userId: 'test_resident_123');
      expect(service.visiblePosts(posts).single.id, 'pldt_outage');
      await service.toggleFollow('pldt', userId: 'test_resident_123');
      expect(service.visiblePosts(posts), isEmpty);
    });

    test('Search query and category filters in getOrganizations', () async {
      final service = PrivateOrganizationService.instance;

      final bankList = await service.getOrganizations(category: 'Banking & Finance');
      expect(bankList.every((o) => o.category == 'Banking & Finance'), isTrue);
      expect(bankList.any((o) => o.name == 'LANDBANK'), isTrue);

      final searchList = await service.getOrganizations(query: 'Cebu Pacific');
      expect(searchList.length, 1);
      expect(searchList.first.name, 'Cebu Pacific');
    });
  });

  group('Discover & Profile Widget Tests', () {
    testWidgets('DiscoverPrivateOrganizationsPage displays header, search, 5 categories in line with Others, and organization cards', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DiscoverPrivateOrganizationsPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the header matches the official Barili header design
      expect(find.text('Private Organizations'), findsOneWidget);
      expect(find.text('BARILI DIRECTORY'), findsOneWidget);

      // Verify search input
      expect(find.textContaining('Search organizations'), findsOneWidget);

      // Verify the 5 categories on the single line including 'Others'
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Banking & Finance'), findsWidgets);
      expect(find.text('School & Education'), findsWidgets);
      expect(find.text('Health & Medical'), findsWidgets);
      expect(find.text('Others'), findsOneWidget);

      // Verify section header
      expect(find.text('Organizations You May Want to Follow'), findsOneWidget);
    });

    testWidgets('OrganizationProfilePage displays 3D hero canopy, 3-metric ribbon, name, about, and updates', (tester) async {
      final landbank = PrivateOrganization.approvedOrganizations.firstWhere(
        (o) => o.id == 'landbank',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: OrganizationProfilePage(organization: landbank),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('LANDBANK'), findsWidgets);
      expect(find.text('BARILI PRIVATE PARTNER'), findsOneWidget);
      expect(find.text('Banking & Finance'), findsWidgets);
      expect(find.text('•  Private Organization'), findsOneWidget);
      expect(find.text('About'), findsWidgets);
      expect(find.text('Followers'), findsWidgets);
      expect(find.text('Follow'), findsOneWidget);
    });

    testWidgets('Follow button on card toggles to Following in just one single tap', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DiscoverPrivateOrganizationsPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Find the first Follow button on an organization card
      final followBtn = find.text('Follow').first;
      expect(followBtn, findsOneWidget);

      // Tap it once
      await tester.tap(followBtn);
      await tester.pumpAndSettle();

      // Verify it immediately becomes 'Following' on one single tap
      expect(find.text('Following'), findsWidgets);
    });
  });
}
