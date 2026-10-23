import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';

String userFacingError(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  if (error is TimeoutException) {
    return 'The connection is taking too long. Please try again.';
  }
  if (error is SocketException) {
    return 'Check your internet connection and try again.';
  }
  if (error is FirebaseException) {
    final code = error.code.toLowerCase();
    if (code == 'deadline-exceeded') {
      return 'The connection is taking too long. Please try again.';
    }
    if (code == 'unauthenticated' || code == 'requires-recent-login') {
      return 'Please sign in again to continue.';
    }
    if (code.contains('permission-denied') || code.contains('unauthorized')) {
      return 'You do not have permission to do that.';
    }
    if (code.contains('network') || code.contains('unavailable')) {
      return 'Check your internet connection and try again.';
    }
    if (code.contains('object-not-found')) {
      return 'The requested file could not be found.';
    }
    if (code.contains('quota') || code.contains('too-many-requests')) {
      return 'The service is busy. Wait a moment and try again.';
    }
    if (code == 'cancelled' || code == 'canceled') {
      return 'The action was cancelled. Please try again.';
    }
    if (code == 'invalid-argument') {
      return 'Please check the required fields and try again.';
    }
  }
  if (error is PlatformException) {
    final code = error.code.toLowerCase();
    if (code.contains('denied') || code.contains('restricted')) {
      return 'Please allow access in your device settings and try again.';
    }
  }
  return fallback;
}
