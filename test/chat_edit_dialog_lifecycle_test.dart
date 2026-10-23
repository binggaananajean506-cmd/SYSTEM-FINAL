import 'package:esugid/widgets/chat_message_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final save in [true, false]) {
    testWidgets('edit dialog ${save ? 'saves' : 'cancels'} and disposes after unmount', (tester) async {
      String? result;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) => TextButton(
        onPressed: () async { result = await showEditMessageDialog(context, initialText: 'Original'); },
        child: const Text('Edit'),
      )))));
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      final controller = tester.widget<TextField>(find.byType(TextField)).controller!;
      expect(controller.text, 'Original');
      await tester.enterText(find.byType(TextField), 'Updated');
      await tester.tap(find.text(save ? 'Save' : 'Cancel'));
      await tester.pump();
      expect(result, save ? 'Updated' : isNull);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(() => controller.addListener(() {}), throwsFlutterError);
    });
  }
}
