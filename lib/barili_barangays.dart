/// Official barangays of the Municipality of Barili, Cebu.
/// Source: Philippine Standard Geographic Code, Philippine Statistics Authority.
/// https://psa.gov.ph/classification/psgc/barangays/0702210000
const List<String> bariliBarangays = [
  'Azucena',
  'Bagakay',
  'Balao',
  'Bolocboloc',
  'Budbud',
  'Bugtong Kawayan',
  'Cabcaban',
  'Campangga',
  'Dakit',
  'Giloctog',
  'Guibuangan',
  'Giwanon',
  'Gunting',
  'Hilasgasan',
  'Japitan',
  'Cagay',
  'Kalubihan',
  'Kangdampas',
  'Candugay',
  'Luhod',
  'Lupo',
  'Luyo',
  'Maghanoy',
  'Maigang',
  'Malolos',
  'Mantalongon',
  'Mantayupan',
  'Mayana',
  'Minolos',
  'Nabunturan',
  'Nasipit',
  'Pancil',
  'Pangpang',
  'Paril',
  'Patupat',
  'Poblacion',
  'San Rafael',
  'Santa Ana',
  'Sayaw',
  'Tal-ot',
  'Tubod',
  'Vito',
];

/// Returns the official spelling for a Barili barangay value stored in a user
/// profile or post. Older profiles may contain values such as "Barangay Vito".
String? canonicalBariliBarangay(String? value) {
  final cleaned = value
      ?.trim()
      .replaceFirst(
        RegExp(r'^(barangay|brgy\.?|bgy\.?)\s+', caseSensitive: false),
        '',
      )
      .trim();
  if (cleaned == null || cleaned.isEmpty) return null;
  for (final barangay in bariliBarangays) {
    if (barangay.toLowerCase() == cleaned.toLowerCase()) return barangay;
  }
  return null;
}

/// Stable audience key used by announcement queries and notification topics.
/// Display names remain in Firestore for compatibility with existing posts.
String? barangayAudienceKey(String? value) {
  final barangay = canonicalBariliBarangay(value);
  return barangay == null ? null : 'barangay:$barangay';
}

/// Stable Firestore relationship key for a Barili barangay.
///
/// Human-readable barangay names remain in documents for presentation and
/// backwards compatibility, while authorization and queue routing use this
/// key. Do not derive authorization from a user-editable display label.
String? bariliBarangayId(String? value) {
  final barangay = canonicalBariliBarangay(value);
  if (barangay == null) return null;
  final slug = barangay
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return 'barili_$slug';
}

/// Resolves a stored stable ID back to its official display name.
String? bariliBarangayNameForId(String? id) {
  final normalized = id?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) return null;
  for (final barangay in bariliBarangays) {
    if (bariliBarangayId(barangay) == normalized) return barangay;
  }
  return null;
}

const String bariliMunicipalityAudienceKey = 'municipality:barili';
