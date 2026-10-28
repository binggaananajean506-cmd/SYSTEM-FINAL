import '../../auth_service.dart';

enum AssistantDestination {
  none,
  home,
  announcements,
  emergencyCenter,
  hotlines,
  fileConcern,
  myConcerns,
  concernDraft,
  services,
  municipalOfficials,
  myBarangay,
  calendar,
  exploreBarili,
  profile,
  residentVerification,
  jobs,
  market,
  notifications,
  savedAnnouncements,
  barangayMap,
  bariliWeather,
  myMarketListings,
  bayanihanMessages,
}

class AssistantNavigationAction {
  const AssistantNavigationAction({
    this.destination = AssistantDestination.none,
    this.resourceId,
    this.query,
  });

  final AssistantDestination destination;
  final String? resourceId;
  final String? query;

  bool get isEmpty => destination == AssistantDestination.none;
}

class AssistantRouteEntry {
  const AssistantRouteEntry({
    required this.destination,
    required this.title,
    required this.parent,
    required this.description,
    required this.keywords,
    required this.allowedRoles,
    required this.actionLabel,
  });

  final AssistantDestination destination;
  final String title;
  final String parent;
  final String description;
  final List<String> keywords;
  final Set<UserRole> allowedRoles;
  final String actionLabel;

  bool allows(UserRole role) => allowedRoles.contains(role);

  Map<String, dynamic> toAssistantContext() => {
    'action': destination.name,
    'title': title,
    'parent': parent,
    'description': description,
    'keywords': keywords,
    'actionLabel': actionLabel,
  };
}

/// Source of truth for pages that the assistant can open from the resident app.
/// Entries point at existing screens; they are not a second navigation system.
abstract final class AppAssistantRouteRegistry {
  static const _allRoles = {
    UserRole.resident,
    UserRole.barangay,
    UserRole.partner,
    UserRole.lgu,
  };
  static const _residentOnly = {UserRole.resident};

