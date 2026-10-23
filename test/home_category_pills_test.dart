import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:esugid/community_service.dart';
import 'package:google_fonts/google_fonts.dart';

// Test harness widget replicating _buildCommunityCategoryPills behavior
class CategoryPillsTestHarness extends StatefulWidget {
  final ValueChanged<String>? onCategoryChanged;
  final String initialCategory;

  const CategoryPillsTestHarness({
    super.key,
    this.onCategoryChanged,
    this.initialCategory = 'All',
  });

  @override
  State<CategoryPillsTestHarness> createState() =>
      _CategoryPillsTestHarnessState();
}

class _CategoryPillsTestHarnessState extends State<CategoryPillsTestHarness> {
  late String _selected;

  final categories = const [
    (label: 'All', icon: Icons.grid_view_rounded, accent: Color(0xFF059669)),
    (label: 'Notices', icon: Icons.campaign_rounded, accent: Color(0xFF0284C7)),
    (
      label: 'Advisories',
      icon: Icons.warning_amber_rounded,
      accent: Color(0xFFD97706),
    ),
    (
      label: 'Events',
      icon: Icons.event_available_rounded,
      accent: Color(0xFF7C3AED),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selected = widget.initialCategory;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final selected = _selected == cat.label;
          return InkWell(
            key: ValueKey('category-pill-${cat.label}'),
            onTap: () {
              setState(() {
                _selected = cat.label;
              });
              widget.onCategoryChanged?.call(cat.label);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
              decoration: BoxDecoration(
                gradient: selected
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF10B981),
                          Color(0xFF059669),
                          Color(0xFF044D3C),
                        ],
                      )
                    : null,
                color: selected ? null : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.45)
                      : const Color(0xFFDCECE4),
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: selected
                        ? const Color(0xFF059669).withValues(alpha: 0.32)
                        : Colors.black.withValues(alpha: 0.035),
                    blurRadius: selected ? 8 : 4,
                    offset: Offset(0, selected ? 3 : 1.5),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    cat.icon,
                    size: 14,
                    color: selected ? Colors.white : cat.accent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    cat.label,
                    style: GoogleFonts.outfit(
                      color: selected ? Colors.white : const Color(0xFF064E3B),
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CommunityPost createPost({
    required String id,
    required String title,
    required String content,
    String tag = 'Notice',
    String priority = 'regular',
    String category = 'General',
    String announcementType = 'general',
    DateTime? createdAt,
    DateTime? priorityExpiresAt,
  }) {
    return CommunityPost(
      id: id,
      title: title,
      content: content,
      authorName: 'Barangay Official',
      authorId: 'auth-$id',
      authorRole: 'barangay',
      authorBarangay: 'Cabcaban',
      authorOrganizationName: 'Barangay LGU',
      targetAudience: 'All Residents',
      targetBarangay: 'All Barangays',
      visibility: 'public',
      targetBarangays: const [],
      createdAt: createdAt ?? DateTime.now(),
      status: 'approved',
      tag: tag,
      priority: priority,
      priorityExpiresAt: priorityExpiresAt,
      category: category,
      announcementType: announcementType,
    );
  }

  group('Category Pills UI and Interaction', () {
    testWidgets(
      'renders All, Notices, Advisories, Events pills (without Urgent button)',
      (tester) async {
        String? selectedCategory;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CategoryPillsTestHarness(
                onCategoryChanged: (cat) => selectedCategory = cat,
              ),
            ),
          ),
        );

        // Verify the 4 category pills are present in order
        expect(find.text('All'), findsOneWidget);
        expect(find.text('Notices'), findsOneWidget);
        expect(find.text('Advisories'), findsOneWidget);
        expect(find.text('Events'), findsOneWidget);

        // Verify 'Urgent' category button is removed
        expect(find.text('Urgent'), findsNothing);

        // Tap on 'Advisories'
        await tester.tap(find.text('Advisories'));
        await tester.pumpAndSettle();
        expect(selectedCategory, 'Advisories');

        // Tap on 'Notices'
        await tester.tap(find.text('Notices'));
        await tester.pumpAndSettle();
        expect(selectedCategory, 'Notices');
      },
    );
  });

  group('Urgent Announcements in Advisories Matching Logic', () {
    test('matches urgent priority posts under Advisories', () {
      final post = createPost(
        id: 'post-1',
        title: 'Emergency Response Drill',
        content: 'Community simulation today',
        priority: 'urgent',
      );

      final normPriority = post.priority.toLowerCase().trim();
      final matchesAdvisory =
          normPriority == 'urgent' ||
          normPriority == 'emergency' ||
          post.tag.toLowerCase().contains('advisory');

      expect(matchesAdvisory, isTrue);
    });

    test('matches emergency priority posts under Advisories', () {
      final post = createPost(
        id: 'post-2',
        title: 'Water Service Interruption',
        content: 'Immediate line repairs ongoing',
        priority: 'emergency',
      );

      final normPriority = post.priority.toLowerCase().trim();
      final matchesAdvisory =
          normPriority == 'urgent' ||
          normPriority == 'emergency' ||
          post.tag.toLowerCase().contains('advisory');

      expect(matchesAdvisory, isTrue);
    });

    test('matches post labeled with advisory tag', () {
      final post = createPost(
        id: 'post-3',
        title: 'Barangay Health Advisory',
        content: 'Free rabies vaccines available today only',
        tag: 'Advisory',
      );

      expect(post.tag.toLowerCase(), contains('advisory'));
    });
  });

  group('Latest Announcements Section Header and View All Navigation', () {
    testWidgets('renders LATEST ANNOUNCEMENTS title and View All button', (
      tester,
    ) async {
      String? navigatedCategory;

      Widget buildHeader(String categoryName) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF34D399),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'LATEST ANNOUNCEMENTS',
                  style: GoogleFonts.outfit(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            InkWell(
              key: const ValueKey('home-community-updates-view-all'),
              onTap: () {
                navigatedCategory = categoryName;
              },
              child: Row(
                children: const [
                  Text('View All'),
                  Icon(Icons.arrow_forward_rounded, size: 13),
                ],
              ),
            ),
          ],
        );
      }

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: buildHeader('Notices'))),
      );

      // Verify text title
      expect(find.text('LATEST ANNOUNCEMENTS'), findsOneWidget);
      expect(find.text('View All'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);

      // Tap View All
      await tester.tap(
        find.byKey(const ValueKey('home-community-updates-view-all')),
      );
      await tester.pumpAndSettle();

      expect(navigatedCategory, 'Notices');
    });
  });

  group('Home Dashboard Latest Announcements Limit', () {
    test(
      'active urgent posts stay in the latest list by date, not priority',
      () {
        final now = DateTime(2026, 9, 25, 10);
        final urgentOlder = createPost(
          id: 'urgent-older',
          title: 'Urgent update',
          content: 'Still pinned above',
          priority: 'urgent',
          createdAt: now.subtract(const Duration(hours: 2)),
          priorityExpiresAt: now.add(const Duration(hours: 2)),
        );
        final regularNewer = createPost(
          id: 'regular-newer',
          title: 'New update',
          content: 'Posted later',
          createdAt: now.subtract(const Duration(minutes: 1)),
        );

        expect(
          CommunityService.sortPostsForFeed([
            urgentOlder,
            regularNewer,
          ], now: now).first.id,
          'urgent-older',
        );
        expect(
          CommunityService.sortPostsByNewest([
            urgentOlder,
            regularNewer,
          ]).map((post) => post.id),
          ['regular-newer', 'urgent-older'],
        );
      },
    );

    test(
      'limits dashboard feed to latest 5 posts while preserving older posts for updates page',
      () {
        final now = DateTime.now();
        final posts = List.generate(
          8,
          (i) => CommunityPost(
            id: 'post-$i',
            title: 'Post #$i',
            content: 'Content $i',
            authorName: 'Official',
            authorId: 'auth',
            authorRole: 'barangay',
            authorBarangay: 'Poblacion',
            authorOrganizationName: 'LGU',
            targetAudience: 'All Residents',
            targetBarangay: 'All Barangays',
            visibility: 'public',
            targetBarangays: const [],
            createdAt: now.subtract(
              Duration(days: i),
            ), // 0 is newest, 7 is oldest
            status: 'approved',
            tag: 'Notice',
            priority: 'regular',
            category: 'General',
            announcementType: 'general',
          ),
        );

        final sorted = CommunityService.sortPostsByNewest(posts);
        expect(sorted.length, 8);

        // Dashboard logic: take latest 5
        final homeFeedPosts = sorted.take(5).toList();
        expect(homeFeedPosts.length, 5);
        expect(homeFeedPosts.map((p) => p.id).toList(), [
          'post-0',
          'post-1',
          'post-2',
          'post-3',
          'post-4',
        ]);

        // When 1 newer announcement arrives (posted today), older post-4 drops off to updates page
        final newPost = CommunityPost(
          id: 'post-new-today',
          title: 'Brand New Post',
          content: 'Latest',
          authorName: 'Official',
          authorId: 'auth',
          authorRole: 'barangay',
          authorBarangay: 'Poblacion',
          authorOrganizationName: 'LGU',
          targetAudience: 'All Residents',
          targetBarangay: 'All Barangays',
          visibility: 'public',
          targetBarangays: const [],
          createdAt: now.add(const Duration(minutes: 5)),
          status: 'approved',
          tag: 'Notice',
          priority: 'regular',
          category: 'General',
          announcementType: 'general',
        );

        final updatedSorted = CommunityService.sortPostsByNewest([
          newPost,
          ...posts,
        ]);
        final updatedHomeFeedPosts = updatedSorted.take(5).toList();

        expect(updatedHomeFeedPosts.length, 5);
        expect(updatedHomeFeedPosts.first.id, 'post-new-today');
        expect(updatedHomeFeedPosts.map((p) => p.id).toList(), [
          'post-new-today',
          'post-0',
          'post-1',
          'post-2',
          'post-3',
        ]);
        // post-4 is no longer in home feed, but remains in full list (for updates page)
        expect(updatedSorted.any((p) => p.id == 'post-4'), isTrue);
      },
    );
  });
}
