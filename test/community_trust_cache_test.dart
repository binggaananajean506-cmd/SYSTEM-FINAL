import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:esugid/services/community_trust_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _Firestore extends Fake implements FirebaseFirestore {}

class _Result<T> extends Fake implements HttpsCallableResult<T> {
  _Result(this.data);
  @override
  final T data;
}

class _Callable extends Fake implements HttpsCallable {
  final responses = <Completer<Object?>>[];

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    final response = Completer<Object?>();
    responses.add(response);
    return _Result<T>(await response.future as T);
  }
}

class _Functions extends Fake implements FirebaseFunctions {
  final callable = _Callable();

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    expect(name, 'getCommunityTrustProfile');
    return callable;
  }
}

Map<String, Object?> _profile([String? photo]) => {
  'profile': {'name': 'Ana', 'profilePhotoUrl': photo},
  'reviews': <Object?>[],
};

void main() {
  test('concurrent public profile reads share one request', () async {
    final functions = _Functions();
    final service = CommunityTrustService(
      firestore: _Firestore(),
      functions: functions,
    );
    final first = service.getTrustProfile('cache-concurrent');
    final second = service.getTrustProfile(' cache-concurrent ');
    expect(functions.callable.responses, hasLength(1));
    functions.callable.responses.single.complete(_profile());
    expect((await first)?.displayName, 'Ana');
    expect((await second)?.displayName, 'Ana');
  });

  test('fresh profiles without avatars do not refetch on rebuild', () async {
    final functions = _Functions();
    final service = CommunityTrustService(
      firestore: _Firestore(),
      functions: functions,
    );
    final initial = service.getTrustProfile('cache-no-avatar');
    functions.callable.responses.single.complete(_profile());
    expect((await initial)?.profilePhotoUrl, isNull);
    expect(
      (await service.getTrustProfile('cache-no-avatar'))?.displayName,
      'Ana',
    );
    expect(functions.callable.responses, hasLength(1));
  });

  test('explicit refresh discovers a newly uploaded avatar', () async {
    final functions = _Functions();
    final service = CommunityTrustService(
      firestore: _Firestore(),
      functions: functions,
    );
    final initial = service.getTrustProfile('cache-new-avatar');
    functions.callable.responses.single.complete(_profile());
    await initial;
    final refreshed = service.getTrustProfile(
      'cache-new-avatar',
      useCache: false,
    );
    functions.callable.responses.last.complete(
      _profile('https://example.com/a.jpg'),
    );
    expect((await refreshed)?.profilePhotoUrl, 'https://example.com/a.jpg');
    expect(
      CommunityTrustService.getCachedProfile(
        'cache-new-avatar',
      )?.profilePhotoUrl,
      'https://example.com/a.jpg',
    );
  });

  test(
    'seeded avatar-less profiles revalidate and deliver a new avatar',
    () async {
      CommunityTrustService.seedProfile(
        userId: 'cache-seeded',
        displayName: 'Ana',
      );
      final functions = _Functions();
      final service = CommunityTrustService(
        firestore: _Firestore(),
        functions: functions,
      );
      final refreshed = service.getTrustProfile('cache-seeded');
      functions.callable.responses.single.complete(
        _profile('https://example.com/new.jpg'),
      );
      expect((await refreshed)?.profilePhotoUrl, 'https://example.com/new.jpg');
    },
  );

  test('offline reads are throttled and can be explicitly retried', () async {
    final functions = _Functions();
    final service = CommunityTrustService(
      firestore: _Firestore(),
      functions: functions,
    );
    final initial = service.getTrustProfile('cache-offline');
    functions.callable.responses.single.completeError(StateError('offline'));
    expect(await initial, isNull);
    expect(await service.getTrustProfile('cache-offline'), isNull);
    expect(functions.callable.responses, hasLength(1));
    final retry = service.getTrustProfile('cache-offline', useCache: false);
    functions.callable.responses.last.complete(_profile());
    expect((await retry)?.displayName, 'Ana');
  });
}
