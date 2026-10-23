import 'dart:async';
import 'dart:io';

import 'package:esugid/core/widgets/app_feedback.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/announcement_image_cache.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';
import 'package:esugid/app_motion.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme_controller.dart';
import 'auth_service.dart';
import 'pages/concern_center_page.dart';
import 'pages/profile_page.dart';
import 'pages/barangay_page.dart';
import 'pages/officials_page.dart';
import 'pages/carabao_game_page.dart';
import 'pages/jobs_page.dart';
import 'pages/marketplace_page.dart';
import 'pages/my_listings_page.dart';
import 'pages/resident_map_page.dart';
import 'pages/explore_barili_page.dart';
import 'pages/emergency_hotlines_page.dart';
import 'community_service.dart';
import 'barili_barangays.dart';
import 'emergency_service.dart';
import 'emergency_alert_service.dart';
import 'submission_service.dart';
import 'pending_approval_screen.dart';
import 'verification_screen.dart';
import 'widgets/exit_confirmation_dialog.dart';
import 'widgets/community_post_widgets.dart';
import 'widgets/home_header_status_bar.dart';
import 'widgets/user_profile_avatar.dart';
import 'widgets/esugid_page_header.dart';
import 'core/widgets/async_error_view.dart';
import 'core/widgets/esugid_pull_to_refresh.dart';
import 'features/home/presentation/authenticated_bottom_navigation.dart';
import 'features/home/presentation/hub_service_cards.dart';
import 'features/home/presentation/services_directory.dart';
import 'features/home/data/dashboard_announcement_cache.dart';
import 'features/notifications/presentation/notification_inbox.dart';
import 'features/notifications/application/open_notification.dart';
import 'features/calendar/presentation/calendar_page.dart';
import 'features/calendar/domain/calendar_event.dart';
import 'features/app_assistant/app_assistant_launcher.dart';
import 'features/app_assistant/app_assistant_dock.dart';
import 'features/app_assistant/app_assistant_service.dart';
import 'features/bayanihan_messages/presentation/pages/bayanihan_messages_page.dart';
import 'services/barili_weather_service.dart';
import 'services/concern_draft_store.dart';
import 'pages/barili_weather_page.dart';
import 'widgets/weather_animation_effects.dart';
import 'features/saved_announcements/domain/offline_announcement.dart';
import 'features/saved_announcements/presentation/saved_announcements_page.dart';
import 'features/saved_announcements/services/saved_announcement_service.dart';
import 'services/smart_announcement_search.dart';
import 'services/private_organization_service.dart';
import 'pages/discover_private_organizations_page.dart';

enum _BulletinCategory { all, notices, advisory, events }

enum _BulletinView { all, saved }

enum _ResidentFeatureAction { barangay, map, explore }

/// Returns the resident's assigned barangay for the compact Home header.
///
/// Verified barangay IDs take precedence because they are assigned by an
/// authorized reviewer. Newly registered residents fall back to the barangay
/// stored on their profile while their verification is still pending.
String homeLocationLabelForUser(User user) {
  final barangay =
      bariliBarangayNameForId(user.verifiedBarangayId) ??
      canonicalBariliBarangay(user.barangay) ??
      bariliBarangayNameForId(user.barangayId);

  return barangay == null ? 'Barili, Cebu' : '$barangay, Barili';
}

bool _matchesBulletinCategory(CommunityPost post, _BulletinCategory category) {
  if (category == _BulletinCategory.all) return true;

  final tag = post.tag.toLowerCase();
  final title = post.title.toLowerCase();
  final content = post.content.toLowerCase();
  final priority = post.priority.toLowerCase();
  final displayCategory = post.displayCategory.toLowerCase();
  final postCategory = post.category.toLowerCase();
  final announcementType = post.announcementType.toLowerCase();

  bool containsAny(List<String> keywords) {
    return keywords.any(
      (keyword) =>
          title.contains(keyword) ||
          content.contains(keyword) ||
          tag.contains(keyword) ||
          displayCategory.contains(keyword) ||
          postCategory.contains(keyword) ||
          announcementType.contains(keyword),
    );
  }

  switch (category) {
    case _BulletinCategory.notices:
      return tag.contains('notice') ||
          tag.contains('community') ||
          containsAny(const [
            'notice',
            'ordinance',
            'resolution',
            'memorandum',
            'memo',
            'update',
            'announcement',
            'community',
            'bulletin',
            'barangay',
          ]);
    case _BulletinCategory.advisory:
      return tag.contains('advisory') ||
          tag.contains('official') ||
          priority == 'urgent' ||
          priority == 'emergency' ||
          containsAny(const [
            'advisory',
            'alert',
            'weather',
            'utility',
            'interruption',
            'power',
            'water',
            'flood',
            'typhoon',
            'storm',
            'warning',
            'electric',
          ]);
    case _BulletinCategory.events:
      return post.hasCalendarSchedule ||
          tag.contains('event') ||
          containsAny(const [
            'event',
            'activity',
            'seminar',
            'gathering',
            'celebration',
            'festival',
            'meeting',
            'fiesta',
            'fair',
            'schedule',
          ]);
    case _BulletinCategory.all:
      return true;
  }
}

class _ResidentFeature {
  final String eyebrow;
  final String title;
  final String description;
  final String buttonLabel;
  final String imageAsset;
  final Alignment imageAlignment;
  final IconData icon;
  final _ResidentFeatureAction action;

  const _ResidentFeature({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.imageAsset,
    required this.imageAlignment,
    required this.icon,
    required this.action,
  });
}

const _residentFeatures = <_ResidentFeature>[
  _ResidentFeature(
    eyebrow: 'Your Local Government',
    title: 'My Barangay,\nStronger Together.',
    description: 'Stay updated with your local community.',
    buttonLabel: 'View My Barangay',
    imageAsset: 'assets/images/resident_dashboard/municipall-hall.png',
    imageAlignment: Alignment.centerRight,
    icon: Icons.account_balance_rounded,
    action: _ResidentFeatureAction.barangay,
  ),
  _ResidentFeature(
    eyebrow: 'Beauty and Beyond',
    title: 'Explore\nMantayupan Falls.',
    description: 'Experience Barili’s iconic waterfall and natural beauty.',
    buttonLabel: 'Open Map',
    imageAsset: 'assets/images/resident_dashboard/mantayupanfalls.png',
    imageAlignment: Alignment.centerRight,
    icon: Icons.map_rounded,
    action: _ResidentFeatureAction.map,
  ),
  _ResidentFeature(
    eyebrow: 'Barili Heritage',
    title: 'Visit Sta. Ana\nParish Church.',
    description: 'Discover a treasured landmark in the heart of Barili.',
    buttonLabel: 'Explore Barili',
    imageAsset: 'assets/images/resident_dashboard/santa-ana.png',
    imageAlignment: Alignment.center,
    icon: Icons.church_rounded,
    action: _ResidentFeatureAction.explore,
  ),
];

class HomeScreen extends StatefulWidget {
  final int initialPage;

  const HomeScreen({super.key, this.initialPage = 0});

  @visibleForTesting
  static Widget emergencyHotlinesShortcutCardForTest(BuildContext context) {
    return _HomeScreenState.buildEmergencyHotlinesShortcutCard(context);
  }

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final ValueNotifier<int> _selectedPageIndex;
  int get _selectedIndex => _selectedPageIndex.value;
  final Set<int> _visitedPageIndexes = {0};
  final ValueNotifier<int> _residentBannerPage = ValueNotifier(0);
  final ValueNotifier<int> _postPriorityTick = ValueNotifier(0);
  final PageController _residentBannerController = PageController();
  late final Stream<User?> _currentUserStream;
  late final ValueNotifier<BariliWeather?> _weather;
  bool _weatherRefreshInProgress = false;
  Timer? _weatherRefreshTimer;
  Timer? _postPriorityRefreshTimer;
  final Set<int> _residentAssetsPrecached = <int>{};
  int _alertsInitialTab = 0;
  final DashboardAnnouncementCache _announcementCache =
      DashboardAnnouncementCache();
  StreamSubscription<dynamic>? _announcementSubscription;
  Timer? _announcementInitialLoadTimer;
  List<CommunityPost> _cachedPosts = const [];
  _BulletinCategory _selectedHomeCategory = _BulletinCategory.all;
  CommunityAlert? _activeEmergency;
  bool _announcementInitialLoadComplete = false;
  String? _targetUpdatesPostId;
  final Map<String, GlobalKey> _updatesPostKeys = {};
  bool _announcementRefreshInProgress = false;
  String? _announcementRefreshError;
  String? _headerNotificationUserId;
  Stream<List<ResidentNotification>>? _headerNotificationStream;
  String? _lastLoadedUrgentUserId;
  Set<String> _viewedUrgentPostIds = <String>{};

  // Barili, Cebu Coordinates
  final TextEditingController _updatesSearchController =
      TextEditingController();
  String _updatesSearchQuery = '';
  SmartTimePreset _updatesTimePreset = SmartTimePreset.anyTime;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _announcementEventLocationController =
      TextEditingController();
  String _announcementVisibility = 'public';
  String _announcementPriority = 'regular';
  DateTime? _announcementPriorityExpiresAt;
  Set<String> _selectedAnnouncementBarangays = {};
  Set<String> _allowedAnnouncementBarangays = {};
  bool _canPublishMunicipalityWide = false;
  XFile? _announcementImage;
  Uint8List? _announcementImageBytes;
  bool _announcementAddToCalendar = false;
  bool _announcementEventAllDay = true;
  String _announcementType = 'general';
  String _announcementCategory = 'Community Activity';
  DateTime? _announcementEventStartAt;
  DateTime? _announcementEventEndAt;

