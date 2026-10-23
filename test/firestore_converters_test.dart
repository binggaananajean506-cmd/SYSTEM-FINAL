import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:esugid/firestore_converters.dart';

void main() {
  final expected = DateTime.utc(2026, 8, 4, 12, 30);

  test('converts supported Firestore date representations', () {
    void expectSameInstant(DateTime actual) {
      expect(actual.isAtSameMomentAs(expected), isTrue);
    }

    expectSameInstant(dateTimeFromFirestore(expected));
    expectSameInstant(dateTimeFromFirestore(expected.toIso8601String()));
    expectSameInstant(dateTimeFromFirestore(Timestamp.fromDate(expected)));
    expectSameInstant(dateTimeFromFirestore(expected.millisecondsSinceEpoch));
  });

  test('uses an explicit fallback for malformed values', () {
    final fallback = DateTime.utc(2000);

    expect(dateTimeFromFirestore('not-a-date', fallback: fallback), fallback);
    expect(nullableDateTimeFromFirestore('not-a-date'), isNull);
    expect(nullableDateTimeFromFirestore(null), isNull);
  });

  test('uses a deterministic epoch fallback when none is provided', () {
    expect(
      dateTimeFromFirestore('not-a-date'),
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  });
}
