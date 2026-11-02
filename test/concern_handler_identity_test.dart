import 'package:esugid/submission_service.dart';
import 'package:esugid/widgets/concern_handler_identity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  final concern = Submission.fromMap({
    'id': 'CON-2026-913415',
    'kind': 'concern',
    'date': '2026-10-05T13:16:00Z',
    'status': 'being_handled',
    'statusHistory': [
      {
        'action': 'handle',
        'actorId': 'captain-uid',
        'actorName': 'Ana Jean Binggaan',
      },
    ],
  });

  testWidgets(
    'legacy progress loads the actual handler role from the database',
    (tester) async {
      String? requested;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConcernHandlerIdentity(
              concern: concern,
              progressNote: 'Barangay Vito is now handling this concern.',
              handlerLoader: (id) async {
                requested = id;
                return {
                  'name': 'Ana Jean Binggaan',
                  'role': 'barangay_captain',
                };
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(requested, concern.id);
      expect(
        find.text('Handled by: Ana Jean Binggaan · Barangay Captain'),
        findsOneWidget,
      );
      expect(
        find.text('Barangay Vito is now handling this concern.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'current assignment takes precedence over an older handling event',
    (tester) async {
      final reassigned = concern.copyWith(
        handledBy: 'secretary-uid',
        handledByName: 'New Secretary',
        handledByRole: 'barangay_secretary',
      );
      final restored = Submission.fromMap(reassigned.toMap());
      expect(restored.handledBy, 'secretary-uid');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConcernHandlerIdentity(
              concern: restored,
              progressNote: '',
              handlerLoader: (_) =>
                  throw StateError('The current handler snapshot is complete'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Handled by: New Secretary · Barangay Secretary'),
        findsOneWidget,
      );
      expect(find.textContaining('Ana Jean Binggaan'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
