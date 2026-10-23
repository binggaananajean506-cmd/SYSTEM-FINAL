import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../auth_service.dart';
import '../firestore_converters.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

enum TrustContext { bayanihan, market }

class UserReview {
  const UserReview({
    required this.id,
    required this.reviewerUid,
    required this.reviewerName,
    required this.rating,
    required this.comment,
    required this.context,
    required this.createdAt,
  });

  final String id;
  final String reviewerUid;
  final String reviewerName;
  final double rating;
  final String comment;
  final TrustContext context;
  final DateTime createdAt;

  factory UserReview.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return UserReview.fromMap(doc.id, data);
  }

  factory UserReview.fromMap(String id, Map<String, dynamic> data) {
    return UserReview(
      id: id,
      reviewerUid: data['reviewerUid']?.toString() ?? '',
      reviewerName: data['reviewerName']?.toString() ?? 'A community member',
      rating: (data['rating'] as num?)?.toDouble() ?? 0,
      comment: data['comment']?.toString() ?? '',
      context: data['context']?.toString() == 'market'
          ? TrustContext.market
          : TrustContext.bayanihan,
      createdAt: dateTimeFromFirestore(data['createdAt']),
    );
  }

  String get contextLabel =>
      context == TrustContext.bayanihan ? 'Bayanihan' : 'Local Market';
}

class UserTrustProfile {
  const UserTrustProfile({
    required this.userId,
    required this.displayName,
    required this.barangay,
    required this.isVerified,
    required this.profilePhotoUrl,
    required this.bayanihanRating,
    required this.bayanihanRatingCount,
    required this.marketRating,
    required this.marketRatingCount,
    required this.memberSince,
  });

  final String userId;
  final String displayName;
  final String? barangay;
  final bool isVerified;
  final String? profilePhotoUrl;
  final double bayanihanRating;
  final int bayanihanRatingCount;
  final double marketRating;
  final int marketRatingCount;
  final DateTime? memberSince;