  @override
  void initState() {
    super.initState();
    final initialPage = widget.initialPage.clamp(0, 4);
    _selectedPageIndex = ValueNotifier(initialPage);
    _visitedPageIndexes.add(initialPage);
    WidgetsBinding.instance.addObserver(this);
    _currentUserStream = AuthService.currentUserDocStream;
    _weather = ValueNotifier(null);
    unawaited(_initializeAnnouncementFeed());
    unawaited(_initializeWeather());
    unawaited(_checkActiveEmergency());
    unawaited(_loadViewedUrgentPostIds());
    unawaited(PrivateOrganizationService.instance.init());
    PrivateOrganizationService.instance.feedFilterChanges.addListener(
      _onFeedFilterChanged,
    );
    _weatherRefreshTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => _refreshWeather(),
    );
    _postPriorityRefreshTimer = Timer.periodic(const Duration(seconds: 30), (
      _,
    ) {
      if (mounted && _selectedIndex == 0) _postPriorityTick.value++;
    });
  }

  Future<void> _initializeWeather() async {
    final cached = await BariliWeatherService.loadCached();
    if (mounted && cached != null) _weather.value = cached;
    if (cached == null || !BariliWeatherService.isCacheFresh(cached)) {
      await _refreshWeather();
    }
  }

  Future<void> _initializeAnnouncementFeed() async {
    final locallyStored = await _announcementCache.load();
    if (!mounted) return;
    if (locallyStored.isNotEmpty) {
      setState(() {
        _cachedPosts = locallyStored;
        _announcementInitialLoadComplete = true;
      });
      _precacheTopAnnouncementImages(locallyStored);
    }

    await _announcementSubscription?.cancel();
    final user = AuthService.currentUser;
    if (user != null) {
      _announcementSubscription = CommunityService.approvedPostsForUser(user)
          .listen(
            (postList) {
              if (!mounted) return;
              final posts = CommunityService.sortPostsForFeed(postList);
              setState(() {
                _cachedPosts = posts;
                _announcementInitialLoadComplete = true;
                _announcementInitialLoadTimer?.cancel();
                _announcementRefreshError = null;
              });
              _precacheTopAnnouncementImages(posts);
              unawaited(_saveAnnouncementSnapshot(posts));
            },
            onError: (Object error, StackTrace stackTrace) {
              debugPrint(
                'Community Bulletin stream failed: $error\n$stackTrace',
              );
              if (!mounted) return;
              _announcementInitialLoadTimer?.cancel();
              setState(() {
                _announcementInitialLoadComplete = true;
                _announcementRefreshError = "Couldn't refresh. Try again.";
              });
            },
          );
    } else {
      _announcementSubscription = CommunityService.publicPostSnapshots().listen(
        (snapshot) {
          if (!mounted) return;
          // Firestore can first report an empty device cache. Preserve our last
          // successful durable snapshot until the server has actually replied.
          if (snapshot.isFromCache &&
              snapshot.posts.isEmpty &&
              _cachedPosts.isNotEmpty) {
            return;
          }
          final posts = CommunityService.sortPostsForFeed(snapshot.posts);
          setState(() {
            _cachedPosts = posts;
            if (posts.isNotEmpty || !snapshot.isFromCache) {
              _announcementInitialLoadComplete = true;
              _announcementInitialLoadTimer?.cancel();
            }
            if (!snapshot.isFromCache) _announcementRefreshError = null;
          });
          _precacheTopAnnouncementImages(posts);
          if (!snapshot.isFromCache) {
            unawaited(_saveAnnouncementSnapshot(posts));
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('Community Bulletin stream failed: $error\n$stackTrace');
          if (!mounted) return;
          _announcementInitialLoadTimer?.cancel();
          setState(() {
            _announcementInitialLoadComplete = true;
            _announcementRefreshError = "Couldn't refresh. Try again.";
          });
        },
      );
    }
    _announcementInitialLoadTimer?.cancel();
    _announcementInitialLoadTimer = Timer(const Duration(seconds: 8), () {
      if (!mounted || _announcementInitialLoadComplete) return;
      setState(() {
        _announcementInitialLoadComplete = true;
        _announcementRefreshError = "Couldn't refresh. Try again.";
      });
    });
  }

  void _precacheTopAnnouncementImages(List<CommunityPost> posts) {
    if (!mounted) return;
    for (final post in posts.take(6)) {
      final local = post.localImagePath.trim();
      if (local.isNotEmpty && File(local).existsSync()) {
        try {
          unawaited(precacheImage(FileImage(File(local)), context));
        } catch (_) {}
      } else if (post.imageUrl.trim().isNotEmpty) {
        unawaited(AnnouncementImageCache.precache(post.imageUrl, context));
      }
    }
  }

  Future<void> _saveAnnouncementSnapshot(List<CommunityPost> posts) async {
    try {
      await _announcementCache.save(posts);
    } catch (error, stackTrace) {
      debugPrint('Community Bulletin cache save failed: $error\n$stackTrace');
    }
  }

  Future<bool> _refreshAnnouncements({bool reportFailure = false}) async {
    if (_announcementRefreshInProgress) return false;
    final previousSignature = _communityPostSignature(_cachedPosts);
    setState(() {
      _announcementRefreshInProgress = true;
      _announcementRefreshError = null;
    });
    try {
      final user = AuthService.currentUser;
      final posts = user != null
          ? await CommunityService.fetchApprovedPostsForUserFromServer(user)
          : await CommunityService.fetchPublicPostsFromServer();
      final sorted = CommunityService.sortPostsForFeed(posts);
      if (!mounted) return false;
      setState(() {
        _cachedPosts = sorted;
        _announcementInitialLoadComplete = true;
      });
      await _saveAnnouncementSnapshot(sorted);
      return previousSignature != _communityPostSignature(sorted);
    } catch (error, stackTrace) {
      debugPrint('Community Bulletin refresh failed: $error\n$stackTrace');
      if (mounted) {
        setState(() {
          _announcementInitialLoadComplete = true;
          _announcementRefreshError =
              "Couldn't refresh. Pull down to try again.";
        });
      }
      if (reportFailure) rethrow;
      return false;
    } finally {
      if (mounted) setState(() => _announcementRefreshInProgress = false);
    }
  }

  Future<bool> _refreshWeather({bool reportFailure = false}) async {
    if (!mounted || _weatherRefreshInProgress) return false;
    final previous = _weather.value;
    _weatherRefreshInProgress = true;
    try {
      final latest = await BariliWeatherService.fetchLatest();
      if (mounted) _weather.value = latest;
      return previous?.temperatureCelsius != latest.temperatureCelsius ||
          previous?.weatherCode != latest.weatherCode ||
          previous?.isDay != latest.isDay;
    } catch (_) {
      // Preserve the last valid reading when the network is unavailable. The
      // header refresh is intentionally silent and never blocks Home.
      if (reportFailure) rethrow;
      return false;
    } finally {
      _weatherRefreshInProgress = false;
    }
  }

  String _communityPostSignature(Iterable<CommunityPost> posts) => posts
      .map(
        (post) =>
            '${post.id}|${post.title}|${post.status}|${post.createdAt.toIso8601String()}',
      )
      .join('||');

  String _userSignature(User? user) => user?.toMap().toString() ?? '';

  Future<ESugidRefreshOutcome> _refreshHomePage() async {
    final previousUser = _userSignature(AuthService.currentUser);
    final results = await Future.wait<bool>([
      _refreshAnnouncements(reportFailure: true),
      _refreshWeather(reportFailure: true),
      AuthService.refreshCurrentUserFromServer().then(
        (user) => previousUser != _userSignature(user),
      ),
    ]);
    return results.any((changed) => changed)
        ? ESugidRefreshOutcome.updated
        : ESugidRefreshOutcome.upToDate;
  }

  Future<ESugidRefreshOutcome> _refreshAlertsPage(User user) async {
    final tasks = <Future<Object>>[
      CommunityService.fetchAlertsFromServer(user),
      AuthService.refreshCurrentUserFromServer(),
    ];
    if (user.role != UserRole.resident) {
      tasks.add(EmergencyService.fetchReportsFromServer(user));
    }
    await Future.wait(tasks);
    return ESugidRefreshOutcome.updated;
  }

  Future<ESugidRefreshOutcome> _refreshServicesPage(User user) async {
    final previousUser = _userSignature(user);
    final refreshedUser = await AuthService.refreshCurrentUserFromServer();
    return previousUser == _userSignature(refreshedUser)
        ? ESugidRefreshOutcome.upToDate
        : ESugidRefreshOutcome.updated;
  }

  Future<ESugidRefreshOutcome> _refreshPartnerPosts(User user) async {
    await Future.wait<Object>([
      CommunityService.fetchPostsForAuthorFromServer(user.uid),
      AuthService.refreshCurrentUserFromServer(),
    ]);
    return ESugidRefreshOutcome.updated;
  }

  Future<ESugidRefreshOutcome> _refreshPartnerNotifications(User user) async {
    await SubmissionService.fetchNotificationsFromServer(user.uid);
    return ESugidRefreshOutcome.updated;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshWeather();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheResidentFeature(0);
    _precacheResidentFeature(1);
  }

  void _precacheResidentFeature(int index) {
    if (index < 0 || index >= _residentFeatures.length) return;
    if (!_residentAssetsPrecached.add(index)) return;
    SchedulerBinding.instance.scheduleTask(
      () {
        if (!mounted) return Future<void>.value();
        return precacheImage(
          ResizeImage.resizeIfNeeded(
            1200,
            null,
            AssetImage(_residentFeatures[index].imageAsset),
          ),
          context,
        );
      },
      Priority.idle,
      debugLabel: 'Precache resident banner $index',
    );
  }

  void _selectPage(int index) {
    if (_selectedIndex == index) return;
    final user = AuthService.currentUser;
    if (user != null &&
        user.role == UserRole.resident &&
        !user.canUseInteractiveFeatures &&
        index == 2) {
      _showVerificationRequired(user);
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    final isFirstVisit = _visitedPageIndexes.add(index);
    // Build a lazy page once. Subsequent tab switches update only the shell's
    // Stack instead of rebuilding the full home feed and every visited page.
    if (isFirstVisit) setState(() {});
    _selectedPageIndex.value = index;
  }

  Future<void> _openAssistantDestination(
    AssistantNavigationAction action,
    User user,
  ) async {
    switch (action.destination) {
      case AssistantDestination.none:
        return;
      case AssistantDestination.home:
        _selectPage(0);
        return;
      case AssistantDestination.announcements:
        _openAllCommunityPosts(user);
        return;
      case AssistantDestination.emergencyCenter:
        _openAlertsTab(0);
        return;
      case AssistantDestination.hotlines:
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const EmergencyHotlinesPage()),
        );
        return;
      case AssistantDestination.fileConcern:
        if (user.role != UserRole.resident || !_ensureInteractiveAccess(user)) {
          return;
        }
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const ConcernCenterPage(formOnly: true),
          ),
        );
        return;
      case AssistantDestination.myConcerns:
        if (user.role != UserRole.resident) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const ConcernCenterPage(initialCenterTab: 1),
          ),
        );
        return;
      case AssistantDestination.concernDraft:
        if (user.role != UserRole.resident) return;
        final preferences = await SharedPreferences.getInstance();
        if (!mounted) return;
        final drafts = ConcernDraftStore(preferences, user.uid).list();
        Map<String, dynamic>? draft;
        final requestedId = action.resourceId?.trim();
        for (final candidate in drafts) {
          if (requestedId == null || requestedId.isEmpty) {
            draft = candidate;
            break;
          }
          if (candidate['id']?.toString() == requestedId) {
            draft = candidate;
            break;
          }
        }
        if (draft == null) {
          ScaffoldMessenger.of(context).showAppSnackBar(
            AppSnackBar(content: Text('No unfinished draft was found.'),
              kind: FeedbackKind.info,
            ),
          );
          return;
        }
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ConcernCenterPage(formOnly: true, draft: draft),
          ),
        );
        return;
      case AssistantDestination.services:
        _selectPage(3);
        return;
      case AssistantDestination.municipalOfficials:
        await Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const OfficialsPage()));
        return;
      case AssistantDestination.myBarangay:
        final barangay = canonicalBariliBarangay(user.barangay);
        final initialBarangayPosts = barangay == null
            ? null
            : _cachedPosts
                .where((p) =>
                    canonicalBariliBarangay(p.targetBarangay) == barangay ||
                    canonicalBariliBarangay(p.authorBarangay) == barangay,
                  )
                .toList();
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => BarangayPage(
              initialData: user,
              initialPosts: (initialBarangayPosts != null &&
                      initialBarangayPosts.isNotEmpty)
                  ? initialBarangayPosts
                  : CommunityService.latestBarangayPosts(user.barangay),
            ),
          ),
        );
        return;
      case AssistantDestination.calendar:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => CalendarPage(user: user)),
        );
        return;
      case AssistantDestination.exploreBarili:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ExploreBariliPage(
              initialQuery: action.query,
              openFirstResult: action.query?.trim().isNotEmpty == true,
            ),
          ),
        );
        return;
      case AssistantDestination.profile:
        _selectPage(4);
        return;
      case AssistantDestination.residentVerification:
        if (user.role != UserRole.resident) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const VerificationScreen()),
        );
        return;
      case AssistantDestination.jobs:
        if (!_ensureInteractiveAccess(user)) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => JobsPage(initialRequestId: action.resourceId),
          ),
        );
        return;
      case AssistantDestination.market:
        if (!_ensureInteractiveAccess(user)) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const MarketplacePage()),
        );
        return;
      case AssistantDestination.notifications:
        _openNotifications(user);
        return;
      case AssistantDestination.savedAnnouncements:
        _openAllCommunityPosts(user, savedOnly: true);
        return;
      case AssistantDestination.barangayMap:
        _openMap();
        return;
      case AssistantDestination.bariliWeather:
        _openWeatherPage();
        return;
      case AssistantDestination.myMarketListings:
        if (!_ensureInteractiveAccess(user)) return;
        await Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const MyListingsPage()));
        return;
      case AssistantDestination.bayanihanMessages:
        if (!_ensureInteractiveAccess(user)) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => BayanihanMessagesPage(user: user),
          ),
        );
        return;
    }
  }

  bool _ensureInteractiveAccess(User user) {
    if (user.canUseInteractiveFeatures) return true;
    _showVerificationRequired(user);
    return false;
  }

  void _showVerificationRequired(User user) {
    final restricted = user.isRestricted;
    final status = user.verificationStatus;
    final isPending =
        status == VerificationStatus.submitted ||
        status == VerificationStatus.underReview;
    final needsAdditionalDocument =
        status == VerificationStatus.additionalDocumentRequired;
    final needsAttention =
        needsAdditionalDocument || status == VerificationStatus.rejected;
    final barangay = user.barangay?.trim();
    final title = restricted
        ? 'Account Restricted'
        : isPending
        ? 'Verification is being reviewed'
        : needsAttention
        ? 'Verification needs attention'
        : 'Resident verification required';
    final message = restricted
        ? 'Your account currently has limited access. Please contact your barangay office for assistance.'
        : isPending
        ? 'Barangay ${barangay?.isNotEmpty == true ? barangay : 'officials'} will review your documents. You can continue reading public information while you wait.'
        : needsAttention
        ? (user.verificationReviewReason?.trim().isNotEmpty == true
              ? 'Reason: ${user.verificationReviewReason!.trim()}${user.verificationReviewNote?.trim().isNotEmpty == true ? '\n${user.verificationReviewNote!.trim()}' : ''}'
              : "We couldn't confirm your residency from the document you submitted.")
        : 'Verify your residency before using this feature.';
    final actionLabel = restricted
        ? 'Okay'
        : isPending
        ? 'Okay'
        : needsAttention
        ? 'Resubmit document'
        : 'Verify my account';

    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color:
                    (needsAttention
                            ? sheetContext.colors.errorSurface
                            : sheetContext.colors.surfaceAlt)
                        .withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(
                isPending
                    ? Icons.hourglass_top_rounded
                    : needsAttention
                    ? Icons.error_outline_rounded
                    : Icons.verified_user_outlined,
                color: needsAttention ? sheetContext.colors.error
                    : sheetContext.colors.primaryGreen,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: sheetContext.colors.textSecondary,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 19),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  if (!restricted && !isPending) {
                    Navigator.pushNamed(context, '/verification');
                  }
                },
                style: FilledButton.styleFrom(
                  foregroundColor: sheetContext.colors.onAccent,

                  backgroundColor: sheetContext.colors.brand,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openAlertsTab(int tab) {
    if (_alertsInitialTab != tab) {
      setState(() => _alertsInitialTab = tab);
    }
    _selectPage(1);
  }

  /// Follows decide which organization posts Home and Updates show.
  void _onFeedFilterChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    PrivateOrganizationService.instance.feedFilterChanges.removeListener(
      _onFeedFilterChanged,
    );
    WidgetsBinding.instance.removeObserver(this);
    _weatherRefreshTimer?.cancel();
    _postPriorityRefreshTimer?.cancel();
    _announcementInitialLoadTimer?.cancel();
    unawaited(_announcementSubscription?.cancel());
    _selectedPageIndex.dispose();
    _residentBannerPage.dispose();
    _postPriorityTick.dispose();
    _weather.dispose();
    _residentBannerController.dispose();
    _updatesSearchController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _announcementEventLocationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _currentUserStream,
      builder: (context, snapshot) {
        final user = snapshot.data ?? AuthService.currentUser;
        if (user == null) {
          return Scaffold(
            backgroundColor: context.colors.background,
            body: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: LinearProgressIndicator(minHeight: 2),
              ),
            ),
          );
        }

        if (user.isRestricted || !user.isActive) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          });
          return PendingApprovalScreen(user: user);
        }

        final String userName =
            user.role == UserRole.partner &&
                (user.organizationName?.trim().isNotEmpty ?? false)
            ? user.organizationName!.trim()
            : user.name.split(' ').first;
        final bool isPartner = user.role == UserRole.partner;
        final bool isBarangay = user.role == UserRole.barangay;

        final pages = (isPartner || isBarangay)
            ? <Widget>[
                _buildHomeFeed(userName, user),
                _visitedPageIndexes.contains(1)
                    ? (isPartner
                          ? _buildPartnerMyPostsPage(user)
                          : _buildAlertsPage(user))
                    : const SizedBox.shrink(),
                const SizedBox.shrink(),
                _visitedPageIndexes.contains(3)
                    ? (isPartner
                          ? _buildPartnerNotificationsPage(user)
                          : _buildServicesPage(user))
                    : const SizedBox.shrink(),
                _visitedPageIndexes.contains(4)
                    ? const ProfilePage()
                    : const SizedBox.shrink(),
              ]
            : <Widget>[
                _buildHomeFeed(userName, user),
                _visitedPageIndexes.contains(1)
                    ? _buildUpdatesPage(user)
                    : const SizedBox.shrink(),
                _visitedPageIndexes.contains(2)
                    ? ConcernCenterPage(
                        onOpenAlerts: () => _openAlertsModal(user),
                      )
                    : const SizedBox.shrink(),
                _visitedPageIndexes.contains(3)
                    ? _buildServicesPage(user)
                    : const SizedBox.shrink(),
                _visitedPageIndexes.contains(4)
                    ? const ProfilePage()
                    : const SizedBox.shrink(),
              ];

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            if (_selectedPageIndex.value != 0) {
              _selectPage(0);
              return;
            }
            final shouldExit = await showExitConfirmationDialog(context);
            if (shouldExit == true) {
              await SystemNavigator.pop();
            }
          },
          child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          // Each tab owns its own Scaffold. Resizing this outer shell rebuilt
          // and relaid out all five cached tabs whenever the keyboard moved.
          resizeToAvoidBottomInset: false,
          body: ValueListenableBuilder<int>(
            valueListenable: _selectedPageIndex,
            builder: (context, selectedIndex, _) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final usesLightStatusIcons = selectedIndex != 2 || isDark;
              final navigationReservedHeight =
                  authenticatedBottomNavigationReservedHeight(context);
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: usesLightStatusIcons
                      ? Brightness.light
                      : Brightness.dark,
                  statusBarBrightness: usesLightStatusIcons
                      ? Brightness.dark
                      : Brightness.light,
                  systemNavigationBarColor: Theme.of(
                    context,
                  ).scaffoldBackgroundColor,
                  systemNavigationBarIconBrightness: isDark
                      ? Brightness.light
                      : Brightness.dark,
                  systemNavigationBarContrastEnforced: false,
                ),
                child: Stack(
                  children: [
                    AppAssistantDock(
                      bottomInset: navigationReservedHeight,
                      visible: MediaQuery.viewInsetsOf(context).bottom == 0,
                      reserveRightCorner:
                          selectedIndex == 0 && user.role == UserRole.barangay,
                      launcher: AppAssistantLauncher(
                        user: user,
                        onNavigate: (action) =>
                            _openAssistantDestination(action, user),
                      ),
                      child: ESugidAnimatedIndexedStack(
                        index: selectedIndex,
                        children: pages,
                      ),
                    ),
                    if (selectedIndex == 0 && user.role == UserRole.barangay)
                      Positioned(
                        right: 18,
                        bottom: navigationReservedHeight + 2,
                        child: _buildBarangayConcernAction(user),
                      ),
                    AuthenticatedBottomNavigation(
                      selectedIndex: selectedIndex,
                      user: user,
                      onSelect: _selectPage,
                      onPrimaryAction: () => _handlePrimaryAction(user),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    },
  );
  }

  Widget _buildHomeFeed(String name, User user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaQuery = MediaQueryData(
      size: MediaQuery.sizeOf(context),
      padding: MediaQuery.paddingOf(context),
      textScaler: MediaQuery.textScalerOf(context),
    );
    final horizontalPadding = responsiveHomeHorizontalPadding(
      mediaQuery.size.width,
    );
    final navigationReservedHeight =
        authenticatedBottomNavigationReservedHeight(context);
    final floatingActionsHeight = user.role == UserRole.barangay ? 140.0 : 74.0;

    final sortedPosts = CommunityService.sortPostsForFeed(
      PrivateOrganizationService.instance.visiblePosts(_cachedPosts),
    );

    if (_lastLoadedUrgentUserId != user.uid) {
      _lastLoadedUrgentUserId = user.uid;
      unawaited(_loadViewedUrgentPostIds(user.uid));
    }
    final filteredPosts = CommunityService.sortPostsByNewest(
      sortedPosts.where((post) {
        if (_selectedHomeCategory == _BulletinCategory.all) return true;
        return _matchesBulletinCategory(post, _selectedHomeCategory);
      }),
    );

    // Limit dashboard announcements to the 5 latest items; older posts reside in Updates page
    final homeFeedPosts = filteredPosts.take(5).toList();

    return Container(
      decoration: BoxDecoration(
        color: context.colors.background,
      ),
      child: ESugidPullToRefresh(
        onRefresh: _refreshHomePage,
        child: CustomScrollView(
          scrollCacheExtent: const ScrollCacheExtent.pixels(420),
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _CollapsingHomeHeaderDelegate(
                minHeight: responsiveCompactHomeHeaderExtent(mediaQuery),
                maxHeight: responsiveHomeHeaderExtent(
                  mediaQuery,
                  hasEyebrow: user.role == UserRole.partner,
                ),
                builder: (context, collapseProgress) => RepaintBoundary(
                  child: _buildHomeHeader(
                    name,
                    user,
                    collapseProgress: collapseProgress,
                  ),
                ),
              ),
            ),
            if (user.role == UserRole.resident) ...[
              // View My Barangay Card
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  10,
                  horizontalPadding,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: RepaintBoundary(
                    child: _buildResidentCommunityBanner(user),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // ACTIVE EMERGENCY BANNER (only when active)
              if (_activeEmergency != null) ...[
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  sliver: SliverToBoxAdapter(
                    child: _buildActiveEmergencyBanner(_activeEmergency!),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
              ],
            ],

            // CATEGORIES FILTER (Above Urgent Announcements)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                user.role == UserRole.resident ? 2 : 10,
                horizontalPadding,
                10,
              ),
              sliver: SliverToBoxAdapter(child: _buildCommunityCategoryPills()),
            ),

            SliverToBoxAdapter(
              child: _buildPinnedUrgentAnnouncementsSection(
                posts: sortedPosts,
                isDark: isDark,
              ),
            ),

            if (_announcementRefreshError != null)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  0,
                  horizontalPadding,
                  10,
                ),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: context.colors.error,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          _announcementRefreshError!,
                          style: GoogleFonts.outfit(
                            color: context.colors.warning,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // LATEST ANNOUNCEMENTS SECTION HEADER (With View All)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  8,
                  horizontalPadding,
                  8,
                ),
                sliver: SliverToBoxAdapter(
                  child: _buildCommunityUpdatesSectionHeader(
                    isDark: isDark,
                    category: _selectedHomeCategory,
                  ),
                ),
              ),

              if (!_announcementInitialLoadComplete)
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  sliver: SliverToBoxAdapter(
                    child: _buildAnnouncementSkeleton()),
                )
              else if (filteredPosts.isEmpty)
                SliverToBoxAdapter(
                  child: _buildCategoryEmptyState(
                    _categoryLabelForEmptyState(_selectedHomeCategory),
                    isDark,
                  ),
                )
              else ...[
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final post = homeFeedPosts[index];
                      return ModernPostCard(
                        key: ValueKey(
                          'home-feed-${_selectedHomeCategory.name}-${post.id}',
                        ),
                        post: post,
                        heroScope: 'home_feed',
                        animateEntrance: index < 5,
                      );
                    }, childCount: homeFeedPosts.length),
                  ),
                ),
                if (filteredPosts.length > 5)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        6,
                        horizontalPadding,
                        16,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                            context.colors.surface,
                            context.colors.surfaceAlt,
                            context.colors.surfaceAlt,
                                  ],
                          ),
                          border: Border.all(
                            color: isDark
                                ? context.colors.primaryGreen.withValues(alpha: 0.35,
                                  )
                              : context.colors.primaryGreen.withValues(alpha: 0.50,
                                ),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? context.colors.brandStrong.withValues(alpha: 0.35,
                                    )
                                : context.colors.brandStrong.withValues(alpha: 0.10,
                                  ),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            key: const ValueKey('home-feed-view-all-footer'),
                            onTap: () {
                              setState(() {
                                _selectedHomeCategory = _selectedHomeCategory;
                              });
                              _selectPage(1);
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              child: Row(
                                children: [
                                  // Left Medallion Icon
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                        context.colors.brand,
                                        context.colors.brand,
                                        context.colors.brandStrong,
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: context.colors.brandStrong
                                            .withValues(alpha: 0.35),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Icon(
                                        Icons.newspaper_rounded,
                                        color: context.colors.onAccent,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  // Text Column
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'View all announcements in Updates',
                                          style: GoogleFonts.outfit(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: context.colors.textPrimary,
                                            letterSpacing: 0.1,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '+${filteredPosts.length - 5} more posts in municipal bulletin',
                                          style: GoogleFonts.outfit(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: context.colors.primaryGreen,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Forward Action Button
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isDark
                                          ? context.colors.brand.withValues(alpha: 0.18,
                                            )
                                        : context.colors.brand.withValues(alpha: 0.10,
                                          ),
                                      border: Border.all(
                                        color: isDark
                                            ? context.colors.primaryGreen
                                                .withValues(alpha: 0.3)
                                            : context.colors.primaryGreen
                                                .withValues(alpha: 0.25),
                                      ),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 16,
                                        color: context.colors.primaryGreen,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],

            SliverToBoxAdapter(
              child: SizedBox(
                height: navigationReservedHeight + floatingActionsHeight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunityUpdatesSectionHeader({
    required bool isDark,
    required _BulletinCategory category,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            // Live Pulsing Emerald Dot
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.colors.brand,
                boxShadow: [
                  BoxShadow(
                    color: context.colors.brandStrong.withValues(alpha: 0.8),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'LATEST ANNOUNCEMENTS',
              style: GoogleFonts.outfit(
                color: context.colors.textPrimary,
                fontSize: 14.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        // View All Button for Respective Category
        InkWell(
          key: const ValueKey('home-community-updates-view-all'),
          onTap: () {
            setState(() {
              _selectedHomeCategory = category;
            });
            _selectPage(1);
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'View All',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: context.colors.primaryGreen,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 13,
                  color: context.colors.primaryGreen,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _categoryLabelForEmptyState(_BulletinCategory category) {
    switch (category) {
      case _BulletinCategory.all:
        return 'Announcements';
      case _BulletinCategory.notices:
        return 'Community Notices';
      case _BulletinCategory.advisory:
        return 'Public Advisories';
      case _BulletinCategory.events:
        return 'Upcoming Events';
    }
  }

  Widget _buildCategoryEmptyState(String categoryLabel, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.colors.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inbox_rounded,
                size: 36,
                color: context.colors.primaryGreen,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No $categoryLabel Found',
              style: GoogleFonts.outfit(
                color: context.colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'There are no announcements currently under $categoryLabel.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: context.colors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnouncementSkeleton({int count = 2}) {
    return Semantics(
      label: 'Loading Community Bulletin',
      child: ModernPostCardSkeleton.feedList(count: count),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(
            Icons.auto_awesome_motion_outlined,
            size: 60,
            color: context.colors.primaryGreen.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 16),
          Text(
            'No announcements yet',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.colors.textPrimary,
            ),
          ),
          Text(
            'Check back later for community news.',
            style: GoogleFonts.poppins(fontSize: 12, color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerMyPostsPage(User user) {
    return ESugidPullToRefresh(
      onRefresh: () => _refreshPartnerPosts(user),
      child: Column(
        children: [
          _buildPageHeader('My Posts'),
          Expanded(
            child: StreamBuilder<List<CommunityPost>>(
              stream: CommunityService.postsForAuthor(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return AsyncErrorView(onRetry: () => setState(() {}));
                }
                final posts = snapshot.data ?? [];
                if (posts.isEmpty) {
                  return _buildPartnerEmptyState(
                    Icons.campaign_outlined,
                    'No posts yet',
                    'Create your first community announcement.',
                    user,
                    showCreateAction: true,
                  );
                }
                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: ClampingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 135),
                  scrollCacheExtent: const ScrollCacheExtent.pixels(720),
                  itemCount: posts.length,
                  itemBuilder: (context, index) => ModernPostCard(
                    post: posts[index],
                    showStatus: true,
                    animateEntrance: index < 4,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerEmptyState(
    IconData icon,
    String title,
    String subtitle,
    User user, {
    bool showCreateAction = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: context.colors.surfaceAlt,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: context.colors.primaryGreen, size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      height: 1.5,
                      color: context.colors.textSecondary,
                    ),
                  ),
                  if (showCreateAction && user.canPublishAnnouncements) ...[
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _showPostModal,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Create Post'),
                      style: FilledButton.styleFrom(
                        foregroundColor: context.colors.onAccent,

                        backgroundColor: context.colors.brandStrong,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _publisherRoleLabel(String role) {
    return switch (role.trim().toLowerCase()) {
      'super_admin' => 'LGU IT Administrator',
      'lgu' => 'LGU Department Staff',
      'organization' || 'partner' => 'Organization Staff',
      'barangay_captain' => 'Barangay Captain',
      'barangay_vice_captain' => 'Barangay Vice Captain',
      'barangay_secretary' => 'Barangay Secretary',
      'barangay_councilor' => 'Barangay Councilor',
      _ => 'Barangay Official',
    };
  }

  Widget _buildHomeHeader(
    String name,
    User user, {
    double collapseProgress = 0,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPartner = user.role == UserRole.partner;
    final trimmedName = name.trim();
    final displayName = trimmedName.isEmpty
        ? 'Resident'
        : '${trimmedName[0].toUpperCase()}${trimmedName.substring(1)}';
    final greeting = isPartner
        ? 'Welcome, $displayName'
        : 'Maayong Adlaw, $displayName';
    final progress = collapseProgress.clamp(0.0, 1.0);
    final expandedOpacity = 1 - progress;
    final bodyCrownHeight = esugidBodyCrownHeight * expandedOpacity;
    final headerWidth = MediaQuery.sizeOf(context).width;
    final isVeryNarrowHeader = headerWidth < 280;
    final isCompactHeader = headerWidth < 350;
    final horizontalPadding = isVeryNarrowHeader
        ? 10.0
        : isCompactHeader
        ? 14.0
        : 16.0;
    final brandSize = isVeryNarrowHeader
        ? 30.0
        : isCompactHeader
        ? 34.0
        : 36.0;
    final actionSize = isVeryNarrowHeader
        ? 32.0
        : isCompactHeader
        ? 36.0
        : 42.0;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.colors.brandStrong,
            context.colors.brandStrong,
            context.colors.brand,
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.lerp(
          esugidHeaderBorderRadius,
          BorderRadius.zero,
          progress,
        ),
      ),
      child: Stack(
        children: [
          // 1. Top Specular Crystal Rim Light (simulating curved glass refraction)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 1.5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    context.colors.surface.withValues(alpha: 0.0),
                    context.colors.surface.withValues(alpha: 0.45),
                    context.colors.surface.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // 2. Ambient Volumetric 3D Light Orbs
          Positioned(
            top: -40,
            right: -20,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    context.colors.warningSolid.withValues(alpha: 0.14),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -30,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    context.colors.brand.withValues(alpha: 0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // 3. Embossed Municipal Watermark
          Positioned(
            top: -15,
            right: 15,
            child: Opacity(
              opacity: 0.06 * expandedOpacity,
              child: Image.asset(
                'assets/images/resident_dashboard/pinakafinal.png',
                width: 170,
                color: context.colors.surface,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              MediaQuery.paddingOf(context).top + 6,
              horizontalPadding,
              6 + bodyCrownHeight,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // 3D Minted Civic Medallion for Town Seal
                    Container(
                      width: brandSize,
                      height: brandSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFFDE047), // Vibrant luminous gold
                            Color(0xFFEAB308), // Warm gold
                            Color(0xFF10B981), // Fresh emerald
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.50),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                          BoxShadow(
                            color: const Color(0xFFFDE047).withValues(alpha: 0.45),
                            offset: const Offset(-1, -1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(2.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                            color: const Color(0xFFE5E7EB),
                            width: 0.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Padding(
                            padding: const EdgeInsets.all(1.0),
                            child: Image.asset(
                              'assets/images/resident_dashboard/pinakafinal.png',
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                              errorBuilder: (_, _, _) => Icon(
                                Icons.account_balance_rounded,
                                size: 20,
                                color: context.colors.primaryGreen,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: isVeryNarrowHeader ? 8 : 10),
                    // Sculpted Brand Title with Civic Eyebrow
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'BARILI OFFICIAL CENTER',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              color: context.colors.onBrandMuted,
                              fontSize: isVeryNarrowHeader ? 7.5 : 8.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              height: 1.0,
                              shadows: isDark ? const [] : [
                                Shadow(
                                  color: context.colors.textPrimary.withValues(alpha: 0.45,
                                  ),
                                  offset: const Offset(0, 1),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'E-SUGID',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              color: context.colors.onAccent,
                              fontSize: isVeryNarrowHeader
                                  ? 13
                                  : isCompactHeader
                                  ? 15
                                  : 17,
                              fontWeight: FontWeight.w900,
                              letterSpacing: isVeryNarrowHeader ? 1.1 : 1.4,
                              height: 1.05,
                              shadows: isDark ? const [] : [
                                Shadow(
                                  color: context.colors.textPrimary.withValues(alpha: 0.45,
                                  ),
                                  offset: const Offset(0, 2.5),
                                  blurRadius: 5,
                                ),
                                Shadow(
                                  color: context.colors.primaryGreen.withValues(alpha: 0.3,
                                  ),
                                  offset: const Offset(0, 0),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildHeaderAction(
                        tooltip: isDark
                          ? 'Switch to light mode'
                            : 'Switch to dark mode',
                        icon: isDark
                          ? Icons.light_mode_rounded
                            : Icons.nightlight_round_rounded,
                        onTap: () async {
                        try {
                          await AppThemeController.toggle();
                        } catch (_) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showAppSnackBar(
                            AppSnackBar(
                              content: Text(
                                'Could not save appearance. Your choice applies until the app closes.',
                              ),
                              kind: FeedbackKind.error,
                            ),
                          );
                        }
                      },
                        size: actionSize,
                      ),
                    const SizedBox(width: 6),
                    _buildHeaderNotificationAction(user, size: actionSize),
                    const SizedBox(width: 6),
                    _buildHeaderAction(
                      tooltip: 'Open profile',
                      onTap: () => _selectPage(4),
                      size: actionSize,
                      child: UserProfileAvatar(
                        user: user,
                        size: actionSize,
                        borderColor: context.colors.border.withValues(alpha: 0.45,
                        ),
                        borderWidth: 1.5,
                        badgeBorderColor: context.colors.border,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6 * expandedOpacity),
                // Dimensional Greeting Presentation
                ClipRect(
                  child: Align(
                    alignment: Alignment.topLeft,
                    heightFactor: expandedOpacity,
                    child: Opacity(
                      opacity: expandedOpacity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isPartner)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: context.colors.brand,
                                    boxShadow: [
                                      BoxShadow(
                                        color: context.colors.brandStrong,
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'COMMUNITY PARTNER',
                                  style: GoogleFonts.outfit(
                                    color: context.colors.onBrandMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          if (isPartner) const SizedBox(height: 3),
                          Text(
                            greeting,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              color: context.colors.onAccent,
                              fontSize: isCompactHeader ? 19 : 21,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                              height: 1.1,
                              shadows: isDark ? const [] : [
                                Shadow(
                                  color: context.colors.textPrimary.withValues(alpha: 0.45,
                                  ),
                                  offset: const Offset(0, 3),
                                  blurRadius: 8,
                                ),
                                Shadow(
                                  color: context.colors.textPrimary.withValues(alpha: 0.5,
                                  ),
                                  offset: const Offset(0, 1),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 9 * expandedOpacity),
                ClipRect(
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: expandedOpacity,
                    child: Opacity(
                      opacity: expandedOpacity,
                      child: HomeHeaderStatusBar(
                        locationLabel: homeLocationLabelForUser(user),
                        trailing: _buildHeaderWeather(),
                        onTap: _openWeatherPage,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ESugidBodyCrown(
              height: bodyCrownHeight,
              opacity: expandedOpacity,
              color: context.colors.background,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderAction({
    required String tooltip,
    required VoidCallback onTap,
    IconData? icon,
    Widget? child,
    String? badgeLabel,
    double size = 34,
  }) {
    assert(icon != null || child != null);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 3D Convex Frosted Glass Gem Orb
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: context.colors.shadow.withValues(alpha: 0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 3.5),
                  ),
                  BoxShadow(
                    color: context.colors.highlight.withValues(alpha: 0.2),
                    blurRadius: 2,
                    offset: const Offset(-1, -1),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: onTap,
                  customBorder: const CircleBorder(),
                  child: Ink(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.40),
                        width: 1.2,
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.28),
                          Colors.white.withValues(alpha: 0.14),
                          Colors.white.withValues(alpha: 0.06),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.20),
                          blurRadius: 6,
                          offset: const Offset(0, 2.5),
                        ),
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.25),
                          blurRadius: 2,
                          offset: const Offset(-0.5, -0.5),
                        ),
                      ],
                    ),
                    child:
                        child ??
                        Icon(
                          icon,
                          color: icon == Icons.nightlight_round_rounded
                              ? const Color(0xFFFDE047) // Warm golden moon
                              : icon == Icons.light_mode_rounded
                                  ? const Color(0xFFFBBF24) // Warm bright sun
                                  : Colors.white,
                          size: size * 0.50,
                        ),
                  ),
                ),
              ),
            ),
            if (badgeLabel != null)
              Positioned(
                top: -3,
                right: -3,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 17,
                    minHeight: 17,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        context.colors.errorSolid,
                        context.colors.errorSolid,
                        context.colors.errorSolid,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.colors.border, width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: context.colors.errorSolid.withValues(alpha: 0.5),
                        offset: const Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    badgeLabel,
                    style: GoogleFonts.outfit(
                      color: context.colors.onAccent,
                      fontSize: 9,
                      height: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderNotificationAction(User user, {required double size}) {
    return StreamBuilder<List<ResidentNotification>>(
      stream: _notificationsForHeader(user.uid),
      builder: (context, snapshot) {
        final unreadCount =
            snapshot.data?.where((notification) => !notification.read).length ??
            0;
        return _buildHeaderAction(
          tooltip: unreadCount == 0
              ? 'Notifications'
              : '$unreadCount unread ${unreadCount == 1 ? 'notification' : 'notifications'}',
          icon: Icons.notifications_none_rounded,
          onTap: () => _openNotifications(user),
          badgeLabel: unreadNotificationBadgeLabel(unreadCount),
          size: size,
        );
      },
    );
  }

  Stream<List<ResidentNotification>> _notificationsForHeader(String userId) {
    if (_headerNotificationUserId != userId ||
        _headerNotificationStream == null) {
      _headerNotificationUserId = userId;
      _headerNotificationStream = SubmissionService.notificationsForUser(
        userId,
      );
    }
    return _headerNotificationStream!;
  }

  void _openWeatherPage([BariliWeather? weather]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BariliWeatherPage(
          initialWeather: weather ?? _weather.value,
          onWeatherUpdated: (latest) {
            if (mounted) _weather.value = latest;
          },
        ),
      ),
    );
  }

  Widget _buildHeaderWeather() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ValueListenableBuilder<BariliWeather?>(
      valueListenable: _weather,
      builder: (context, weather, _) {
        if (weather == null) {
          return ESugidPressable(
            onTap: () => _openWeatherPage(null),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: context.colors.surface.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: context.colors.border.withValues(alpha: 0.2),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_outlined,
                    size: 16,
                    color: context.colors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Barili Weather',
                        style: GoogleFonts.outfit(
                          color: context.colors.onAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        'Tap to load',
                        style: GoogleFonts.outfit(
                          color: context.colors.onAccent.withValues(alpha: 0.75,
                          ),
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }

        return ESugidPressable(
          onTap: () => _openWeatherPage(weather),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4.5,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    context.colors.surface.withValues(alpha: 0.22),
                    context.colors.surface.withValues(alpha: 0.08),
                    context.colors.shadow.withValues(alpha: 0.08),
                  ],
                ),
                border: Border.all(
                  color: context.colors.border.withValues(alpha: 0.35),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: context.colors.shadow.withValues(alpha: 0.18),
                    offset: const Offset(0, 2),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Subtle condition-based background animation for header
                  Positioned.fill(
                    child: WeatherAnimationWidget(
                      type: weather.animationType,
                      isDay: weather.isDay,
                      isCompact: true,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              (weather.isDay
                                      ? context.colors.warningSolid
                                      : context.colors.infoSolid)
                                  .withValues(alpha: 0.22),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (weather.isDay
                                          ? context.colors.highlight
                                          : context.colors.highlight)
                                      .withValues(alpha: 0.35),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          weather.icon,
                          color: weather.isDay
                              ? const Color(0xFFFBBF24) // Radiant golden sun
                              : const Color(0xFF67E8F9), // Crisp sky cyan
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${weather.temperatureCelsius.round()}°C',
                                style: GoogleFonts.outfit(
                                  color: context.colors.onAccent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  height: 1.1,
                                  shadows: isDark ? const [] : [
                                    Shadow(
                                      color: context.colors.textPrimary
                                          .withValues(
                                        alpha: 0.4),
                                      offset: const Offset(0, 1),
                                      blurRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'As of ${weather.formattedUpdatedTime}',
                                style: GoogleFonts.outfit(
                                  color: context.colors.onAccent.withValues(alpha: 0.72,
                                  ),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            weather.condition,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              color: context.colors.textSecondary,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              height: 1.15,
                              shadows: isDark ? const [] : [
                                Shadow(
                                  color: context.colors.textPrimary.withValues(alpha: 0.3,
                                  ),
                                  offset: const Offset(0, 1),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBarangayConcernAction(User user) {
    return Tooltip(
      message: 'Concern Center',
      child: ESugidPressable(
        semanticLabel: 'Concern Center',
        haptic: ESugidHaptic.light,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ConcernCenterPage(onOpenAlerts: () => _selectPage(1)),
            ),
          );
        },
        child: AnimatedContainer(
          duration: ESugidMotion.standard,
          curve: ESugidMotion.enterCurve,
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [context.colors.brand, context.colors.brand],
            ),
            shape: BoxShape.circle,
            border: Border.all(
              color: context.colors.border.withValues(alpha: 0.72),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: context.colors.brandStrong.withValues(alpha: 0.24),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              color: context.colors.onAccent,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResidentCommunityBanner(User user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textScaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bannerHeight = responsiveResidentBannerHeight(
          availableWidth: constraints.maxWidth,
          textScaler: textScaler,
        );
        return ConstrainedBox(
          constraints: BoxConstraints(minHeight: bannerHeight),
          child: ESugidPressable(
            semanticLabel: 'View My Barangay',
            onTap: () => _openResidentFeature(_ResidentFeatureAction.barangay),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF065F46), // Rich deep emerald
                    Color(0xFF047857), // Vibrant emerald
                    Color(0xFF064E3B), // Deep forest emerald
                  ],
                ),
                border: Border.all(
                  color: const Color(0xFF34D399).withValues(alpha: 0.50),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: context.colors.shadow.withValues(alpha: 0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 7),
                  ),
                  BoxShadow(
                    color: context.colors.brandStrong.withValues(alpha: 0.22),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Subtle 3D Radial Glow Background Accent
                    Positioned(
                      right: -25,
                      top: -25,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              context.colors.brand.withValues(alpha: 0.20),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Glossy Specular Top Highlight Rim
                    Positioned(
                      top: 0,
                      left: 18,
                      right: 18,
                      height: 1.5,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              context.colors.surface.withValues(alpha: 0.0),
                              context.colors.surface.withValues(alpha: 0.55),
                              context.colors.surface.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Main Content Padding
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          // Left Prominent 3D Action Button Pill
                          Expanded(
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 52),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    context.colors.brand,
                                    context.colors.brand,
                                    context.colors.brandStrong,
                                  ],
                                ),
                                border: Border.all(
                                  color: (isDark ? context.colors.primaryGreen : context.colors.border).withValues(alpha: 0.75,
                                  ),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: context.colors.shadow.withValues(alpha: 0.40,
                                    ),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                  BoxShadow(
                                    color: context.colors.brandStrong
                                        .withValues(alpha: 0.35),
                                    blurRadius: 12,
                                    spreadRadius: -1,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.location_city_rounded,
                                    color: const Color(0xFF6EE7B7),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'VIEW MY BARANGAY',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.outfit(
                                        color: isDark ? context.colors.textPrimary : context.colors.onAccent,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.8,
                                        shadows: isDark ? const [] : [
                                          Shadow(
                                            color: context.colors.textPrimary
                                                .withValues(
                                              alpha: 0.65),
                                            offset: const Offset(0, 2),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: context.colors.brandStrong
                                          .withValues(alpha: 0.5),
                                      border: Border.all(
                                        color: (isDark ? context.colors.primaryGreen : context.colors.border).withValues(
                                          alpha: 0.4,
                                        ),
                                        width: 1,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.arrow_forward_rounded,
                                      color: const Color(0xFF6EE7B7),
                                      size: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Barangay navigation icon.
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF059669), // Fresh minted emerald
                                  Color(0xFF047857), // Deep emerald
                                  Color(0xFF064E3B), // Forest emerald
                                ],
                              ),
                              border: Border.all(
                                color: const Color(0xFF6EE7B7).withValues(alpha: 0.85),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.45),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3),
                                ),
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.30),
                                  blurRadius: 3,
                                  offset: const Offset(-1, -1),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.account_balance_rounded,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCommunityCategoryPills() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final categories = [
      (
        category: _BulletinCategory.all,
        label: 'All',
        icon: Icons.grid_view_rounded,
      ),
      (
        category: _BulletinCategory.notices,
        label: 'Notices',
        icon: Icons.campaign_rounded,
      ),
      (
        category: _BulletinCategory.advisory,
        label: 'Advisories',
        icon: Icons.warning_amber_rounded,
      ),
      (
        category: _BulletinCategory.events,
        label: 'Events',
        icon: Icons.event_available_rounded,
      ),
    ];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = _selectedHomeCategory == cat.category;

          return ESugidPressable(
            semanticLabel: '${cat.label} category filter',
            onTap: () {
              if (_selectedHomeCategory != cat.category) {
                setState(() {
                  _selectedHomeCategory = cat.category;
                });
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [context.colors.brand, context.colors.brand],
                      )
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          context.colors.surface,
                          context.colors.surface,
                        ],
                      ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? context.colors.border.withValues(alpha: 0.45)
                      : (isDark
                          ? context.colors.border
                            : context.colors.border.withValues(alpha: 0.8)),
                  width: 1.2,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: context.colors.brandStrong.withValues(alpha: 0.38,
                          ),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                        BoxShadow(
                          color: context.colors.highlight.withValues(alpha: 0.35,
                          ),
                          offset: const Offset(0, -1.2),
                          blurRadius: 0,
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: isDark
                              ? context.colors.shadow.withValues(alpha: 0.25)
                              : context.colors.shadow.withValues(alpha: 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? context.colors.surface.withValues(alpha: 0.20)
                          : (isDark
                              ? context.colors.brandStrong
                                : context.colors.brand.withValues(alpha: 0.09)),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        cat.icon,
                        size: 13,
                        color: isSelected
                            ? context.colors.onAccent
                            : (context.colors.primaryGreen),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    cat.label,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: isSelected
                          ? context.colors.onAccent
                          : (isDark
                              ? context.colors.textSecondary
                                : context.colors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _checkActiveEmergency() async {
    try {
      final alerts =
          await EmergencyAlertService.getActiveEmergenciesForResident();
      if (mounted) {
        setState(() {
          _activeEmergency = alerts.isNotEmpty ? alerts.first : null;
        });
      }
    } catch (_) {}
  }

  Widget _buildActiveEmergencyBanner(CommunityAlert alert) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.colors.errorSolid, context.colors.errorSolid],
        ),
        border: Border.all(color: context.colors.error, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: context.colors.errorSolid.withValues(alpha: 0.4000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: context.colors.errorSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: context.colors.error,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'ACTIVE EMERGENCY',
                      style: GoogleFonts.outfit(
                        color: context.colors.error,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'URGENT',
                style: GoogleFonts.outfit(
                  color: context.colors.onAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            alert.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              color: context.colors.onAccent,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (alert.message.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              alert.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                color: context.colors.onAccent,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(
                  context,
                ).pushNamed('/emergency', arguments: alert.id);
              },
              style: FilledButton.styleFrom(
                backgroundColor: context.colors.surface,
                foregroundColor: context.colors.error,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              icon: const Icon(Icons.shield_rounded, size: 16),
              label: Text(
                'View Emergency',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinnedUrgentAnnouncementsSection({
    required List<CommunityPost> posts,
    required bool isDark,
  }) {
    return ValueListenableBuilder<int>(
      valueListenable: _postPriorityTick,
      builder: (context, tick, child) {
        final now = DateTime.now();
        final activePosts = posts.where((post) {
          final expiry = post.priorityExpiresAt ?? post.expiresAt;
          return expiry != null && expiry.isAfter(now);
        }).toList();

        if (activePosts.isEmpty) return const SizedBox.shrink();

        return _PinnedUrgentAnnouncementsCarousel(
          posts: activePosts,
          viewedPostIds: _viewedUrgentPostIds,
          isDark: isDark,
          onViewAll: () => _showAllUrgentAnnouncementsSheet(activePosts),
          onTapPost: (post) => _openPinnedPostDetails(post),
        );
      },
    );
  }

  void _markUrgentPostViewed(String postId) {
    if (_viewedUrgentPostIds.contains(postId)) return;
    setState(() {
      _viewedUrgentPostIds = {..._viewedUrgentPostIds, postId};
    });
    _persistViewedUrgentPostIds();
  }

  void _markAllUrgentPostsViewed(List<CommunityPost> posts) {
    final toAdd = posts
        .map((p) => p.id)
        .where((id) => !_viewedUrgentPostIds.contains(id))
        .toList();
    if (toAdd.isEmpty) return;
    setState(() {
      _viewedUrgentPostIds = {..._viewedUrgentPostIds, ...toAdd};
    });
    _persistViewedUrgentPostIds();
  }

  Future<void> _loadViewedUrgentPostIds([String? userId]) async {
    try {
      final currentUserId = userId ?? AuthService.currentUser?.uid ?? 'guest';
      _lastLoadedUrgentUserId = currentUserId;
      final prefs = await SharedPreferences.getInstance();
      final list =
          prefs.getStringList('viewed_urgent_announcements_$currentUserId') ??
          [];
      if (mounted && list.isNotEmpty) {
        setState(() {
          _viewedUrgentPostIds = list.toSet();
        });
      }
    } catch (e) {
      debugPrint('[HOME] Error loading viewed urgent announcements: $e');
    }
  }

  Future<void> _persistViewedUrgentPostIds() async {
    try {
      final currentUserId =
          _lastLoadedUrgentUserId ?? AuthService.currentUser?.uid ?? 'guest';
      final prefs = await SharedPreferences.getInstance();
      final list = _viewedUrgentPostIds.toList();
      final trimmed = list.length > 100
          ? list.sublist(list.length - 100)
          : list;
      await prefs.setStringList(
        'viewed_urgent_announcements_$currentUserId',
        trimmed,
      );
    } catch (e) {
      debugPrint('[HOME] Error persisting viewed urgent announcements: $e');
    }
  }

  void _openPinnedPostDetails(CommunityPost post) {
    _markUrgentPostViewed(post.id);
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: context.colors.shadow.withValues(alpha: 0.50),
        transitionDuration: const Duration(milliseconds: 360),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) =>
            PostDetailsPage(
              post: post,
              imageHeroTag: 'pinned-urgent-${post.id}',
              primaryGreen: context.colors.primaryGreen,
              deepGreen: context.colors.textPrimary,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubic,
            reverseCurve: Curves.easeInOutCubic,
          );
          return FadeTransition(opacity: curved, child: child);
        },
      ),
    );
  }

  void _showAllUrgentAnnouncementsSheet(List<CommunityPost> posts) {
    _markAllUrgentPostsViewed(posts);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.85,
          ),
          decoration: BoxDecoration(
            color: sheetContext.colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: isDark
                  ? sheetContext.colors.border.withValues(alpha: 0.25)
                  : sheetContext.colors.border,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: sheetContext.colors.shadow.withValues(alpha: isDark ? 0.5 : 0.15,
                ),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              // Grab handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? sheetContext.colors.shadow.withValues(alpha: 0.25)
                        : sheetContext.colors.shadow.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: sheetContext.colors.errorSolid.withValues(alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: sheetContext.colors.error.withValues(alpha: 0.3,
                          ),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.campaign_rounded,
                        size: 20,
                        color: sheetContext.colors.error,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Urgent Announcements',
                                style: GoogleFonts.outfit(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: sheetContext.colors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: sheetContext.colors.errorSolid,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${posts.length} Active',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: sheetContext.colors.onAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Important updates posted by authorized authorities',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: sheetContext.colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: isDark
                            ? sheetContext.colors.textPrimary
                            : sheetContext.colors.textPrimary,
                      ),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, thickness: 1),
              // Announcements list
              Flexible(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: posts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    final expiry = post.priorityExpiresAt ?? post.expiresAt;
                    return ESugidPressable(
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _openPinnedPostDetails(post);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? context.colors.errorSolid
                              : context.colors.errorSurface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: context.colors.border,
                            width: 1.1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: context.colors.shadow.withValues(
                                alpha: isDark ? 0.2 : 0.05,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Author & Expiry row
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.colors.errorSurface,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.verified_rounded,
                                        size: 11,
                                        color: isDark
                                            ? context.colors.warning
                                            : context.colors.error,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        post.displayPublisher.isNotEmpty
                                            ? post.displayPublisher
                                                  .toUpperCase()
                                            : (post.authorName.isNotEmpty &&
                                                      post.authorName
                                                              .toLowerCase() !=
                                                          'anajean'
                                                  ? post.authorName
                                                        .toUpperCase()
                                                  : 'LGU IT DEPARTMENT'),
                                        style: GoogleFonts.outfit(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: context.colors.error,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                if (expiry != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: context.colors.errorSolid
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: context.colors.error.withValues(alpha: 0.25,
                                        ),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.timer_outlined,
                                          size: 11,
                                          color: context.colors.error,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatExpiryCountdown(expiry),
                                          style: GoogleFonts.outfit(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: context.colors.error,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Title
                            Text(
                              post.title.isNotEmpty
                                  ? post.title
                                  : 'Urgent Announcement',
                              style: GoogleFonts.outfit(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: context.colors.textPrimary,
                                height: 1.25,
                              ),
                            ),
                            if (post.content.trim().isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Text(
                                post.content,
                                style: GoogleFonts.outfit(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: context.colors.textSecondary,
                                  height: 1.35,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 8),
                            // Clickability note
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.touch_app_outlined,
                                  size: 13,
                                  color: context.colors.error,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Tap to view details',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: context.colors.error,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 11,
                                  color: context.colors.error,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUpdatesSearchBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final parsedQuery = SmartAnnouncementSearch.parse(
      _updatesSearchQuery,
      preset: _updatesTimePreset,
    );
    final hasActiveTimeFilter = parsedQuery.hasTimeFilter;
    final hasQuery = _updatesSearchQuery.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: context.colors.surface,
            border: Border.all(
              color: hasActiveTimeFilter
                  ? context.colors.primaryGreen
                  : (context.colors.border),
              width: hasActiveTimeFilter ? 1.5 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: (context.colors.brandStrong)
                    .withValues(alpha: isDark ? 0.3 : 0.05,
                ),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: _updatesSearchController,
            textInputAction: TextInputAction.search,
            autocorrect: false,
            enableSuggestions: true,
            onChanged: (value) => setState(
              () => _updatesSearchQuery = value.toLowerCase()),
            style: GoogleFonts.outfit(
              color: context.colors.textPrimary,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'Search updates, e.g. "barangay", "electric", "sports"...',
              hintStyle: GoogleFonts.outfit(
                color: context.colors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [context.colors.brand, context.colors.brand],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: context.colors.brandStrong.withValues(alpha: 0.3,
                        ),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.search_rounded,
                    color: context.colors.onAccent,
                    size: 17,
                  ),
                ),
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasQuery)
                    IconButton(
                      tooltip: 'Clear search text',
                      onPressed: () {
                        _updatesSearchController.clear();
                        setState(() => _updatesSearchQuery = '');
                      },
                      icon: Icon(
                        Icons.close_rounded,
                        color: context.colors.primaryGreen,
                        size: 18,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: InkWell(
                      key: const ValueKey('updates-search-time-filter-button'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: _showTimePresetSelectorSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: hasActiveTimeFilter
                              ? context.colors.brand.withValues(alpha: 0.18)
                              : (context.colors.surfaceAlt),
                          border: Border.all(
                            color: hasActiveTimeFilter
                                ? context.colors.primaryGreen
                                : (context.colors.border),
                            width: hasActiveTimeFilter ? 1.2 : 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              hasActiveTimeFilter
                                  ? Icons.filter_alt_rounded
                                  : Icons.tune_rounded,
                              size: 15,
                              color: hasActiveTimeFilter
                                  ? context.colors.primaryGreen
                                  : (context.colors.textSecondary),
                            ),
                            if (hasActiveTimeFilter) ...[
                              const SizedBox(width: 4),
                              Text(
                                parsedQuery.displayFilterLabel,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: context.colors.primaryGreen,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              filled: false,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 13,
                horizontal: 16,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
        if (hasActiveTimeFilter) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Container(
                  key: const ValueKey('active-time-filter-pill'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.brand.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.colors.primaryGreen.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 13,
                        color: context.colors.primaryGreen,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Time: ${parsedQuery.displayFilterLabel}',
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: context.colors.primaryGreen,
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        key: const ValueKey('clear-time-filter-pill'),
                        onTap: () {
                          setState(() {
                            _updatesTimePreset = SmartTimePreset.anyTime;
                            if (parsedQuery.textQuery.isNotEmpty &&
                                parsedQuery.textQuery != parsedQuery.rawQuery) {
                              _updatesSearchController.text =
                                  parsedQuery.textQuery;
                              _updatesSearchQuery = parsedQuery.textQuery;
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: context.colors.brand.withValues(alpha: 0.2),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 11,
                            color: context.colors.primaryGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasQuery ||
                    _updatesTimePreset != SmartTimePreset.anyTime) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      _updatesSearchController.clear();
                      setState(() {
                        _updatesSearchQuery = '';
                        _updatesTimePreset = SmartTimePreset.anyTime;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Text(
                        'Clear all',
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: context.colors.error,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _showTimePresetSelectorSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: sheetContext.colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: sheetContext.colors.shadow.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: isDark
                        ? sheetContext.colors.shadow.withValues(alpha: 0.2)
                        : sheetContext.colors.shadow.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          sheetContext.colors.brand,
                          sheetContext.colors.brand,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: sheetContext.colors.brandStrong.withValues(alpha: 0.3,
                          ),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.calendar_month_rounded,
                      color: sheetContext.colors.onAccent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Filter by Date & Time',
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: sheetContext.colors.textPrimary,
                          ),
                        ),
                        Text(
                          'Find announcements from specific time periods',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: sheetContext.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_updatesTimePreset != SmartTimePreset.anyTime)
                    TextButton(
                      onPressed: () {
                        setState(
                          () => _updatesTimePreset = SmartTimePreset.anyTime,
                        );
                        Navigator.pop(sheetContext);
                      },
                      child: Text(
                        'Reset',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: sheetContext.colors.error,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: SmartTimePreset.values.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final preset = SmartTimePreset.values[index];
                    final isSelected = _updatesTimePreset == preset;
                    return InkWell(
                      key: ValueKey('time-preset-${preset.name}'),
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        setState(() => _updatesTimePreset = preset);
                        Navigator.pop(sheetContext);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: isSelected
                              ? context.colors.brand.withValues(alpha: isDark ? 0.2 : 0.1,
                                )
                              : (context.colors.surface),
                          border: Border.all(
                            color: isSelected
                                ? context.colors.primaryGreen
                                : (context.colors.border),
                            width: isSelected ? 1.6 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? context.colors.brand
                                    : (context.colors.infoSurface),
                              ),
                              child: Icon(
                                preset.icon,
                                size: 17,
                                color: isSelected
                                    ? context.colors.onAccent
                                    : (context.colors.textSecondary),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    preset.label,
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      color: isSelected
                                          ? (context.colors.primaryGreen)
                                          : (context.colors.textPrimary),
                                    ),
                                  ),
                                  Text(
                                    _getTimePresetDescription(preset),
                                    style: GoogleFonts.outfit(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color: context.colors.info,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_circle_rounded,
                                color: context.colors.primaryGreen,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: sheetContext.colors.surfaceAlt,
                  border: Border.all(
                    color: sheetContext.colors.border,
                    width: 0.9,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_rounded,
                      color: sheetContext.colors.primaryGreen,
                      size: 17,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Smart Search: You can also type "yesterday", "last week", "electric", or "water" directly in the search bar.',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: sheetContext.colors.primaryGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getTimePresetDescription(SmartTimePreset preset) {
    switch (preset) {
      case SmartTimePreset.anyTime:
        return 'Show all announcements from any date';
      case SmartTimePreset.past24Hours:
        return 'Announcements posted within the last 24 hours';
      case SmartTimePreset.past7Days:
        return 'Announcements from the past week';
      case SmartTimePreset.past30Days:
        return 'Announcements from the past month';
      case SmartTimePreset.past6Months:
        return 'Announcements from the past half-year';
      case SmartTimePreset.pastYear:
        return 'Announcements posted within the last 365 days';
    }
  }

  Widget _buildSearchEmptyState(SmartSearchQuery parsedQuery) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.colors.surfaceAlt,
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 32,
              color: context.colors.primaryGreen,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No matching announcements',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            parsedQuery.tokens.isNotEmpty
                ? 'No updates found for "${parsedQuery.rawQuery}" within the selected filters.'
                : 'No updates found for ${parsedQuery.displayFilterLabel}.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            key: const ValueKey('clear-search-empty-state-btn'),
            onPressed: () {
              _updatesSearchController.clear();
              setState(() {
                _updatesSearchQuery = '';
                _updatesTimePreset = SmartTimePreset.anyTime;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.brand,
              foregroundColor: context.colors.onAccent,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(
              'Clear Search & Filters',
              style: GoogleFonts.outfit(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoverPrivateOrganizationsBanner() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ESugidPressable(
      pressedScale: 0.98,
      haptic: ESugidHaptic.light,
      semanticLabel: 'Private Organizations Directory',
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder<void>(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const DiscoverPrivateOrganizationsPage(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              );
              return FadeTransition(
                opacity: curved,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.05, 0),
                    end: Offset.zero,
                  ).animate(curved),
                  child: child,
                ),
              );
            },
            transitionDuration: const Duration(milliseconds: 260),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.colors.surface,
              context.colors.surfaceAlt,
              context.colors.surfaceAlt,
                  ],
            stops: const [0.0, 0.45, 1.0],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? context.colors.border
                : context.colors.border.withValues(alpha: 0.85),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: context.colors.brandStrong.withValues(alpha: isDark ? 0.35 : 0.12,
              ),
              blurRadius: 18,
              offset: const Offset(0, 8),
              spreadRadius: -2,
            ),
            BoxShadow(
              color: context.colors.shadow.withValues(alpha: isDark ? 0.25 : 0.03,
              ),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
            BoxShadow(
              color: context.colors.highlight.withValues(alpha: isDark ? 0.06 : 0.90,
              ),
              blurRadius: 0,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Subtle 3D Layered Architectural Silhouette graphic on bottom right (ignoring pointers)
            Positioned(
              right: 28,
              bottom: -4,
              child: IgnorePointer(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Icon(
                      Icons.location_city_rounded,
                      size: 48,
                      color: context.colors.primaryGreen.withValues(alpha: isDark ? 0.20 : 0.14,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.apartment_rounded,
                      size: 38,
                      color: context.colors.primaryGreen.withValues(alpha: isDark ? 0.22 : 0.16,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.domain_rounded,
                      size: 30,
                      color: context.colors.primaryGreen.withValues(alpha: isDark ? 0.18 : 0.12,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
              child: Row(
                children: [
                  // 3D Elevated Dimensional Squircle Badge
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          context.colors.brand,
                          context.colors.brand,
                          context.colors.brand,
                          context.colors.brandStrong,
                        ],
                        stops: [0.0, 0.35, 0.75, 1.0],
                      ),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: context.colors.border.withValues(alpha: 0.9),
                        width: 1.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: context.colors.brandStrong.withValues(alpha: 0.40,
                          ),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.corporate_fare_rounded,
                        color: context.colors.onAccent,
                        size: 25,
                        shadows: [
                          Shadow(
                            color: context.colors.textPrimary.withValues(alpha: 0.25,
                            ),
                            blurRadius: 4,
                            offset: const Offset(0, 1.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 13),

                  // Title & Concise Subtitle with micro-tag
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Private Organizations',
                          style: GoogleFonts.outfit(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: context.colors.textPrimary,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Explore & follow local partners',
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: context.colors.textSecondary,
                            height: 1.25,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // 3D Floating Circular Arrow Button
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isDark
                            ? [
                                context.colors.surfaceAlt,
                                context.colors.surfaceAlt,
                              ]
                            : [
                                context.colors.surface,
                                context.colors.surfaceAlt,
                              ],
                      ),
                      border: Border.all(
                        color: context.colors.border,
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: context.colors.brandStrong.withValues(alpha: isDark ? 0.35 : 0.12,
                          ),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                        BoxShadow(
                          color: context.colors.shadow.withValues(alpha: 0.05),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: context.colors.primaryGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdatesPage(User user) {
    final horizontalPadding = responsiveHomeHorizontalPadding(
      MediaQuery.sizeOf(context).width,
    );
    final navigationReservedHeight =
        authenticatedBottomNavigationReservedHeight(context);

    return Container(
      color: context.colors.background,
      child: ESugidPullToRefresh(
        onRefresh: _refreshHomePage,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            ESugidSliverPageHeader(
              pinned: true,
              sectionLabelWidget: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 3.5,
                ),
                decoration: BoxDecoration(
                  color: context.colors.brandStrong.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: context.colors.border.withValues(alpha: 0.75),
                    width: 1.1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: context.colors.shadow.withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 1.5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.colors.warningSolid,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'BARILI COMMUNITY',
                      style: GoogleFonts.outfit(
                        color: context.colors.onBrandMuted,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              title: 'Community Updates',
              iconWidget: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      context.colors.warningSolid,
                      context.colors.warningSolid,
                      context.colors.brand,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: context.colors.shadow.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2.5),
                    ),
                  ],
                ),
                child: Container(
                  margin: const EdgeInsets.all(1.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        context.colors.brand,
                        context.colors.brandStrong,
                      ],
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.newspaper_rounded,
                      color: context.colors.onBrandMuted,
                      size: 19,
                    ),
                  ),
                ),
              ),
              trailing: _buildSavedAnnouncementsHeaderAction(),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                14,
                horizontalPadding,
                14,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildUpdatesSearchBar(),
                    const SizedBox(height: 12),
                    _buildCommunityCategoryPills(),
                    const SizedBox(height: 14),
                    _buildDiscoverPrivateOrganizationsBanner(),
                  ],
                ),
              ),
            ),
            if (_announcementRefreshError != null)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  0,
                  horizontalPadding,
                  10,
                ),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: context.colors.error,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          _announcementRefreshError!,
                          style: GoogleFonts.outfit(
                            color: context.colors.warning,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ListenableBuilder(
              listenable: PrivateOrganizationService.instance.feedFilterChanges,
              builder: (context, _) {
                return ValueListenableBuilder<int>(
                  valueListenable: _postPriorityTick,
                  builder: (context, _, _) {
                    if (!_announcementInitialLoadComplete) {
                      return SliverPadding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: _buildAnnouncementSkeleton(),
                        ),
                      );
                    }

                    // Municipal, barangay and public-agency posts always show;
                    // private organization posts only when followed. They all
                    // arrive through the same audience feeds.
                    final combinedPosts = PrivateOrganizationService.instance
                        .visiblePosts(_cachedPosts);

                    // Sort chronologically by date descending
                    combinedPosts.sort(
                      (a, b) => b.createdAt.compareTo(a.createdAt),
                    );

                    final parsedSearch = SmartAnnouncementSearch.parse(
                      _updatesSearchQuery,
                      preset: _updatesTimePreset,
                    );

                    final filteredPosts = combinedPosts.where((post) {
                      if (!_matchesBulletinCategory(
                        post,
                        _selectedHomeCategory,
                      )) {
                        return false;
                      }
                      return SmartAnnouncementSearch.matchesPost(
                        post,
                        parsedSearch,
                      );
                    }).toList();

                    if (filteredPosts.isEmpty) {
                      if (parsedSearch.isEmpty) {
                        return SliverToBoxAdapter(child: _buildEmptyState());
                      }
                      return SliverToBoxAdapter(
                        child: _buildSearchEmptyState(parsedSearch),
                      );
                    }

                    return SliverPadding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final post = filteredPosts[index];
                          final isTarget = _targetUpdatesPostId == post.id;
                          final itemKey = _updatesPostKeys.putIfAbsent(
                            post.id,
                            () => GlobalKey(),
                          );
                          return ModernPostCard(
                            key: itemKey,
                            post: post,
                            heroScope: 'updates',
                            isHighlighted: isTarget,
                            animateEntrance: index < 6,
                          );
                        }, childCount: filteredPosts.length),
                      ),
                    );
                  },
                );
              },
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: navigationReservedHeight + 24),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedAnnouncementsHeaderAction() {
    final user = AuthService.currentUser;
    if (user == null || user.role != UserRole.resident) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<List<OfflineAnnouncement>>(
      stream: SavedAnnouncementService.instance.watchOffline(user.uid),
      builder: (context, snapshot) {
        final count = snapshot.data?.length ?? 0;

        return Tooltip(
          message: 'Saved Announcements',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => SavedAnnouncementsPage.show(context),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: context.colors.surface.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: context.colors.border.withValues(alpha: 0.22),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bookmark_rounded,
                      color: context.colors.onBrandMuted,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Saved',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.colors.onAccent,
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.brand,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: context.colors.onAccent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openAlertsModal(User user) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: _buildAlertsPage(user),
        ),
      ),
    );
  }

  void _openResidentFeature(_ResidentFeatureAction action) {
    switch (action) {
      case _ResidentFeatureAction.barangay:
        final currentResident = AuthService.currentUser;
        final barangay = canonicalBariliBarangay(currentResident?.barangay);
        final initialBarangayPosts = barangay == null
            ? null
            : _cachedPosts
                .where((p) =>
                    canonicalBariliBarangay(p.targetBarangay) == barangay ||
                    canonicalBariliBarangay(p.authorBarangay) == barangay,
                  )
                .toList();
        Navigator.push(
          context,
          PageRouteBuilder<void>(
            pageBuilder: (_, _, _) => BarangayPage(
              initialData: currentResident,
              initialPosts: (initialBarangayPosts != null &&
                      initialBarangayPosts.isNotEmpty)
                  ? initialBarangayPosts
                  : CommunityService.latestBarangayPosts(
                      currentResident?.barangay,
                    ),
            ),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
        break;
      case _ResidentFeatureAction.map:
        _openMap();
      case _ResidentFeatureAction.explore:
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (context) => const ExploreBariliPage(),
          ),
        );
    }
  }

  void _openNotifications(User user) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: _buildPartnerNotificationsPage(user, showBackButton: true),
        ),
      ),
    );
  }

  void _openAllCommunityPosts(
    User user, {
    bool savedOnly = false,
    _BulletinCategory initialCategory = _BulletinCategory.all,
    String? targetPostId,
    String? targetTitle,
  }) {
    // PRE-FETCH: Get existing posts from the Home Screen's stream to avoid loading delay
    final existingPosts = CommunityService.sortPostsForFeed(
      PrivateOrganizationService.instance.visiblePosts(_cachedPosts),
    );

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _CommunityBulletinArchivePage(
          user: user,
          initialPosts: existingPosts,
          initialView: savedOnly ? _BulletinView.saved : _BulletinView.all,
          initialCategory: initialCategory,
          targetPostId: targetPostId,
          targetTitle: targetTitle,
        ),
      ),
    );
  }

  void _openMap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => const ResidentMapPage(),
      ),
    );
  }

  Future<void> _showPostModal() async {
    final user = AuthService.currentUser;
    if (user == null) return;
    await _loadAnnouncementPublishingScope(user);
    if (!mounted) return;
    if (!_canPublishMunicipalityWide && _allowedAnnouncementBarangays.isEmpty) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        AppSnackBar(
          content: Text(
            'No publishing area is assigned to this account. Contact the LGU administrator.',
          ),
          kind: FeedbackKind.warning,
        ),
      );
      return;
    }
    _titleController.clear();
    _contentController.clear();
    _announcementVisibility = _canPublishMunicipalityWide
        ? 'public'
        : 'targeted';
    _announcementPriority = 'regular';
    _announcementPriorityExpiresAt = null;
    _selectedAnnouncementBarangays = _canPublishMunicipalityWide
        ? {}
        : _allowedAnnouncementBarangays.length == 1
        ? Set<String>.from(_allowedAnnouncementBarangays)
        : {};
    _announcementImage = null;
    _announcementImageBytes = null;
    _announcementAddToCalendar = false;
    _announcementEventAllDay = true;
    _announcementType = 'general';
    _announcementCategory = 'Community Activity';
    _announcementEventStartAt = null;
    _announcementEventEndAt = null;
    _announcementEventLocationController.clear();
    var isSubmitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          final isTargeted = _announcementVisibility == 'targeted';
          final ownBarangay = canonicalBariliBarangay(
            AuthService.currentUser?.barangay,
          );
          final isOnlyOwnBarangay =
              ownBarangay != null &&
              _selectedAnnouncementBarangays.length == 1 &&
              _selectedAnnouncementBarangays.contains(ownBarangay);
          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 18,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.colors.surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create Announcement',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textPrimary,
                            ),
                          ),
                          Text(
                            'Choose who should receive this update.',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _titleController,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Announcement title',
                            prefixIcon: Icon(Icons.title_rounded),
                          ),
                        ),
                        const SizedBox(height: 13),
                        TextField(
                          controller: _contentController,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Message',
                            alignLabelWithHint: true,
                            prefixIcon: Padding(
                              padding: EdgeInsets.only(bottom: 70),
                              child: Icon(Icons.notes_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildAnnouncementImagePicker(setModalState),
                        if (AuthService.currentUser?.role ==
                            UserRole.barangay) ...[
                          const SizedBox(height: 20),
                          Text(
                            'PRIORITY',
                            style: GoogleFonts.poppins(
                              color: context.colors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Choose how this announcement should appear.',
                            style: GoogleFonts.poppins(
                              color: context.colors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 9),
                          Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children: const ['regular', 'important', 'urgent']
                                .map((priority) {
                                  return _buildPriorityChoice(
                                    priority,
                                    selected: _announcementPriority == priority,
                                    onTap: () => setModalState(() {
                                      _announcementPriority = priority;
                                      if (priority != 'urgent' &&
                                          priority != 'emergency') {
                                        _announcementPriorityExpiresAt = null;
                                      }
                                    }),
                                  );
                                })
                                .toList(),
                          ),
                          if (_announcementPriority == 'urgent' ||
                              _announcementPriority == 'emergency') ...[
                            const SizedBox(height: 11),
                            InkWell(
                              onTap: () async {
                                final selected = await _pickPriorityExpiry(
                                  _announcementPriorityExpiresAt,
                                );
                                if (selected != null) {
                                  setModalState(() {
                                    _announcementPriorityExpiresAt = selected;
                                  });
                                }
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: AnimatedContainer(
                                duration: ESugidMotion.standard,
                                padding: const EdgeInsets.all(13),
                                decoration: BoxDecoration(
                                  color: _announcementPriorityExpiresAt == null
                                      ? context.colors.errorSurface
                                      : context.colors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color:
                                        _announcementPriorityExpiresAt == null
                                        ? context.colors.error
                                        : context.colors.primaryGreen,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.event_busy_outlined,
                                      color:
                                          _announcementPriorityExpiresAt == null
                                          ? context.colors.error
                                          : context.colors.primaryGreen,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _announcementPriorityExpiresAt ==
                                                    null
                                                ? 'Set urgency end time'
                                                : 'Pinned until',
                                            style: GoogleFonts.poppins(
                                              color: context.colors.textPrimary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          if (_announcementPriorityExpiresAt !=
                                              null)
                                            Text(
                                              DateFormat(
                                                'MMM d, y • h:mm a',
                                              ).format(
                                                _announcementPriorityExpiresAt!,
                                              ),
                                              style: GoogleFonts.poppins(
                                                color: context
                                                    .colors
                                                    .textSecondary,
                                                fontSize: 12,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right_rounded),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                        const SizedBox(height: 20),
                        if (user.role != UserRole.partner) ...[
                          _buildAnnouncementCalendarSchedule(setModalState),
                          const SizedBox(height: 20),
                        ],
                        Text(
                          'WHO SHOULD SEE THIS?',
                          style: GoogleFonts.poppins(
                            color: context.colors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            if (_canPublishMunicipalityWide) ...[
                              Expanded(
                                child: _buildVisibilityOption(
                                  icon: Icons.public_rounded,
                                  title: 'All Barili',
                                  subtitle: 'Everyone can see it',
                                  selected: !isTargeted,
                                  onTap: () => setModalState(
                                    () => _announcementVisibility = 'public',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                            Expanded(
                              child: _buildVisibilityOption(
                                icon: Icons.location_on_outlined,
                                title: _canPublishMunicipalityWide
                                    ? 'Targeted'
                                    : 'Authorized area',
                                subtitle:
                                    _allowedAnnouncementBarangays.length == 1
                                    ? _allowedAnnouncementBarangays.first
                                    : 'Specific barangays',
                                selected: isTargeted,
                                onTap: () => setModalState(
                                  () => _announcementVisibility = 'targeted',
                                ),
                              ),
                            ),
                          ],
                        ),
                        AnimatedSize(
                          duration: ESugidMotion.emphasized,
                          curve: ESugidMotion.enterCurve,
                          alignment: Alignment.topCenter,
                          child: !isTargeted
                              ? const SizedBox.shrink()
                              : TweenAnimationBuilder<double>(
                                  key: const ValueKey(
                                    'targeted-audience-panel',
                                  ),
                                  tween: Tween(begin: 0, end: 1),
                                  duration: ESugidMotion.emphasized,
                                  curve: ESugidMotion.enterCurve,
                                  builder: (context, value, child) => Opacity(
                                    opacity: value,
                                    child: Transform.translate(
                                      offset: Offset(0, 10 * (1 - value)),
                                      child: child,
                                    ),
                                  ),
                                  child: Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(top: 14),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: context.colors.surface,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: context.colors.border,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: context.colors.brandStrong
                                              .withValues(
                                            alpha: 0.08),
                                          blurRadius: 18,
                                          offset: const Offset(0, 7),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Choose your target',
                                          style: GoogleFonts.poppins(
                                            color: context.colors.textPrimary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          'Where should this announcement appear?',
                                          style: GoogleFonts.poppins(
                                            color: context.colors.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 11),
                                        Row(
                                          children: [
                                            if (ownBarangay != null) ...[
                                              Expanded(
                                                child: _buildTargetChoice(
                                                  icon:
                                                      Icons.home_work_outlined,
                                                  title: 'My Barangay',
                                                  subtitle: ownBarangay,
                                                  selected: isOnlyOwnBarangay,
                                                  onTap: () => setModalState(() {
                                                    _selectedAnnouncementBarangays =
                                                        {ownBarangay};
                                                  }),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                            ],
                                            if (_allowedAnnouncementBarangays
                                                    .length >
                                                1)
                                              Expanded(
                                                child: _buildTargetChoice(
                                                  icon: Icons.checklist_rounded,
                                                  title: 'Choose Barangays',
                                                  subtitle:
                                                      _selectedAnnouncementBarangays
                                                          .isEmpty
                                                      ? 'Select one or more'
                                                      : '${_selectedAnnouncementBarangays.length} selected',
                                                  selected:
                                                      _selectedAnnouncementBarangays
                                                          .isNotEmpty &&
                                                      !isOnlyOwnBarangay,
                                                  onTap: () async {
                                                    final selected =
                                                        await _selectAnnouncementBarangays();
                                                    if (selected != null) {
                                                      setModalState(() {
                                                        _selectedAnnouncementBarangays =
                                                            selected;
                                                      });
                                                    }
                                                  },
                                                ),
                                              ),
                                          ],
                                        ),
                                        if (_selectedAnnouncementBarangays
                                            .isNotEmpty) ...[
                                          const SizedBox(height: 10),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: _selectedAnnouncementBarangays
                                                .map(
                                                  (barangay) => InputChip(
                                                    label: Text(
                                                      barangay,
                                                      style:
                                                          GoogleFonts.poppins(
                                                            fontSize: 12,
                                                          ),
                                                    ),
                                                    onDeleted:
                                                        _allowedAnnouncementBarangays
                                                                .length ==
                                                            1
                                                        ? null
                                                        : () => setModalState(
                                                            () =>
                                                                _selectedAnnouncementBarangays
                                                                    .remove(
                                                                      barangay,
                                                                    ),
                                                          ),
                                                    backgroundColor: context
                                                        .colors
                                                        .surfaceAlt,
                                                    side: BorderSide.none,
                                                    deleteIconColor: context
                                                        .colors
                                                        .primaryGreen,
                                                  ),
                                                )
                                                .toList(),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.colors.surfaceAlt,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isTargeted
                                    ? Icons.my_location_rounded
                                    : Icons.public_rounded,
                                color: context.colors.primaryGreen,
                                size: 17,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _announcementAudiencePreview(isTargeted),
                                  style: GoogleFonts.poppins(
                                    color: context.colors.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            setModalState(() => isSubmitting = true);
                            final submitted = await _submitPost(sheetContext);
                            if (!submitted && sheetContext.mounted) {
                              setModalState(() => isSubmitting = false);
                            }
                          },
                    icon: isSubmitting
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: context.colors.surface,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                      isSubmitting ? 'Publishing...' : 'Post Announcement',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnnouncementImagePicker(StateSetter setModalState) {
    final imageBytes = _announcementImageBytes;
    if (imageBytes != null) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: context.colors.shadow.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(imageBytes, fit: BoxFit.cover),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          context.colors.shadow.withValues(alpha: 0.1),
                          context.colors.shadow.withValues(alpha: 0.6),
                        ],
                        stops: const [0.5, 0.7, 1],
                      ),
                    ),
                  ),
                ),
                // Glassy control bar
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Row(
                    children: [
                      Expanded(
                        child: ESugidPressable(
                          onTap: () async {
                            await _pickAnnouncementImage();
                            setModalState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: context.colors.surface.withValues(alpha: 0.2,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: context.colors.border.withValues(alpha: 0.3,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.photo_library_rounded,
                                  color: context.colors.onAccent,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Change Photo',
                                  style: GoogleFonts.outfit(
                                    color: context.colors.onAccent,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ESugidPressable(
                        onTap: () => setModalState(() {
                          _announcementImage = null;
                          _announcementImageBytes = null;
                        }),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: context.colors.errorSolid.withValues(alpha: 0.9,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: context.colors.shadow.withValues(alpha: 0.2,
                                ),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            color: context.colors.onAccent,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ESugidPressable(
      onTap: () async {
        await _pickAnnouncementImage();
        setModalState(() {});
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.colors.border, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: context.colors.shadow.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: context.colors.brand.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: context.colors.primaryGreen.withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.add_photo_alternate_rounded,
                color: context.colors.primaryGreen,
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Add Visual Context',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'A photo makes your post stand out and look more official.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: context.colors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityChoice(
    String priority, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    final color = _priorityColor(priority);
    return ChoiceChip(
      selected: selected,
      showCheckmark: false,
      avatar: Icon(
        _priorityIcon(priority),
        size: 15,
        color: selected ? context.colors.onAccent : color,
      ),
      label: Text(
        priority[0].toUpperCase() + priority.substring(1),
        style: GoogleFonts.poppins(
          color: selected ? context.colors.onAccent : color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      selectedColor: color,
      backgroundColor: color.withValues(alpha: 0.07),
      side: BorderSide(color: color.withValues(alpha: selected ? 1 : 0.25)),
      onSelected: (_) => onTap(),
    );
  }

  Color _priorityColor(String priority) {
    return switch (priority.toLowerCase()) {
      'emergency' => context.colors.error,
      'urgent' => context.colors.error,
      'important' => context.colors.warning,
      _ => context.colors.textSecondary,
    };
  }

  IconData _priorityIcon(String priority) {
    return switch (priority.toLowerCase()) {
      'emergency' => Icons.emergency_rounded,
      'urgent' => Icons.priority_high_rounded,
      'important' => Icons.star_rounded,
      _ => Icons.notes_rounded,
    };
  }

  Future<DateTime?> _pickPriorityExpiry(DateTime? current) async {
    final now = DateTime.now();
    final initial = current != null && current.isAfter(now)
        ? current
        : now.add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'When should urgency end?',
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: 'Select end time',
    );
    if (time == null) return null;
    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (!selected.isAfter(DateTime.now())) {
      if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          AppSnackBar(content: Text('Choose a future date and time.'),
            kind: FeedbackKind.warning,
          ),
        );
      }
      return null;
    }
    return selected;
  }

  Future<void> _pickAnnouncementImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1800,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.length > 8 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showAppSnackBar(
            AppSnackBar(content: Text('Please choose an image below 8 MB.'),
              kind: FeedbackKind.warning,
            ),
          );
        }
        return;
      }
      _announcementImage = picked;
      _announcementImageBytes = bytes;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          AppSnackBar(content: Text('The image could not be opened.'),
            kind: FeedbackKind.error,
          ),
        );
      }
    }
  }

  Widget _buildVisibilityOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: selected ? context.colors.surfaceAlt : context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? context.colors.primaryGreen
                : context.colors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: context.colors.primaryGreen, size: 20),
                const Spacer(),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? context.colors.primaryGreen
                      : context.colors.textSecondary,
                  size: 18,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.poppins(
                color: context.colors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                color: context.colors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetChoice({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: ESugidMotion.standard,
        curve: ESugidMotion.enterCurve,
        constraints: const BoxConstraints(minHeight: 92),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? context.colors.surfaceAlt : context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? context.colors.primaryGreen
                : context.colors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: context.colors.primaryGreen, size: 19),
                const Spacer(),
                AnimatedSwitcher(
                  duration: ESugidMotion.quick,
                  child: Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.arrow_forward_rounded,
                    key: ValueKey(selected),
                    color: selected ? context.colors.primaryGreen
                        : context.colors.textSecondary,
                    size: 17,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: context.colors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: context.colors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _announcementAudiencePreview(bool isTargeted) {
    if (!isTargeted) return 'Everyone in Barili can see this announcement.';
    if (_selectedAnnouncementBarangays.isEmpty) {
      return 'Choose at least one barangay before posting.';
    }

    final selected = bariliBarangays
        .where(_selectedAnnouncementBarangays.contains)
        .toList();
    if (selected.length == 1) {
      return 'Residents of Barangay ${selected.first} will see this.';
    }
    if (selected.length <= 3) {
      return 'Residents of ${selected.map((name) => 'Barangay $name').join(', ')} will see this.';
    }
    return 'Residents of ${selected.length} selected barangays will see this.';
  }

  Future<void> _loadAnnouncementPublishingScope(User user) async {
    if (user.role == UserRole.lgu) {
      _allowedAnnouncementBarangays = bariliBarangays.toSet();
      _canPublishMunicipalityWide = true;
      return;
    }

    if (user.role == UserRole.barangay) {
      final barangay = canonicalBariliBarangay(user.barangay);
      _allowedAnnouncementBarangays = barangay == null ? {} : {barangay};
      _canPublishMunicipalityWide = false;
      return;
    }

    _canPublishMunicipalityWide = false;
    final fallbackBarangay = canonicalBariliBarangay(user.barangay);
    var serviceBarangays = fallbackBarangay == null
        ? <String>{}
        : <String>{fallbackBarangay};
    try {
      final organizations = FirebaseFirestore.instance.collection(
        'organizations',
      );
      var snapshot = await organizations.doc(user.uid).get();
      if (!snapshot.exists) {
        final matches = await organizations
            .where('primaryAdminId', isEqualTo: user.uid)
            .limit(1)
            .get();
        if (matches.docs.isNotEmpty) snapshot = matches.docs.first;
      }
      final data = snapshot.data();
      if (data != null) {
        serviceBarangays =
            (data['serviceBarangays'] as List<dynamic>? ?? const [])
                .map((item) => canonicalBariliBarangay(item.toString()))
                .whereType<String>()
                .toSet();
        _canPublishMunicipalityWide =
            data['municipalityWidePublishing'] == true;
      }
    } catch (_) {
      // The server rules remain authoritative. The profile barangay is a safe
      // fallback when an older organization record has not been created yet.
    }
    _allowedAnnouncementBarangays = serviceBarangays;
  }

  Future<Set<String>?> _selectAnnouncementBarangays() async {
    final searchController = TextEditingController();
    final workingSelection = Set<String>.from(_selectedAnnouncementBarangays);
    var query = '';

    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final availableBarangays = bariliBarangays
              .where(_allowedAnnouncementBarangays.contains)
              .toList();
          final filtered = availableBarangays
              .where(
                (barangay) =>
                    barangay.toLowerCase().contains(query.toLowerCase()),
              )
              .toList();

          return Container(
            height: MediaQuery.sizeOf(context).height * 0.78,
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colors.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select Barangays',
                              style: GoogleFonts.poppins(
                                color: context.colors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${workingSelection.length} of ${availableBarangays.length} selected',
                              style: GoogleFonts.poppins(
                                color: context.colors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => setSheetState(() {
                          if (workingSelection.length ==
                              availableBarangays.length) {
                            workingSelection.clear();
                          } else {
                            workingSelection
                              ..clear()
                              ..addAll(availableBarangays);
                          }
                        }),
                        child: Text(
                          workingSelection.length == availableBarangays.length
                              ? 'Clear all'
                              : 'Select all',
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: TextField(
                    controller: searchController,
                    onChanged: (value) => setSheetState(() => query = value),
                    decoration: const InputDecoration(
                      hintText: 'Search barangay',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final barangay = filtered[index];
                      final selected = workingSelection.contains(barangay);
                      return CheckboxListTile(
                        value: selected,
                        activeColor: context.colors.primaryGreen,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(
                          barangay,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                        onChanged: (_) => setSheetState(() {
                          selected
                              ? workingSelection.remove(barangay)
                              : workingSelection.add(barangay);
                        }),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    18,
                    10,
                    18,
                    MediaQuery.paddingOf(context).bottom + 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            FocusManager.instance.primaryFocus?.unfocus();
                            Navigator.pop(context);
                          },
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: workingSelection.isEmpty
                              ? null
                              : () {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  Navigator.pop(
                                    context,
                                    Set<String>.from(workingSelection),
                                  );
                                },
                          child: const Text('Confirm'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => searchController.dispose(),
    );
    return result;
  }

  Widget _buildAnnouncementCalendarSchedule(StateSetter setModalState) {
    const categoriesByType = {
      'event': [
        'Community Activity',
        'Clean-Up Drive',
        'Barangay Meeting',
        'Health Program',
        'Relief/Assistance Distribution',
        'Public Service Activity',
        'Other Scheduled Announcement',
      ],
      'advisory': [
        'Public Advisory',
        'Power Interruption',
        'Water Interruption',
        'Emergency Advisory',
        'Registration Deadline',
        'Other Scheduled Announcement',
      ],
      'general': [
        'General Announcement',
        'Urgent',
        'Public Advisory',
        'Community Activity',
        'Public Service Activity',
        'Registration Deadline',
        'Other Scheduled Announcement',
      ],
    };

    final effectiveType = _announcementType == 'scheduled_activity'
        ? 'event'
        : _announcementType;
    final categories =
        categoriesByType[effectiveType] ?? categoriesByType['general']!;
    final selectedCat = categories.contains(_announcementCategory)
        ? _announcementCategory
        : categories.first;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'POST TYPE & CATEGORY',
            style: GoogleFonts.poppins(
              color: context.colors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: ['general', 'advisory', 'event'].contains(effectiveType)
                ? effectiveType
                : 'general',
            decoration: const InputDecoration(
              labelText: 'Post Type',
              prefixIcon: Icon(Icons.article_outlined),
            ),
            items: const [
              DropdownMenuItem(value: 'general', child: Text('Announcement')),
              DropdownMenuItem(
                value: 'advisory',
                child: Text('Public Advisory'),
              ),
              DropdownMenuItem(value: 'event', child: Text('Event / Activity')),
            ],
            onChanged: (value) => setModalState(() {
              if (value != null) {
                _announcementType = value;
                if (value == 'event') {
                  _announcementAddToCalendar = true;
                }
                final newCategories =
                    categoriesByType[value] ?? categoriesByType['general']!;
                if (!newCategories.contains(_announcementCategory)) {
                  _announcementCategory = newCategories.first;
                }
              }
            }),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: selectedCat,
            decoration: const InputDecoration(
              labelText: 'Category',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: categories
                .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                .toList(),
            onChanged: (value) => setModalState(() {
              if (value != null) _announcementCategory = value;
            }),
          ),
          const SizedBox(height: 10),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Schedule on Community Calendar',
              style: GoogleFonts.poppins(
                color: context.colors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              'Places this announcement on the official Community Calendar and sends automatic reminders to residents.',
              style: GoogleFonts.poppins(
                color: context.colors.textSecondary,
                fontSize: 11,
              ),
            ),
            value: _announcementAddToCalendar,
            onChanged: (value) {
              setModalState(() {
                _announcementAddToCalendar = value;
                _announcementType = value ? 'scheduled_activity' : 'general';
              });
            },
          ),
          if (_announcementAddToCalendar) ...[
            const Divider(height: 18),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('All day'),
              subtitle: const Text(
                'Turn off to specify exact start and end times.',
              ),
              value: _announcementEventAllDay,
              onChanged: (value) => setModalState(() {
                _announcementEventAllDay = value;
                final date = _announcementEventStartAt;
                _announcementEventStartAt = value && date != null
                    ? DateTime(date.year, date.month, date.day)
                    : null;
                _announcementEventEndAt = _announcementEventStartAt?.add(
                  const Duration(days: 1),
                );
              }),
            ),
            _announcementScheduleTile(
              label: _announcementEventAllDay
                  ? 'Scheduled date'
                  : 'Start date & time',
              value: _announcementEventStartAt,
              onTap: () => _pickAnnouncementEventDateTime(
                start: true,
                setModalState: setModalState,
              ),
            ),
            if (!_announcementEventAllDay)
              _announcementScheduleTile(
                label: 'End date & time (optional)',
                value: _announcementEventEndAt,
                onTap: () => _pickAnnouncementEventDateTime(
                  start: false,
                  setModalState: setModalState,
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _announcementEventLocationController,
              maxLength: 200,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Event location (optional)',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _announcementScheduleTile({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.schedule_rounded, color: context.colors.primaryGreen),
      title: Text(label),
      subtitle: Text(
        value == null
            ? (_announcementEventAllDay
                  ? 'Choose date'
                  : 'Choose date and time')
            : DateFormat(
                _announcementEventAllDay
                    ? 'EEE, MMM d, y'
                    : 'EEE, MMM d, y • h:mm a',
              ).format(value),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }

  Future<void> _pickAnnouncementEventDateTime({
    required bool start,
    required StateSetter setModalState,
  }) async {
    final current = start ? _announcementEventStartAt : _announcementEventEndAt;
    final initial = current ?? DateTime.now().add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date == null || !mounted) return;
    if (_announcementEventAllDay) {
      setModalState(() {
        _announcementEventStartAt = DateTime(date.year, date.month, date.day);
        _announcementEventEndAt = _announcementEventStartAt!.add(
          const Duration(days: 1),
        );
      });
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setModalState(() {
      if (start) {
        _announcementEventStartAt = selected;
      } else {
        _announcementEventEndAt = selected;
      }
    });
  }

  Future<bool> _submitPost(BuildContext modalContext) async {
    if (_titleController.text.trim().isEmpty ||
        _contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        AppSnackBar(content: Text('Please enter a title and message.'),
          kind: FeedbackKind.warning,
        ),
      );
      return false;
    }
    if (_announcementVisibility == 'targeted' &&
        _selectedAnnouncementBarangays.isEmpty) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        AppSnackBar(content: Text('Please select at least one barangay.'),
          kind: FeedbackKind.warning,
        ),
      );
      return false;
    }
    final user = AuthService.currentUser;
    if (user == null) return false;
    if (!user.canPublishAnnouncements) {
      if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          AppSnackBar(
            content: Text(
              'Your account must be verified before posting announcements.',
            ),
            kind: FeedbackKind.warning,
          ),
        );
      }
      return false;
    }
    final requestedBarangays = _selectedAnnouncementBarangays
        .map(canonicalBariliBarangay)
        .whereType<String>()
        .toSet();
    if (_announcementVisibility == 'public' && !_canPublishMunicipalityWide) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        AppSnackBar(
          content: Text('Your account cannot publish municipality-wide.'),
          kind: FeedbackKind.warning,
        ),
      );
      return false;
    }
    if (!requestedBarangays.every(_allowedAnnouncementBarangays.contains)) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        AppSnackBar(
          content: Text('Choose only barangays within your authorized area.'),
          kind: FeedbackKind.warning,
        ),
      );
      return false;
    }
    final canSetPriority = user.role == UserRole.barangay;
    final priority = canSetPriority ? _announcementPriority : 'regular';
    final needsExpiry = priority == 'urgent' || priority == 'emergency';
    if (needsExpiry &&
        (_announcementPriorityExpiresAt == null ||
            !_announcementPriorityExpiresAt!.isAfter(DateTime.now()))) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        AppSnackBar(
          content: Text('Set a future end time for this urgent post.'),
          kind: FeedbackKind.warning,
        ),
      );
      return false;
    }
    if (_announcementAddToCalendar) {
      final startAt = _announcementEventStartAt;
      if (startAt == null) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          AppSnackBar(
            content: Text('Choose a scheduled date for this announcement.'),
            kind: FeedbackKind.warning,
          ),
        );
        return false;
      }
      if (_announcementEventEndAt == null) {
        _announcementEventEndAt = _announcementEventAllDay
            ? startAt.add(const Duration(days: 1))
            : startAt.add(const Duration(hours: 1));
      } else if (!_announcementEventEndAt!.isAfter(startAt)) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          AppSnackBar(
            content: Text('End time must be after the start time.'),
            kind: FeedbackKind.warning,
          ),
        );
        return false;
      }
    }

    final selectedBarangays = bariliBarangays
        .where(requestedBarangays.contains)
        .toList();
    final isPublic = _announcementVisibility == 'public';
    final postId = 'POST-${DateTime.now().millisecondsSinceEpoch}';
    String imageUrl = '';
    String imageStoragePath = '';
    String localSavedImagePath = '';

    try {
      final imageBytes = _announcementImageBytes;
      if (imageBytes != null) {
        try {
          localSavedImagePath = await AnnouncementImageCache.saveImageBytes(
            key: postId,
            bytes: imageBytes,
            extension: '.jpg',
          );
        } catch (_) {}

        imageStoragePath = 'announcements/${user.uid}/$postId/announcement.jpg';
        final imageReference = FirebaseStorage.instance.ref(imageStoragePath);
        await imageReference.putData(
          imageBytes,
          SettableMetadata(
            contentType: _announcementImage?.mimeType ?? 'image/jpeg',
          ),
        );
        imageUrl = await imageReference.getDownloadURL();

        if (imageUrl.isNotEmpty) {
          try {
            await AnnouncementImageCache.saveImageBytes(
              key: imageUrl,
              bytes: imageBytes,
              extension: '.jpg',
            );
          } catch (_) {}
        }
      }

      final post = TargetedPost(
        id: postId,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        authorName: user.name,
        authorId: user.uid,
        authorRole: user.canonicalStaffRole,
        authorPosition:
            user.positionTitle ?? _publisherRoleLabel(user.canonicalStaffRole),
        authorBarangay: user.barangay ?? '',
        authorOrganizationName: user.organizationName ?? '',
        publisherEntityId: user.role == UserRole.partner
            ? user.organizationId ?? user.uid
            : user.role == UserRole.barangay
            ? (user.barangay ?? '').toLowerCase().replaceAll(
                RegExp(r'[^a-z0-9]+'),
                '-',
              )
            : 'municipality-of-barili',
        publisherEntityType: user.role == UserRole.partner
            ? 'organization'
            : user.role == UserRole.barangay
            ? 'barangay'
            : 'lgu',
        publisherEntityName: user.role == UserRole.partner
            ? user.organizationName ?? 'Service organization'
            : user.role == UserRole.barangay
            ? 'Barangay ${user.barangay ?? 'Barili'}'
            : 'Municipality of Barili',
        targetAudience: 'All Residents',
        targetBarangay: isPublic
            ? 'All Barangays'
            : selectedBarangays.length == 1
            ? selectedBarangays.first
            : 'Selected Barangays',
        visibility: isPublic ? 'public' : 'targeted',
        targetBarangays: isPublic ? const [] : selectedBarangays,
        imageUrl: imageUrl,
        imageStoragePath: imageStoragePath,
        localImagePath: localSavedImagePath,
        createdAt: DateTime.now(),
        status: 'approved',
        priority: priority,
        priorityExpiresAt: needsExpiry ? _announcementPriorityExpiresAt : null,
        category: _announcementCategory,
        notificationRequested: true,
      );
      final linkedEvent = _announcementAddToCalendar
          ? CalendarEvent(
              id: '',
              title: post.title,
              description: post.content.length > 1200
                  ? post.content.substring(0, 1200)
                  : post.content,
              startAt: _announcementEventStartAt!,
              endAt: _announcementEventEndAt!,
              allDay: _announcementEventAllDay,
              category: CalendarEventCategory.announcement,
              categoryName: _announcementCategory,
              location: _announcementEventLocationController.text.trim(),
              createdBy: user.uid,
              sourceType: CalendarEventSourceType.announcement,
              sourceId: postId,
              visibility: isPublic
                  ? CalendarEventVisibility.public
                  : CalendarEventVisibility.barangay,
              targetBarangay: !isPublic && selectedBarangays.length == 1
                  ? selectedBarangays.first
                  : '',
              targetUserIds: const [],
              audienceKeys: isPublic
                  ? const ['municipality:barili']
                  : selectedBarangays
                        .map((barangay) => 'barangay:$barangay')
                        .toList(),
              status: CalendarEventStatus.scheduled,
              isImportant: priority != 'regular',
              organizerName: post.publisherEntityName,
            )
          : null;
      await CommunityService.createTargetedPost(
        post,
        linkedCalendarEvent: linkedEvent,
        announcementType: _announcementType,
      );

      final communityPost = CommunityPost(
        id: post.id,
        title: post.title,
        content: post.content,
        authorName: post.authorName,
        authorId: post.authorId,
        authorRole: post.authorRole,
        authorPosition: post.authorPosition,
        authorBarangay: post.authorBarangay,
        authorOrganizationName: post.authorOrganizationName,
        authorPhotoUrl: user.profilePhotoUrl ?? '',
        publisherEntityId: post.publisherEntityId,
        publisherEntityType: post.publisherEntityType,
        publisherEntityName: post.publisherEntityName,
        targetAudience: post.targetAudience,
        targetBarangay: post.targetBarangay,
        visibility: post.visibility,
        targetBarangays: post.targetBarangays,
        imageUrl: post.imageUrl,
        imageStoragePath: post.imageStoragePath,
        localImagePath: localSavedImagePath,
        createdAt: post.createdAt,
        status: post.status,
        tag: 'OFFICIAL',
        priority: post.priority,
        priorityExpiresAt: post.priorityExpiresAt,
        category: post.category,
        announcementType: _announcementType,
        hasSchedule: _announcementAddToCalendar,
        eventDate: _announcementEventStartAt,
        eventEndDate: _announcementEventEndAt,
        eventAllDay: _announcementEventAllDay,
        location: _announcementEventLocationController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _cachedPosts = [
            communityPost,
            ..._cachedPosts.where((p) => p.id != communityPost.id),
          ];
        });
        unawaited(_announcementCache.save(_cachedPosts));
        if (localSavedImagePath.isNotEmpty) {
          try {
            unawaited(
              precacheImage(FileImage(File(localSavedImagePath)), context),
            );
          } catch (_) {}
        }
      }

      if (modalContext.mounted) {
        FocusManager.instance.primaryFocus?.unfocus();
        Navigator.of(modalContext).pop();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          AppSnackBar(
            content: Text(
              isPublic
                  ? 'Announcement posted throughout Barili.'
                  : 'Announcement posted to ${selectedBarangays.length} selected barangay${selectedBarangays.length == 1 ? '' : 's'}.',
            ),
            kind: FeedbackKind.success,
          ),
        );
      }
      return true;
    } catch (_) {
      if (imageStoragePath.isNotEmpty) {
        try {
          await FirebaseStorage.instance.ref(imageStoragePath).delete();
        } catch (_) {
          // The upload may not have completed, so there may be nothing to remove.
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          AppSnackBar(
            content: Text('The announcement could not be posted. Try again.'),
            kind: FeedbackKind.error,
          ),
        );
      }
      return false;
    }
  }

  Widget _buildAlertsPage(User user, {bool showBackButton = true}) {
    final isResident = user.role == UserRole.resident;
    final tabCount = isResident ? 2 : 3;
    final initialTab = _alertsInitialTab.clamp(0, tabCount - 1);

    return ESugidPullToRefresh(
      onRefresh: () => _refreshAlertsPage(user),
      child: DefaultTabController(
        key: ValueKey<int>(initialTab),
        length: tabCount,
        initialIndex: initialTab,
        child: NestedScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            ESugidSliverPageHeader(
              pinned: true,
              showBackButton: showBackButton,
              onBack: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  _selectedPageIndex.value = 0;
                }
              },
              sectionLabelWidget: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 3.5,
                ),
                decoration: BoxDecoration(
                  color: context.colors.brandStrong.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: context.colors.error.withValues(alpha: 0.75),
                    width: 1.1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: context.colors.shadow.withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 1.5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.colors.errorSolid,
                        boxShadow: [
                          BoxShadow(
                            color: context.colors.highlight,
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'SAFETY & EMERGENCY',
                      style: GoogleFonts.outfit(
                        color: context.colors.onAccent,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              title: 'Emergency Center',
            ),
            SliverToBoxAdapter(
              child: buildEmergencyHotlinesShortcutCard(context),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _EmergencyTabBarDelegate(
                child: Container(
                  color: context.colors.background,
                  padding: const EdgeInsets.only(top: 2, bottom: 4),
                  alignment: Alignment.center,
                  child: ESugidFloatingTabBar(
                    tabs: isResident
                        ? const [Tab(text: 'Current'), Tab(text: 'History')]
                        : const [
                            Tab(text: 'Current'),
                            Tab(text: 'Resident Reports'),
                            Tab(text: 'History'),
                          ],
                  ),
                ),
                height: 72,
              ),
            ),
          ],
          body: TabBarView(
            children: isResident
                ? [
                    _KeepAliveTab(child: _buildActiveAlertsList(user)),
                    _KeepAliveTab(child: _buildAlertHistoryList(user)),
                  ]
                : [
                    _KeepAliveTab(child: _buildActiveAlertsList(user)),
                    _KeepAliveTab(child: _buildResponderEmergencyReports(user)),
                    _KeepAliveTab(child: _buildAlertHistoryList(user)),
                  ],
          ),
        ),
      ),
    );
  }

  static Widget buildEmergencyHotlinesShortcutCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.colors.surface, context.colors.errorSurface],
        ),
        border: Border.all(
          color: context.colors.error.withValues(alpha: isDark ? 0.45 : 0.30),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (context.colors.highlight).withValues(
              alpha: isDark ? 0.35 : 0.06,
            ),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: (context.colors.errorSolid).withValues(
              alpha: isDark ? 0.40 : 0.08,
            ),
            blurRadius: 18,
            offset: const Offset(0, 7),
            spreadRadius: -1,
          ),
          BoxShadow(
            color: context.colors.highlight.withValues(alpha: isDark ? 0.16 : 0.10,
            ),
            blurRadius: 20,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const EmergencyHotlinesPage()),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    context.colors.errorSolid,
                                    context.colors.errorSolid,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color: context.colors.highlight.withValues(alpha: 0.35,
                                    ),
                                    blurRadius: 6,
                                    offset: const Offset(0, 1.5),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: context.colors.surface,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'EMERGENCY HOTLINES',
                                    style: GoogleFonts.outfit(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: context.colors.onAccent,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: context.colors.errorSolid.withValues(alpha: isDark ? 0.25 : 0.12,
                                ),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: context.colors.error.withValues(alpha: 0.35,
                                  ),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                'DIRECT DIAL',
                                style: GoogleFonts.outfit(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: context.colors.error,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.errorSolid.withValues(alpha: isDark ? 0.20 : 0.08,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '24/7 TOLL-FREE',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            color: context.colors.error,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 11),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            context.colors.errorSolid,
                            context.colors.errorSolid,
                            context.colors.errorSolid,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: context.colors.highlight.withValues(alpha: 0.45,
                            ),
                            blurRadius: 10,
                            offset: const Offset(0, 3.5),
                          ),
                          BoxShadow(
                            color: context.colors.highlight.withValues(
                              alpha: isDark ? 0.15 : 0.35,
                            ),
                            blurRadius: 2,
                            offset: const Offset(-1, -1),
                          ),
                        ],
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(2.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              context.colors.errorSolid,
                              context.colors.errorSolid,
                            ],
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.phone_in_talk_rounded,
                            color: context.colors.onAccent,
                            size: 20,
                            shadows: [
                              Shadow(
                                color: context.colors.textPrimary,
                                blurRadius: 4,
                                offset: Offset(0, 1.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Immediate Assistance',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: context.colors.textPrimary,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      context.colors.errorSolid,
                                      context.colors.errorSolid,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: [
                                    BoxShadow(
                                      color: context.colors.highlight
                                          .withValues(alpha: 0.35),
                                      blurRadius: 5,
                                      offset: const Offset(0, 1.5),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '911',
                                  style: GoogleFonts.outfit(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    color: context.colors.onAccent,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Direct dial PNP, BFP, MDRRMO & 911',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              color: context.colors.error.withValues(alpha: 0.8,
                              ),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6.5,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            context.colors.errorSolid,
                            context.colors.errorSolid,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: [
                          BoxShadow(
                            color: context.colors.highlight.withValues(alpha: 0.35,
                            ),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View',
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: context.colors.onAccent,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 12,
                            color: context.colors.onAccent,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAlertsLoadingSkeleton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark
        ? context.colors.surfaceAlt
        : context.colors.surfaceAlt;

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 140),
      itemCount: 3,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: context.colors.border),
          boxShadow: [
            BoxShadow(
              color: context.colors.shadow.withValues(alpha: isDark ? 0.2 : 0.04,
              ),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: baseColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 120,
                        height: 12,
                        decoration: BoxDecoration(
                          color: baseColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 80,
                        height: 10,
                        decoration: BoxDecoration(
                          color: baseColor.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              height: 12,
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 180,
              height: 12,
              decoration: BoxDecoration(
                color: baseColor.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveAlertsList(User user) {
    return StreamBuilder<List<CommunityAlert>>(
      stream: CommunityService.alertsForUser(user),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildAlertsLoadingSkeleton(context);
        }
        if (snapshot.hasError) {
          return AsyncErrorView(onRetry: () => setState(() {}));
        }
        final alerts = snapshot.data ?? [];
        if (alerts.isEmpty) {
          return _buildAlertEmptyState(
            Icons.shield_outlined,
            'No active alerts',
            'There are no current safety warnings for your area.',
          );
        }
        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 140),
          itemCount: alerts.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      context.colors.errorSurface,
                      context.colors.errorSurface,
                    ],
                  ),
                  border: Border.all(
                    color: context.colors.error.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: context.colors.highlight.withValues(alpha: isDark ? 0.2 : 0.08,
                      ),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            context.colors.errorSolid,
                            context.colors.errorSolid,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: context.colors.highlight.withValues(alpha: 0.4,
                            ),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.campaign_rounded,
                          color: context.colors.onAccent,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'OFFICIAL EMERGENCY BROADCAST',
                            style: GoogleFonts.outfit(
                              color: context.colors.error,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Active emergency directives issued by authorized Barili LGU dispatchers.',
                            style: GoogleFonts.outfit(
                              color: context.colors.error,
                              fontSize: 12,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }
            return _buildAlertCard(alerts[index - 1], showResolved: false);
          },
        );
      },
    );
  }

  Widget _buildAlertHistoryList(User user) {
    return StreamBuilder<List<CommunityAlert>>(
      stream: CommunityService.alertHistoryForUser(user),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildAlertsLoadingSkeleton(context);
        }
        if (snapshot.hasError) {
          return AsyncErrorView(onRetry: () => setState(() {}));
        }
        final alerts = snapshot.data ?? [];
        if (alerts.isEmpty) {
          return _buildAlertEmptyState(
            Icons.history_rounded,
            'No previous alerts',
            'Closed and expired emergency alerts will appear here.',
          );
        }
        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 140),
          itemCount: alerts.length,
          itemBuilder: (context, index) =>
              _buildAlertCard(alerts[index], showResolved: true),
        );
      },
    );
  }

  Widget _buildResponderEmergencyReports(User user) {
    return StreamBuilder<List<EmergencyReport>>(
      stream: EmergencyService.reportsForResponder(user),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildAlertsLoadingSkeleton(context);
        }
        if (snapshot.hasError) {
          return AsyncErrorView(onRetry: () => setState(() {}));
        }
        final reports = snapshot.data ?? [];
        if (reports.isEmpty) {
          return _buildAlertEmptyState(
            Icons.health_and_safety_outlined,
            'No routed emergencies',
            'Resident incidents assigned to your area will appear here.',
          );
        }
        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 140),
          itemCount: reports.length,
          itemBuilder: (context, index) =>
              _buildEmergencyReportCard(reports[index], responderView: true),
        );
      },
    );
  }

  Widget _buildAlertEmptyState(
    IconData icon,
    String title,
    String subtitle, {
    bool compact = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSafetyNoAlerts =
        icon == Icons.shield_outlined ||
        title.toLowerCase().contains('no active');

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 24,
                vertical: compact ? 20 : 40,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 3D Concentric Ripple Scanner Rings with Minted Crest
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outermost ambient pulse ring
                      Container(
                        width: compact ? 100 : 130,
                        height: compact ? 100 : 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              (context.colors.brand)
                                  .withValues(alpha: isDark ? 0.08 : 0.05,
                          ),
                        ),
                      ),
                      // Middle ring
                      Container(
                        width: compact ? 80 : 104,
                        height: compact ? 80 : 104,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              (context.colors.brand)
                                  .withValues(alpha: isDark ? 0.14 : 0.09,
                          ),
                        ),
                      ),
                      // 3D Minted Crest / Medallion
                      Container(
                        width: compact ? 60 : 76,
                        height: compact ? 60 : 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isSafetyNoAlerts
                                ? [
                                    context.colors.warningSolid,
                                    context.colors.brand,
                                    context.colors.brand,
                                    context.colors.brandStrong,
                                  ]
                                : [
                                    context.colors.infoSolid,
                                    context.colors.infoSolid,
                                    context.colors.infoSolid,
                                    context.colors.infoSolid,
                                  ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (isSafetyNoAlerts
                                          ? context.colors.brandStrong
                                          : context.colors.infoSolid)
                                      .withValues(alpha: isDark ? 0.35 : 0.28),
                              blurRadius: 18,
                              offset: const Offset(0, 7),
                            ),
                          ],
                        ),
                        child: Container(
                          margin: const EdgeInsets.all(2.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: isSafetyNoAlerts
                                  ? [
                                      context.colors.brand,
                                      context.colors.brandStrong,
                                    ]
                                  : [
                                      context.colors.infoSolid,
                                      context.colors.infoSolid,
                                    ],
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              isSafetyNoAlerts
                                  ? Icons.verified_user_rounded
                                  : icon,
                              color: isSafetyNoAlerts
                                  ? context.colors.onBrandMuted
                                  : context.colors.onAccent,
                              size: compact ? 26 : 34,
                              shadows: [
                                Shadow(
                                  color: context.colors.textPrimary,
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 3D Live Status Chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 4.5,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isSafetyNoAlerts
                            ? ([
                                context.colors.surfaceAlt,
                                context.colors.surfaceAlt,
                                    ])
                            : ([
                                context.colors.surfaceAlt,
                                context.colors.infoSurface,
                                    ]),
                      ),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: isSafetyNoAlerts
                            ? context.colors.primaryGreen.withValues(alpha: 0.4)
                            : context.colors.border.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: isSafetyNoAlerts
                                ? context.colors.brand
                                : context.colors.infoSolid,
                            shape: BoxShape.circle,
                            boxShadow: isSafetyNoAlerts
                                ? [
                                    BoxShadow(
                                      color: context.colors.brandStrong,
                                      blurRadius: 5,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isSafetyNoAlerts
                              ? 'ALL CLEAR • NORMAL SAFETY STATUS'
                              : 'HISTORICAL LOGS UP TO DATE',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isSafetyNoAlerts
                                ? (context.colors.primaryGreen)
                                      : (context.colors.textSecondary),
                            letterSpacing: 0.7,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Title (omitted when isSafetyNoAlerts as outlined by user)
                  if (!isSafetyNoAlerts) ...[
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: context.colors.textPrimary,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],

                  // Subtitle / Status Note
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Text(
                      isSafetyNoAlerts
                          ? 'No active emergency alerts or safety advisories in Barili.'
                          : subtitle,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: context.colors.textSecondary,
                        fontSize: 13,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyReportCard(
    EmergencyReport report, {
    bool responderView = false,
  }) {
    final (color, icon) = _emergencyStyle(report.emergencyType);
    final statusColor = _emergencyStatusColor(report.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.colors.border),
        boxShadow: [
          BoxShadow(
            color: context.colors.brandStrong.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.emergencyType,
                      style: GoogleFonts.poppins(
                        color: context.colors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      DateFormat(
                        'MMM d, y \u2022 h:mm a',
                      ).format(report.createdAt.toLocal()),
                      style: GoogleFonts.poppins(
                        color: context.colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              responderView
                  ? PopupMenuButton<String>(
                      tooltip: 'Update status',
                      onSelected: (status) async {
                        final user = AuthService.currentUser;
                        if (user == null) return;
                        await EmergencyService.updateStatus(
                          report.id,
                          status,
                          updatedBy: user.uid,
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showAppSnackBar(
                            AppSnackBar(
                              content: Text('Emergency status updated.'),
                              kind: FeedbackKind.success,
                            ),
                          );
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'acknowledged',
                          child: Text('Acknowledged'),
                        ),
                        PopupMenuItem(
                          value: 'responding',
                          child: Text('Responding'),
                        ),
                        PopupMenuItem(
                          value: 'resolved',
                          child: Text('Resolved'),
                        ),
                      ],
                      child: _buildEmergencyStatusPill(
                        report.status,
                        statusColor,
                        showArrow: true,
                      ),
                    )
                  : _buildEmergencyStatusPill(report.status, statusColor),
            ],
          ),
          const SizedBox(height: 11),
          Text(
            report.description,
            style: GoogleFonts.poppins(
              color: context.colors.textPrimary,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          _buildEmergencyDetailRow(
            Icons.location_on_outlined,
            '${report.location}, Barangay ${report.barangay}',
          ),
          const SizedBox(height: 6),
          _buildEmergencyDetailRow(
            responderView ? Icons.person_outline_rounded : Icons.route_rounded,
            responderView
                ? '${report.reporterName} \u2022 ${report.contactNumber}'
                : 'Routed to ${report.routedAgency}',
          ),
          if (report.imageUrl.isNotEmpty) ...[
            const SizedBox(height: 11),
            GestureDetector(
              onTap: () => _showAnnouncementImage(report.imageUrl),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 2.2,
                  child: Image.network(
                    report.imageUrl,
                    fit: BoxFit.cover,
                    cacheWidth: 900,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmergencyStatusPill(
    String status,
    Color color, {
    bool showArrow = false,
  }) {
    final label = switch (status.toLowerCase()) {
      'received' => 'Received',
      'dispatched' => 'Dispatched',
      'resolved' => 'Resolved',
      _ => 'Submitted',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (showArrow) ...[
            const SizedBox(width: 2),
            Icon(Icons.expand_more_rounded, color: color, size: 14),
          ],
        ],
      ),
    );
  }

  Widget _buildEmergencyDetailRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: context.colors.textSecondary, size: 15),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              color: context.colors.textSecondary,
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  void _showAnnouncementImage(String imageUrl) {
    showDialog<void>(
      context: context,
      barrierColor: context.colors.shadow.withValues(alpha: 0.92),
      builder: (dialogContext) => Dialog.fullscreen(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: Center(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Icon(
                      Icons.broken_image_outlined,
                      color: dialogContext.colors.onBrandMuted,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.paddingOf(dialogContext).top + 8,
              right: 10,
              child: IconButton.filled(
                onPressed: () => Navigator.pop(dialogContext),
                style: IconButton.styleFrom(
                  backgroundColor: dialogContext.colors.shadow.withValues(alpha: 0.45,
                  ),
                ),
                icon: Icon(Icons.close_rounded, color: dialogContext.colors.onAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  (Color, IconData) _emergencyStyle(String type) {
    return switch (type) {
      'Fire' => (context.colors.error, Icons.local_fire_department_rounded),
      'Medical' => (context.colors.error, Icons.medical_services_rounded),
      'Crime or Threat' => (context.colors.info,
        Icons.local_police_rounded),
      'Flood or Disaster' => (context.colors.info, Icons.flood_rounded),
      'Electrical Hazard' => (context.colors.warning, Icons.bolt_rounded),
      _ => (context.colors.purple, Icons.emergency_rounded),
    };
  }

  Color _emergencyStatusColor(String status) {
    return switch (status.toLowerCase()) {
      'acknowledged' => context.colors.info,
      'responding' => context.colors.warning,
      'resolved' => context.colors.primaryGreen,
      _ => context.colors.textSecondary,
    };
  }

  Widget _buildPartnerNotificationsPage(
    User user, {
    bool showBackButton = false,
  }) {
    return ESugidPullToRefresh(
      onRefresh: () => _refreshPartnerNotifications(user),
      child: NotificationInbox(
        key: ValueKey('notification-inbox-${user.uid}'),
        includeHeader: true,
        showBackButton: showBackButton,
        onBack: () => Navigator.maybePop(context),
        watchNotifications: () =>
            SubmissionService.notificationsForUser(user.uid),
        onOpen: (notification) => _handleNotificationOpen(
          user,
          notification,
          openedFromPushedPage: showBackButton,
        ),
      ),
    );
  }

  Future<void> _handleNotificationOpen(
    User user,
    ResidentNotification notification, {
    required bool openedFromPushedPage,
  }) async {
    if (!mounted) return;
    await openNotification(
      isRead: notification.read,
      markRead: () => SubmissionService.markNotificationRead(notification.id),
      openDestination: () => _openNotificationDestination(
        notification,
        openedFromPushedPage: openedFromPushedPage,
      ),
      onReceiptError: (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showAppSnackBar(
          AppSnackBar(
            content: Text('Could not mark this notification as read.'),
            kind: FeedbackKind.error,
          ),
        );
      },
    );
  }

  Future<void> _openNotificationDestination(
    ResidentNotification notification, {
    required bool openedFromPushedPage,
  }) async {
    if (!mounted) return;

    final type = notification.type.trim().toLowerCase();
    final referenceId = notification.referenceId;
    if (type.startsWith('bayanihan_')) {
      await Navigator.of(context).pushNamed('/bayanihan-messages');
      return;
    }
    if (type == 'help_interest') {
      await Navigator.of(context).pushNamed('/jobs', arguments: referenceId);
      return;
    }
    if (type == 'emergency_alert' && referenceId?.isNotEmpty == true) {
      await Navigator.of(
        context,
      ).pushNamed('/emergency', arguments: referenceId);
      return;
    }
    if (type == 'emergency_update') {
      if (openedFromPushedPage) Navigator.of(context).pop();
      _selectPage(1);
      return;
    }
    if (type.contains('verification')) {
      await Navigator.of(context).pushNamed('/verification');
      return;
    }
    if (type == 'announcement' ||
        type == 'post_review' ||
        type == 'announcement_reminder' ||
        type.contains('announcement') ||
        notification.relatedEntityType == 'community_post' ||
        notification.title.toLowerCase().contains('announcement')) {
      final postId = referenceId?.isNotEmpty == true
          ? referenceId
          : notification.metadata['postId']?.toString();
      if (openedFromPushedPage) Navigator.of(context).pop();
      _navigateToUpdatesPost(postId);
      return;
    }
    if (type.contains('concern') || type.startsWith('complaint_') || notification.relatedEntityType == 'complaint') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ConcernCenterPage(
            initialConcernId: referenceId,
            initialCenterTab: 1,
            initialActivitySubTab: referenceId?.startsWith('BC-') == true ? 1 : null,
          ),
        ),
      );
      return;
    }
    if (type.contains('document') || type.contains('service')) {
      await Navigator.of(context).pushNamed('/documents');
      return;
    }
    if (type.contains('helpdesk')) {
      await Navigator.of(context).pushNamed('/helpdesk');
      return;
    }
    if (type.startsWith('account_') && type != 'account_approval_requested') {
      if (openedFromPushedPage) Navigator.of(context).pop();
      _selectPage(4);
      return;
    }
  }

  void _navigateToUpdatesPost(String? postId) {
    setState(() {
      _selectedHomeCategory = _BulletinCategory.all;
      _updatesSearchQuery = '';
      _targetUpdatesPostId = postId;
    });

    _selectPage(1);

    if (postId != null && postId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToUpdatesPost(postId);
      });
    }
  }

  void _scrollToUpdatesPost(String postId) {
    Future.delayed(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      final targetKey = _updatesPostKeys[postId];
      final targetContext = targetKey?.currentContext;
      if (targetContext != null && targetContext.mounted) {
        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOutCubic,
          alignment: 0.18,
        );
      }
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _targetUpdatesPostId == postId) {
          setState(() {
            _targetUpdatesPostId = null;
          });
        }
      });
    });
  }

  Widget _buildServicesPage(User user) {
    final horizontalPadding = responsiveHomeHorizontalPadding(
      MediaQuery.sizeOf(context).width,
    );
    final navigationReservedHeight =
        authenticatedBottomNavigationReservedHeight(context);

    return Container(
      color: context.colors.background,
      child: ESugidPullToRefresh(
        onRefresh: () => _refreshServicesPage(user),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          slivers: [
            // Pinned Collapsible Header
            ESugidSliverPageHeader(
              pinned: true,
              bodyColor: context.colors.background,
              sectionLabelWidget: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 3.5,
                ),
                decoration: BoxDecoration(
                  color: context.colors.brandStrong.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: context.colors.border.withValues(alpha: 0.75),
                    width: 1.1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: context.colors.shadow.withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 1.5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.colors.warningSolid,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'BARILI SERVICES',
                      style: GoogleFonts.outfit(
                        color: context.colors.onBrandMuted,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              title: 'Barili Services',
              trailing: TactileSpringButton(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const CarabaoGamePage(),
                  ),
                ),
                scale: 0.92,
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        context.colors.brand,
                        context.colors.brand,
                        context.colors.brand,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: context.colors.border.withValues(alpha: 0.65),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: context.colors.brandStrong.withValues(alpha: 0.55,
                        ),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: context.colors.shadow.withValues(alpha: 0.22),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                      BoxShadow(
                        color: context.colors.highlight.withValues(alpha: 0.35),
                        offset: const Offset(0, -1),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.sports_esports_rounded,
                        size: 20,
                        color: context.colors.onAccent,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'PLAY',
                        style: GoogleFonts.outfit(
                          color: context.colors.onAccent,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              iconWidget: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      context.colors.warningSolid,
                      context.colors.warningSolid,
                      context.colors.brand,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: context.colors.shadow.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2.5),
                    ),
                  ],
                ),
                child: Container(
                  margin: const EdgeInsets.all(1.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        context.colors.brand,
                        context.colors.brandStrong,
                      ],
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.grid_view_rounded,
                      color: context.colors.onBrandMuted,
                      size: 19,
                    ),
                  ),
                ),
              ),
            ),

            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                14,
                horizontalPadding,
                navigationReservedHeight + 32,
              ),
              sliver: SliverToBoxAdapter(
                child: ServicesDirectory(
                  onBayanihan: () {
                    if (!_ensureInteractiveAccess(user)) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(builder: (_) => JobsPage()),
                    );
                  },
                  onMarket: () {
                    if (!_ensureInteractiveAccess(user)) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(builder: (_) => const MarketplacePage()),
                    );
                  },
                  onEmergency: () => _openAlertsModal(user),
                  onOfficials: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const OfficialsPage()),
                  ),
                  onMap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const ResidentMapPage()),
                  ),
                  onCalendar: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => CalendarPage(user: user)),
                  ),
                  onWeather: () => _openWeatherPage(),
                  onOrganizations: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const DiscoverPrivateOrganizationsPage()),
                  ),
                  onExplore: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const ExploreBariliPage()),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader(String title, {bool showBackButton = false}) {
    final (subtitle, icon) = switch (title) {
      'My Posts' => ('Manage your community updates.', Icons.article_outlined),
      _ => (null, null),
    };
    return ESugidPageHeader(
      sectionLabel: 'Updates',
      title: title,
      subtitle: subtitle,
      icon: icon,
      showBackButton: showBackButton,
    );
  }

  Widget _buildAlertCard(CommunityAlert alert, {required bool showResolved}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = showResolved
        ? context
              .colors
              .textSecondary // Sophisticated slate
        : alert.isCritical
        ? context
              .colors
              .error // Vivid danger
        : context.colors.warning; // Amber warning
    final location = alert.visibility.toLowerCase() == 'public'
        ? 'All Barili'
        : alert.targetBarangays.length > 1
        ? '${alert.targetBarangays.length} barangays'
        : alert.targetBarangay;
    final endLabel = alert.expiresAt == null
        ? null
        : '${showResolved ? 'Ended' : 'Until'} ${DateFormat('MMM d • h:mm a').format(alert.expiresAt!)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAlertDetails(alert),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [context.colors.surface, context.colors.surface],
              ),
              border: Border.all(
                color: isDark
                    ? context.colors.primaryGreen
                    : context.colors.border,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (context.colors.brandStrong)
                      .withValues(alpha: isDark ? 0.35 : 0.04,
                  ),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: (context.colors.brandStrong)
                      .withValues(alpha: isDark ? 0.38 : 0.07,
                  ),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                  spreadRadius: -1,
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 3D Spherical Icon Orb
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: showResolved
                          ? [
                              context.colors.infoSolid,
                              context.colors.infoSolid,
                              context.colors.infoSolid,
                            ]
                          : alert.isCritical
                          ? [
                              context.colors.errorSolid,
                              context.colors.errorSolid,
                              context.colors.errorSolid,
                            ]
                          : [
                              context.colors.warningSolid,
                              context.colors.warningSolid,
                              context.colors.warningSolid,
                            ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            (showResolved
                                    ? context.colors.infoSolid
                                    : alert.isCritical
                                    ? context.colors.highlight
                                    : context.colors.highlight)
                                .withValues(alpha: 0.35),
                        blurRadius: 9,
                        offset: const Offset(0, 3),
                      ),
                      BoxShadow(
                        color: context.colors.highlight.withValues(alpha: 0.25),
                        blurRadius: 2,
                        offset: const Offset(-1, -1),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      showResolved
                          ? Icons.history_toggle_off_rounded
                          : alert.isCritical
                          ? Icons.warning_rounded
                          : Icons.campaign_rounded,
                      color: context.colors.onAccent,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Badge Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: showResolved
                                  ? (context.colors.infoSurface)
                                  : alert.isCritical
                                  ? (context.colors.errorSurface)
                                  : (isDark
                                        ? context.colors.warningSolid
                                        : context.colors.warningSurface),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              showResolved
                                  ? 'PAST ADVISORY'
                                  : alert.severity.toUpperCase(),
                              style: GoogleFonts.outfit(
                                color: accentColor,
                                fontSize: 10,
                                letterSpacing: 0.7,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              alert.alertType,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                color: context.colors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        alert.title,
                        style: GoogleFonts.outfit(
                          color: context.colors.textPrimary,
                          fontSize: 16,
                          height: 1.25,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        alert.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: context.colors.textSecondary,
                          fontSize: 12.5,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // 3D Metadata Badges
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _alertMetaPill(
                            icon: Icons.location_on_rounded,
                            label: location,
                            isDark: isDark,
                            color: context.colors.brand,
                          ),
                          if (endLabel != null)
                            _alertMetaPill(
                              icon: Icons.schedule_rounded,
                              label: endLabel,
                              isDark: isDark,
                              color: context.colors.infoSolid,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 3D Action Disc
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        context.colors.surfaceAlt,
                        context.colors.surfaceAlt,
                      ],
                    ),
                    border: Border.all(
                      color: context.colors.border,
                      width: 1),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: context.colors.primaryGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _alertMetaPill({
    required IconData icon,
    required String label,
    required bool isDark,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: context.colors.border,
          width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.5, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.outfit(
              color: context.colors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAlertDetails(CommunityAlert alert) {
    final location = alert.visibility.toLowerCase() == 'public'
        ? 'All Barili'
        : alert.targetBarangays.isNotEmpty
        ? alert.targetBarangays.join(', ')
        : alert.targetBarangay;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.86,
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          color: sheetContext.colors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: sheetContext.colors.errorSurface,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '${alert.severity.toUpperCase()} • ${alert.alertType}',
                style: GoogleFonts.poppins(
                  color: sheetContext.colors.error,
                  fontSize: 12,
                  letterSpacing: 0.7,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                alert.title,
                style: GoogleFonts.poppins(
                  color: sheetContext.colors.textPrimary,
                  fontSize: 22,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                alert.message,
                style: GoogleFonts.poppins(
                  color: sheetContext.colors.textPrimary,
                  fontSize: 14,
                  height: 1.55,
                ),
              ),
              if (alert.instructions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: sheetContext.colors.errorSurface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'What you should do',
                        style: GoogleFonts.poppins(
                          color: sheetContext.colors.error,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        alert.instructions,
                        style: GoogleFonts.poppins(
                          color: sheetContext.colors.error,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _buildEmergencyDetailRow(Icons.location_on_outlined, location),
              const SizedBox(height: 8),
              _buildEmergencyDetailRow(
                Icons.account_balance_outlined,
                alert.sourceName,
              ),
              if (alert.expiresAt != null) ...[
                const SizedBox(height: 8),
                _buildEmergencyDetailRow(
                  Icons.schedule_rounded,
                  'Valid until ${DateFormat('MMM d, y • h:mm a').format(alert.expiresAt!)}',
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('I Understand'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handlePrimaryAction(User user) {
    final bool canPost =
        (user.role == UserRole.partner || user.role == UserRole.barangay)
        ? user.canPublishAnnouncements
        : true;
    if (user.role == UserRole.resident) {
      if (_ensureInteractiveAccess(user)) _selectPage(2);
    } else if (canPost) {
      _showPostModal();
    } else {
      ScaffoldMessenger.of(context).showAppSnackBar(
        AppSnackBar(content: Text('Account approval is required.'),
          kind: FeedbackKind.warning,
        ),
      );
    }
  }
}

typedef _HomeHeaderBuilder =
    Widget Function(BuildContext context, double collapseProgress);

class _CollapsingHomeHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final _HomeHeaderBuilder builder;

  const _CollapsingHomeHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.builder,
  }) : assert(minHeight <= maxHeight);

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final collapseRange = maxExtent - minExtent;
    final progress = collapseRange == 0
        ? 1.0
        : (shrinkOffset / collapseRange).clamp(0.0, 1.0);
    return SizedBox.expand(child: builder(context, progress));
  }

  @override
  bool shouldRebuild(covariant _CollapsingHomeHeaderDelegate oldDelegate) {
    return oldDelegate.minHeight != minHeight ||
        oldDelegate.maxHeight != maxHeight ||
        oldDelegate.builder != builder;
  }
}

class _EmergencyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  const _EmergencyTabBarDelegate({required this.child, required this.height});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(covariant _EmergencyTabBarDelegate oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}

class _KeepAliveTab extends StatefulWidget {
  final Widget child;
  const _KeepAliveTab({required this.child});

  @override
  State<_KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<_KeepAliveTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _CommunityBulletinArchivePage extends StatefulWidget {
  final User user;
  final List<CommunityPost> initialPosts; // Direct data injection
  final _BulletinView initialView;
  final _BulletinCategory initialCategory;
  final String? targetPostId;
  final String? targetTitle;

  const _CommunityBulletinArchivePage({
    required this.user,
    required this.initialPosts,
    this.initialView = _BulletinView.all,
    this.initialCategory = _BulletinCategory.all,
    this.targetPostId,
    this.targetTitle,
  });

  @override
  State<_CommunityBulletinArchivePage> createState() =>
      _CommunityBulletinArchivePageState();
}

class _CommunityBulletinArchivePageState
    extends State<_CommunityBulletinArchivePage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<int> _priorityTick = ValueNotifier<int>(0);
  Timer? _priorityRefreshTimer;
  Timer? _searchDebounce;
  String _query = '';
  late _BulletinCategory _selectedCategory;
  late _BulletinView _selectedView;
  final SavedAnnouncementService _savedService =
      SavedAnnouncementService.instance;
  bool _savedSyncing = false;
  bool _showOfflineSavedBanner = false;
  CommunityPost? _injectedPost;
  bool _didAutoScroll = false;

  @override
  void initState() {
    super.initState();
    _selectedView = widget.initialView;
    _selectedCategory = widget.initialCategory;
    if (widget.targetPostId != null &&
        widget.targetPostId!.isNotEmpty &&
        !widget.initialPosts.any((p) => p.id == widget.targetPostId)) {
      CommunityService.fetchPostById(widget.targetPostId!).then((fetched) {
        if (fetched != null && mounted) {
          setState(() => _injectedPost = fetched);
        }
      });
    }
    _priorityRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _priorityTick.value++;
      if (_selectedView == _BulletinView.saved && _showOfflineSavedBanner) {
        unawaited(_syncSaved());
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncSaved());
  }

  @override
  void dispose() {
    _priorityRefreshTimer?.cancel();
    _searchDebounce?.cancel();
    _priorityTick.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleSearch(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 180), () {
      if (mounted && value != _query) setState(() => _query = value);
    });
  }

  bool _matchesQuery(CommunityPost post) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    final searchableText = [
      post.title,
      post.content,
      post.authorName,
      post.authorOrganizationName,
      post.authorBarangay,
      post.targetBarangay,
      post.targetBarangays.join(' '),
      post.tag,
      post.displayCategory,
      post.location,
    ].join(' ').toLowerCase();
    return searchableText.contains(query);
  }

  bool _matchesCategory(CommunityPost post) {
    return _matchesBulletinCategory(post, _selectedCategory);
  }

  String _categoryLabel(_BulletinCategory category) {
    switch (category) {
      case _BulletinCategory.all:
        return 'All';
      case _BulletinCategory.notices:
        return 'Notices';
      case _BulletinCategory.advisory:
        return 'Advisories';
      case _BulletinCategory.events:
        return 'Events';
    }
  }

  IconData _categoryIcon(_BulletinCategory category) {
    switch (category) {
      case _BulletinCategory.all:
        return Icons.grid_view_rounded;
      case _BulletinCategory.notices:
        return Icons.campaign_rounded;
      case _BulletinCategory.advisory:
        return Icons.warning_amber_rounded;
      case _BulletinCategory.events:
        return Icons.event_available_rounded;
    }
  }

  Widget _buildBulletinFilters(bool isDark) {
    final categories = _BulletinCategory.values;
    return Container(
      width: double.infinity,
      color: context.colors.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: SizedBox(
        height: 42,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          itemCount: categories.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final cat = categories[index];
            final selected = _selectedCategory == cat;

            return ESugidPressable(
                semanticLabel:
                  '${_categoryLabel(cat)} announcements${selected ? ', selected' : ''}',
              onTap: () => setState(() => _selectedCategory = cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  gradient: selected
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [context.colors.brand, context.colors.brand],
                        )
                      : LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            context.colors.surface,
                            context.colors.surface,
                          ],
                        ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? context.colors.border.withValues(alpha: 0.45)
                        : (isDark
                            ? context.colors.primaryGreen
                              : context.colors.border.withValues(alpha: 0.8)),
                    width: 1.2,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: context.colors.brandStrong.withValues(alpha: 0.38,
                            ),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                          BoxShadow(
                            color: context.colors.highlight.withValues(alpha: 0.35,
                            ),
                            offset: const Offset(0, -1.2),
                            blurRadius: 0,
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: isDark
                                ? context.colors.shadow.withValues(alpha: 0.25)
                                : context.colors.shadow.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: selected
                            ? context.colors.surface.withValues(alpha: 0.20)
                            : (isDark
                                ? context.colors.brandStrong
                                  : context.colors.brand.withValues(
                                    alpha: 0.09,
                                  )),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          _categoryIcon(cat),
                          size: 13,
                          color: selected
                              ? context.colors.onAccent
                              : (context.colors.primaryGreen),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _categoryLabel(cat),
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: selected
                            ? context.colors.onAccent
                            : (isDark
                                ? context.colors.textSecondary
                                  : context.colors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildViewSelector(bool isDark) {
    return Container(
      color: context.colors.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: context.colors.surfaceAlt,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: _BulletinView.values.map((view) {
            final selected = _selectedView == view;
            final saved = view == _BulletinView.saved;
            return Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  if (view == _selectedView) return;
                  setState(() {
                    _selectedView = view;
                    _selectedCategory = _BulletinCategory.all;
                  });
                  if (saved) _syncSaved();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  height: 42,
                  decoration: BoxDecoration(
                    color: selected
                        ? context.colors.brand : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: context.colors.brandStrong.withValues(alpha: 0.22,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        saved ? Icons.bookmark_rounded : Icons.campaign_rounded,
                        size: 18,
                        color: selected
                            ? context.colors.onAccent
                            : context.colors.textPrimary,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        saved ? 'Saved' : 'All',
                        style: GoogleFonts.outfit(
                          color: selected
                              ? context.colors.onAccent
                              : context.colors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _syncSaved() async {
    if (_savedSyncing || !mounted) return;
    setState(() => _savedSyncing = true);
    final result = await _savedService.sync(widget.user.uid);
    if (!mounted) return;
    setState(() {
      _savedSyncing = false;
      _showOfflineSavedBanner = result.isOffline;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBackground = context.colors.background;
    final titleColor = context.colors.textPrimary;

    return Scaffold(
      backgroundColor: pageBackground,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [context.colors.brandStrong, context.colors.brand],
              ),
              borderRadius: esugidHeaderBorderRadius,
            ),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    MediaQuery.paddingOf(context).top + 12,
                    16,
                    20,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton.filledTonal(
                            tooltip: 'Back',
                            onPressed: () => Navigator.pop(context),
                            style: IconButton.styleFrom(
                              backgroundColor: context.colors.surface
                                  .withValues(
                                alpha: 0.13),
                              foregroundColor: context.colors.onAccent,
                            ),
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Community Bulletin',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    color: context.colors.onAccent,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.25,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.public_rounded,
                                      size: 13,
                                      color: context.colors.onAccent,
                                    ),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        'Public announcements for everyone in Barili',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.outfit(
                                          color: context.colors.onAccent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: _searchController,
                        onChanged: _scheduleSearch,
                        textInputAction: TextInputAction.search,
                        style: GoogleFonts.outfit(
                          color: context.colors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search CEBECO, title, or barangay',
                          hintStyle: GoogleFonts.outfit(
                            color: context.colors.textSecondary,
                            fontSize: 13,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: context.colors.textSecondary,
                          ),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _query = '');
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                ),
                          filled: true,
                          fillColor: context.colors.inputBackground,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: context.colors.border,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ESugidBodyCrown(color: pageBackground),
              ],
            ),
          ),
          _buildViewSelector(isDark),
          _buildBulletinFilters(isDark),
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: context.colors.border),
                boxShadow: [
                  BoxShadow(
                    color: context.colors.shadow.withValues(alpha: isDark ? 0.18 : 0.06,
                    ),
                    blurRadius: 18,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Column(
                children: [
                  if (_selectedView == _BulletinView.saved &&
                      (_showOfflineSavedBanner || _savedSyncing))
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      color: _showOfflineSavedBanner
                          ? context.colors.warningSurface
                          : context.colors.surfaceAlt,
                      child: Row(
                        children: [
                          if (_savedSyncing)
                            const SizedBox.square(
                              dimension: 15,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            Icon(
                              Icons.cloud_off_rounded,
                              size: 17,
                              color: context.colors.warning,
                            ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _savedSyncing
                                  ? 'Checking for announcement updates...'
                                  : "You're offline. Showing saved announcements.",
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: context.colors.textSecondary,
                              ),
                            ),
                          ),
                          if (_showOfflineSavedBanner)
                            IconButton(
                              tooltip: 'Try syncing again',
                              visualDensity: VisualDensity.compact,
                              onPressed: _syncSaved,
                              icon: const Icon(Icons.refresh_rounded, size: 19),
                            ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: ValueListenableBuilder<int>(
                      valueListenable: _priorityTick,
                      builder: (context, _, _) => StreamBuilder<List<CommunityPost>>(
                        key: ValueKey(_selectedView),
                        stream: _selectedView == _BulletinView.saved
                            ? _savedService
                                  .watchOffline(widget.user.uid)
                                  .map(
                                    (records) => records
                                        .map((record) => record.toPost())
                                        .toList(growable: false),
                                  )
                            : CommunityService.approvedPostsForUser(
                                widget.user,
                              ),
                        initialData: _selectedView == _BulletinView.saved
                            ? const <CommunityPost>[]
                            : widget.initialPosts,
                        builder: (context, snapshot) {
                          // No more blank loading screen if we have initial data!
                          final rawPosts =
                              snapshot.data ?? const <CommunityPost>[];
                          final allPosts = <CommunityPost>[
                            if (_injectedPost != null &&
                                !rawPosts.any((p) => p.id == _injectedPost!.id))
                              _injectedPost!,
                            // Saved posts stay; the full list follows the
                            // same follow rules as Home and Updates.
                            ...(_selectedView == _BulletinView.saved
                                ? rawPosts
                                : PrivateOrganizationService.instance
                                      .visiblePosts(rawPosts)),
                          ];
                          final posts =
                              CommunityService.sortPostsForFeed(
                                    allPosts,
                                    includeExpired:
                                        _selectedView == _BulletinView.saved,
                                  )
                                  .where(_matchesCategory)
                                  .where(_matchesQuery)
                                  .toList();

                          if (!_didAutoScroll &&
                              (widget.targetPostId != null ||
                                  widget.targetTitle != null)) {
                            final targetIndex = posts.indexWhere(
                              (p) =>
                                  (widget.targetPostId != null &&
                                      p.id == widget.targetPostId) ||
                                  (widget.targetTitle != null &&
                                      widget.targetTitle!.trim().isNotEmpty &&
                                      (p.title.trim().toLowerCase() ==
                                              widget.targetTitle!
                                                  .trim()
                                                  .toLowerCase() ||
                                          p.title.trim().toLowerCase().contains(
                                            widget.targetTitle!
                                                .trim()
                                                .toLowerCase(),
                                          ))),
                            );
                            if (targetIndex >= 0) {
                              _didAutoScroll = true;
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (_scrollController.hasClients) {
                                  final targetOffset = (targetIndex * 260.0)
                                      .clamp(
                                        0.0,
                                        _scrollController
                                            .position
                                            .maxScrollExtent,
                                      );
                                  _scrollController.animateTo(
                                    targetOffset,
                                    duration: const Duration(milliseconds: 650),
                                    curve: Curves.easeOutCubic,
                                  );
                                }
                              });
                            }
                          }
                          if (posts.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(28),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 66,
                                      height: 66,
                                      decoration: BoxDecoration(
                                        color: context.colors.brand.withValues(alpha: 0.09,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.search_off_rounded,
                                        color: context.colors.primaryGreen,
                                        size: 31,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      _query.isEmpty &&
                                              _selectedCategory ==
                                                  _BulletinCategory.all
                                          ? _selectedView == _BulletinView.saved
                                                ? 'No saved announcements yet'
                                                : 'No announcements yet'
                                          : 'No matching posts',
                                      style: GoogleFonts.outfit(
                                        color: titleColor,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (_query.isNotEmpty ||
                                        _selectedCategory !=
                                            _BulletinCategory.all) ...[
                                      const SizedBox(height: 5),
                                      Text(
                                        _selectedView == _BulletinView.saved
                                            ? 'Saved announcements can be read here even without internet.'
                                            : 'Try changing your search or filters.',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.outfit(
                                          color: context.colors.textSecondary,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      TextButton.icon(
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {
                                            _query = '';
                                            _selectedCategory =
                                                _BulletinCategory.all;
                                          });
                                        },
                                        icon: const Icon(Icons.refresh_rounded),
                                        label: const Text('Reset filters'),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }

                          return ESugidAnimatedSwap(
                            child: ListView.builder(
                              controller: _scrollController,
                              key: ValueKey(
                                '${_selectedCategory.name}-$_query',
                              ),
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              physics: const ClampingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                20,
                                16,
                                42,
                              ),
                              itemCount: posts.length,
                              itemBuilder: (_, index) {
                                final post = posts[index];
                                final isHighlighted =
                                    (widget.targetPostId != null &&
                                        post.id == widget.targetPostId) ||
                                    (widget.targetTitle != null &&
                                        widget.targetTitle!.trim().isNotEmpty &&
                                        (post.title.trim().toLowerCase() ==
                                                widget.targetTitle!
                                                    .trim()
                                                    .toLowerCase() ||
                                            post.title
                                                .trim()
                                                .toLowerCase()
                                                .contains(
                                                  widget.targetTitle!
                                                      .trim()
                                                      .toLowerCase(),
                                                )));
                                return ModernPostCard(
                                  key: ValueKey('bulletin-post-${post.id}'),
                                  post: post,
                                  showStatus:
                                      _selectedView == _BulletinView.saved,
                                  heroScope:
                                      _selectedView == _BulletinView.saved
                                      ? 'saved'
                                      : 'archive',
                                  animateEntrance: index < 4,
                                  isHighlighted: isHighlighted,
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PinnedUrgentAnnouncementsCarousel extends StatefulWidget {
  final List<CommunityPost> posts;
  final Set<String> viewedPostIds;
  final bool isDark;
  final VoidCallback onViewAll;
  final ValueChanged<CommunityPost> onTapPost;

  const _PinnedUrgentAnnouncementsCarousel({
    required this.posts,
    this.viewedPostIds = const <String>{},
    required this.isDark,
    required this.onViewAll,
    required this.onTapPost,
  });

  @override
  State<_PinnedUrgentAnnouncementsCarousel> createState() =>
      _PinnedUrgentAnnouncementsCarouselState();
}

class _PinnedUrgentAnnouncementsCarouselState
    extends State<_PinnedUrgentAnnouncementsCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: widget.posts.length > 1 ? 0.94 : 1.0,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final posts = widget.posts;
    final unviewedCount = posts
        .where((p) => !widget.viewedPostIds.contains(p.id))
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // Pulsing Live Dot
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.colors.errorSolid,
                      boxShadow: [
                        BoxShadow(
                          color: context.colors.highlight.withValues(alpha: 0.8,
                          ),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'URGENT ANNOUNCEMENTS',
                    style: GoogleFonts.outfit(
                      color: context.colors.textPrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    ),
                  ),
                  if (unviewedCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.errorSolid.withValues(alpha: 0.15,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$unviewedCount',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: context.colors.error,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              InkWell(
                onTap: widget.onViewAll,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View All',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: context.colors.error,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 13,
                        color: context.colors.error,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Body: Single card or PageView
        if (posts.length == 1)
          _PinnedCardContent(
            post: posts.first,
            isDark: isDark,
            onTap: () => widget.onTapPost(posts.first),
          )
        else ...[
          SizedBox(
            height: 184,
            child: PageView.builder(
              clipBehavior: Clip.none,
              controller: _pageController,
              physics: const PageScrollPhysics(parent: BouncingScrollPhysics()),
              itemCount: posts.length,
              onPageChanged: (index) {
                if (mounted) setState(() => _currentPage = index);
              },
              itemBuilder: (context, index) {
                final post = posts[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _PinnedCardContent(
                    post: post,
                    isDark: isDark,
                    onTap: () => widget.onTapPost(post),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Page indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(posts.length, (idx) {
              final isSelected = idx == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isSelected ? 18 : 6,
                height: 5,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  color: isSelected
                      ? context.colors.errorSolid
                      : (context.colors.errorSolid.withValues(alpha: 0.2)),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _PinnedCardContent extends StatelessWidget {
  final CommunityPost post;
  final bool isDark;
  final VoidCallback onTap;

  const _PinnedCardContent({
    required this.post,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final expiry = post.priorityExpiresAt ?? post.expiresAt;
    final authorDisplayName = post.displayPublisher.isNotEmpty
        ? post.displayPublisher
        : (post.authorName.isNotEmpty &&
                  post.authorName.toLowerCase() != 'anajean'
              ? post.authorName
              : 'LGU IT DEPARTMENT');
    final isOfficial =
        post.tag.toUpperCase() == 'OFFICIAL' ||
        post.authorRole.toLowerCase() == 'lgu' ||
        post.authorRole.toLowerCase() == 'super_admin' ||
        post.authorRole.toLowerCase() == 'admin' ||
        post.authorRole.toLowerCase() == 'barangay' ||
        post.authorRole.toLowerCase().startsWith('barangay_') ||
        post.authorRole.toLowerCase() == 'mayor';

    final authorInitial =
        (authorDisplayName.isNotEmpty
                ? authorDisplayName.trim().substring(0, 1)
                : 'L')
            .toUpperCase();

    return ESugidPressable(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.colors.errorSolid,
              context.colors.errorSolid,
              context.colors.errorSolid,
            ],
          ),
          border: Border.all(
            color: context.colors.error.withValues(alpha: 0.55),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: context.colors.shadow.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
            BoxShadow(
              color: context.colors.errorSolid.withValues(alpha: 0.22),
              blurRadius: 18,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(21),
          child: Stack(
            children: [
              // Top specular rim light
              Positioned(
                top: 0,
                left: 20,
                right: 20,
                height: 1.5,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        context.colors.errorSurface.withValues(alpha: 0.4),
                        context.colors.surface.withValues(alpha: 0.5),
                        context.colors.errorSurface.withValues(alpha: 0.4),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Row: Author Profile with Badge (left) & Expiry countdown (right)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Author medallion avatar
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      context.colors.errorSolid,
                                      context.colors.errorSolid,
                                    ],
                                  ),
                                  border: Border.all(
                                    color: context.colors.error.withValues(alpha: 0.8,
                                    ),
                                    width: 1.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: context.colors.errorSolid
                                          .withValues(alpha: 0.35),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: PublisherAvatar.isBarangayPublisher(post)
                                      ? PublisherAvatar(
                                          post: post,
                                          size: 20,
                                          showVerifiedBadge: false,
                                        )
                                      : isOfficial
                                      ? Icon(
                                          Icons.account_balance_rounded,
                                          size: 13,
                                          color: context.colors.onAccent,
                                        )
                                      : Text(
                                          authorInitial,
                                          style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                            color: context.colors.onAccent,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 7),
                              // Author Name
                              Flexible(
                                child: Text(
                                  authorDisplayName,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: context.colors.onAccent,
                                    letterSpacing: 0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              // Verified badge
                              Icon(
                                Icons.verified_rounded,
                                size: 13,
                                color: context.colors.onBrandMuted,
                              ),
                            ],
                          ),
                        ),

                        // Expiry timer tag
                        if (expiry != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: context.colors.shadow.withValues(alpha: 0.25,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: context.colors.error.withValues(alpha: 0.3,
                                ),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 11,
                                  color: context.colors.error,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatExpiryCountdown(expiry),
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: context.colors.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 8),

                    // "IMPORTANT UPDATE" pill badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.errorSolid.withValues(alpha: 0.75,
                        ),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: context.colors.border.withValues(alpha: 0.8),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.push_pin_rounded,
                            size: 11,
                            color: context.colors.warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'IMPORTANT UPDATE',
                            style: GoogleFonts.outfit(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: context.colors.warning,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 7),

                    // Title
                    Text(
                      post.title.isNotEmpty
                          ? post.title
                          : 'Urgent Announcement',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: context.colors.onAccent,
                        letterSpacing: -0.2,
                        height: 1.25,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    if (post.content.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        post.content,
                        style: GoogleFonts.outfit(
                          fontSize: 12.5,
                          color: context.colors.onAccent,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: 8),

                    // Clickability note ("Tap to view details") matching other cards
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.touch_app_outlined,
                            size: 13,
                            color: context.colors.onAccent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Tap to view details',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: context.colors.onAccent,
                              letterSpacing: 0.1,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 11,
                            color: context.colors.onAccent,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatExpiryCountdown(DateTime expiry) {
  final now = DateTime.now();
  final difference = expiry.difference(now);
  if (difference.isNegative) return 'Expired';
  if (difference.inDays > 0) {
    return 'Ends in ${difference.inDays}d';
  } else if (difference.inHours > 0) {
    return 'Ends in ${difference.inHours}h';
  } else if (difference.inMinutes > 0) {
    return 'Ends in ${difference.inMinutes}m';
  } else {
    return 'Ending soon';
  }
}
