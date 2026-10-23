import 'package:flutter/material.dart';

/// Represents an individual emergency contact number belonging to an agency.
class EmergencyContactNumber {
  const EmergencyContactNumber({
    required this.label,
    required this.number,
    this.isPrimary = false,
  });

  /// Descriptive label such as 'Mobile (Smart)', 'Mobile (Globe)', 'Station Landline'.
  final String label;

  /// The raw telephone or mobile number string.
  final String number;

  /// Whether this is the main direct number to dial.
  final bool isPrimary;

  /// Returns a clean dial-ready number for tel: scheme.
  String get dialUriString => number.replaceAll(RegExp(r'[^0-9+]'), '');
}

/// Represents an officially verified emergency agency in Barili / National.
class EmergencyAgency {
  const EmergencyAgency({
    required this.id,
    required this.name,
    required this.shortPurpose,
    required this.category,
    this.logoAsset,
    this.fallbackIcon = Icons.shield_outlined,
    this.isUrgent911 = false,
    required this.contactNumbers,
    this.address,
    this.mapQuery,
    this.officialPageUrl,
    this.officialPageName,
    this.lastUpdated = 'September 2026',
    this.verifiedLabel = 'Verified Emergency Contact',
  });

  final String id;
  final String name;
  final String shortPurpose;
  final String category;
  final String? logoAsset;
  final IconData fallbackIcon;
  final bool isUrgent911;
  final List<EmergencyContactNumber> contactNumbers;
  final String? address;
  final String? mapQuery;
  final String? officialPageUrl;
  final String? officialPageName;
  final String lastUpdated;
  final String verifiedLabel;

  /// Returns the primary contact number or the first available number.
  EmergencyContactNumber? get primaryNumber {
    if (contactNumbers.isEmpty) return null;
    return contactNumbers.firstWhere(
      (n) => n.isPrimary,
      orElse: () => contactNumbers.first,
    );
  }

