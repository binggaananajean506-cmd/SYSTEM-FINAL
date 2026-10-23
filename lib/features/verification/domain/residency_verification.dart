import 'package:intl/intl.dart';

import '../../../auth_service.dart';

class AcceptedResidencyDocument {
  const AcceptedResidencyDocument({
    required this.label,
    required this.code,
    required this.description,
  });

  final String label;
  final String code;
  final String description;
}

/// A short, resident-friendly list of proofs that normally show an address.
/// The barangay official still makes the final residency decision.
const acceptedResidencyDocuments = <AcceptedResidencyDocument>[
  AcceptedResidencyDocument(
    code: 'national_id',
    label: 'National ID',
    description: 'Philippine National ID/ePhilID showing your current address',
  ),
  AcceptedResidencyDocument(
    code: 'drivers_license',
    label: "Driver's License",
    description: "LTO driver's license showing your current address",
  ),
  AcceptedResidencyDocument(
    code: 'postal_id',
    label: 'Postal ID',
    description: 'Postal identification card showing your home address',
  ),
  AcceptedResidencyDocument(
    code: 'barangay_certificate',
    label: 'Barangay Certificate',
    description: 'Certificate showing that you live in your barangay',
  ),
  AcceptedResidencyDocument(
    code: 'other_proof',
    label: 'Other Proof',
    description:
        'Another official document showing your name and current address',
  ),
];

final residencyVerificationDocumentTypes = List<String>.unmodifiable(
  acceptedResidencyDocuments.map((document) => document.label),
);

final additionalResidencyDocumentTypes = residencyVerificationDocumentTypes;

DateTime? parseResidentBirthDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return DateTime(value.year, value.month, value.day);
  final text = value.toString().trim();
  if (text.isEmpty) return null;

  // 1. Direct tryParse (ISO-8601 like 2005-09-15 or 2005-09-15T00:00:00.000)
  final dateOnly = text.contains('T') ? text.split('T').first.trim() : text;
  final direct = DateTime.tryParse(dateOnly) ?? DateTime.tryParse(text);
  if (direct != null) {
    return DateTime(direct.year, direct.month, direct.day);
  }

  // 2. Common slash patterns: MM/dd/yyyy or M/d/yyyy
  final slashMatch =
      RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(dateOnly);
  if (slashMatch != null) {
    final m = int.tryParse(slashMatch.group(1)!);
    final d = int.tryParse(slashMatch.group(2)!);
    final y = int.tryParse(slashMatch.group(3)!);
    if (m != null && d != null && y != null) {
      try {
        final parsed = DateTime(y, m, d);
        if (parsed.year == y && parsed.month == m && parsed.day == d) {
          return parsed;
        }
      } catch (_) {}
    }
  }

  // 3. Human-readable and common locale date patterns
  final patterns = [
    'MMMM d, yyyy',
    'MMM d, yyyy',
    'd MMMM yyyy',
    'd MMM yyyy',
    'MM/dd/yyyy',
    'M/d/yyyy',
    'yyyy-MM-dd',
    'MM-dd-yyyy',
    'yyyy/MM/dd',
  ];
  for (final pattern in patterns) {
    try {
      final parsed = DateFormat(pattern).parseLoose(text);
      return DateTime(parsed.year, parsed.month, parsed.day);
    } catch (_) {}
  }

  return null;
}

String registrationBirthDateValue(DateTime date) =>
    '${date.month.toString().padLeft(2, '0')}/'
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.year.toString().padLeft(4, '0')}';

String storedBirthDateValue(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

int residentAge(DateTime birthDate, {DateTime? onDate}) {
  final today = onDate ?? DateTime.now();
  var age = today.year - birthDate.year;
  if (today.month < birthDate.month ||
      (today.month == birthDate.month && today.day < birthDate.day)) {
    age -= 1;
  }
  return age;
}

String? validateResidentBirthDate(String? value, {DateTime? now}) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Birth date is required';
  if (!RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(text)) {
    return 'Use MM/DD/YYYY';
  }
  final date = parseResidentBirthDate(text);
  if (date == null) return 'Enter a real date';
  final today = now ?? DateTime.now();
  final todayOnly = DateTime(today.year, today.month, today.day);
  if (date.isAfter(todayOnly)) return 'Birth date cannot be in the future';
  return null;
}

bool verificationAcceptsInitialDocument(VerificationStatus status) {
  return status == VerificationStatus.notVerified ||
      status == VerificationStatus.rejected;
}

bool verificationRequiresAdditionalDocument(VerificationStatus status) {
  return status == VerificationStatus.additionalDocumentRequired;
}

bool verificationIsWaitingForReview(VerificationStatus status) {
  return status == VerificationStatus.submitted ||
      status == VerificationStatus.underReview;
}