  factory UserTrustProfile.fromMap(
    String userId,
    Map<String, dynamic> userData,
    Map<String, dynamic> trustData,
  ) {
    return UserTrustProfile(
      userId: userId,
      displayName: userData['name']?.toString() ?? 'Community Member',
      barangay: userData['barangay']?.toString(),
      isVerified:
          userData['verificationStatus']?.toString() == 'verified' ||
          userData['identityVerified'] == true,
      profilePhotoUrl:
          userData['profilePhotoUrl']?.toString() ??
          userData['photoUrl']?.toString(),
      bayanihanRating:
          (trustData['bayanihanRating'] as num?)?.toDouble() ?? 0.0,
      bayanihanRatingCount:
          (trustData['bayanihanRatingCount'] as num?)?.toInt() ?? 0,
      marketRating: (trustData['marketRating'] as num?)?.toDouble() ?? 0.0,
      marketRatingCount: (trustData['marketRatingCount'] as num?)?.toInt() ?? 0,
      memberSince: nullableDateTimeFromFirestore(
        userData['createdAt'] ?? userData['joinedAt'],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

class CommunityTrustService {
  CommunityTrustService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ??
           FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  // In-memory static caches so profiles and reviews are instant across screen navigations!
  static final Map<String, UserTrustProfile> _profileCache = {};
  static final Map<String, List<UserReview>> _reviewsCache = {};
  static final Map<String, DateTime> _profileFetchedAt = {};
  static final Map<String, Future<UserTrustProfile?>> _profileRequests = {};
  static const _profileRefreshInterval = Duration(minutes: 2);

  static UserTrustProfile? getCachedProfile(String userId) =>
      _profileCache[userId.trim()];

  static void seedProfile({
    required String userId,
    required String displayName,
    String? photoUrl,
    String? barangay,
    bool isVerified = true,
  }) {
    final id = userId.trim();
    if (id.isEmpty || _profileCache.containsKey(id)) return;
    _profileCache[id] = UserTrustProfile(
      userId: id,
      displayName: displayName,
      barangay: barangay,
      isVerified: isVerified,
      profilePhotoUrl: photoUrl,
      bayanihanRating: 5.0,
      bayanihanRatingCount: 0,
      marketRating: 0.0,
      marketRatingCount: 0,
      memberSince: null,
    );
  }

  // ── Trust Profile ─────────────────────────────────────────────────────────

  /// Fetches the public profile fields and trust data exposed by the backend.
  ///
  /// Full `users` documents contain private account data and cannot be read by
  /// other residents. The callable validates the viewer and returns only the
  /// fields intended for the Community Profile screen.
  Future<UserTrustProfile?> getTrustProfile(
    String userId, {
    bool useCache = true,
  }) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return null;

    final pending = _profileRequests[normalizedUserId];
    if (pending != null) return pending;
    final lastFetch = _profileFetchedAt[normalizedUserId];
    if (useCache &&
        lastFetch != null &&
        DateTime.now().difference(lastFetch) < _profileRefreshInterval) {
      return _profileCache[normalizedUserId];
    }

    // Callers can render getCachedProfile while awaiting revalidation. Return
    // the refreshed value so a newly added avatar reaches the waiting widget.
    return _requestProfile(normalizedUserId);
  }

  Future<UserTrustProfile?> _requestProfile(String userId) {
    final existing = _profileRequests[userId];
    if (existing != null) return existing;
    // Throttle failed/offline and missing-profile reads as well as successful
    // reads; rebuilding a card must not retry the callable continuously.
    _profileFetchedAt[userId] = DateTime.now();
    final request = _fetchAndCacheProfile(userId);
    _profileRequests[userId] = request;
    request.whenComplete(() => _profileRequests.remove(userId));
    return request;
  }

  Future<UserTrustProfile?> _fetchAndCacheProfile(
    String normalizedUserId,
  ) async {
    try {
      final result = await _functions
          .httpsCallable(
            'getCommunityTrustProfile',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 8)),
          )
          .call<Object?>({'userId': normalizedUserId});
      final response = _stringKeyedMap(result.data);
      final profileData = _nullableStringKeyedMap(response['profile']);
      if (profileData == null) return _profileCache[normalizedUserId];

      final rawReviews = response['reviews'];
      final reviews = rawReviews is List
          ? rawReviews
                .map(_nullableStringKeyedMap)
                .whereType<Map<String, dynamic>>()
                .map(
                  (review) => UserReview.fromMap(
                    review['id']?.toString() ?? '',
                    review,
                  ),
                )
                .toList(growable: false)
          : const <UserReview>[];

      _reviewsCache[normalizedUserId] = reviews;
      final profile = UserTrustProfile.fromMap(
        normalizedUserId,
        profileData,
        profileData,
      );
      _profileCache[normalizedUserId] = profile;
      return profile;
    } catch (_) {
      return _profileCache[normalizedUserId];
    }
  }

  /// Returns the safe review data loaded with the public profile response.
  Stream<List<UserReview>> reviewsFor(String userId) {
    return Stream.value(_reviewsCache[userId.trim()] ?? const []);
  }

  // ── Rating Submission ─────────────────────────────────────────────────────

  /// The backend verifies completion and enforces one review per interaction.
  Future<void> submitRating({
    required String targetUserId,
    required double rating,
    required String comment,
    required TrustContext context,
    required String sourceId, // conversationId or interestId
  }) async {
    if (AuthService.currentUser == null) {
      throw StateError('Please sign in again.');
    }
    if (rating < 1 || rating > 5) {
      throw StateError('Rating must be between 1 and 5.');
    }

    await _functions.httpsCallable('submitCommunityRating').call<Object?>({
      'targetUserId': targetUserId,
      'rating': rating.toInt(),
      'comment': comment.trim(),
      'context': context.name,
      'sourceId': sourceId,
    });
  }

  Future<bool> hasRated({
    required String sourceId,
    required String targetUserId,
    required TrustContext context,
  }) async {
    final result = await _functions
        .httpsCallable('getCommunityReviewStatus')
        .call<Object?>({
          'sourceId': sourceId,
          'targetUserId': targetUserId,
          'context': context.name,
        });
    return _stringKeyedMap(result.data)['rated'] == true;
  }

  // ── Report User ───────────────────────────────────────────────────────────

  Future<void> reportUser({
    required String reportedUserId,
    required String reportedUserName,
    required String reason,
    String details = '',
    String? conversationId,
    TrustContext? context,
  }) async {
    final reporter = AuthService.currentUser;
    if (reporter == null) throw StateError('Please sign in again.');

    final ticket = _firestore.collection('helpdesk_tickets').doc();
    await ticket.set({
      'id': ticket.id,
      'userId': reporter.uid,
      'userName': reporter.name,
      'subject': 'User Report: $reportedUserName',
      'message': details.trim().isEmpty
          ? 'Please review this user\'s activity.'
          : details.trim(),
      'category': 'user_report',
      'reportedUserId': reportedUserId,
      'reportedUserName': reportedUserName,
      'reason': reason,
      'conversationId': conversationId ?? '',
      'context': context == TrustContext.market ? 'market' : 'bayanihan',
      'status': 'Open',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

}

Map<String, dynamic> _stringKeyedMap(Object? value) {
  if (value is! Map) return <String, dynamic>{};
  return value.map((key, item) => MapEntry(key.toString(), item));
}

Map<String, dynamic>? _nullableStringKeyedMap(Object? value) {
  if (value is! Map) return null;
  return _stringKeyedMap(value);
}
