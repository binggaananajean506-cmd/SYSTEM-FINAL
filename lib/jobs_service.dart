import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import 'firestore_converters.dart';

class JobItem {
  final String id;
  final String posterId;
  final String? helperId;
  final String title;
  final String company;
  final String salary;
  final String type;
  final String description;
  final String location;
  final String contact;
  final String category; // 'request' or 'offer'
  final String helpCategory;
  final String urgency;
  final String dateNeeded;
  final DateTime? scheduledAt;
  final String? imageUrl;
  final DateTime createdAt;
  final String status; // 'Active', 'Completed'
  final String contactPreference; // 'Calls', 'Messages', 'Both'
  final int helpersNeeded;
  final int acceptedHelperCount;

  JobItem({
    required this.id,
    required this.posterId,
    this.helperId,
    required this.title,
    required this.company,
    required this.salary,
    required this.type,
    required this.description,
    this.location = '',
    this.contact = '',
    this.category = 'offer',
    this.helpCategory = '',
    this.urgency = 'Normal',
    this.dateNeeded = '',
    this.scheduledAt,
    this.imageUrl,
    required this.createdAt,
    this.status = 'Active',
    this.contactPreference = 'Both',
    this.helpersNeeded = 1,
    this.acceptedHelperCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'posterId': posterId,
      'helperId': helperId,
      'title': title,
      'company': company,
      'salary': salary,
      'type': type,
      'description': description,
      'location': location,
      'contact': contact,
      'category': category,
      'helpCategory': helpCategory,
      'urgency': urgency,
      'dateNeeded': dateNeeded,
      'scheduledAt': scheduledAt == null
          ? null
          : Timestamp.fromDate(scheduledAt!),
      'imageUrl': imageUrl,
      'createdAt': createdAt.toIso8601String(),
      'status': status,
      'contactPreference': contactPreference,
      'helpersNeeded': helpersNeeded,
      'acceptedHelperCount': acceptedHelperCount,
    };
  }

  factory JobItem.fromMap(Map<String, dynamic> map) {
    return JobItem(
      id: map['id'] ?? '',
      posterId: map['posterId'] ?? '',
      helperId: map['helperId'],
      title: map['title'] ?? '',
      company: map['company'] ?? '',
      salary: map['salary'] ?? '',
      type: map['type'] ?? '',
      description: map['description'] ?? '',
      location: map['location'] ?? '',
      contact: map['contact'] ?? '',
      category: map['category'] ?? 'offer',
      helpCategory: map['helpCategory'] ?? '',
      urgency: map['urgency'] ?? 'Normal',
      dateNeeded: map['dateNeeded'] ?? '',
      scheduledAt: nullableDateTimeFromFirestore(map['scheduledAt']),
      imageUrl: map['imageUrl'],
      createdAt: dateTimeFromFirestore(map['createdAt']),
      status: map['status'] ?? 'Active',
      contactPreference: map['contactPreference'] ?? 'Both',
      helpersNeeded: _positiveInt(map['helpersNeeded'], fallback: 1),
      acceptedHelperCount: _positiveInt(
        map['acceptedHelperCount'],
        fallback: 0,
        allowZero: true,
      ),
    );
  }

  static int _positiveInt(
    Object? value, {
    required int fallback,
    bool allowZero = false,
  }) {
    final parsed = value is num ? value.toInt() : int.tryParse('$value');
    if (parsed == null || parsed < (allowZero ? 0 : 1)) return fallback;
    return parsed;
  }
}

class JobsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Stream<List<JobItem>> get jobsStream => _firestore
      .collection('jobs')
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) => JobItem.fromMap(doc.data())).toList(),
      );

  static Future<void> addJob(JobItem job) async {
    if (AuthService.currentUser?.isRestricted == true) {
      throw StateError('Account Restricted: Your account currently has limited access. Please contact your barangay office for assistance.');
    }
    await _firestore.collection('jobs').doc(job.id).set(job.toMap());
  }

  static Future<void> updateJob(JobItem job) async {
    await _firestore
        .collection('jobs')
        .doc(job.id)
        .set(job.toMap(), SetOptions(merge: true));
  }

  static Future<void> deleteJob(String jobId) async {
    await _firestore.collection('jobs').doc(jobId).delete();
  }

  static Future<JobItem?> getJob(String jobId) async {
    final snapshot = await _firestore.collection('jobs').doc(jobId).get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) return null;
    return JobItem.fromMap({...data, 'id': snapshot.id});
  }
}
