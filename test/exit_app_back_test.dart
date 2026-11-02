import 'package:esugid/auth_service.dart';
import 'package:esugid/login_screen.dart';
import 'package:esugid/pages/concern_center_page.dart';
import 'package:esugid/submission_service.dart';
import 'package:esugid/widgets/root_exit_pop_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _EmptySubmissionRepo implements SubmissionRepository {
  @override
  Future<Submission> addSubmission(Submission submission) async => submission;

  @override
  Stream<List<Submission>> submissionsForUser(String userId) =>
      Stream.value(const []);

  @override
  Future<Submission> resubmitConcern(Submission submission) async => submission;

  @override
  Future<void> addResidentInformation({
    required String submissionId,
    required String userId,
    required String message,
    String attachmentUrl = '',
    String attachmentStoragePath = '',
  }) async {}
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets(
    'system back at the login root shows the requested confirmation once',
    (tester) async {
      var exitCalls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'SystemNavigator.pop') exitCalls++;
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );

      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Exit E-SUGID?'), findsOneWidget);
      expect(
        find.text('Are you sure you want to exit the app?'),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Exit'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        find.text('Exit E-SUGID?').evaluate().length,
        lessThanOrEqualTo(1),
      );

      if (find.text('Exit E-SUGID?').evaluate().isEmpty) {
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Exit E-SUGID?'), findsNothing);
      expect(exitCalls, 0);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Exit'));
      await tester.pumpAndSettle();
      expect(exitCalls, 1);
    },
  );

  testWidgets(
    'system back from a pushed login route returns to the prior page',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LoginScreen(),
                    ),
                  ),
                  child: const Text('Open login'),
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Open login'));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Open login'), findsOneWidget);
      expect(find.text('Exit E-SUGID?'), findsNothing);
    },
  );

  testWidgets('report subpage back runs before root tab back or exit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = User(
      uid: 'resident-test',
      email: 'resident@example.com',
      role: UserRole.resident,
      name: 'Test Resident',
      barangay: 'Vito',
    );

    final selectedTab = ValueNotifier(2);
    addTearDown(selectedTab.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: RootExitPopScope(
          onRootBack: () => selectedTab.value == 2,
          child: ValueListenableBuilder<int>(
            valueListenable: selectedTab,
            builder: (context, tab, _) => ConcernCenterPage(
              initialCenterTab: 2,
              repository: _EmptySubmissionRepo(),
              categoryLoader: () async => const [],
              publicConcernsLoader: (_) => Stream.value(const []),
              isActiveRootTab: tab == 2,
              onRootBack: () => selectedTab.value = 0,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(selectedTab.value, 2);
    expect(find.text('Exit E-SUGID?'), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(selectedTab.value, 0);
    expect(find.text('Exit E-SUGID?'), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Exit E-SUGID?'), findsOneWidget);
  });
}
