import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';
import 'firestore_converters.dart';

String normalizeEmergencyStatus(String value) {
  final normalized = value.trim().toLowerCase().replaceAll(' ', '_');
  return switch (normalized) {
    'received' => 'acknowledged',
    'dispatched' || 'in_progress' => 'responding',
    _ => normalized.isEmpty ? 'submitted' : normalized,
  };
}

bool canTransitionEmergencyStatus(String from, String to) {
  final current = normalizeEmergencyStatus(from);
  final next = normalizeEmergencyStatus(to);
  return switch (current) {
    'submitted' => next == 'acknowledged',
    'acknowledged' => next == 'responding' || next == 'resolved',
    'responding' => next == 'resolved',
    _ => false,
  };
}

class EmergencyReport {
  final String id;
  final String reporterId;
  final String reporterName;
  final String contactNumber;
  final String barangay;
  final String emergencyType;
  final String description;
  final String location;
  final String routedAgency;
  final String routingKey;
  final String status;
  final String imageUrl;
  final String imageStoragePath;
  final DateTime createdAt;

  const EmergencyReport({
    required this.id,
    required this.reporterId,
    required this.reporterName,
    required this.contactNumber,
    required this.barangay,
    required this.emergencyType,
    required this.description,
    required this.location,
    required this.routedAgency,
    required this.routingKey,
    this.status = 'submitted',
    this.imageUrl = '',
    this.imageStoragePath = '',
    required this.createdAt,
  });

  factory EmergencyReport.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? {};
    final timestamp = data['createdAt'];
    final localDate = data['createdAtLocal']?.toString();
    return EmergencyReport(
      id: data['id']?.toString() ?? document.id,
      reporterId: data['reporterId']?.toString() ?? '',
      reporterName: data['reporterName']?.toString() ?? 'Resident',
      contactNumber: data['contactNumber']?.toString() ?? '',
      barangay: data['barangay']?.toString() ?? '',
      emergencyType: data['emergencyType']?.toString() ?? 'Other Emergency',
      description: data['description']?.toString() ?? '',
      location: data['location']?.toString() ?? '',
      routedAgency: data['routedAgency']?.toString() ?? 'Local responders',
      routingKey: data['routingKey']?.toString() ?? 'barangay',
      status: normalizeEmergencyStatus(
        data['status']?.toString() ?? 'submitted',
      ),
      imageUrl: data['imageUrl']?.toString() ?? '',
      imageStoragePath: data['imageStoragePath']?.toString() ?? '',
      createdAt: dateTimeFromFirestore(timestamp ?? localDate),
    );
  }
}

class EmergencyRoute {
  final String agency;
  final String key;

  const EmergencyRoute(this.agency, this.key);
}

class EmergencyService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final Map<String, Stream<List<EmergencyReport>>> _responderStreams =
      {};

  static EmergencyRoute routeFor(String emergencyType) {
    return switch (emergencyType) {
      'Fire' => const EmergencyRoute('Bureau of Fire Protection', 'bfp'),
      'Medical' => const EmergencyRoute(
        'Municipal Health / Emergency Medical Team',
        'health',
      ),
      'Crime or Threat' => const EmergencyRoute(
        'Philippine National Police',
        'pnp',
      ),
      'Flood or Disaster' => const EmergencyRoute(
        'Municipal Disaster Risk Reduction Office',
        'mdrrmo',
      ),
      'Electrical Hazard' => const EmergencyRoute('CEBECO', 'cebeco'),
      _ => const EmergencyRoute('Barangay Emergency Responders', 'barangay'),
    };
  }

  static Future<void> updateStatus(
    String reportId,
    String status, {
    required String updatedBy,
  }) async {
    final reference = _firestore.collection('emergency_reports').doc(reportId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final current = snapshot.data()?['status']?.toString() ?? 'submitted';
      final next = normalizeEmergencyStatus(status);
      if (!canTransitionEmergencyStatus(current, next)) {
        throw StateError('This emergency status can no longer be changed.');
      }
      transaction.update(reference, {
        'status': next,
        'statusUpdatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
        'statusHistory': FieldValue.arrayUnion([
          {
            'status': next,
            'updatedBy': updatedBy,
            'updatedAt': Timestamp.now(),
          },
        ]),
      });
    });
  }

  static void clearCaches() {
    _responderStreams.clear();
  }

  static Stream<List<EmergencyReport>> reportsForResponder(User user) {
    final key = [
      user.uid,
      user.role.name,
      user.barangay ?? '',
      user.organizationName ?? user.name,
    ].join('|');
    return _responderStreams.putIfAbsent(key, () {
      Query<Map<String, dynamic>>? reportQuery;
      if (user.role == UserRole.lgu) {
        reportQuery = _firestore.collection('emergency_reports');
      } else if (user.role == UserRole.barangay) {
        final barangay = user.barangay?.trim() ?? '';
        if (barangay.isEmpty) {
          return Stream<List<EmergencyReport>>.value(
            const <EmergencyReport>[],
          ).asBroadcastStream();
        }
        reportQuery = _firestore
            .collection('emergency_reports')
            .where('barangay', isEqualTo: barangay);
      } else if (user.role == UserRole.partner) {
        final routingKeys = _partnerRoutingKeys(user);
        if (routingKeys.isEmpty) {
          return Stream<List<EmergencyReport>>.value(
            const <EmergencyReport>[],
          ).asBroadcastStream();
        }
        reportQuery = _firestore
            .collection('emergency_reports')
            .where('routingKey', whereIn: routingKeys);
      } else {
        return Stream<List<EmergencyReport>>.value(
          const <EmergencyReport>[],
        ).asBroadcastStream();
      }
      return reportQuery.snapshots().map((snapshot) {
        final reports = snapshot.docs.map(EmergencyReport.fromDoc).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return reports;
      }).asBroadcastStream(
        onCancel: (sub) {
          sub.cancel();
          _responderStreams.remove(key);
        },
      );
    });
  }

  static Future<List<EmergencyReport>> fetchReportsFromServer(User user) async {
    Query<Map<String, dynamic>>? reportQuery;
    if (user.role == UserRole.lgu) {
      reportQuery = _firestore.collection('emergency_reports');
    } else if (user.role == UserRole.barangay) {
      final barangay = user.barangay?.trim() ?? '';
      if (barangay.isEmpty) return const [];
      reportQuery = _firestore
          .collection('emergency_reports')
          .where('barangay', isEqualTo: barangay);
    } else if (user.role == UserRole.partner) {
      final routingKeys = _partnerRoutingKeys(user);
      if (routingKeys.isEmpty) return const [];
      reportQuery = _firestore
          .collection('emergency_reports')
          .where('routingKey', whereIn: routingKeys);
    } else {
      return const [];
    }

    final snapshot = await reportQuery.get(
      const GetOptions(source: Source.server),
    );
    return snapshot.docs.map(EmergencyReport.fromDoc).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static List<String> _partnerRoutingKeys(User user) {
    final organization = (user.organizationName ?? user.name).toLowerCase();
    const routes = {
      'bfp': ['bfp', 'fire protection', 'fire station'],
      'pnp': ['pnp', 'police'],
      'cebeco': ['cebeco', 'electric cooperative'],
      'health': ['health', 'medical', 'hospital', 'ambulance'],
      'mdrrmo': ['mdrrmo', 'disaster', 'rescue'],
    };
    return routes.entries
        .where(
          (entry) =>
              entry.value.any((keyword) => organization.contains(keyword)),
        )
        .map((entry) => entry.key)
        .toList(growable: false);
  }
}
