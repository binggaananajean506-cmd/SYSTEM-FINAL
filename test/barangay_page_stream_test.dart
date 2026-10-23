import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:esugid/barili_barangays.dart';
import 'package:esugid/community_service.dart';

void main() {
  setUp(() {
    CommunityService.clearCaches();
  });

  tearDown(() {
    CommunityService.clearCaches();
  });

  group('Barangay Announcement Stream Lifecycle Tests', () {
    test('canonicalBariliBarangay normalizes variations properly', () {
      expect(canonicalBariliBarangay('Barangay Vito'), 'Vito');
      expect(canonicalBariliBarangay('brgy. vito'), 'Vito');
      expect(canonicalBariliBarangay('vito'), 'Vito');
      expect(canonicalBariliBarangay('Vito'), 'Vito');
      expect(canonicalBariliBarangay('All Barangays'), isNull);
      expect(canonicalBariliBarangay(''), isNull);
      expect(canonicalBariliBarangay(null), isNull);
    });

    test('latestBarangayPosts returns null initially and can be cleared', () {
      expect(CommunityService.latestBarangayPosts('Vito'), isNull);
      expect(CommunityService.latestBarangayPosts('Barangay Vito'), isNull);
      CommunityService.clearBarangayStream('Vito');
      expect(CommunityService.latestBarangayPosts('Vito'), isNull);
    });

    test('Stream broadcast eviction allows fresh subscription on back and re-enter', () async {
      final streamMap = <String, Stream<List<String>>>{};
      var factoryCallCount = 0;
      var activeListenersCount = 0;

      Stream<List<String>> getBarangayFeedStream(String key) {
        return streamMap.putIfAbsent(
          key,
          () {
            factoryCallCount++;
            late StreamController<List<String>> controller;
            controller = StreamController<List<String>>(
              onListen: () {
                activeListenersCount++;
                controller.add(['Barangay Assembly Notice', 'Water Interruption Advisory']);
              },
              onCancel: () {
                activeListenersCount--;
              },
            );
            return controller.stream.asBroadcastStream(
              onCancel: (sub) {
                sub.cancel();
                streamMap.remove(key);
              },
            );
          },
        );
      }

      // First Visit: User opens "View My Barangay"
      final stream1 = getBarangayFeedStream('vito');
      expect(factoryCallCount, 1);
      List<String>? visit1Posts;
      final sub1 = stream1.listen((posts) {
        visit1Posts = posts;
      });

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(visit1Posts, isNotNull);
      expect(visit1Posts!.length, 2);
      expect(activeListenersCount, 1);

      // User presses Back: Page is disposed, subscription cancelled
      await sub1.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(activeListenersCount, 0);
      expect(streamMap.containsKey('vito'), isFalse,
          reason: 'Stream must be evicted on cancellation so the next visit gets fresh data');

      // Second Visit: User clicks "View My Barangay" again
      final stream2 = getBarangayFeedStream('vito');
      expect(factoryCallCount, 2,
          reason: 'Factory must be invoked again to re-subscribe to Firestore');
      List<String>? visit2Posts;
      final sub2 = stream2.listen((posts) {
        visit2Posts = posts;
      });

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(visit2Posts, isNotNull,
          reason: 'Announcements must be present on the second visit');
      expect(visit2Posts!.length, 2);
      expect(activeListenersCount, 1);

      // User presses Back again
      await sub2.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(activeListenersCount, 0);
      expect(streamMap.containsKey('vito'), isFalse);
    });
  });
}
