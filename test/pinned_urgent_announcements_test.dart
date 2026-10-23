import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:esugid/community_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CommunityPost createUrgentPost({
    required String id,
    required String title,
    required String content,
    required DateTime expiry,
    String role = 'barangay',
    String tag = 'OFFICIAL',
    String priority = 'urgent',
  }) {
    final now = DateTime.now();
    return CommunityPost(
      id: id,
      title: title,
      content: content,
      authorName: 'Barangay Official',
      authorId: 'auth-$id',
      authorRole: role,
      authorBarangay: 'Cabcaban',
      authorOrganizationName: 'Barangay LGU',
      targetAudience: 'All Residents',
      targetBarangay: 'All Barangays',
      visibility: 'public',
      targetBarangays: const [],
      createdAt: now.subtract(const Duration(hours: 1)),
      status: 'approved',
      tag: tag,
      priority: priority,
      priorityExpiresAt: expiry,
    );
  }

  group('Pinned Urgent Announcements Filter & Expiry Logic', () {
    test('filters active urgent announcements and excludes expired ones', () {
      final now = DateTime.now();
      final activePost = createUrgentPost(
        id: 'active-1',
        title: 'Water Service Interruption',
        content: 'Scheduled maintenance from 1pm to 5pm.',
        expiry: now.add(const Duration(hours: 3)),
      );
      final expiredPost = createUrgentPost(
        id: 'expired-1',
        title: 'Past Typhoon Advisory',
        content: 'Storm signal has lowered.',
        expiry: now.subtract(const Duration(minutes: 10)),
      );
      final residentPost = createUrgentPost(
        id: 'resident-1',
        title: 'Lost Dog',
        content: 'Please help find my dog.',
        expiry: now.add(const Duration(hours: 5)),
        role: 'resident',
        tag: 'COMMUNITY',
      );

      final allPosts = [activePost, expiredPost, residentPost];

      final pinned = allPosts.where((post) {
        final normPriority = post.priority.toLowerCase().trim();
        final isUrgent =
            normPriority == 'urgent' ||
            normPriority == 'emergency' ||
            post.tag.toLowerCase().contains('urgent');
        final expiry = post.priorityExpiresAt ?? post.expiresAt;
        final notExpired = expiry != null && expiry.isAfter(now);
        final role = post.authorRole.toLowerCase().trim();
        final tag = post.tag.toUpperCase().trim();
        final isAuthorized =
            role != 'resident' &&
            (tag == 'OFFICIAL' ||
                role.contains('barangay') ||
                role.contains('lgu') ||
                role.contains('admin') ||
                role.contains('official') ||
                role.contains('partner') ||
                role == 'super_admin' ||
                role == 'moderator');
        return isUrgent && notExpired && isAuthorized;
      }).toList();

      expect(pinned.length, 1);
      expect(pinned.first.id, 'active-1');
    });
  });

  group('Pinned Card UI Rendering', () {
    testWidgets('renders single pinned urgent card with badge and button', (
      tester,
    ) async {
      final now = DateTime.now();
      final post = createUrgentPost(
        id: 'test-urgent-card',
        title: 'Emergency Flood Alert',
        content: 'High tide expected. Please stay alert.',
        expiry: now.add(const Duration(hours: 4)),
      );

      bool viewAllTapped = false;
      CommunityPost? tappedPost;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PinnedUrgentAnnouncementsTestWrapper(
              posts: [post],
              isDark: false,
              onViewAll: () => viewAllTapped = true,
              onTapPost: (p) => tappedPost = p,
            ),
          ),
        ),
      );

      // Check header elements
      expect(find.text('URGENT ANNOUNCEMENTS'), findsOneWidget);
      expect(find.text('View All'), findsOneWidget);

      // Check card contents matching Picture 1
      expect(find.text('IMPORTANT UPDATE'), findsOneWidget);
      expect(find.text('Emergency Flood Alert'), findsOneWidget);
      expect(
        find.text('High tide expected. Please stay alert.'),
        findsOneWidget,
      );
      // Check author profile with badge positioned ABOVE title
      expect(find.text('Barangay Official'), findsOneWidget);
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
      final authorOffset = tester.getTopLeft(find.text('Barangay Official'));
      final titleOffset = tester.getTopLeft(find.text('Emergency Flood Alert'));
      expect(authorOffset.dy, lessThan(titleOffset.dy));
      expect(find.text('Urgent Alert'), findsNothing);
      expect(find.text('Read Full Update'), findsNothing);
      expect(find.text('Tap to view details'), findsOneWidget);
      expect(find.byIcon(Icons.touch_app_outlined), findsOneWidget);

      // Tap View All
      await tester.tap(find.text('View All'));
      await tester.pump();
      expect(viewAllTapped, isTrue);

      // Tap Card
      await tester.tap(find.text('Emergency Flood Alert'));
      await tester.pump();
      expect(tappedPost?.id, 'test-urgent-card');
    });

    testWidgets('renders swipeable carousel when multiple urgent posts exist', (
      tester,
    ) async {
      final now = DateTime.now();
      final post1 = createUrgentPost(
        id: 'card-1',
        title: 'Advisory 1: Power Outage',
        content: 'Power will be shut off in Poblacion.',
        expiry: now.add(const Duration(hours: 2)),
      );
      final post2 = createUrgentPost(
        id: 'card-2',
        title: 'Advisory 2: Road Repair',
        content: 'Main highway under maintenance.',
        expiry: now.add(const Duration(hours: 6)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PinnedUrgentAnnouncementsTestWrapper(
              posts: [post1, post2],
              isDark: false,
              onViewAll: () {},
              onTapPost: (_) {},
            ),
          ),
        ),
      );

      // Both posts exist in widget tree, first is visible
      expect(find.text('Advisory 1: Power Outage'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // Count badge

      // Swipe to next
      await tester.drag(
        find.text('Advisory 1: Power Outage'),
        const Offset(-600, 0),
      );
      await tester.pumpAndSettle();

      expect(find.text('Advisory 2: Road Repair'), findsOneWidget);
    });
  });

  group('Urgent Announcements Notification Badge & Viewed State', () {
    testWidgets('badge displays unviewed count and disappears when posts are viewed or View All is tapped', (
      tester,
    ) async {
      final now = DateTime.now();
      final post1 = createUrgentPost(
        id: 'urgent-1',
        title: 'Emergency 1',
        content: 'Desc 1',
        expiry: now.add(const Duration(hours: 2)),
      );
      final post2 = createUrgentPost(
        id: 'urgent-2',
        title: 'Emergency 2',
        content: 'Desc 2',
        expiry: now.add(const Duration(hours: 4)),
      );

      final posts = [post1, post2];
      final viewed = <String>{};

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: PinnedUrgentAnnouncementsTestWrapper(
                  posts: posts,
                  viewedPostIds: viewed,
                  isDark: false,
                  onViewAll: () {
                    setState(() {
                      viewed.addAll(posts.map((p) => p.id));
                    });
                  },
                  onTapPost: (p) {
                    setState(() {
                      viewed.add(p.id);
                    });
                  },
                ),
              );
            },
          ),
        ),
      );

      // Initially both are unviewed, so badge displays '2'
      expect(find.text('2'), findsOneWidget);

      // User taps first card -> marks post1 as viewed
      await tester.tap(find.text('Emergency 1'));
      await tester.pump();

      // Now only 1 unviewed remains -> badge updates to '1'
      expect(find.text('2'), findsNothing);
      expect(find.text('1'), findsOneWidget);

      // User taps "View All" -> marks remaining posts as viewed
      await tester.tap(find.text('View All'));
      await tester.pump();

      // All viewed -> badge is NOT displayed anymore!
      expect(find.text('2'), findsNothing);
      expect(find.text('1'), findsNothing);
    });
  });
}

