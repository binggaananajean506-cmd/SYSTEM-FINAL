import 'package:flutter_test/flutter_test.dart';

import 'package:esugid/auth_service.dart';
import 'package:esugid/features/app_assistant/app_assistant_service.dart';

void main() {
  final resident = User(
    uid: 'resident-1',
    email: 'resident@example.com',
    role: UserRole.resident,
    name: 'Resident User',
  );
  final barangayOfficial = User(
    uid: 'official-1',
    email: 'official@example.com',
    role: UserRole.barangay,
    name: 'Barangay Official',
  );

  test('quick questions keep the E-SUGID explanation first', () {
    expect(AppAssistantService.quickQuestions, const [
      'What is E-SUGID?',
      'Can I submit a concern here?',
      'Where can I find the hotlines?',
    ]);
  });

  test('built-in E-SUGID explanation does not call Gemini', () async {
    var wasCalled = false;
    final service = AppAssistantService(
      callable: (_) async {
        wasCalled = true;
        return {};
      },
    );

    final reply = await service.ask(
      question: 'What is E-SUGID?',
      user: resident,
      history: const [],
    );

    expect(wasCalled, isFalse);
    expect(reply.text, contains('Barili'));
    expect(reply.destination, AssistantDestination.none);
  });

  test('resident concern question offers direct concern navigation', () async {
    final service = AppAssistantService(callable: (_) async => {});

    final reply = await service.ask(
      question: 'Can I submit a concern here?',
      user: resident,
      history: const [],
    );

    expect(reply.destination, AssistantDestination.fileConcern);
    expect(reply.actionLabel, 'Open Concern');
  });

  test('Bisaya concern question receives a Bisaya navigation reply', () async {
    final service = AppAssistantService(callable: (_) async => {});

    final reply = await service.ask(
      question: 'Pwede ko maka-submit og concern dinhi?',
      user: resident,
      history: const [],
    );

    expect(reply.text, startsWith('Oo.'));
    expect(reply.destination, AssistantDestination.fileConcern);
    expect(reply.actionLabel, 'Open Concern');
  });

  test('staff account is not offered a resident concern route', () async {
    final service = AppAssistantService(callable: (_) async => {});

    final reply = await service.ask(
      question: 'Can I submit a concern here?',
      user: barangayOfficial,
      history: const [],
    );

    expect(reply.destination, AssistantDestination.none);
    expect(reply.text, contains('resident accounts'));
  });

  test(
    'free-form Gemini response is parsed into a navigation action',
    () async {
      late Map<String, dynamic> sentRequest;
      final service = AppAssistantService(
        callable: (request) async {
          sentRequest = request;
          return {
            'answer': 'Open Services, then choose Local Market.',
            'action': 'market',
            'actionLabel': 'Open Local Market',
          };
        },
      );

      final reply = await service.ask(
        question: 'Where can I sell vegetables?',
        user: resident,
        history: const [AssistantMessage(text: 'Older message', isUser: true)],
      );

      expect(sentRequest['role'], 'resident');
      expect(sentRequest['question'], 'Where can I sell vegetables?');
      expect(reply.destination, AssistantDestination.market);
      expect(reply.actionLabel, 'Open Local Market');
    },
  );

  test('parses an exact subpage action and its safe route data', () async {
    final service = AppAssistantService(
      callable: (_) async => {
        'answer': 'You can view them under Services > Municipal Officials.',
        'action': 'municipalOfficials',
        'actionLabel': 'View Municipal Officials',
        'actionData': {'query': 'Mayor'},
      },
    );

    final reply = await service.ask(
      question: 'Where can I see the municipal officials?',
      user: resident,
      history: const [],
    );

    expect(reply.destination, AssistantDestination.municipalOfficials);
    expect(reply.action.query, 'Mayor');
  });

  test('removes resident-only deep links returned to staff', () async {
    final service = AppAssistantService(
      callable: (_) async => {
        'answer': 'Concern filing is for resident accounts.',
        'action': 'fileConcern',
        'actionLabel': 'File a Concern',
      },
    );

    final reply = await service.ask(
      question: 'Open the concern form',
      user: barangayOfficial,
      history: const [],
    );

    expect(reply.destination, AssistantDestination.none);
  });

  test('supports direct actions for additional app destinations', () async {
    final service = AppAssistantService(
      callable: (_) async => {
        'answer': 'Here are your saved announcements.',
        'action': 'savedAnnouncements',
        'actionLabel': 'View Saved Announcements',
      },
    );

    final reply = await service.ask(
      question: 'Show my saved announcements',
      user: resident,
      history: const [],
    );

    expect(reply.destination, AssistantDestination.savedAnnouncements);
    expect(
      AppAssistantRouteRegistry.contextFor(
        UserRole.resident,
      ).map((entry) => entry['action']),
      containsAll(<String>[
        'notifications',
        'savedAnnouncements',
        'barangayMap',
        'bariliWeather',
        'myMarketListings',
        'bayanihanMessages',
      ]),
    );
  });

  test(
    'does not replace a concern process question with the quick reply',
    () async {
      var wasCalled = false;
      final service = AppAssistantService(
        callable: (_) async {
          wasCalled = true;
          return {
            'answer': 'Track updates in Concern Center > My Concerns.',
            'action': 'myConcerns',
            'actionLabel': 'View My Concerns',
          };
        },
      );

      final reply = await service.ask(
        question: 'What happens after I submit a concern?',
        user: resident,
        history: const [],
      );

      expect(wasCalled, isTrue);
      expect(reply.destination, AssistantDestination.myConcerns);
    },
  );
}
