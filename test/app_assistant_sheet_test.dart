import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:esugid/auth_service.dart';
import 'package:esugid/features/app_assistant/app_assistant_launcher.dart';
import 'package:esugid/features/app_assistant/app_assistant_service.dart';

void main() {
  final resident = User(
    uid: 'resident-1',
    email: 'resident@example.com',
    role: UserRole.resident,
    name: 'Resident User',
  );

  testWidgets(
    'assistant shows three quick questions and navigates to concern',
    (tester) async {
      AssistantNavigationAction? action;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppAssistantSheet(
              user: resident,
              service: AppAssistantService(callable: (_) async => {}),
              onNavigate: (value) => action = value,
            ),
          ),
        ),
      );

      for (final question in AppAssistantService.quickQuestions) {
        expect(find.text(question), findsOneWidget);
      }

      await tester.tap(find.text('Can I submit a concern here?'));
      await tester.pumpAndSettle();
      expect(find.text('Open Concern'), findsOneWidget);

      await tester.tap(find.text('Open Concern'));
      await tester.pumpAndSettle();
      expect(action?.destination, AssistantDestination.fileConcern);
    },
  );
}