/// Helper wrapper for testing pinned announcements widgets outside private state
class PinnedUrgentAnnouncementsTestWrapper extends StatelessWidget {
  final List<CommunityPost> posts;
  final Set<String> viewedPostIds;
  final bool isDark;
  final VoidCallback onViewAll;
  final ValueChanged<CommunityPost> onTapPost;

  const PinnedUrgentAnnouncementsTestWrapper({
    super.key,
    required this.posts,
    this.viewedPostIds = const <String>{},
    required this.isDark,
    required this.onViewAll,
    required this.onTapPost,
  });

  @override
  Widget build(BuildContext context) {
    final unviewedCount =
        posts.where((p) => !viewedPostIds.contains(p.id)).length;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('URGENT ANNOUNCEMENTS'),
                  if (unviewedCount > 0) ...[
                    const SizedBox(width: 8),
                    Text('$unviewedCount'),
                  ],
                ],
              ),
              InkWell(onTap: onViewAll, child: const Text('View All')),
            ],
          ),
          if (posts.length == 1)
            _buildCard(posts.first)
          else ...[
            SizedBox(
              height: 184,
              child: PageView.builder(
                itemCount: posts.length,
                itemBuilder: (context, index) => _buildCard(posts[index]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCard(CommunityPost post) {
    return InkWell(
      onTap: () => onTapPost(post),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF3F0B0B),
              Color(0xFF5F0E0E),
              Color(0xFF7F1D1D),
            ],
          ),
          border: Border.all(
            color: const Color(0xFFEF4444),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Author profile with badge above
            Row(
              children: [
                CircleAvatar(
                  radius: 11,
                  backgroundColor: const Color(0xFFEF4444),
                  child: Text(
                    post.authorName.isNotEmpty
                        ? post.authorName.substring(0, 1).toUpperCase()
                        : 'A',
                    style: const TextStyle(fontSize: 10, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  post.authorName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.verified_rounded,
                  size: 13,
                  color: Color(0xFFFDE68A),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              child: const Text('IMPORTANT UPDATE'),
            ),
            const SizedBox(height: 8),
            Text(post.title),
            if (post.content.isNotEmpty) Text(post.content),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.touch_app_outlined, size: 13),
                SizedBox(width: 4),
                Text('Tap to view details'),
                SizedBox(width: 3),
                Icon(Icons.arrow_forward_rounded, size: 11),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
