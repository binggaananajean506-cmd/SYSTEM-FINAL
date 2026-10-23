import 'package:flutter/material.dart';
import '../barili_barangays.dart';
import 'emergency_agency.dart';

enum CivicEntityType {
  department,
  barangay,
  publicOrganization,
}

class PublicCivicEntity {
  final String id;
  final String name;
  final CivicEntityType type;
  final String badgeLabel;
  final String category;
  final String shortPurpose;
  final String about;
  final String address;
  final List<EmergencyContactNumber> contactNumbers;
  final String operatingHours;
  final String jurisdiction;
  final String leadershipTitle;
  final String leadershipName;
  final String? officialPageUrl;
  final String? logoAsset;
  final String? logoUrl;
  final IconData fallbackIcon;
  final Color brandColor;
  final bool isVerified;

  const PublicCivicEntity({
    required this.id,
    required this.name,
    required this.type,
    required this.badgeLabel,
    required this.category,
    required this.shortPurpose,
    required this.about,
    required this.address,
    required this.contactNumbers,
    this.operatingHours = 'Monday - Friday • 8:00 AM - 5:00 PM',
    this.jurisdiction = 'Municipal-Wide (Barili)',
    this.leadershipTitle = 'Head of Office',
    this.leadershipName = 'Designated Officer',
    this.officialPageUrl,
    this.logoAsset,
    this.logoUrl,
    this.fallbackIcon = Icons.account_balance_rounded,
    this.brandColor = const Color(0xFF047857),
    this.isVerified = true,
  });

  /// Official public state university campus in Barili.
  static const PublicCivicEntity ctu = PublicCivicEntity(
    id: 'ctu',
    name: 'CTU',
    type: CivicEntityType.publicOrganization,
    badgeLabel: 'PUBLIC STATE UNIVERSITY • CTU BARILI CAMPUS',
    category: 'School & Education',
    shortPurpose:
        'Higher technological & agricultural education, scientific research, and community extension',
    about:
        'Cebu Technological University (CTU) Barili Campus, located in Cagay, Barili, is a premier state university campus dedicated to advanced education, higher technological and agricultural instruction, scientific research, and community extension programs.',
    address: 'Cagay, Barili, Cebu 6036',
    contactNumbers: [
      EmergencyContactNumber(
        label: 'CTU Barili Campus Administration',
        number: '(032) 517-0950',
        isPrimary: true,
      ),
    ],
    operatingHours: 'Monday - Friday • 8:00 AM - 5:00 PM',
    jurisdiction: 'Barili Campus & Regional Academic Community',
    leadershipTitle: 'Campus Director',
    leadershipName: 'Office of the Campus Director',
    officialPageUrl: 'https://www.ctu.edu.ph',
    fallbackIcon: Icons.school_rounded,
    brandColor: Color(0xFF0F766E),
    isVerified: true,
  );

  /// Master directory of officially recognized public organizations in Barili.
  static final List<PublicCivicEntity> publicOrganizations = [
    ctu,
  ];

