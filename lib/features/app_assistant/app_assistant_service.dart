import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth_service.dart';
import '../../services/concern_draft_store.dart';
import 'app_route_registry.dart';

export 'app_route_registry.dart';

class AssistantMessage {
  const AssistantMessage({
    required this.text,
    required this.isUser,
    this.action = const AssistantNavigationAction(),
    this.actionLabel,
  });

  final String text;
  final bool isUser;
  final AssistantNavigationAction action;
  final String? actionLabel;

  AssistantDestination get destination => action.destination;
}

class AssistantReply {
  const AssistantReply({
    required this.text,
    this.action = const AssistantNavigationAction(),
    this.actionLabel,
  });

  final String text;
  final AssistantNavigationAction action;
  final String? actionLabel;

  AssistantDestination get destination => action.destination;
}

typedef AssistantCallable =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> request);
typedef AssistantContextLoader =
    Future<Map<String, dynamic>> Function(User user, String question);

class AppAssistantService {
  AppAssistantService({
    AssistantCallable? callable,
    AssistantContextLoader? contextLoader,
  }) : _callable = callable ?? _callFirebase,
       _contextLoader = contextLoader ?? _loadLocalContext;

  static const quickQuestions = <String>[
    'What is E-SUGID?',
    'Can I submit a concern here?',
    'Where can I find the hotlines?',
  ];

  final AssistantCallable _callable;
  final AssistantContextLoader _contextLoader;

  Future<AssistantReply> ask({
    required String question,
    required User user,
    required List<AssistantMessage> history,
  }) async {
    final cleanQuestion = question.trim();
    if (cleanQuestion.isEmpty) {
      throw const FormatException('Please enter a question.');
    }

    final instant = instantReply(cleanQuestion, user.role);
    if (instant != null) return instant;

    final localContext = await _contextLoader(user, cleanQuestion);
    final response = await _callable({
      'question': cleanQuestion,
      'role': user.role.name,
      'routes': AppAssistantRouteRegistry.contextFor(user.role),
      'clientContext': localContext,
      'history': history
          .where((message) => message.text.trim().isNotEmpty)
          .takeLast(6)
          .map(
            (message) => {
              'role': message.isUser ? 'user' : 'assistant',
              'text': message.text.trim(),
            },
          )
          .toList(),
    });

    final answer = response['answer']?.toString().trim() ?? '';
    if (answer.isEmpty) {
      throw StateError('The assistant returned an empty response.');
    }
    final destination = destinationFromName(response['action']?.toString());
    final allowedDestination = _allowedDestination(destination, user.role);
    final actionData = response['actionData'];
    final data = actionData is Map
        ? Map<String, dynamic>.from(actionData)
        : const <String, dynamic>{};
    return AssistantReply(
      text: answer,
      action: AssistantNavigationAction(
        destination: allowedDestination,
        resourceId: _safeActionValue(data['resourceId']),
        query: _safeActionValue(data['query']),
      ),
      actionLabel: response['actionLabel']?.toString().trim(),
    );
  }

