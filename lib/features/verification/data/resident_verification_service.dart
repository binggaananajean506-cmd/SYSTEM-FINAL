import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

class ResidentVerificationSubmission {
  const ResidentVerificationSubmission({
    required this.birthDate,
    required this.contactNumber,
    required this.documentType,
    required this.otherDocumentName,
    required this.documentPath,
    required this.submissionStage,
    this.frontDocumentPath,
    this.backDocumentPath,
  });

  final String birthDate;
  final String contactNumber;
  final String documentType;
  final String otherDocumentName;
  final String documentPath;
  final String submissionStage;
  final String? frontDocumentPath;
  final String? backDocumentPath;

  Map<String, dynamic> toMap() => {
    'birthDate': birthDate,
    'contactNumber': contactNumber,
    'documentType': documentType,
    'otherDocumentName': otherDocumentName,
    'documentPath': documentPath,
    'submissionStage': submissionStage,
    if (frontDocumentPath != null) 'frontDocumentPath': frontDocumentPath,
    if (backDocumentPath != null) 'backDocumentPath': backDocumentPath,
  };
}

class ResidentVerificationService {
  ResidentVerificationService._();

  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-southeast1',
  );

  static Future<void> submit(ResidentVerificationSubmission submission) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Please sign in again before submitting verification.');
    }
    await user.getIdToken(true);
    await _functions
        .httpsCallable('submitResidentVerification')
        .call<void>(submission.toMap());
  }
}
