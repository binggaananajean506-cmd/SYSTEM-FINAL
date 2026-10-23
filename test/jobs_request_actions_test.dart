import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Bottom bar has MANAGE and COMPLETE buttons (CLOSE and old EDIT removed)', (
    tester,
  ) async {
    bool manageTapped = false;
    bool completeTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => manageTapped = true,
                    icon: const Icon(Icons.tune_rounded, size: 16),
                    label: const Text('MANAGE'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () => completeTapped = true,
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 17),
                    label: const Text('COMPLETE'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Verify MANAGE and COMPLETE are present
    expect(find.text('MANAGE'), findsOneWidget);
    expect(find.text('COMPLETE'), findsOneWidget);

    // Verify CLOSE and standalone EDIT are not in the bottom bar
    expect(find.text('CLOSE'), findsNothing);
    expect(find.text('EDIT'), findsNothing);

    // Test taps
    await tester.tap(find.text('MANAGE'));
    expect(manageTapped, isTrue);

    await tester.tap(find.text('COMPLETE'));
    expect(completeTapped, isTrue);
  });

  testWidgets('Manage modal provides Edit Request and Delete Request options', (
    tester,
  ) async {
    bool editClicked = false;
    bool deleteClicked = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showModalBottomSheet<void>(
                  context: context,
                  builder: (ctx) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Manage Help Request'),
                      ListTile(
                        leading: const Icon(Icons.edit_note_rounded),
                        title: const Text('Edit Request'),
                        onTap: () {
                          Navigator.pop(ctx);
                          editClicked = true;
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.delete_outline_rounded),
                        title: const Text('Delete Request'),
                        onTap: () {
                          Navigator.pop(ctx);
                          deleteClicked = true;
                        },
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Open Manage'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Manage'));
    await tester.pumpAndSettle();

    // Verify modal elements
    expect(find.text('Manage Help Request'), findsOneWidget);
    expect(find.text('Edit Request'), findsOneWidget);
    expect(find.text('Delete Request'), findsOneWidget);

    // Tap Edit Request
    await tester.tap(find.text('Edit Request'));
    await tester.pumpAndSettle();
    expect(editClicked, isTrue);

    // Reopen and tap Delete Request
    await tester.tap(find.text('Open Manage'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Request'));
    await tester.pumpAndSettle();
    expect(deleteClicked, isTrue);
  });

  testWidgets('Creative delete confirmation modal shows warning details and confirms', (
    tester,
  ) async {
    bool deleted = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogCtx) => Dialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.delete_sweep_rounded, size: 26),
                          const Text('Delete Help Request?'),
                          const Text(
                            'Are you sure you want to delete this request? This action cannot be undone.',
                          ),
                          Row(
                            children: [
                              OutlinedButton(
                                onPressed: () => Navigator.pop(dialogCtx, false),
                                child: const Text('Keep Request'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(dialogCtx, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
                if (confirmed == true) {
                  deleted = true;
                }
              },
              child: const Text('Trigger Delete'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Trigger Delete'));
    await tester.pumpAndSettle();

    // Creative dialog elements
    expect(find.byIcon(Icons.delete_sweep_rounded), findsOneWidget);
    expect(find.text('Delete Help Request?'), findsOneWidget);
    expect(find.text('Keep Request'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    // Cancel first
    await tester.tap(find.text('Keep Request'));
    await tester.pumpAndSettle();
    expect(deleted, isFalse);

    // Reopen and confirm delete
    await tester.tap(find.text('Trigger Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(deleted, isTrue);
  });

  testWidgets('My Activity header has Completed History button and removed old MY ACTIVITY / STATUS', (
    tester,
  ) async {
    bool historyOpened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    InkWell(
                      onTap: () => historyOpened = true,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history_rounded, size: 13),
                          SizedBox(width: 6),
                          Text('Completed History'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Row(
                  children: [
                    Expanded(child: Text('My Requests')),
                    SizedBox(width: 4),
                    Expanded(child: Text('Helping')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Verify outlined items are gone
    expect(find.text('MY ACTIVITY'), findsNothing);
    expect(find.text('STATUS'), findsNothing);

    // Verify Completed History button exists
    expect(find.text('Completed History'), findsOneWidget);
    expect(find.byIcon(Icons.history_rounded), findsOneWidget);

    // Verify button can be tapped
    await tester.tap(find.text('Completed History'));
    expect(historyOpened, isTrue);
  });

  testWidgets('My Request card renders 3D split-card with distinct MY REQUEST sign', (
    tester,
  ) async {
    bool cardTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Container(
            margin: const EdgeInsets.fromLTRB(18, 8, 18, 22),
            height: 196,
            child: Row(
              children: [
                // Left Tile with MY REQUEST sign
                Expanded(
                  flex: 40,
                  child: Stack(
                    children: [
                      Container(color: Colors.green),
                      const Positioned(
                        top: 12,
                        left: 12,
                        child: Row(
                          children: [
                            Icon(Icons.person_pin_rounded, size: 10),
                            Text('MY REQUEST'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Right Section
                Expanded(
                  flex: 60,
                  child: Column(
                    children: [
                      const Text('You'),
                      const Text('OPEN'),
                      const Text('Fix Leaking Pipe'),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () => cardTapped = true,
                        child: const Text('VIEW OFFERS'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Verify card content
    expect(find.text('MY REQUEST'), findsOneWidget);
    expect(find.byIcon(Icons.person_pin_rounded), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    expect(find.text('OPEN'), findsOneWidget);
    expect(find.text('Fix Leaking Pipe'), findsOneWidget);
    expect(find.text('VIEW OFFERS'), findsOneWidget);

    await tester.tap(find.text('VIEW OFFERS'));
    expect(cardTapped, isTrue);
  });

  testWidgets('Helping card renders 3D split-card with distinct HELPING sign and neighbor details', (
    tester,
  ) async {
    bool chatTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Container(
            margin: const EdgeInsets.fromLTRB(18, 8, 18, 22),
            height: 196,
            child: Row(
              children: [
                // Left Tile with HELPING sign
                Expanded(
                  flex: 40,
                  child: Stack(
                    children: [
                      Container(color: Colors.blue),
                      const Positioned(
                        top: 12,
                        left: 12,
                        child: Row(
                          children: [
                            Icon(Icons.volunteer_activism_rounded, size: 10),
                            Text('HELPING'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Right Section
                Expanded(
                  flex: 60,
                  child: Column(
                    children: [
                      const Text('Maria Santos'),
                      const Text('IN PROGRESS'),
                      const Text('Help Carrying Groceries'),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () => chatTapped = true,
                        child: const Text('VIEW CONVERSATION'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Verify card content
    expect(find.text('HELPING'), findsOneWidget);
    expect(find.byIcon(Icons.volunteer_activism_rounded), findsOneWidget);
    expect(find.text('Maria Santos'), findsOneWidget);
    expect(find.text('IN PROGRESS'), findsOneWidget);
    expect(find.text('Help Carrying Groceries'), findsOneWidget);
    expect(find.text('VIEW CONVERSATION'), findsOneWidget);

    await tester.tap(find.text('VIEW CONVERSATION'));
    expect(chatTapped, isTrue);
  });

  testWidgets(
    'Poster attribution row renders without overflow even with long resident name on narrow viewport',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const displayName = 'Julie Mae Tenebroso Dumapias';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Flexible(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.person, size: 16),
                          ),
                          const SizedBox(width: 8),
                          const Flexible(
                            child: Text(
                              'Posted by $displayName',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified_rounded,
                            size: 13,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('|'),
                  ),
                  const Text(
                    '3 days ago',
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Posted by Julie Mae'), findsOneWidget);
      expect(find.text('3 days ago'), findsOneWidget);

      final textWidget = tester.widget<Text>(find.textContaining('Posted by Julie Mae'));
      expect(textWidget.style?.decoration, isNot(TextDecoration.underline));
    },
  );

  testWidgets('Pending offer bottom bar renders informative status card and OPEN DIRECT CHAT button', (
    tester,
  ) async {
    bool chatOpened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                child: Row(
                  children: [
                    const Icon(Icons.hourglass_top_rounded),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('Help Offer Submitted'),
                              Spacer(),
                              Text('Pending Review'),
                            ],
                          ),
                          Text('Awaiting neighbor to review and accept. You can chat with them anytime.'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => chatOpened = true,
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: const Text('OPEN DIRECT CHAT'),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Help Offer Submitted'), findsOneWidget);
    expect(find.text('Pending Review'), findsOneWidget);
    expect(find.text('Awaiting neighbor to review and accept. You can chat with them anytime.'), findsOneWidget);
    expect(find.text('OPEN DIRECT CHAT'), findsOneWidget);

    await tester.tap(find.text('OPEN DIRECT CHAT'));
    expect(chatOpened, isTrue);
  });
}


