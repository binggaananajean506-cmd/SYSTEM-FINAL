import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:esugid/community_service.dart';
import 'package:esugid/features/home/data/dashboard_announcement_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  CommunityPost post(String id, DateTime createdAt) => CommunityPost(
    id: id,
    title: 'Announcement $id',
    content: 'Community update',
    authorName: 'E-SUGID',
    authorId: 'admin',
    authorRole: 'lgu',
    authorBarangay: '',
    authorOrganizationName: 'Municipality of Barili',
    targetAudience: 'All Residents',
    targetBarangay: 'All Barangays',
    visibility: 'public',
    targetBarangays: const [],
    createdAt: createdAt,
    status: 'approved',
    tag: 'OFFICIAL',
  );

  test(
    'dashboard announcements survive an app restart in newest-first order',
    () async {
      final cache = DashboardAnnouncementCache();
      await cache.save([
        post('older', DateTime.utc(2026, 8, 20)),
        post('newer', DateTime.utc(2026, 8, 30)),
      ]);

      final restored = await DashboardAnnouncementCache().load();

      expect(restored.map((item) => item.id), ['newer', 'older']);
      expect(restored.first.title, 'Announcement newer');
    },
  );

  test('a corrupt local record does not break the dashboard', () async {
    SharedPreferences.setMockInitialValues({
      'dashboard_public_announcements_v1':
          '[{"id":"broken","createdAt":"not-a-date"}]',
    });

    expect(await DashboardAnnouncementCache().load(), isEmpty);
  });
}