  static AssistantReply? instantReply(String question, UserRole role) {
    final normalized = question
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
    final isBisaya = _looksBisaya(normalized);
    final asksAboutESugid =
        normalized == 'what is e sugid' ||
        ((normalized.contains('unsa') || normalized.contains('unsay')) &&
            normalized.contains('e sugid'));
    final asksAboutConcern =
        normalized == 'can i submit a concern here' ||
        (normalized.contains('concern') &&
            (normalized.contains('pwede') || normalized.contains('makapasa')));
    final asksAboutHotlines =
        normalized == 'where can i find the hotlines' ||
        (normalized.contains('hotline') &&
            (normalized.contains('asa') ||
                normalized.contains('diin') ||
                normalized.contains('makita')));
    if (asksAboutESugid) {
      return AssistantReply(
        text: isBisaya
            ? 'Ang E-SUGID mao ang community information ug services app sa Barili. Dinhi makita ang opisyal nga pahibalo, emergency information, concerns, Bayanihan help, ug lokal nga serbisyo sa usa ka kasaligan nga lugar.'
            : 'E-SUGID is Barili’s community information and services app. It brings official announcements, emergency information, concerns, Bayanihan help, and local services into one trusted place.',
      );
    }
    if (asksAboutConcern) {
      if (role != UserRole.resident) {
        return AssistantReply(
          text: isBisaya
              ? 'Ang pag-submit og concern para ra sa resident accounts. Ang imong staff o organization account adunay kaugalingong mga gamit sumala sa imong role.'
              : 'Concern submission is available to resident accounts. Your current staff or organization account can manage its role-specific tools instead.',
        );
      }
      return AssistantReply(
        text: isBisaya
            ? 'Oo. Ablihi ang Concern, pilia ang opisina nga modawat niini, kompletoha ang form, ug i-submit. Makabalik usab ka didto aron susihon ang status.'
            : 'Yes. Open Concern, choose the office that should receive it, complete the form, and submit it. You can also return there later to track its status.',
        action: const AssistantNavigationAction(
          destination: AssistantDestination.fileConcern,
        ),
        actionLabel: 'Open Concern',
      );
    }
    if (asksAboutHotlines) {
      return AssistantReply(
        text: isBisaya
            ? role == UserRole.resident
                  ? 'Ablihi ang Alerts, dayon pilia ang Hotlines. I-tap ang phone icon aron direktang maablihan ang dialer sa imong telepono.'
                  : 'Ablihi ang Emergency Center aron makita ang kasamtangang safety information. Ang resident app adunay kaugalingong Hotlines tab.'
            : role == UserRole.resident
            ? 'Open Alerts, then choose Hotlines. You can tap a phone icon there to open your phone dialer.'
            : 'Open the Emergency Center to view current safety information. The resident app also provides a dedicated Hotlines tab.',
        action: AssistantNavigationAction(
          destination: role == UserRole.resident
              ? AssistantDestination.hotlines
              : AssistantDestination.emergencyCenter,
        ),
        actionLabel: role == UserRole.resident
            ? 'Open Hotlines'
            : 'Open Emergency Center',
      );
    }
    return null;
  }

  static bool _looksBisaya(String normalized) {
    const bisayaWords = <String>{
      'asa',
      'diin',
      'unsa',
      'unsay',
      'pwede',
      'palihog',
      'makita',
      'makapasa',
      'akong',
      'nimo',
      'dinhi',
    };
    return normalized.split(' ').any(bisayaWords.contains);
  }

  static AssistantDestination destinationFromName(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == 'alerts') return AssistantDestination.emergencyCenter;
    if (normalized == 'concern') return AssistantDestination.fileConcern;
    return AssistantDestination.values.firstWhere(
      (destination) => destination.name.toLowerCase() == normalized,
      orElse: () => AssistantDestination.none,
    );
  }

  static AssistantDestination _allowedDestination(
    AssistantDestination destination,
    UserRole role,
  ) {
    return AppAssistantRouteRegistry.allows(destination, role)
        ? destination
        : AssistantDestination.none;
  }

  static String? _safeActionValue(Object? value) {
    final result = value?.toString().trim() ?? '';
    return result.isEmpty
        ? null
        : result.substring(0, result.length.clamp(0, 160));
  }

  static Future<Map<String, dynamic>> _loadLocalContext(
    User user,
    String question,
  ) async {
    if (user.role != UserRole.resident ||
        !RegExp(
          r'\b(draft|unfinished|continue.*concern|save.*concern|gisave|wala.*nahuman|ipadayon)\b',
          caseSensitive: false,
        ).hasMatch(question)) {
      return const {};
    }
    final preferences = await SharedPreferences.getInstance();
    final drafts = ConcernDraftStore(preferences, user.uid).list();
    return {
      'manualDraftCount': drafts.length,
      if (drafts.isNotEmpty) ...{
        'latestDraftId': drafts.first['id']?.toString(),
        'latestDraftUpdatedAt': drafts.first['updatedAt']?.toString(),
      },
    };
  }

  static Future<Map<String, dynamic>> _callFirebase(
    Map<String, dynamic> request,
  ) async {
    final functions = FirebaseFunctions.instanceFor(region: 'asia-southeast1');
    final result = await functions
        .httpsCallable(
          'askESugidAssistant',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 50)),
        )
        .call<Map<String, dynamic>>(request);
    return Map<String, dynamic>.from(result.data);
  }
}

extension<T> on Iterable<T> {
  Iterable<T> takeLast(int count) {
    final values = toList(growable: false);
    return values.skip(values.length > count ? values.length - count : 0);
  }
}
