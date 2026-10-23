import 'package:esugid/auth_service.dart';
import 'package:esugid/community_service.dart';
import 'package:esugid/widgets/community_post_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _testPost = CommunityPost(
  id: 'power-advisory',
  title: 'Scheduled Power Interruption',
  content:
      'Power service will be temporarily unavailable while maintenance work is completed.',
  authorName: 'E-SUGID',
  authorId: 'lgu-admin',
  authorRole: 'lgu',
  authorBarangay: '',
  authorOrganizationName: 'Municipality of Barili',
  targetAudience: 'All Residents',
  targetBarangay: 'All Barangays',
  visibility: 'public',
  targetBarangays: const [],
  createdAt: DateTime(2026, 8, 27),
  status: 'approved',
  tag: 'OFFICIAL',
  category: 'Other Advisory',
  customCategory: 'Transportation Update',
);

void main() {
  for (final configuration in <(double, double)>[
    (240, 1),
    (320, 2),
    (320, 1.5),
    (360, 1),
    (375, 1.3),
    (390, 2),
    (412, 1),
    (430, 1.5),
  ]) {
    final (width, textScale) = configuration;
    testWidgets(
      'Community Bulletin card fits ${width.toInt()}px at ${textScale}x text',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        AuthService.currentUser = null;

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: ModernPostCard(
                    post: _testPost,
                    animateEntrance: false,
                    onTap: () {},
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.text('E-SUGID'), findsOneWidget);
        expect(find.text('OFFICIAL'), findsNothing);
        expect(find.text('Scheduled Power Interruption'), findsOneWidget);
        expect(find.byKey(ValueKey('save-card-${_testPost.id}')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('announcement details display a custom Other category', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: PostDetailsPage(
          post: _testPost,
          imageHeroTag: 'custom-category-test',
          primaryGreen: const Color(0xFF059669),
          deepGreen: const Color(0xFF064E3B),
        ),
      ),
    );

    expect(find.text('TRANSPORTATION UPDATE'), findsOneWidget);
    expect(find.text('OTHER ADVISORY'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'ModernPostCard shows non-interactive schedule chip and no manual calendar button',
    (tester) async {
      final scheduledPost = CommunityPost(
        id: 'clean-up-drive',
        title: 'COMMUNITY CLEAN-UP DRIVE',
        content: 'Clean-up drive in Barangay Cabcaban.',
        authorName: 'Barangay Cabcaban',
        authorId: 'cabcaban-captain',
        authorRole: 'barangay_captain',
        authorBarangay: 'Cabcaban',
        authorOrganizationName: 'Barangay Cabcaban',
        targetAudience: 'All Residents',
        targetBarangay: 'Cabcaban',
        visibility: 'targeted',
        targetBarangays: const ['Cabcaban'],
        createdAt: DateTime(2026, 9, 9),
        status: 'approved',
        tag: 'OFFICIAL',
        category: 'Community',
        eventDate: DateTime(2026, 9, 17, 9, 16),
        eventEndDate: DateTime(2026, 9, 17, 12, 0),
        hasSchedule: true,
        calendarEventId: 'source_announcement_clean-up-drive',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ModernPostCard(
                post: scheduledPost,
                animateEntrance: false,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      // Manual add-to-calendar button is removed
      expect(
        find.byKey(const ValueKey('calendar-card-clean-up-drive')),
        findsNothing,
      );
      // Non-interactive schedule chip is displayed
      expect(find.textContaining('Sep 17'), findsOneWidget);
      expect(find.text('OFFICIAL'), findsNothing);
    },
  );

  testWidgets(
    'ModernPostCard renders urgent badge next to title while keeping clean brand header and omitting redundant top banner',
    (tester) async {
      final now = DateTime.now();
      final expiredUrgentPost = CommunityPost(
        id: 'expired-urgent-post',
        title: 'High Tide Warning',
        content: 'Residents near coastal areas please take precaution.',
        authorName: 'E-SUGID',
        authorId: 'lgu-admin',
        authorRole: 'lgu',
        authorBarangay: '',
        authorOrganizationName: 'Barili LGU',
        targetAudience: 'All Residents',
        targetBarangay: 'All Barangays',
        visibility: 'public',
        targetBarangays: const [],
        createdAt: now.subtract(const Duration(days: 3)),
        status: 'approved',
        tag: 'OFFICIAL',
        priority: 'urgent',
        priorityExpiresAt: now.subtract(const Duration(hours: 12)), // Expired from pinned carousel!
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ModernPostCard(
                post: expiredUrgentPost,
                animateEntrance: false,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      // Top redundant eyebrow strip is removed
      expect(find.text('URGENT ANNOUNCEMENT'), findsNothing);
      expect(find.text('PRIORITY'), findsNothing);

      // Urgent badge is removed per requirement
      expect(find.text('URGENT'), findsNothing);
      expect(find.byIcon(Icons.bolt_rounded), findsNothing);

      // Official author icon on medallion instead of warning icon
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
      expect(find.byIcon(Icons.account_balance_rounded), findsOneWidget);

      // Content and tap hint
      expect(find.text('High Tide Warning'), findsOneWidget);
      expect(find.text('Tap to view details'), findsOneWidget);
    },
  );

  testWidgets('ModernPostCardSkeleton renders correctly for regular and urgent variants', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                ModernPostCardSkeleton(isUrgent: false, enableShimmer: false),
                ModernPostCardSkeleton(isUrgent: true, enableShimmer: false),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(ModernPostCardSkeleton), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ModernPostCardSkeleton.feedList renders with shimmer without errors', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ModernPostCardSkeleton.feedList(count: 2),
          ),
        ),
      ),
    );

    expect(find.byType(ModernPostCardSkeleton), findsNWidgets(2));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ModernPostCard renders PublisherAvatar with verified badge for Barangay Vito', (tester) async {
    final vitoPost = CommunityPost(
      id: 'vito-sports',
      title: 'Sports Activity',
      content: 'Kabatan-onan sa Vito, lihok ug apil!',
      authorName: 'Barangay Vito',
      authorId: 'vito-admin',
      authorRole: 'barangay_captain',
      authorBarangay: 'Vito',
      authorOrganizationName: '',
      authorPhotoUrl: 'https://firebasestorage.googleapis.com/v0/b/esugid.appspot.com/o/users%2Fvito%2Fphoto.jpg',
      targetAudience: 'All Residents',
      targetBarangay: 'Vito',
      visibility: 'public',
      targetBarangays: const ['Vito'],
      createdAt: DateTime(2026, 8, 27),
      status: 'approved',
      tag: 'OFFICIAL',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ModernPostCard(
            post: vitoPost,
            animateEntrance: false,
          ),
        ),
      ),
    );

    expect(find.byType(PublisherAvatar), findsOneWidget);
    expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
    expect(find.text('Barangay Vito'), findsOneWidget);
  });
}
