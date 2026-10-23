import 'package:esugid/pages/concern_revision_page.dart';
import 'package:esugid/submission_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class RevisionRepository implements SubmissionRepository {
  Submission? saved;
  bool fail = false;
  Object? failure;
  @override
  Future<Submission> resubmitConcern(Submission submission) async {
    if (failure case final error?) throw error;
    if (fail) throw StateError('offline');
    saved = submission;
    return submission.copyWith(status: 'submitted');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final concern = Submission(
    id: 'CON-1',
    title: 'Broken streetlight',
    description: 'Light is not working',
    category: 'Infrastructure',
    type: 'Complaint',
    userId: 'resident-1',
    status: 'needs_information',
    date: DateTime(2026, 9, 30),
    location: 'Near the chapel',
    attachmentUrl: 'https://example.com/photo.jpg',
    attachmentStoragePath: 'concerns/resident-1/CON-1/photo.jpg',
  );

  Future<void> open(WidgetTester tester, RevisionRepository repository) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<Submission>(
                  builder: (_) => ConcernRevisionPage(
                    concern: concern,
                    request: 'Please correct the location',
                    repository: repository,
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'focused edits resubmit the same concern and safely close the route',
    (tester) async {
      final repository = RevisionRepository();
      await open(tester, repository);
      expect(
        find.textContaining('Please correct the location'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'Beside the school',
      );
      await tester.scrollUntilVisible(
        find.text('Resubmit Concern'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resubmit Concern'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Open'), findsOneWidget);
      expect(repository.saved!.id, concern.id);
      expect(repository.saved!.location, 'Beside the school');
      expect(repository.saved!.attachmentUrl, concern.attachmentUrl);
      expect(repository.saved!.date, concern.date);
    },
  );

  testWidgets('failed saves preserve edits and allow retry', (tester) async {
    final repository = RevisionRepository()..fail = true;
    await open(tester, repository);
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'Updated streetlight',
    );
    await tester.scrollUntilVisible(
      find.text('Resubmit Concern'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resubmit Concern'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Check your connection'), findsOneWidget);
    expect(tester.takeException(), isNull);
    repository.fail = false;
    await tester.scrollUntilVisible(
      find.text('Resubmit Concern'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resubmit Concern'));
    await tester.pumpAndSettle();
    expect(repository.saved!.title, 'Updated streetlight');
    expect(tester.takeException(), isNull);
  });

  testWidgets('unexpected callable failures hide internal details', (tester) async {
    final repository = RevisionRepository()
      ..failure = FirebaseFunctionsException(
        code: 'internal',
        message: 'private database path and stack trace',
      );
    await open(tester, repository);
    await tester.scrollUntilVisible(
      find.text('Resubmit Concern'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Resubmit Concern'));
    await tester.pumpAndSettle();
    expect(find.textContaining('private database path'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
