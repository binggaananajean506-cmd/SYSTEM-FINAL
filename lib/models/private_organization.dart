import 'package:flutter/material.dart';
import '../community_service.dart';

/// Represents a single update or advisory posted by a private organization.
class PrivateOrganizationUpdate {
  final String id;
  final String organizationId;
  final String title;
  final String content;
  final DateTime date;
  final String? imageUrl;
  final String category;
  final String? priority;

  const PrivateOrganizationUpdate({
    required this.id,
    required this.organizationId,
    required this.title,
    required this.content,
    required this.date,
    this.imageUrl,
    this.category = 'Advisory',
    this.priority = 'regular',
  });

  /// Converts this update into a [CommunityPost] so it can be rendered seamlessly
  /// in the standard Community Updates feed using [ModernPostCard].
  CommunityPost toCommunityPost(PrivateOrganization organization) {
    return CommunityPost(
      id: id,
      title: title,
      content: content,
      authorName: organization.name,
      authorId: organization.id,
      authorRole: 'organization',
      authorBarangay: organization.address,
      authorOrganizationName: organization.name,
      authorPhotoUrl: organization.logoUrl ?? '',
      publisherEntityId: organization.id,
      publisherEntityType: 'private_organization',
      publisherEntityName: organization.name,
      targetAudience: 'All Residents',
      targetBarangay: 'All Barangays',
      visibility: 'public',
      targetBarangays: const [],
      imageUrl: imageUrl ?? '',
      createdAt: date,
      status: 'approved',
      tag: 'PARTNER',
      category: category,
      priority: priority ?? 'regular',
    );
  }
}

/// Represents an approved private organization operating in Barili.
class PrivateOrganization {
  final String id;
  final String name;
  final String category;
  final String shortDescription;
  final String about;
  final String address;
  final String website;
  final String? logoAsset;
  final String? logoUrl;
  final String? coverImageUrl;
  final IconData fallbackIcon;
  final Color brandColor;
  final int baseFollowerCount;
  final bool isVerified;
  final List<PrivateOrganizationUpdate> updates;

  const PrivateOrganization({
    required this.id,
    required this.name,
    required this.category,
    required this.shortDescription,
    required this.about,
    required this.address,
    required this.website,
    this.logoAsset,
    this.logoUrl,
    this.coverImageUrl,
    this.fallbackIcon = Icons.corporate_fare_rounded,
    this.brandColor = const Color(0xFF047857),
    this.baseFollowerCount = 100,
    this.isVerified = true,
    this.updates = const [],
  });

  factory PrivateOrganization.fromFirestore(
    String id,
    Map<String, dynamic> data, {
    List<PrivateOrganizationUpdate> updates = const [],
  }) {
    return PrivateOrganization.fromMap(id, data, updates: updates);
  }

  factory PrivateOrganization.fromMap(
    String id,
    Map<String, dynamic> data, {
    List<PrivateOrganizationUpdate> updates = const [],
  }) {
    final rawName = data['name']?.toString() ??
        data['organizationName']?.toString() ??
        data['displayName']?.toString() ??
        id;
    final rawCategory = data['category']?.toString() ??
        data['organizationType']?.toString() ??
        data['organizationSector']?.toString() ??
        'Others';
    final normalizedCategory = normalizeCategoryName(rawCategory);
    final rawDesc = data['shortDescription']?.toString() ??
        data['description']?.toString() ??
        'Verified private organization in Barili.';
    final rawAbout = data['about']?.toString() ??
        data['description']?.toString() ??
        rawDesc;
    final rawAddress = data['address']?.toString() ??
        data['barangay']?.toString() ??
        'Barili, Cebu';
    final rawWebsite = data['website']?.toString() ??
        data['url']?.toString() ??
        data['link']?.toString() ??
        '';
    final rawLogoUrl = data['logoUrl']?.toString() ??
        data['photoUrl']?.toString() ??
        data['profilePicture']?.toString();
    final rawCoverUrl = data['coverImageUrl']?.toString() ??
        data['coverPhoto']?.toString() ??
        data['headerImageUrl']?.toString();
    final status = data['status']?.toString().toLowerCase() ?? 'verified';
    final isVerified = status == 'verified' ||
        status == 'active' ||
        status == 'approved' ||
        data['isVerified'] == true;
    final followers = (data['followerCount'] is num)
        ? (data['followerCount'] as num).toInt()
        : (data['baseFollowerCount'] is num)
            ? (data['baseFollowerCount'] as num).toInt()
            : 0;

    return PrivateOrganization(
      id: id,
      name: rawName,
      category: normalizedCategory,
      shortDescription: rawDesc,
      about: rawAbout,
      address: rawAddress,
      website: rawWebsite,
      logoUrl: rawLogoUrl,
      coverImageUrl: rawCoverUrl,
      fallbackIcon: iconForCategory(normalizedCategory),
      brandColor: colorForCategory(normalizedCategory),
      baseFollowerCount: followers,
      isVerified: isVerified,
      updates: updates,
    );
  }

