import 'dart:convert';

import 'package:esugid/services/concern_draft_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'saving updates the same draft, retains fields, and isolates residents',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = ConcernDraftStore(prefs, 'resident-a');
      final draft = <String, dynamic>{
        'id': 'draft-1',
        'title': 'Blocked drain',
        'recipient': 'My Barangay Office',
        'category': 'Road Repair',
        'description': 'Drain is blocked near the road.',
        'location': 'Cabcaban',
        'incidentDate': '2026-09-07',
        'formStep': 1,
        'createdAt': '2026-09-07T08:00:00',
        'updatedAt': '2026-09-07T08:00:00',
        'evidence': base64Encode([1, 2, 3]),
        'anonymous': false,
      };
      await store.save(draft);
      await store.save({...draft, 'title': 'Drainage issue', 'formStep': 2});
      final restored = ConcernDraftStore(prefs, 'resident-a').list();
      expect(restored, hasLength(1));
      expect(restored.single['title'], 'Drainage issue');
      expect(restored.single['formStep'], 2);
      expect(restored.single['recipient'], 'My Barangay Office');
      expect(base64Decode(restored.single['evidence'] as String), [1, 2, 3]);
      expect(restored.single.containsKey('submissionReference'), isFalse);
      expect(ConcernDraftStore(prefs, 'resident-b').list(), isEmpty);
    },
  );

  test(
    'deletion affects only selected draft and completed drafts stay closed',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = ConcernDraftStore(prefs, 'resident-a');
      await store.save({'id': 'one', 'updatedAt': '2026-09-07T08:00:00'});
      await store.save({'id': 'two', 'updatedAt': '2026-09-07T09:00:00'});
      expect(store.list().first['id'], 'two');
      await store.delete('one');
      expect(store.list().single['id'], 'two');
      await store.save({...store.list().single, 'submitted': true});
      expect(store.list(), isEmpty);
    },
  );
}
