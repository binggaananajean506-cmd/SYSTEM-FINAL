import 'package:cloud_functions/cloud_functions.dart';

class ConcernRecipient {
  const ConcernRecipient({
    required this.id,
    required this.displayName,
    required this.type,
    required this.categoriesHandled,
  });

  final String id;
  final String displayName;
  final String type;
  final List<String> categoriesHandled;

  factory ConcernRecipient.fromMap(Map<String, dynamic> data) {
    return ConcernRecipient(
      id: data['recipientId']?.toString() ?? data['id']?.toString() ?? '',
      displayName: data['displayName']?.toString() ?? 'Receiving office',
      type: data['recipientType']?.toString() ?? '',
      categoriesHandled:
          (data['categoriesHandled'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .where((item) => item.trim().isNotEmpty)
              .toList(growable: false),
    );
  }
}

abstract interface class ConcernRecipientRepository {
  Future<List<ConcernRecipient>> listAvailableRecipients();
}

class FirebaseConcernRecipientRepository implements ConcernRecipientRepository {
  const FirebaseConcernRecipientRepository();

  @override
  Future<List<ConcernRecipient>> listAvailableRecipients() async {
    final callable = FirebaseFunctions.instanceFor(
      region: 'asia-southeast1',
    ).httpsCallable('listConcernRecipients');
    final response = await callable.call<Map<String, dynamic>>();
    final raw = response.data['recipients'] as List<dynamic>? ?? const [];
    return raw
        .whereType<Map>()
        .map(
          (item) => ConcernRecipient.fromMap(Map<String, dynamic>.from(item)),
        )
        .where((item) => item.id.isNotEmpty && item.type.isNotEmpty)
        .toList(growable: false);
  }
}