  static String normalizeCategoryName(String raw) {
    final lower = raw.toLowerCase().trim();
    if (lower.contains('bank') || lower.contains('finance')) {
      return 'Banking & Finance';
    }
    if (lower.contains('school') || lower.contains('educat') || lower.contains('academy')) {
      return 'School & Education';
    }
    if (lower.contains('health') || lower.contains('medic') || lower.contains('clinic') || lower.contains('hospital')) {
      return 'Health & Medical';
    }
    if (lower.contains('util') || lower.contains('power') || lower.contains('electric') || lower.contains('water')) {
      return 'Utilities';
    }
    if (lower.contains('telecom') || lower.contains('internet') || lower.contains('wifi') || lower.contains('fiber')) {
      return 'Internet & Telecom';
    }
    if (lower.contains('transport') || lower.contains('transit') || lower.contains('bus') || lower.contains('airline')) {
      return 'Transportation';
    }
    if (lower.contains('retail') || lower.contains('commercial') || lower.contains('store') || lower.contains('mall')) {
      return 'Retail & Commercial';
    }
    if (lower.contains('ngo') || lower.contains('community') || lower.contains('civic')) {
      return 'Community & NGO';
    }
    return raw.isEmpty ? 'Others' : raw;
  }

  static IconData iconForCategory(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('bank') || lower.contains('finance')) {
      return Icons.account_balance_rounded;
    }
    if (lower.contains('school') || lower.contains('educat') || lower.contains('academy')) {
      return Icons.school_rounded;
    }
    if (lower.contains('health') || lower.contains('medic') || lower.contains('clinic') || lower.contains('hospital')) {
      return Icons.favorite_rounded;
    }
    if (lower.contains('util') || lower.contains('power') || lower.contains('electric') || lower.contains('water')) {
      return Icons.bolt_rounded;
    }
    if (lower.contains('telecom') || lower.contains('internet') || lower.contains('wifi')) {
      return Icons.wifi_rounded;
    }
    if (lower.contains('transport') || lower.contains('transit') || lower.contains('bus')) {
      return Icons.directions_bus_rounded;
    }
    if (lower.contains('retail') || lower.contains('commercial')) {
      return Icons.storefront_rounded;
    }
    if (lower.contains('ngo') || lower.contains('community')) {
      return Icons.volunteer_activism_rounded;
    }
    return Icons.corporate_fare_rounded;
  }

  static Color colorForCategory(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('bank') || lower.contains('finance')) {
      return const Color(0xFF047857);
    }
    if (lower.contains('school') || lower.contains('educat')) {
      return const Color(0xFF1E3A8A);
    }
    if (lower.contains('health') || lower.contains('medic')) {
      return const Color(0xFFE11D48);
    }
    if (lower.contains('util') || lower.contains('power')) {
      return const Color(0xFFD97706);
    }
    if (lower.contains('telecom') || lower.contains('internet')) {
      return const Color(0xFF0284C7);
    }
    if (lower.contains('transport')) {
      return const Color(0xFF0D9488);
    }
    return const Color(0xFF047857);
  }

  String formattedFollowerCount([int followerOffset = 0]) {
    final count = baseFollowerCount + followerOffset;
    if (count >= 1000) {
      final formatted = (count / 1000).toStringAsFixed(1);
      return '${formatted.endsWith('.0') ? formatted.substring(0, formatted.length - 2) : formatted}K followers';
    }
    return '$count followers';
  }

  /// Master list of approved private organizations in Barili matching the reference UI.
  static final List<PrivateOrganization> approvedOrganizations = [
    // 1. LANDBANK
    PrivateOrganization(
      id: 'landbank',
      name: 'LANDBANK',
      category: 'Banking & Finance',
      shortDescription:
          'Financial services, accounts, service advisories and local updates.',
      about:
          'LANDBANK is committed to providing accessible and responsive financial services to support communities and local development in Barili and Western Cebu.',
      address: 'Barili, Cebu',
      website: 'https://www.landbank.com',
      brandColor: const Color(0xFF047857),
      fallbackIcon: Icons.account_balance_rounded,
      baseFollowerCount: 1300,
      isVerified: true,
      updates: [
        PrivateOrganizationUpdate(
          id: 'landbank_update_1',
          organizationId: 'landbank',
          title: 'Service Advisory: System Maintenance',
          content:
              'Please be advised that LANDBANK electronic banking channels and ATMs in Barili will undergo scheduled routine maintenance on Sunday from 12:00 AM to 4:00 AM.',
          date: DateTime(2026, 9, 28, 9, 30),
          category: 'Advisory',
        ),
        PrivateOrganizationUpdate(
          id: 'landbank_update_2',
          organizationId: 'landbank',
          title: 'New Loan Program for Local MSMEs',
          content:
              'LANDBANK launches an accessible micro-financing loan facility with reduced interest rates tailored for farmers, fishermen, and local MSME entrepreneurs across Barili.',
          date: DateTime(2026, 9, 25, 14, 0),
          category: 'Notice',
        ),
        PrivateOrganizationUpdate(
          id: 'landbank_update_3',
          organizationId: 'landbank',
          title: 'Branch Holiday Schedule',
          content:
              'In observance of the upcoming special non-working holiday, our Barili branch will be closed. Mobile banking and online transfer facilities remain 24/7 operational.',
          date: DateTime(2026, 9, 22, 10, 15),
          category: 'Notice',
        ),
      ],
    ),

    // 2. PLDT
    PrivateOrganization(
      id: 'pldt',
      name: 'PLDT',
      category: 'Internet & Telecom',
      shortDescription:
          'Service advisories, network updates and maintenance schedules.',
      about:
          'PLDT is the Philippines’ premier telecommunications provider, delivering high-speed Home Fiber internet and digital enterprise connectivity to households and businesses in Barili.',
      address: 'Barili, Cebu',
      website: 'https://www.pldt.com',
      brandColor: const Color(0xFFDC2626),
      fallbackIcon: Icons.wifi_rounded,
      baseFollowerCount: 940,
      isVerified: true,
      updates: [
        PrivateOrganizationUpdate(
          id: 'pldt_update_1',
          organizationId: 'pldt',
          title: 'Scheduled Fiber Network Maintenance',
          content:
              'PLDT engineering teams will perform fiber backbone maintenance in southern Cebu. Subscribers in Barili may experience intermittent internet connectivity between 1:00 AM and 5:00 AM.',
          date: DateTime(2026, 9, 27, 8, 0),
          category: 'Advisory',
        ),
        PrivateOrganizationUpdate(
          id: 'pldt_update_2',
          organizationId: 'pldt',
          title: 'Submarine Cable Restoration Notice',
          content:
              'Restoration work on the international submarine cable system is now complete. Standard latency and fiber speeds are fully restored across Barili and surrounding municipalities.',
          date: DateTime(2026, 9, 20, 16, 45),
          category: 'Notice',
        ),
        PrivateOrganizationUpdate(
          id: 'pldt_update_3',
          organizationId: 'pldt',
          title: 'Barili Fiber Expansion Coverage',
          content:
              'We have activated 12 new fiber distribution boxes in Barangay Guibuangan, Japitan, and Poblacion. Residents may inquire about new fiber line applications.',
          date: DateTime(2026, 9, 15, 11, 20),
          category: 'Events',
        ),
      ],
    ),

    // 3. Ste. Anne Academy
    PrivateOrganization(
      id: 'ste_anne_academy',
      name: 'Ste. Anne Academy',
      category: 'School & Education',
      shortDescription:
          'School announcements, schedules and community updates.',
      about:
          'Ste. Anne Academy of Barili provides holistic Catholic education, academic excellence, and character formation to students across elementary and secondary levels in Barili.',
      address: 'Poblacion, Barili, Cebu',
      website: 'https://www.steanneacademy.edu.ph',
      logoAsset: 'assets/images/resident_dashboard/santa-ana.png',
      brandColor: const Color(0xFF1E3A8A),
      fallbackIcon: Icons.school_rounded,
      baseFollowerCount: 762,
      isVerified: true,
      updates: [
        PrivateOrganizationUpdate(
          id: 'ste_anne_update_1',
          organizationId: 'ste_anne_academy',
          title: 'First Quarter Examination Schedule',
          content:
              'All Junior and Senior High School students are reminded of the First Quarter Periodic Examinations from Thursday to Friday. Complete exam permits and school IDs are required.',
          date: DateTime(2026, 9, 26, 7, 30),
          category: 'Notice',
        ),
        PrivateOrganizationUpdate(
          id: 'ste_anne_update_2',
          organizationId: 'ste_anne_academy',
          title: 'Intramurals 2026 Opening Ceremony',
          content:
              'Join us for the grand opening parade and banner raising of Intramurals 2026 at the Ste. Anne Gymnasium. Parents and community supporters are warmly invited.',
          date: DateTime(2026, 9, 18, 13, 0),
          category: 'Events',
        ),
        PrivateOrganizationUpdate(
          id: 'ste_anne_update_3',
          organizationId: 'ste_anne_academy',
          title: 'General Parents-Teachers Assembly',
          content:
              'The General PTA Assembly will convene this Saturday at 9:00 AM at the St. Anne Auditorium to discuss upcoming community outreach and academic programs.',
          date: DateTime(2026, 9, 10, 9, 0),
          category: 'Notice',
        ),
      ],
    ),

    // 4. Cebu Pacific
    PrivateOrganization(
      id: 'cebu_pacific',
      name: 'Cebu Pacific',
      category: 'Transportation',
      shortDescription: 'Flight advisories, promos and travel updates.',
      about:
          'Cebu Pacific is the Philippines’ leading low-cost carrier, dedicated to making safe, reliable, and affordable air travel accessible to every Filipino with extensive domestic and international connections.',
      address: 'Barili Booking Desk / MCIA Terminal',
      website: 'https://www.cebupacificair.com',
      brandColor: const Color(0xFF0284C7),
      fallbackIcon: Icons.directions_bus_rounded,
      baseFollowerCount: 1100,
      isVerified: true,
      updates: [
        PrivateOrganizationUpdate(
          id: 'ceb_update_1',
          organizationId: 'cebu_pacific',
          title: 'Travel Advisory: Weather System Update',
          content:
              'Due to prevailing tropical depression weather warnings in eastern Visayas, passengers flying out of Mactan-Cebu are advised to check flight status online prior to airport transit.',
          date: DateTime(2026, 9, 29, 11, 0),
          category: 'Advisory',
        ),
        PrivateOrganizationUpdate(
          id: 'ceb_update_2',
          organizationId: 'cebu_pacific',
          title: 'Special Low Fares for Visayas Residents',
          content:
              'Enjoy promotional seat fares for regional routes from Cebu to Manila, Davao, and Iloilo. Available for bookings through registered local authorized agents in Barili.',
          date: DateTime(2026, 9, 24, 15, 30),
          category: 'Events',
        ),
        PrivateOrganizationUpdate(
          id: 'ceb_update_3',
          organizationId: 'cebu_pacific',
          title: 'Airport Security & Baggage Reminder',
          content:
              'Guests traveling with delicate agricultural produce, seafood, or local delicacies are reminded to follow standard airline packaging guidelines to prevent transit delays.',
          date: DateTime(2026, 9, 16, 8, 45),
          category: 'Notice',
        ),
      ],
    ),

    // 5. CEBECO I (Cebu I Electric Cooperative)
    PrivateOrganization(
      id: 'cebeco_1',
      name: 'CEBECO I',
      category: 'Utilities',
      shortDescription:
          'Power distribution updates, scheduled maintenance, and consumer advisories.',
      about:
          'Cebu I Electric Cooperative, Inc. (CEBECO I) is the electric distribution utility serving the power needs of households, public facilities, and industries in Barili and southern Cebu.',
      address: 'Barili Sub-Office, Barili, Cebu',
      website: 'https://www.cebeco1.com.ph',
      brandColor: const Color(0xFFF59E0B),
      fallbackIcon: Icons.bolt_rounded,
      baseFollowerCount: 3450,
      isVerified: true,
      updates: [
        PrivateOrganizationUpdate(
          id: 'cebeco_update_1',
          organizationId: 'cebeco_1',
          title: 'Scheduled Power Interruption Notice',
          content:
              'Routine line clearing and transformer replacement will affect feeders in Barangay Sayao and Candugay this Thursday from 8:00 AM to 3:00 PM.',
          date: DateTime(2026, 9, 26, 10, 0),
          category: 'Advisory',
        ),
      ],
    ),

    // 6. Barili Community Medical Clinic
    PrivateOrganization(
      id: 'barili_med_clinic',
      name: 'Barili Community Medical Clinic',
      category: 'Health & Medical',
      shortDescription:
          'Clinic schedules, doctor consultations, and health reminders.',
      about:
          'A premier private health facility offering general consultations, diagnostic laboratory services, pediatric care, and urgent outpatient management in Barili.',
      address: 'Poblacion, Barili, Cebu',
      website: 'https://www.barilimediclinic.com',
      brandColor: const Color(0xFF0D9488),
      fallbackIcon: Icons.favorite_rounded,
      baseFollowerCount: 580,
      isVerified: true,
      updates: [
        PrivateOrganizationUpdate(
          id: 'clinic_update_1',
          organizationId: 'barili_med_clinic',
          title: 'Visiting Specialist Consultation Schedule',
          content:
              'Pediatric and Internal Medicine specialists will be available for consultations this Saturday from 9:00 AM to 3:00 PM. Prior booking is encouraged.',
          date: DateTime(2026, 9, 27, 13, 0),
          category: 'Events',
        ),
      ],
    ),
  ];

  /// Finds any approved private organization by ID, name, or aliases.
  static PrivateOrganization? findByNameOrId(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return null;

    // Public institutions/state universities (e.g. CTU) are NOT private organizations.
    if (q == 'ctu' ||
        q.contains('ctu') ||
        q.contains('cebu tech') ||
        q.contains('cebu technological university')) {
      return null;
    }

    // 1. Exact match by id or name
    for (final org in approvedOrganizations) {
      if (org.id.toLowerCase() == q || org.name.toLowerCase() == q) {
        return org;
      }
    }

    // 3. Substring matching
    for (final org in approvedOrganizations) {
      if (org.name.toLowerCase().contains(q) && q.length >= 3) {
        return org;
      }
    }

    return null;
  }

  /// Dynamically constructs an organization profile so organizations/institutions
  /// never inappropriately render as a personal resident profile.
  static PrivateOrganization forOrganization(
    String organizationName, {
    String? category,
    String? address,
    String? website,
  }) {
    final clean = organizationName.trim();
    final slug = clean.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    final detectedCategory = category ?? normalizeCategoryName(clean);

    return PrivateOrganization(
      id: 'org_$slug',
      name: clean,
      category: detectedCategory,
      shortDescription:
          'Recognized partner organization operating in the Municipality of Barili.',
      about:
          '$clean is a registered partner institution and community stakeholder in Barili, providing regular announcements, public advisories, and community services to local residents.',
      address: address ?? 'Barili, Cebu',
      website: website ?? '',
      brandColor: colorForCategory(detectedCategory),
      fallbackIcon: iconForCategory(detectedCategory),
      baseFollowerCount: 350,
      isVerified: true,
    );
  }
}
