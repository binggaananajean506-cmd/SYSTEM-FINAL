import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:esugid/barili_barangays.dart';
import 'package:esugid/services/publisher_avatar_service.dart';
import 'package:flutter_test/flutter_test.dart';

// These fakes replace only the Firestore snapshot boundary.
// ignore: subtype_of_sealed_class
class _Snapshot extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  _Snapshot(this.value);
  final Map<String, dynamic>? value;
  @override
  bool get exists => value != null;
  @override
  Map<String, dynamic>? data() => value;
}

// ignore: subtype_of_sealed_class
class _Document extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  final changes = StreamController<DocumentSnapshot<Map<String, dynamic>>>();
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #snapshots) return changes.stream;
    return super.noSuchMethod(invocation);
  }
}

// ignore: subtype_of_sealed_class
class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  final reference = _Document();
  late final String? requestedId;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    requestedId = path;
    return reference;
  }
}

class _Firestore extends Fake implements FirebaseFirestore {
  final profiles = _Collection();
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    expect(path, 'barangay_profiles');
    return profiles;
  }
}

void main() {
  test(
    'all 42 barangay names and legacy publisher IDs use the web profile ID',
    () {
      for (final barangay in bariliBarangays) {
        final expected = bariliBarangayId(barangay);
        for (final input in [
          barangay,
          'Barangay $barangay',
          expected,
          barangay.toLowerCase().replaceAll(' ', '-'),
        ]) {
          expect(PublisherAvatarService.barangayProfileId(id: input), expected);
        }
      }
      expect(
        PublisherAvatarService.barangayProfileId(id: 'tourism-department'),
        isNull,
      );
    },
  );

  test(
    'profile snapshots propagate uploads, replacements and removal',
    () async {
      final db = _Firestore();
      final photos = PublisherAvatarService.watchBarangayAvatar(
        barangay: 'Vito',
        firestore: db,
      ).take(4).toList();
      final source = db.profiles.reference.changes;
      source.add(_Snapshot(null));
      source.add(
        _Snapshot({
          'photoUrl': '',
          'profilePhotoUrl': 'https://example.test/first.jpg',
        }),
      );
      source.add(_Snapshot({'photoUrl': 'https://example.test/latest.jpg'}));
      source.add(
        _Snapshot({'photoUrl': '', 'profilePhotoUrl': '', 'logoUrl': ''}),
      );
      expect(await photos, [
        null,
        'https://example.test/first.jpg',
        'https://example.test/latest.jpg',
        '',
      ]);
      expect(db.profiles.requestedId, 'barili_vito');
      expect(PublisherAvatarService.getCached('barili_vito'), '');
      expect(PublisherAvatarService.getNotifier('barili_vito').value, '');
      await source.close();
    },
  );
}
