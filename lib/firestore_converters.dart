import 'package:cloud_firestore/cloud_firestore.dart';

/// Converts Firestore timestamps and locally persisted ISO-8601 values into a
/// single date representation. Unknown values use [fallback], or Unix epoch
/// when no fallback is supplied so malformed records are not presented as new.
DateTime dateTimeFromFirestore(dynamic value, {DateTime? fallback}) {
  final parsed = nullableDateTimeFromFirestore(value);
  return parsed ??
      fallback ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

/// Returns `null` when [value] is absent or cannot be interpreted as a date.
DateTime? nullableDateTimeFromFirestore(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return null;
}