  /// Master list of verified emergency agencies for E-SUGID Barili.
  static const List<EmergencyAgency> verifiedAgencies = [
    // 1. National Unified Emergency Hotline
    EmergencyAgency(
      id: '911',
      name: 'National Unified Emergency Hotline',
      shortPurpose:
          'Police, fire, ambulance/medical, rescue, disasters, and other urgent emergencies',
      category: 'National Emergency Hotline',
      fallbackIcon: Icons.emergency_rounded,
      isUrgent911: true,
      verifiedLabel: 'Verified National Emergency Hotline',
      contactNumbers: [
        EmergencyContactNumber(
          label: 'Unified Emergency Hotline (Toll-Free)',
          number: '911',
          isPrimary: true,
        ),
      ],
      address: 'National 24/7 Operations Center',
      officialPageUrl: 'https://e911.dilg.gov.ph',
      officialPageName: 'Emergency 911 National Commission (DILG)',
      lastUpdated: 'September 2026',
    ),

    // 2. Barili MDRRMO / Rescue & Office
    EmergencyAgency(
      id: 'mdrrmo',
      name: 'Barili MDRRMO / Rescue',
      shortPurpose:
          'Rescue, accidents, disasters, flooding, medical emergencies, evacuation',
      category: 'Disaster Risk Reduction & Rescue',
      logoAsset: 'assets/images/resident_dashboard/mdrrmo.png',
      fallbackIcon: Icons.flood_rounded,
      verifiedLabel: 'Verified Barili LGU Emergency Office',
      contactNumbers: [
        EmergencyContactNumber(
          label: 'Barili MDRRMO / Rescue Mobile',
          number: '0918-637-6365',
          isPrimary: true,
        ),
        EmergencyContactNumber(
          label: 'Barili MDRRMO Office Landline',
          number: '(032) 517-0950',
        ),
        EmergencyContactNumber(
          label: 'Alternative Mobile (Globe / TM)',
          number: '0927-537-3136',
        ),
      ],
      address:
          'MDRRMO Operations Center, Barili Municipal Hall Compound, Poblacion, Barili, Cebu',
      mapQuery: 'Barili Municipal Hall, Cebu',
      officialPageUrl:
          'https://www.facebook.com/profile.php?id=100072055826084',
      officialPageName: 'MDRRMO Barili Official Page',
      lastUpdated: 'September 2026',
    ),

    // 3. Barili Fire Station (BFP)
    EmergencyAgency(
      id: 'bfp',
      name: 'Barili Fire Station (BFP)',
      shortPurpose: 'Fire, rescue, and related emergencies',
      category: 'Bureau of Fire Protection (BFP)',
      logoAsset: 'assets/images/resident_dashboard/bfp.png',
      fallbackIcon: Icons.local_fire_department_rounded,
      verifiedLabel: 'Verified BFP Station R7',
      contactNumbers: [
        EmergencyContactNumber(
          label: 'Fire Station Mobile',
          number: '0969-410-1951',
          isPrimary: true,
        ),
        EmergencyContactNumber(
          label: 'Station Landline',
          number: '(032) 517-0833',
        ),
        EmergencyContactNumber(
          label: 'Mantalongon Fire Sub-Station',
          number: '0960-460-0329',
        ),
      ],
      address: 'Barili Fire Station, Poblacion, Barili, Cebu',
      mapQuery: 'Barili Fire Station, Barili, Cebu',
      officialPageUrl: 'https://www.facebook.com/barilifirestation',
      officialPageName: 'BFP R7 Barili Fire Station Official Page',
      lastUpdated: 'September 2026',
    ),

    // 4. Barili Municipal Police Station (PNP)
    EmergencyAgency(
      id: 'pnp',
      name: 'Barili Municipal Police Station (PNP)',
      shortPurpose: 'Crime, accidents, public safety, police emergencies',
      category: 'Philippine National Police (PNP)',
      logoAsset: 'assets/images/resident_dashboard/pnp.png',
      fallbackIcon: Icons.local_police_rounded,
      verifiedLabel: 'Verified PNP Station Unit',
      contactNumbers: [
        EmergencyContactNumber(
          label: 'Police Hotline Mobile',
          number: '0998-598-6361',
          isPrimary: true,
        ),
        EmergencyContactNumber(
          label: 'Station Landline',
          number: '(032) 517-2450',
        ),
      ],
      address:
          'Barili Municipal Police Station, Municipal Complex, Poblacion, Barili, Cebu',
      mapQuery: 'Barili Police Station, Barili, Cebu',
      officialPageUrl: 'https://www.facebook.com/BariliMPS',
      officialPageName: 'Barili Municipal Police Station Official Page',
      lastUpdated: 'September 2026',
    ),

    // 5. Barili Primary Care Facility / RHU
    EmergencyAgency(
      id: 'rhu',
      name: 'Barili Primary Care Facility / RHU',
      shortPurpose: 'Rural health / primary medical services',
      category: 'Rural Health & Primary Care',
      logoAsset: 'assets/images/resident_dashboard/rhu_logo.png',
      fallbackIcon: Icons.medical_services_rounded,
      verifiedLabel: 'Verified Municipal Health Facility',
      contactNumbers: [
        EmergencyContactNumber(
          label: 'Primary Care Facility / RHU Landline',
          number: '(032) 517-3472',
          isPrimary: true,
        ),
      ],
      address: 'Barili Rural Health Unit, Poblacion, Barili, Cebu',
      mapQuery: 'Barili Rural Health Unit, Barili, Cebu',
      officialPageUrl: 'https://www.facebook.com/barili.rhu',
      officialPageName: 'Barili Rural Health Unit Official Page',
      lastUpdated: 'September 2026',
    ),

    // 6. Marlon F. Garcia Infirmary – Barili
    EmergencyAgency(
      id: 'infirmary',
      name: 'Marlon F. Garcia Infirmary – Barili',
      shortPurpose: 'Local medical/infirmary assistance',
      category: 'Local Medical & Infirmary Care',
      logoAsset: 'assets/images/resident_dashboard/infirmary_logo.png',
      fallbackIcon: Icons.healing_rounded,
      verifiedLabel: 'Verified Barili Infirmary Facility',
      contactNumbers: [
        EmergencyContactNumber(
          label: 'Infirmary Assistance Mobile',
          number: '0970-558-0536',
          isPrimary: true,
        ),
        EmergencyContactNumber(
          label: 'Infirmary Landline',
          number: '(032) 517-2264',
        ),
      ],
      address: 'Marlon F. Garcia Infirmary, Poblacion, Barili, Cebu',
      mapQuery: 'Marlon F. Garcia Infirmary, Barili, Cebu',
      officialPageUrl:
          'https://www.facebook.com/profile.php?id=100092650336610',
      officialPageName: 'Marlon F. Garcia Infirmary Official Page',
      lastUpdated: 'September 2026',
    ),
  ];
}
