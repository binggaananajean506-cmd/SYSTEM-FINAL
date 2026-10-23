import 'package:flutter_test/flutter_test.dart';
import 'package:esugid/auth_service.dart';
import 'package:esugid/barili_barangays.dart';
import 'package:esugid/community_service.dart';

void main() {
  final vitoResident = User(
    uid: 'resident-1',
    email: 'resident@example.com',
    role: UserRole.resident,
    name: 'Resident',
    barangay: 'Vito',
  );

  test('official Barili list contains 42 unique barangays', () {
    expect(bariliBarangays, hasLength(42));
    expect(bariliBarangays.toSet(), hasLength(42));
  });

  test('granular staff roles map to the existing mobile role groups', () {
    expect(userRoleGroup('super_admin'), UserRole.lgu);
    expect(userRoleGroup('barangay_captain'), UserRole.barangay);
    expect(userRoleGroup('barangay_secretary'), UserRole.barangay);
    expect(userRoleGroup('barangay_councilor'), UserRole.barangay);
    expect(userRoleGroup('organization'), UserRole.partner);
  });

  test('public announcements match residents from any barangay', () {
    expect(
      CommunityService.postMatchesUser({
        'targetAudience': 'All Residents',
        'targetBarangay': 'All Barangays',
        'visibility': 'public',
        'targetBarangays': <String>[],
      }, vitoResident),
      isTrue,
    );
  });

  test('targeted announcements match only selected barangays', () {
    final data = {
      'targetAudience': 'All Residents',
      'targetBarangay': 'Selected Barangays',
      'visibility': 'targeted',
      'targetBarangays': ['Vito', 'Japitan'],
    };

    expect(CommunityService.postMatchesUser(data, vitoResident), isTrue);
    expect(
      CommunityService.postMatchesUser(
        data,
        User(
          uid: 'resident-2',
          email: 'other@example.com',
          role: UserRole.resident,
          name: 'Other Resident',
          barangay: 'Poblacion',
        ),
      ),
      isFalse,
    );
  });

  test('new announcements persist canonical audience and lifecycle fields', () {
    final map = TargetedPost(
      id: 'post-1',
      title: 'Update',
      content: 'Community information',
      authorName: 'Municipality of Barili',
      authorId: 'admin',
      authorRole: 'lgu',
      authorPosition: 'LGU Staff',
      authorBarangay: '',
      authorOrganizationName: 'Municipality of Barili',
      publisherEntityId: 'municipality-of-barili',
      publisherEntityType: 'lgu',
      publisherEntityName: 'Municipality of Barili',
      targetAudience: 'All Residents',
      targetBarangay: 'Selected Barangays',
      visibility: 'targeted',
      targetBarangays: const ['Barangay Vito', 'Japitan', 'Unknown'],
      createdAt: DateTime(2026, 8, 5),
      status: 'approved',
      category: 'Public Services',
      notificationRequested: true,
    ).toMap();

    expect(map['contentType'], 'announcement');
    expect(map['schemaVersion'], 2);
    expect(map['targetBarangays'], ['Vito', 'Japitan']);
    expect(map['audienceKeys'], ['barangay:Vito', 'barangay:Japitan']);
    expect(map['notificationRequested'], isTrue);
    expect(map['authorPosition'], 'LGU Staff');
    expect(map['publisherEntityId'], 'municipality-of-barili');
    expect(map['publisherEntityName'], 'Municipality of Barili');
  });

  test('targeting accepts profiles saved with a Barangay prefix', () {
    final data = {
      'targetAudience': 'All Residents',
      'targetBarangay': 'Selected Barangays',
      'visibility': 'targeted',
      'targetBarangays': ['Vito'],
    };

    expect(
      CommunityService.postMatchesUser(
        data,
        User(
          uid: 'resident-prefixed',
          email: 'prefixed@example.com',
          role: UserRole.resident,
          name: 'Prefixed Resident',
          barangay: 'Barangay Vito',
        ),
      ),
      isTrue,
    );
  });

  test('publisher and LGU can review a targeted announcement', () {
    final data = {
      'authorId': 'partner-1',
      'targetAudience': 'All Residents',
      'targetBarangay': 'Selected Barangays',
      'visibility': 'targeted',
      'targetBarangays': ['Vito'],
    };

    expect(
      CommunityService.postMatchesUser(
        data,
        User(
          uid: 'partner-1',
          email: 'partner@example.com',
          role: UserRole.partner,
          name: 'Partner',
          barangay: 'Poblacion',
        ),
      ),
      isTrue,
    );
    expect(
      CommunityService.postMatchesUser(
        data,
        User(
          uid: 'lgu-1',
          email: 'admin@example.com',
          role: UserRole.lgu,
          name: 'Administrator',
        ),
      ),
      isTrue,
    );
  });

  CommunityPost post({
    required String id,
    required DateTime createdAt,
    String priority = 'regular',
    DateTime? expiresAt,
  }) {
    return CommunityPost(
      id: id,
      title: id,
      content: '',
      authorName: 'Barangay Vito',
      authorId: 'official-1',
      authorRole: 'barangay',
      authorBarangay: 'Vito',
      authorOrganizationName: '',
      targetAudience: 'All Residents',
      targetBarangay: 'All Barangays',
      visibility: 'public',
      targetBarangays: const [],
      createdAt: createdAt,
      status: 'approved',
      tag: 'OFFICIAL',
      priority: priority,
      priorityExpiresAt: expiresAt,
    );
  }

  test('active emergency and urgent posts are pinned by urgency', () {
    final now = DateTime(2026, 7, 30, 10);
    final sorted = CommunityService.sortPostsForFeed([
      post(
        id: 'regular-new',
        createdAt: now.subtract(const Duration(minutes: 1)),
      ),
      post(
        id: 'urgent',
        createdAt: now.subtract(const Duration(hours: 2)),
        priority: 'urgent',
        expiresAt: now.add(const Duration(hours: 1)),
      ),
      post(
        id: 'emergency',
        createdAt: now.subtract(const Duration(hours: 3)),
        priority: 'emergency',
        expiresAt: now.add(const Duration(minutes: 30)),
      ),
    ], now: now);

    expect(sorted.map((item) => item.id), [
      'emergency',
      'urgent',
      'regular-new',
    ]);
  });

  test('expired urgent post returns to normal chronological position', () {
    final now = DateTime(2026, 7, 30, 10);
    final sorted = CommunityService.sortPostsForFeed([
      post(
        id: 'regular-new',
        createdAt: now.subtract(const Duration(minutes: 1)),
      ),
      post(
        id: 'urgent-expired',
        createdAt: now.subtract(const Duration(hours: 2)),
        priority: 'urgent',
        expiresAt: now.subtract(const Duration(minutes: 1)),
      ),
    ], now: now);

    expect(sorted.map((item) => item.id), ['regular-new', 'urgent-expired']);
  });

  test('multiple active urgent posts are pinned newest first', () {
    final now = DateTime(2026, 7, 30, 10);
    final sorted = CommunityService.sortPostsForFeed([
      post(
        id: 'regular-newest',
        createdAt: now.subtract(const Duration(minutes: 1)),
      ),
      post(
        id: 'urgent-older',
        createdAt: now.subtract(const Duration(hours: 2)),
        priority: 'urgent',
        expiresAt: now.add(const Duration(hours: 1)),
      ),
      post(
        id: 'urgent-newer',
        createdAt: now.subtract(const Duration(minutes: 30)),
        priority: 'urgent',
        expiresAt: now.add(const Duration(hours: 3)),
      ),
    ], now: now);

    expect(sorted.map((item) => item.id), [
      'urgent-newer',
      'urgent-older',
      'regular-newest',
    ]);
  });
}