  /// Master directory of all officially recognized municipal departments and agencies in Barili.
  static final List<PublicCivicEntity> municipalDepartments = [
    const PublicCivicEntity(
      id: 'mdrrmo',
      name: 'Barili MDRRMO / Rescue',
      type: CivicEntityType.department,
      badgeLabel: 'OFFICIAL MUNICIPAL DEPARTMENT • BARILI LGU',
      category: 'Disaster Risk Reduction & Rescue',
      shortPurpose: 'Emergency response, disaster management, 24/7 rescue, and public safety',
      about: 'The Municipal Disaster Risk Reduction and Management Office (MDRRMO) leads disaster preparedness, emergency rescue operations, disaster mitigation, weather bulletins, and 24/7 medical and calamity evacuation across all 42 barangays of Barili.',
      address: 'MDRRMO Operations Center, Barili Municipal Hall Compound, Poblacion, Barili, Cebu',
      contactNumbers: [
        EmergencyContactNumber(
          label: 'MDRRMO Rescue Mobile (Smart)',
          number: '0918-637-6365',
          isPrimary: true,
        ),
        EmergencyContactNumber(
          label: 'MDRRMO Office Landline',
          number: '(032) 517-0950',
        ),
        EmergencyContactNumber(
          label: 'Emergency Mobile (Globe / TM)',
          number: '0927-537-3136',
        ),
      ],
      operatingHours: '24/7 Emergency Operations Center',
      jurisdiction: 'Municipal-Wide (Barili)',
      leadershipTitle: 'MDRRM Officer',
      leadershipName: 'Office of the Disaster Management Officer',
      officialPageUrl: 'https://www.facebook.com/profile.php?id=100072055826084',
      logoAsset: 'assets/images/resident_dashboard/mdrrmo.png',
      fallbackIcon: Icons.emergency_rounded,
      brandColor: Color(0xFF047857),
    ),
    const PublicCivicEntity(
      id: 'rhu',
      name: 'Barili Municipal Health Office (MHO / RHU)',
      type: CivicEntityType.department,
      badgeLabel: 'OFFICIAL MUNICIPAL DEPARTMENT • BARILI LGU',
      category: 'Public Health & Primary Care',
      shortPurpose: 'Primary medical care, immunization, sanitation, and maternal health services',
      about: 'The Municipal Health Office provides primary medical consultations, free basic medicines, routine child immunization, prenatal care, tuberculosis control, animal bite management, and environmental sanitation inspections for residents.',
      address: 'Barili Rural Health Unit, Poblacion, Barili, Cebu',
      contactNumbers: [
        EmergencyContactNumber(
          label: 'Rural Health Unit Landline',
          number: '(032) 517-3472',
          isPrimary: true,
        ),
      ],
      operatingHours: 'Mon - Fri • 8:00 AM - 5:00 PM (Emergency 24/7)',
      jurisdiction: 'Municipal-Wide (Barili)',
      leadershipTitle: 'Municipal Health Officer',
      leadershipName: 'Office of the Municipal Health Physician',
      officialPageUrl: 'https://www.facebook.com/barili.rhu',
      logoAsset: 'assets/images/resident_dashboard/rhu_logo.png',
      fallbackIcon: Icons.medical_services_rounded,
      brandColor: Color(0xFF0D9488),
    ),
    const PublicCivicEntity(
      id: 'engineering',
      name: 'Municipal Engineering Office',
      type: CivicEntityType.department,
      badgeLabel: 'OFFICIAL MUNICIPAL DEPARTMENT • BARILI LGU',
      category: 'Infrastructure & Public Works',
      shortPurpose: 'Road maintenance, municipal building permits, bridges, and drainage works',
      about: 'The Municipal Engineering Office is responsible for public works infrastructure, municipal road repairs, flood control drainages, building permit inspections, streetlight maintenance, and structural safety standards across the municipality.',
      address: 'Engineering Department, Ground Floor, Barili Municipal Hall, Poblacion, Barili, Cebu',
      contactNumbers: [
        EmergencyContactNumber(
          label: 'Engineering Office Desk',
          number: '(032) 517-0950',
          isPrimary: true,
        ),
      ],
      operatingHours: 'Monday - Friday • 8:00 AM - 5:00 PM',
      jurisdiction: 'Municipal-Wide (Barili)',
      leadershipTitle: 'Municipal Engineer',
      leadershipName: 'Office of the Municipal Engineer',
      fallbackIcon: Icons.engineering_rounded,
      brandColor: Color(0xFFD97706),
    ),
    const PublicCivicEntity(
      id: 'menro',
      name: 'Municipal Environment & Natural Resources Office (MENRO)',
      type: CivicEntityType.department,
      badgeLabel: 'OFFICIAL MUNICIPAL DEPARTMENT • BARILI LGU',
      category: 'Environment & Waste Management',
      shortPurpose: 'Solid waste collection, environmental protection, and sanitation compliance',
      about: 'MENRO oversees environmental compliance, solid waste management schedule, material recovery facilities (MRF), reforestation projects, river and watershed conservation, and environmental cleanliness campaigns in Barili.',
      address: 'MENRO Office, Barili Municipal Hall Complex, Poblacion, Barili, Cebu',
      contactNumbers: [
        EmergencyContactNumber(
          label: 'MENRO Service Desk',
          number: '(032) 517-0950',
          isPrimary: true,
        ),
      ],
      operatingHours: 'Monday - Friday • 8:00 AM - 5:00 PM',
      jurisdiction: 'Municipal-Wide (Barili)',
      leadershipTitle: 'MENRO Officer',
      leadershipName: 'Office of the MENRO Officer',
      fallbackIcon: Icons.eco_rounded,
      brandColor: Color(0xFF16A34A),
    ),
    const PublicCivicEntity(
      id: 'pnp',
      name: 'Barili Municipal Police Station (PNP)',
      type: CivicEntityType.department,
      badgeLabel: 'OFFICIAL LAW ENFORCEMENT UNIT • PNP',
      category: 'Public Order & Police Safety',
      shortPurpose: 'Crime prevention, incident reports, blotter assistance, and community peace',
      about: 'The Barili Municipal Police Station enforces law and order, maintains peace and security, conducts proactive checkpoint patrols, processes police clearances and incident blotters, and responds to public emergencies 24 hours a day.',
      address: 'Barili Police Station, Municipal Complex, Poblacion, Barili, Cebu',
      contactNumbers: [
        EmergencyContactNumber(
          label: 'Police Hotline Mobile (Smart)',
          number: '0998-598-6361',
          isPrimary: true,
        ),
        EmergencyContactNumber(
          label: 'Station Landline',
          number: '(032) 517-2450',
        ),
      ],
      operatingHours: '24/7 Police Dispatch Desk',
      jurisdiction: 'Municipal-Wide (Barili)',
      leadershipTitle: 'Chief of Police',
      leadershipName: 'Station Commander',
      officialPageUrl: 'https://www.facebook.com/BariliMPS',
      logoAsset: 'assets/images/resident_dashboard/pnp.png',
      fallbackIcon: Icons.local_police_rounded,
      brandColor: Color(0xFF1E40AF),
    ),
    const PublicCivicEntity(
      id: 'bfp',
      name: 'Barili Fire Station (BFP)',
      type: CivicEntityType.department,
      badgeLabel: 'OFFICIAL FIRE & RESCUE UNIT • BFP R7',
      category: 'Fire Protection & Rescue',
      shortPurpose: 'Fire suppression, rescue operations, fire safety building inspections',
      about: 'The Bureau of Fire Protection (BFP) Barili Fire Station safeguards lives and properties through active fire suppression, emergency vehicular extrication, fire safety code enforcement, and community fire brigade training.',
      address: 'Barili Fire Station, Poblacion, Barili, Cebu',
      contactNumbers: [
        EmergencyContactNumber(
          label: 'Fire Station Mobile (Smart)',
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
      operatingHours: '24/7 Fire & Emergency Dispatch',
      jurisdiction: 'Municipal-Wide (Barili)',
      leadershipTitle: 'Municipal Fire Marshal',
      leadershipName: 'Station Fire Marshal',
      officialPageUrl: 'https://www.facebook.com/barilifirestation',
      logoAsset: 'assets/images/resident_dashboard/bfp.png',
      fallbackIcon: Icons.local_fire_department_rounded,
      brandColor: Color(0xFFDC2626),
    ),
    const PublicCivicEntity(
      id: 'mayors_office',
      name: 'Office of the Municipal Mayor',
      type: CivicEntityType.department,
      badgeLabel: 'EXECUTIVE OFFICE • MUNICIPALITY OF BARILI',
      category: 'Executive Civic Governance',
      shortPurpose: 'Executive leadership, constituent assistance, and municipal policies',
      about: 'The Office of the Municipal Mayor is the executive government authority of Barili. It directs overall municipal development, constituent public assistance programs, inter-agency coordination, and executive ordinances for the welfare of all residents.',
      address: '2nd Floor, Barili Municipal Hall, Poblacion, Barili, Cebu',
      contactNumbers: [
        EmergencyContactNumber(
          label: 'Mayor\'s Executive Office Desk',
          number: '(032) 517-0950',
          isPrimary: true,
        ),
      ],
      operatingHours: 'Monday - Friday • 8:00 AM - 5:00 PM',
      jurisdiction: 'Municipal-Wide (Barili)',
      leadershipTitle: 'Municipal Mayor',
      leadershipName: 'Hon. Municipal Mayor',
      officialPageUrl: 'https://barili.gov.ph',
      fallbackIcon: Icons.account_balance_rounded,
      brandColor: Color(0xFF064E3B),
    ),
    const PublicCivicEntity(
      id: 'agriculture',
      name: 'Department of Agriculture (MAO)',
      type: CivicEntityType.department,
      badgeLabel: 'OFFICIAL MUNICIPAL DEPARTMENT • BARILI LGU',
      category: 'Agriculture & Agrarian Support',
      shortPurpose: 'Farming inputs, crop protection, livestock assistance, and agricultural programs',
      about: 'The Department of Agriculture / Municipal Agriculture Office (MAO) supports farmers, fisherfolk, and livestock growers across all 42 barangays of Barili. It provides technical training, fertilizer & seed distribution, animal veterinary care, irrigation coordination, and government agricultural subsidies.',
      address: 'Municipal Agriculture Office, Barili Municipal Hall Complex, Poblacion, Barili, Cebu',
      contactNumbers: [
        EmergencyContactNumber(
          label: 'MAO Agriculture Desk',
          number: '(032) 517-0950',
          isPrimary: true,
        ),
      ],
      operatingHours: 'Monday - Friday • 8:00 AM - 5:00 PM',
      jurisdiction: 'Municipal-Wide (Barili)',
      leadershipTitle: 'Municipal Agriculturist',
      leadershipName: 'Office of the Municipal Agriculturist',
      officialPageUrl: 'https://barili.gov.ph',
      fallbackIcon: Icons.agriculture_rounded,
      brandColor: Color(0xFF15803D),
    ),
    const PublicCivicEntity(
      id: 'it_department',
      name: 'LGU IT Department',
      type: CivicEntityType.department,
      badgeLabel: 'OFFICIAL MUNICIPAL DEPARTMENT • BARILI LGU',
      category: 'Information Technology & Digital Services',
      shortPurpose: 'Digital government systems, IT infrastructure, citizen apps, and technical support',
      about: 'The LGU Information Technology (IT) Department manages the municipal digital infrastructure, network connectivity, E-SUGID resident platforms, official government portal systems, and technical services ensuring efficient, transparent, and connected municipal governance.',
      address: 'IT Office, 2nd Floor, Barili Municipal Hall, Poblacion, Barili, Cebu',
      contactNumbers: [
        EmergencyContactNumber(
          label: 'IT Helpdesk & Systems Desk',
          number: '(032) 517-0950',
          isPrimary: true,
        ),
      ],
      operatingHours: 'Monday - Friday • 8:00 AM - 5:00 PM',
      jurisdiction: 'Municipal-Wide (Barili)',
      leadershipTitle: 'Head of IT / Systems Administrator',
      leadershipName: 'Office of the Municipal IT Officer',
      officialPageUrl: 'https://barili.gov.ph',
      fallbackIcon: Icons.computer_rounded,
      brandColor: Color(0xFF0284C7),
    ),
    const PublicCivicEntity(
      id: 'mswdo',
      name: 'Municipal Social Welfare & Development Office (MSWDO)',
      type: CivicEntityType.department,
      badgeLabel: 'OFFICIAL MUNICIPAL DEPARTMENT • BARILI LGU',
      category: 'Social Welfare & Public Assistance',
      shortPurpose: 'Crisis assistance, senior citizen welfare, 4Ps, solo parents, and PWD support',
      about: 'The Municipal Social Welfare and Development Office (MSWDO) delivers comprehensive social protection programs to underprivileged families, senior citizens, children in need of special protection, solo parents, and persons with disabilities across Barili.',
      address: 'MSWDO Office, Ground Floor, Barili Municipal Hall, Poblacion, Barili, Cebu',
      contactNumbers: [
        EmergencyContactNumber(
          label: 'MSWDO Public Assistance Desk',
          number: '(032) 517-0950',
          isPrimary: true,
        ),
      ],
      operatingHours: 'Monday - Friday • 8:00 AM - 5:00 PM',
      jurisdiction: 'Municipal-Wide (Barili)',
      leadershipTitle: 'MSWDO Officer',
      leadershipName: 'Office of the Social Welfare Officer',
      officialPageUrl: 'https://barili.gov.ph',
      fallbackIcon: Icons.diversity_1_rounded,
      brandColor: Color(0xFF7C3AED),
    ),
    const PublicCivicEntity(
      id: 'treasury',
      name: 'Municipal Treasury Office',
      type: CivicEntityType.department,
      badgeLabel: 'OFFICIAL MUNICIPAL DEPARTMENT • BARILI LGU',
      category: 'Revenue & Financial Administration',
      shortPurpose: 'Tax collection, real property payments, cedula, and municipal revenues',
      about: 'The Municipal Treasury Office collects local government taxes, business fees, real property taxes (amilyar), and issues official receipts, community tax certificates (cedula), and municipal revenue clearances for Barili.',
      address: 'Ground Floor, Barili Municipal Hall, Poblacion, Barili, Cebu',
      contactNumbers: [
        EmergencyContactNumber(
          label: 'Treasury Collection Desk',
          number: '(032) 517-0950',
          isPrimary: true,
        ),
      ],
      operatingHours: 'Monday - Friday • 8:00 AM - 5:00 PM',
      jurisdiction: 'Municipal-Wide (Barili)',
      leadershipTitle: 'Municipal Treasurer',
      leadershipName: 'Office of the Municipal Treasurer',
      officialPageUrl: 'https://barili.gov.ph',
      fallbackIcon: Icons.payments_rounded,
      brandColor: Color(0xFFB45309),
    ),
    const PublicCivicEntity(
      id: 'assessor',
      name: 'Municipal Assessor\'s Office',
      type: CivicEntityType.department,
      badgeLabel: 'OFFICIAL MUNICIPAL DEPARTMENT • BARILI LGU',
      category: 'Property Assessment & Land Records',
      shortPurpose: 'Tax declarations, real property appraisal, and land classification',
      about: 'The Municipal Assessor\'s Office is in charge of establishing systematic appraisal and assessment of lands, buildings, and improvements in Barili, issuing tax declarations and property assessment records.',
      address: 'Ground Floor, Barili Municipal Hall, Poblacion, Barili, Cebu',
      contactNumbers: [
        EmergencyContactNumber(
          label: 'Assessor Records Desk',
          number: '(032) 517-0950',
          isPrimary: true,
        ),
      ],
      operatingHours: 'Monday - Friday • 8:00 AM - 5:00 PM',
      jurisdiction: 'Municipal-Wide (Barili)',
      leadershipTitle: 'Municipal Assessor',
      leadershipName: 'Office of the Municipal Assessor',
      officialPageUrl: 'https://barili.gov.ph',
      fallbackIcon: Icons.assessment_rounded,
      brandColor: Color(0xFF0369A1),
    ),
    const PublicCivicEntity(
      id: 'bplo',
      name: 'Business Permits & Licensing Office (BPLO)',
      type: CivicEntityType.department,
      badgeLabel: 'OFFICIAL MUNICIPAL DEPARTMENT • BARILI LGU',
      category: 'Business Permits & Commercial Licensing',
      shortPurpose: 'Mayor\'s permits, commercial licenses, business renewal, and inspections',
      about: 'BPLO processes initial business registration applications, mayor\'s business permits, annual renewals, commercial regulatory compliance, and special event licensing in Barili.',
      address: 'Ground Floor, Barili Municipal Hall, Poblacion, Barili, Cebu',
      contactNumbers: [
        EmergencyContactNumber(
          label: 'BPLO Business One-Stop-Shop',
          number: '(032) 517-0950',
          isPrimary: true,
        ),
      ],
      operatingHours: 'Monday - Friday • 8:00 AM - 5:00 PM',
      jurisdiction: 'Municipal-Wide (Barili)',
      leadershipTitle: 'Licensing Officer',
      leadershipName: 'Office of the BPLO Head',
      officialPageUrl: 'https://barili.gov.ph',
      fallbackIcon: Icons.store_rounded,
      brandColor: Color(0xFF4338CA),
    ),
    const PublicCivicEntity(
      id: 'lcr',
      name: 'Local Civil Registrar (LCR)',
      type: CivicEntityType.department,
      badgeLabel: 'OFFICIAL MUNICIPAL DEPARTMENT • BARILI LGU',
      category: 'Civil Registry & Vital Records',
      shortPurpose: 'Birth certificates, marriage licenses, death registration, and legal instruments',
      about: 'The Local Civil Registrar Office registers, records, and issues certified true copies of vital civil status documents including certificates of live birth, certificates of marriage, and death certificates in Barili.',
      address: 'Ground Floor, Barili Municipal Hall, Poblacion, Barili, Cebu',
      contactNumbers: [
        EmergencyContactNumber(
          label: 'Civil Registry Records Desk',
          number: '(032) 517-0950',
          isPrimary: true,
        ),
      ],
      operatingHours: 'Monday - Friday • 8:00 AM - 5:00 PM',
      jurisdiction: 'Municipal-Wide (Barili)',
      leadershipTitle: 'Municipal Civil Registrar',
      leadershipName: 'Office of the Local Civil Registrar',
      officialPageUrl: 'https://barili.gov.ph',
      fallbackIcon: Icons.badge_rounded,
      brandColor: Color(0xFF0F766E),
    ),
    const PublicCivicEntity(
      id: 'tourism',
      name: 'Municipal Tourism & Heritage Office',
      type: CivicEntityType.department,
      badgeLabel: 'OFFICIAL MUNICIPAL DEPARTMENT • BARILI LGU',
      category: 'Tourism, Culture & Heritage',
      shortPurpose: 'Mantayupan Falls, cultural sites, festival coordination, and visitor assistance',
      about: 'Promotes sustainable tourism, historic landmarks, eco-adventures including Mantayupan Falls, and cultural heritage festivals across Barili.',
      address: 'Tourism Center, Barili Municipal Hall Complex, Poblacion, Barili, Cebu',
      contactNumbers: [
        EmergencyContactNumber(
          label: 'Tourism Information Desk',
          number: '(032) 517-0950',
          isPrimary: true,
        ),
      ],
      operatingHours: 'Monday - Friday • 8:00 AM - 5:00 PM',
      jurisdiction: 'Municipal-Wide (Barili)',
      leadershipTitle: 'Municipal Tourism Officer',
      leadershipName: 'Office of the Tourism Officer',
      officialPageUrl: 'https://barili.gov.ph',
      fallbackIcon: Icons.attractions_rounded,
      brandColor: Color(0xFFE11D48),
    ),
    const PublicCivicEntity(
      id: 'sangguniang_bayan',
      name: 'Sangguniang Bayan of Barili',
      type: CivicEntityType.department,
      badgeLabel: 'LEGISLATIVE BODY • MUNICIPALITY OF BARILI',
      category: 'Municipal Legislative Governance',
      shortPurpose: 'Municipal ordinances, resolutions, legislative committee hearings, and policies',
      about: 'The Sangguniang Bayan is the legislative body of Barili, headed by the Municipal Vice Mayor, enacting municipal ordinances and resolutions for the peace, order, and general welfare of the municipality.',
      address: '2nd Floor, Legislative Building, Barili Municipal Hall, Poblacion, Barili, Cebu',
      contactNumbers: [
        EmergencyContactNumber(
          label: 'SB Secretariat Office',
          number: '(032) 517-0950',
          isPrimary: true,
        ),
      ],
      operatingHours: 'Monday - Friday • 8:00 AM - 5:00 PM',
      jurisdiction: 'Municipal-Wide (Barili)',
      leadershipTitle: 'Vice Mayor & Presiding Officer',
      leadershipName: 'Office of the Municipal Vice Mayor',
      officialPageUrl: 'https://barili.gov.ph',
      fallbackIcon: Icons.gavel_rounded,
      brandColor: Color(0xFF1E3A8A),
    ),
  ];

  /// Dynamically constructs an official [PublicCivicEntity] for any department or municipal office.
  static PublicCivicEntity forDepartment(String departmentName) {
    final clean = departmentName.trim();
    final slug = clean.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');

    final (category, icon, color) = _inferDepartmentDetails(clean);

    return PublicCivicEntity(
      id: 'dept_$slug',
      name: clean,
      type: CivicEntityType.department,
      badgeLabel: 'OFFICIAL MUNICIPAL DEPARTMENT • BARILI LGU',
      category: category,
      shortPurpose: 'Official municipal public service and government operations in Barili',
      about: 'The $clean provides dedicated government services, constituent assistance, and public administration for the residents and communities of the Municipality of Barili.',
      address: 'Barili Municipal Hall Compound, Poblacion, Barili, Cebu',
      contactNumbers: [
        EmergencyContactNumber(
          label: '$clean Desk',
          number: '(032) 517-0950',
          isPrimary: true,
        ),
      ],
      operatingHours: 'Monday - Friday • 8:00 AM - 5:00 PM',
      jurisdiction: 'Municipal-Wide (Barili)',
      leadershipTitle: 'Head of Office',
      leadershipName: 'Office of the Designated Department Officer',
      officialPageUrl: 'https://barili.gov.ph',
      fallbackIcon: icon,
      brandColor: color,
    );
  }

  static (String, IconData, Color) _inferDepartmentDetails(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('agri') || lower.contains('farm') || lower.contains('crop') || lower.contains('livestock')) {
      return ('Agriculture & Agrarian Support', Icons.agriculture_rounded, const Color(0xFF15803D));
    }
    if (lower.contains('it') || lower.contains('tech') || lower.contains('comput') || lower.contains('info') || lower.contains('digital')) {
      return ('Information Technology & Digital Services', Icons.computer_rounded, const Color(0xFF0284C7));
    }
    if (lower.contains('welfare') || lower.contains('social') || lower.contains('mswd')) {
      return ('Social Welfare & Public Assistance', Icons.diversity_1_rounded, const Color(0xFF7C3AED));
    }
    if (lower.contains('treasur') || lower.contains('tax') || lower.contains('revenue') || lower.contains('financ')) {
      return ('Revenue & Financial Administration', Icons.payments_rounded, const Color(0xFFB45309));
    }
    if (lower.contains('assess') || lower.contains('property')) {
      return ('Property Assessment & Land Records', Icons.assessment_rounded, const Color(0xFF0369A1));
    }
    if (lower.contains('permit') || lower.contains('licens') || lower.contains('bplo')) {
      return ('Business Permits & Commercial Licensing', Icons.store_rounded, const Color(0xFF4338CA));
    }
    if (lower.contains('civil') || lower.contains('registr') || lower.contains('birth')) {
      return ('Civil Registry & Vital Records', Icons.badge_rounded, const Color(0xFF0F766E));
    }
    if (lower.contains('touris') || lower.contains('heritage') || lower.contains('cultur')) {
      return ('Tourism, Culture & Heritage', Icons.attractions_rounded, const Color(0xFFE11D48));
    }
    if (lower.contains('legislat') || lower.contains('sangguniang') || lower.contains('council') || lower.contains('vice mayor')) {
      return ('Municipal Legislative Governance', Icons.gavel_rounded, const Color(0xFF1E3A8A));
    }
    if (lower.contains('engineer') || lower.contains('work') || lower.contains('infra')) {
      return ('Infrastructure & Public Works', Icons.engineering_rounded, const Color(0xFFD97706));
    }
    if (lower.contains('health') || lower.contains('medic') || lower.contains('clinic')) {
      return ('Public Health & Primary Care', Icons.medical_services_rounded, const Color(0xFF0D9488));
    }
    if (lower.contains('disaster') || lower.contains('rescue') || lower.contains('emergency')) {
      return ('Disaster Risk Reduction & Rescue', Icons.emergency_rounded, const Color(0xFF047857));
    }
    if (lower.contains('police') || lower.contains('peace') || lower.contains('order')) {
      return ('Public Order & Police Safety', Icons.local_police_rounded, const Color(0xFF1E40AF));
    }
    if (lower.contains('fire')) {
      return ('Fire Protection & Rescue', Icons.local_fire_department_rounded, const Color(0xFFDC2626));
    }
    return ('Municipal Civic Department', Icons.account_balance_rounded, const Color(0xFF047857));
  }

  /// Dynamically constructs an official [PublicCivicEntity] for any of the 42 Barili Barangays.
  static PublicCivicEntity forBarangay(String barangayName) {
    final clean = canonicalBariliBarangay(barangayName) ?? barangayName.trim();
    final slug = clean.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');

    return PublicCivicEntity(
      id: 'barangay_$slug',
      name: 'Barangay $clean',
      type: CivicEntityType.barangay,
      badgeLabel: 'OFFICIAL BARANGAY GOVERNMENT UNIT',
      category: 'Barangay Local Government',
      shortPurpose: 'Serving residents, community safety, and local village assistance',
      about: 'Barangay $clean serves and supports all residents in our community. We help keep our neighborhood safe, clean, and peaceful, issue local clearances and permits, and assist families with everyday community services in Barili, Cebu.',
      address: 'Barangay Hall, $clean, Barili, Cebu 6036',
      contactNumbers: [
        EmergencyContactNumber(
          label: 'Barangay Hall Desk & Patrol',
          number: '(032) 517-0950',
          isPrimary: true,
        ),
      ],
      operatingHours: 'Monday - Friday • 8:00 AM - 5:00 PM (Tanod 24/7)',
      jurisdiction: 'Barangay $clean (Puroks & Sitios)',
      leadershipTitle: 'Punong Barangay (Barangay Captain)',
      leadershipName: 'Office of the Punong Barangay',
      fallbackIcon: Icons.location_city_rounded,
      brandColor: const Color(0xFF047857),
    );
  }

  /// Dynamically constructs an official [PublicCivicEntity] for any public organization or institution.
  static PublicCivicEntity forPublicOrganization(
    String organizationName, {
    String? category,
    String? address,
    String? website,
    String? about,
    IconData? fallbackIcon,
    Color? brandColor,
    String? leadershipTitle,
    String? leadershipName,
  }) {
    final clean = organizationName.trim();
    final slug = clean.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');

    return PublicCivicEntity(
      id: 'public_org_$slug',
      name: clean,
      type: CivicEntityType.publicOrganization,
      badgeLabel: 'OFFICIAL PUBLIC ORGANIZATION • BARILI',
      category: category ?? 'School & Education',
      shortPurpose: 'Official public institution and civic educational services in Barili',
      about: about ??
          '$clean is an officially recognized public organization and civic stakeholder in Barili.',
      address: address ?? 'Barili, Cebu 6036',
      contactNumbers: const [
        EmergencyContactNumber(
          label: 'Administration Desk',
          number: '(032) 517-0950',
          isPrimary: true,
        ),
      ],
      operatingHours: 'Monday - Friday • 8:00 AM - 5:00 PM',
      jurisdiction: 'Municipal-Wide (Barili)',
      leadershipTitle: leadershipTitle ?? 'Head of Office',
      leadershipName: leadershipName ?? 'Office of the Designated Head',
      officialPageUrl: website,
      fallbackIcon: fallbackIcon ?? Icons.school_rounded,
      brandColor: brandColor ?? const Color(0xFF0F766E),
      isVerified: true,
    );
  }

  /// Finds any public entity (department, barangay, or public organization) by name or id.
  static PublicCivicEntity? findByNameOrId(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return null;

    // 1. Check barangays FIRST so "Barangay Vito", "Vito", "Brgy Vito" always resolve directly to their Barangay profile!
    final canonical = canonicalBariliBarangay(q);
    if (canonical != null) {
      return forBarangay(canonical);
    }
    for (final bgy in bariliBarangays) {
      final bgyLower = bgy.toLowerCase();
      if (bgyLower == q ||
          'barangay $bgyLower' == q ||
          'brgy. $bgyLower' == q ||
          'brgy $bgyLower' == q ||
          'bgy $bgyLower' == q) {
        return forBarangay(bgy);
      }
    }

    // 2. Check public organizations (CTU / State University)
    if (q == 'ctu' ||
        q.contains('ctu') ||
        q.contains('cebu tech') ||
        q.contains('cebu technological university')) {
      return ctu;
    }
    for (final org in publicOrganizations) {
      if (org.id.toLowerCase() == q ||
          org.name.toLowerCase() == q ||
          (q.length >= 3 && org.name.toLowerCase().contains(q))) {
        return org;
      }
    }

    // 3. Check exact department matches by id or name
    for (final dept in municipalDepartments) {
      if (dept.id.toLowerCase() == q || dept.name.toLowerCase() == q) {
        return dept;
      }
    }

    // 3. Department specific keyword matching
    if (q.contains('agri') || q.contains('farm') || q.contains('crop') || q.contains('mao')) {
      return municipalDepartments.firstWhere((d) => d.id == 'agriculture');
    }
    if (q.contains('it ') || q.startsWith('it') || q.endsWith('it') || q.contains('computer') || q.contains('ict') || q.contains('tech') || q.contains('deapartment') && q.contains('it')) {
      return municipalDepartments.firstWhere((d) => d.id == 'it_department');
    }
    if (q.contains('mdrrmo') || q.contains('rescue')) {
      return municipalDepartments.firstWhere((d) => d.id == 'mdrrmo');
    }
    if (q.contains('health') || q.contains('rhu') || q.contains('mho')) {
      return municipalDepartments.firstWhere((d) => d.id == 'rhu');
    }
    if (q.contains('engineer')) {
      return municipalDepartments.firstWhere((d) => d.id == 'engineering');
    }
    if (q.contains('menro') || q.contains('cenro') || q.contains('waste')) {
      return municipalDepartments.firstWhere((d) => d.id == 'menro');
    }
    if (q.contains('police') || q.contains('pnp')) {
      return municipalDepartments.firstWhere((d) => d.id == 'pnp');
    }
    if (q.contains('fire') || q.contains('bfp')) {
      return municipalDepartments.firstWhere((d) => d.id == 'bfp');
    }
    if (q.contains('social') || q.contains('mswdo') || q.contains('welfare')) {
      return municipalDepartments.firstWhere((d) => d.id == 'mswdo');
    }
    if (q.contains('treasur') || q.contains('tax') || q.contains('amilyar')) {
      return municipalDepartments.firstWhere((d) => d.id == 'treasury');
    }
    if (q.contains('assess')) {
      return municipalDepartments.firstWhere((d) => d.id == 'assessor');
    }
    if (q.contains('permit') || q.contains('bplo') || q.contains('licens')) {
      return municipalDepartments.firstWhere((d) => d.id == 'bplo');
    }
    if (q.contains('civil registr') || q.contains('lcr')) {
      return municipalDepartments.firstWhere((d) => d.id == 'lcr');
    }
    if (q.contains('touris') || q.contains('heritage')) {
      return municipalDepartments.firstWhere((d) => d.id == 'tourism');
    }
    if (q.contains('sangguniang bayan') || q.contains('vice mayor')) {
      return municipalDepartments.firstWhere((d) => d.id == 'sangguniang_bayan');
    }
    if (q.contains('mayor') || q == 'executive office' || q == 'office of the mayor') {
      return municipalDepartments.firstWhere((d) => d.id == 'mayors_office');
    }

    // 4. Substring search for departments
    for (final dept in municipalDepartments) {
      if (dept.name.toLowerCase().contains(q) && q.length >= 3) {
        return dept;
      }
    }

    return null;
  }
}
