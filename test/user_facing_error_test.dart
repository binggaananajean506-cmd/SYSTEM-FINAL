import 'dart:async';
import 'dart:io';

import 'package:esugid/core/errors/user_facing_error.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('distinguishes connection timeout, offline and permission failures', () {
    expect(userFacingError(TimeoutException('private')), contains('too long'));
    expect(userFacingError(const SocketException('private')), contains('internet'));
    expect(userFacingError(FirebaseException(plugin: 'test', code: 'deadline-exceeded')), contains('too long'));
    expect(userFacingError(FirebaseException(plugin: 'test', code: 'permission-denied')), contains('permission'));
    expect(userFacingError(PlatformException(code: 'camera_access_denied', message: 'private')), contains('device settings'));
    expect(userFacingError(FirebaseException(plugin: 'test', code: 'unauthenticated')), contains('sign in'));
  });

  test('unknown internal failures use only the supplied safe fallback', () {
    for (final error in <Object>[
      FirebaseException(plugin: 'test', code: 'internal', message: 'secret path'),
      PlatformException(code: 'internal', message: 'secret path'),
      Exception('secret path'),
    ]) {
      expect(userFacingError(error, fallback: 'Try again.'), 'Try again.');
    }
  });
}
