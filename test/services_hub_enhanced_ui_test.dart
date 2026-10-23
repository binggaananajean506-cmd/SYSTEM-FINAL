import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:esugid/auth_service.dart';
import 'package:esugid/features/app_assistant/app_assistant_launcher.dart';
import 'package:esugid/features/app_assistant/app_assistant_service.dart';
import 'package:esugid/features/home/presentation/hub_service_cards.dart';

void main() {
  final resident = User(
    uid: 'resident-test-1',
    email: 'resident@barili.gov.ph',
    role: UserRole.resident,
    name: 'Ana Resident',
  );

  group('Compact AI Launcher & One-Page Assistant', () {
    testWidgets('AppAssistantLauncher displays a compact accessible icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppAssistantLauncher(user: resident, onNavigate: (_) {}),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('assistant-floating-icon')),
        findsOneWidget,
      );
      expect(
        tester.getSize(find.byType(AppAssistantLauncher)),
        const Size(64, 64),
      );
      expect(
        find.bySemanticsLabel('Open E-SUGID AI Assistant'),
        findsOneWidget,
      );
    });

    testWidgets('AppAssistantSheet renders complete one-page assistant UI', (
      tester,
    ) async {
      AssistantNavigationAction? navigatedAction;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppAssistantSheet(
              user: resident,
              service: AppAssistantService(callable: (_) async => {}),
              onNavigate: (action) => navigatedAction = action,
            ),
          ),
        ),
      );

      // Header elements
      expect(find.text('E-SUGID Assistant'), findsOneWidget);
      expect(find.text('ONLINE'), findsOneWidget);
      expect(find.text('QUICK INQUIRIES'), findsOneWidget);

      // Quick Questions
      for (final question in AppAssistantService.quickQuestions) {
        expect(find.text(question), findsOneWidget);
      }

      // Input dock
      expect(find.byKey(const Key('assistant-input')), findsOneWidget);
      expect(find.byKey(const Key('assistant-send')), findsOneWidget);

      // Tap quick question and verify action button appears
      await tester.tap(find.text('Can I submit a concern here?'));
      await tester.pumpAndSettle();

      expect(find.text('Open Concern'), findsOneWidget);

      // Tap action button and verify navigation
      await tester.tap(find.text('Open Concern'));
      await tester.pumpAndSettle();
      expect(navigatedAction?.destination, AssistantDestination.fileConcern);
    });
  });

  group('Enhanced Services Cards UI & Text Streamlining', () {
    testWidgets('Civic utility cards render cleanly without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedUtilityCard(
                          icon: Icons.map_rounded,
                          title: 'Civic Map',
                          subtitle: '37 Barangays & spots',
                          accent: const Color(0xFF059669),
                          gradient: const [
                            Color(0xFF10B981),
                            Color(0xFF059669),
                          ],
                          onTap: () {},
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedUtilityCard(
                          icon: Icons.calendar_month_rounded,
                          title: 'Town Calendar',
                          subtitle: 'Schedules & events',
                          accent: const Color(0xFF6366F1),
                          gradient: const [
                            Color(0xFF818CF8),
                            Color(0xFF4F46E5),
                          ],
                          onTap: () {},
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedUtilityCard(
                          icon: Icons.wb_cloudy_rounded,
                          title: 'Weather Watch',
                          subtitle: 'Forecast & advisories',
                          accent: const Color(0xFF0284C7),
                          gradient: const [
                            Color(0xFF38BDF8),
                            Color(0xFF0284C7),
                          ],
                          onTap: () {},
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedUtilityCard(
                          icon: Icons.explore_rounded,
                          title: 'Explore Barili',
                          subtitle: 'Tourism & heritage',
                          accent: const Color(0xFFEA580C),
                          gradient: const [
                            Color(0xFFFB923C),
                            Color(0xFFEA580C),
                          ],
                          onTap: () {},
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Civic Map'), findsOneWidget);
      expect(find.text('Town Calendar'), findsOneWidget);
      expect(find.text('Weather Watch'), findsOneWidget);
      expect(find.text('Explore Barili'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Streamlined PrioritizedCommunityCards display concise text', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Row(
                children: [
                  Expanded(
                    child: PrioritizedCommunityCard(
                      icon: Icons.volunteer_activism_rounded,
                      title: 'Bayanihan Works',
                      subtitle: 'Community mutual aid & tasks',
                      badge: '🤝 MUTUAL AID',
                      actionLabel: 'Browse Tasks',
                      primaryGradient: const [
                        Color(0xFF0D9488),
                        Color(0xFF047857),
                      ],
                      accentColor: const Color(0xFF0D9488),
                      watermarkIcon: Icons.handshake_rounded,
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PrioritizedCommunityCard(
                      icon: Icons.storefront_rounded,
                      title: 'Local Market',
                      subtitle: 'Local goods, produce & crafts',
                      badge: '🛒 COMMERCE',
                      actionLabel: 'Shop Local',
                      primaryGradient: const [
                        Color(0xFFF59E0B),
                        Color(0xFFD97706),
                      ],
                      accentColor: const Color(0xFFD97706),
                      watermarkIcon: Icons.shopping_basket_rounded,
                      onTap: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Bayanihan Works'), findsOneWidget);
      expect(find.text('Community mutual aid & tasks'), findsOneWidget);
      expect(find.text('Browse Tasks'), findsOneWidget);

      expect(find.text('Local Market'), findsOneWidget);
      expect(find.text('Local goods, produce & crafts'), findsOneWidget);
      expect(find.text('Shop Local'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