  static const entries = <AssistantRouteEntry>[
    AssistantRouteEntry(
      destination: AssistantDestination.home,
      title: 'Home',
      parent: 'E-SUGID',
      description: 'Home dashboard and Community Bulletin overview.',
      keywords: ['home', 'dashboard', 'community bulletin'],
      allowedRoles: _allRoles,
      actionLabel: 'Open Home',
    ),
    AssistantRouteEntry(
      destination: AssistantDestination.announcements,
      title: 'Announcements',
      parent: 'Home > Community Bulletin',
      description:
          'Full list of official municipality and barangay announcements.',
      keywords: ['announcement', 'bulletin', 'advisory', 'community update'],
      allowedRoles: _allRoles,
      actionLabel: 'View Announcements',
    ),
    AssistantRouteEntry(
      destination: AssistantDestination.emergencyCenter,
      title: 'Emergency Center',
      parent: 'Alerts',
      description: 'Current emergency alerts and safety updates.',
      keywords: ['emergency', 'alert', 'warning', 'flood', 'danger'],
      allowedRoles: _allRoles,
      actionLabel: 'Open Emergency Center',
    ),
    AssistantRouteEntry(
      destination: AssistantDestination.hotlines,
      title: 'Emergency Hotlines',
      parent: 'Alerts',
      description:
          'Verified emergency agencies and tap-to-call contact numbers.',
      keywords: [
        'hotline',
        'police',
        'fire',
        'ambulance',
        'rescue',
        'phone number',
      ],
      allowedRoles: _residentOnly,
      actionLabel: 'Open Emergency Hotlines',
    ),
    AssistantRouteEntry(
      destination: AssistantDestination.fileConcern,
      title: 'File a Concern',
      parent: 'Report Center',
      description: 'Start the existing official resident concern form.',
      keywords: [
        'file concern',
        'report issue',
        'drainage',
        'electricity',
        'complaint',
      ],
      allowedRoles: _residentOnly,
      actionLabel: 'File a Concern',
    ),
    AssistantRouteEntry(
      destination: AssistantDestination.myConcerns,
      title: 'My Concerns',
      parent: 'Report Center',
      description: 'Track concerns submitted by the signed-in resident.',
      keywords: [
        'my concern',
        'concern status',
        'submitted concern',
        'track concern',
      ],
      allowedRoles: _residentOnly,
      actionLabel: 'View My Concerns',
    ),
    AssistantRouteEntry(
      destination: AssistantDestination.concernDraft,
      title: 'Unfinished Drafts',
      parent: 'Report Center > My Concerns',
      description: 'Resume a concern the signed-in resident explicitly saved.',
      keywords: ['draft', 'unfinished concern', 'continue concern'],
      allowedRoles: _residentOnly,
      actionLabel: 'Continue Draft',
    ),
    AssistantRouteEntry(
      destination: AssistantDestination.services,
      title: 'Services',
      parent: 'E-SUGID',
      description: 'Municipality services and resident community tools.',
      keywords: ['service', 'services hub'],
      allowedRoles: _allRoles,
      actionLabel: 'Open Services',
    ),
    AssistantRouteEntry(
      destination: AssistantDestination.municipalOfficials,
      title: 'Municipal Officials',
      parent: 'Services',
      description:
          'Current Mayor, Vice Mayor, councilors, and municipal officials.',
      keywords: [
        'mayor',
        'vice mayor',
        'councilor',
        'municipal officials',
        'people running the municipality',
      ],
      allowedRoles: _allRoles,
      actionLabel: 'View Municipal Officials',
    ),
    AssistantRouteEntry(
      destination: AssistantDestination.myBarangay,
      title: 'My Barangay',
      parent: 'Home',
      description:
          'Information and official updates for the signed-in user\'s barangay.',
      keywords: ['my barangay', 'barangay official', 'barangay captain'],
      allowedRoles: {UserRole.resident, UserRole.barangay},
      actionLabel: 'View My Barangay',
    ),
    AssistantRouteEntry(
      destination: AssistantDestination.calendar,
      title: 'Community Calendar',
      parent: 'Services',
      description: 'Upcoming community events and scheduled announcements.',
      keywords: ['calendar', 'event', 'schedule', 'coming event'],
      allowedRoles: _allRoles,
      actionLabel: 'Open Calendar',
    ),
    AssistantRouteEntry(
      destination: AssistantDestination.exploreBarili,
      title: 'Explore Barili',
      parent: 'Services',
      description:
          'Verified destinations, heritage places, and directions within Barili.',
      keywords: [
        'visit',
        'tourism',
        'destination',
        'heritage',
        'Mantayupan Falls',
        'directions',
      ],
      allowedRoles: _allRoles,
      actionLabel: 'Explore Barili',
    ),
    AssistantRouteEntry(
      destination: AssistantDestination.jobs,
      title: 'Bayanihan Works',
      parent: 'Services',
      description:
          'Community help requests and offers between verified residents.',
      keywords: [
        'bayanihan',
        'help request',
        'help residents',
        'community work',
      ],
      allowedRoles: _residentOnly,
      actionLabel: 'Open Bayanihan Works',
    ),
    AssistantRouteEntry(
      destination: AssistantDestination.market,
      title: 'Local Market',
      parent: 'Services',
      description: 'Browse and list local marketplace items.',
      keywords: ['market', 'sell', 'buy', 'item', 'product'],
      allowedRoles: _residentOnly,
      actionLabel: 'Open Local Market',
    ),
    AssistantRouteEntry(
      destination: AssistantDestination.profile,
      title: 'Profile',
      parent: 'E-SUGID',
      description: 'Account details, settings, and verification status.',
      keywords: [
        'profile',
        'account',
        'settings',
        'am i verified',
        'registered barangay',
      ],
      allowedRoles: _allRoles,
      actionLabel: 'Open Profile',
    ),
    AssistantRouteEntry(
      destination: AssistantDestination.residentVerification,
      title: 'Resident Verification',
      parent: 'Profile',
      description:
          'Submit or update the signed-in resident\'s verification documents.',
      keywords: [
        'verify my account',
        'resident verification',
        'verification document',
      ],
      allowedRoles: _residentOnly,
      actionLabel: 'Open Resident Verification',
    ),
    AssistantRouteEntry(
      destination: AssistantDestination.notifications,
      title: 'Notifications',
      parent: 'Home',
      description: 'Updates for the signed-in account.',
      keywords: ['notifications', 'inbox', 'unread updates'],
      allowedRoles: _allRoles,
      actionLabel: 'Open Notifications',
    ),
    AssistantRouteEntry(
      destination: AssistantDestination.savedAnnouncements,
      title: 'Saved Announcements',
      parent: 'Announcements',
      description: 'Announcements saved for later and offline reading.',
      keywords: ['saved announcements', 'bookmarks', 'offline announcements'],
      allowedRoles: _allRoles,
      actionLabel: 'View Saved Announcements',
    ),
    AssistantRouteEntry(
      destination: AssistantDestination.barangayMap,
      title: 'Barangay Map',
      parent: 'Services',
      description: 'Interactive map of Barili and its barangays.',
      keywords: ['map', 'barangay map', 'map of Barili'],
      allowedRoles: _allRoles,
      actionLabel: 'Open Barangay Map',
    ),
    AssistantRouteEntry(
      destination: AssistantDestination.bariliWeather,
      title: 'Barili Weather',
      parent: 'Home',
      description: 'Current weather and forecast for Barili.',
      keywords: ['weather', 'forecast', 'weather in Barili'],
      allowedRoles: _allRoles,
      actionLabel: 'View Barili Weather',
    ),
    AssistantRouteEntry(
      destination: AssistantDestination.myMarketListings,
      title: 'My Market Listings',
      parent: 'Local Market',
      description: 'Items posted by the signed-in resident.',
      keywords: ['my listings', 'my market posts', 'items I posted'],
      allowedRoles: _residentOnly,
      actionLabel: 'Open My Listings',
    ),
    AssistantRouteEntry(
      destination: AssistantDestination.bayanihanMessages,
      title: 'Bayanihan Messages',
      parent: 'Bayanihan Works',
      description: 'Conversations about help requests and offers.',
      keywords: ['Bayanihan messages', 'help conversations'],
      allowedRoles: _residentOnly,
      actionLabel: 'Open Bayanihan Messages',
    ),
  ];

  static AssistantRouteEntry? entryFor(AssistantDestination destination) {
    for (final entry in entries) {
      if (entry.destination == destination) return entry;
    }
    return null;
  }

  static bool allows(AssistantDestination destination, UserRole role) =>
      destination == AssistantDestination.none ||
      (entryFor(destination)?.allows(role) ?? false);

  static List<Map<String, dynamic>> contextFor(UserRole role) => entries
      .where((entry) => entry.allows(role))
      .map((entry) => entry.toAssistantContext())
      .toList(growable: false);
}
