import 'package:esugid/services/community_trust_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public profile keeps Bayanihan and Local Market ratings separate', () {
    final profile = UserTrustProfile.fromMap(
      'resident-1',
      {'name': 'Ana', 'verificationStatus': 'verified'},
      {
        'bayanihanRating': 4.5,
        'bayanihanRatingCount': 2,
        'marketRating': 3.0,
        'marketRatingCount': 1,
      },
    );

    expect(profile.bayanihanRating, 4.5);
    expect(profile.bayanihanRatingCount, 2);
    expect(profile.marketRating, 3.0);
    expect(profile.marketRatingCount, 1);
  });

  test('unreviewed profile starts with no ratings in either context', () {
    final profile = UserTrustProfile.fromMap(
      'resident-2',
      {'name': 'Ben'},
      {},
    );

    expect(profile.bayanihanRating, 0);
    expect(profile.bayanihanRatingCount, 0);
    expect(profile.marketRating, 0);
    expect(profile.marketRatingCount, 0);
  });
}
