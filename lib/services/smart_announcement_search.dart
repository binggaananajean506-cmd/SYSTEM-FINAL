import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../community_service.dart';

/// Predefined time filter presets for community announcements search.
enum SmartTimePreset {
  anyTime,
  past24Hours,
  past7Days,
  past30Days,
  past6Months,
  pastYear;

  String get label {
    switch (this) {
      case SmartTimePreset.anyTime:
        return 'Any Time';
      case SmartTimePreset.past24Hours:
        return 'Past 24 Hours';
      case SmartTimePreset.past7Days:
        return 'Past 7 Days';
      case SmartTimePreset.past30Days:
        return 'Past 30 Days';
      case SmartTimePreset.past6Months:
        return 'Past 6 Months';
      case SmartTimePreset.pastYear:
        return 'Past Year';
    }
  }

  IconData get icon {
    switch (this) {
      case SmartTimePreset.anyTime:
        return Icons.all_inclusive_rounded;
      case SmartTimePreset.past24Hours:
        return Icons.access_time_filled_rounded;
      case SmartTimePreset.past7Days:
        return Icons.date_range_rounded;
      case SmartTimePreset.past30Days:
        return Icons.calendar_month_rounded;
      case SmartTimePreset.past6Months:
        return Icons.history_rounded;
      case SmartTimePreset.pastYear:
        return Icons.calendar_today_rounded;
    }
  }

  DateTimeRange? computeRange([DateTime? now]) {
    final current = now ?? DateTime.now();
    switch (this) {
      case SmartTimePreset.anyTime:
        return null;
      case SmartTimePreset.past24Hours:
        return DateTimeRange(
          start: current.subtract(const Duration(hours: 24)),
          end: current,
        );
      case SmartTimePreset.past7Days:
        return DateTimeRange(
          start: current.subtract(const Duration(days: 7)),
          end: current,
        );
      case SmartTimePreset.past30Days:
        return DateTimeRange(
          start: current.subtract(const Duration(days: 30)),
          end: current,
        );
      case SmartTimePreset.past6Months:
        return DateTimeRange(
          start: current.subtract(const Duration(days: 180)),
          end: current,
        );
      case SmartTimePreset.pastYear:
        return DateTimeRange(
          start: current.subtract(const Duration(days: 365)),
          end: current,
        );
    }
  }
}

/// Structured representation of a parsed smart search query.
class SmartSearchQuery {
  final String rawQuery;
  final String textQuery;
  final List<String> tokens;
  final DateTimeRange? dateRange;
  final String? detectedTimeLabel;
  final SmartTimePreset preset;

  const SmartSearchQuery({
    required this.rawQuery,
    required this.textQuery,
    required this.tokens,
    this.dateRange,
    this.detectedTimeLabel,
    this.preset = SmartTimePreset.anyTime,
  });

  bool get hasTimeFilter => dateRange != null;
  bool get hasTextFilter => tokens.isNotEmpty;
  bool get isEmpty => !hasTimeFilter && !hasTextFilter;

  String get displayFilterLabel {
    if (detectedTimeLabel != null) return detectedTimeLabel!;
    if (preset != SmartTimePreset.anyTime) return preset.label;
    return 'Any Time';
  }
}

/// Civic and municipal synonym dictionary for Barili community search.
class CivicSynonymDictionary {
  static final Map<String, List<String>> _synonyms = {
    'barangay': [
      'barangay',
      'brgy',
      'bgy',
    ],
    'brgy': [
      'brgy',
      'barangay',
      'bgy',
    ],
    'bgy': [
      'bgy',
      'barangay',
      'brgy',
    ],
    'ctu': [
      'ctu',
      'cebu technological university',
      'ctu-barili',
    ],
    'lgu': [
      'lgu',
      'municipal',
      'municipality',
      'local government',
      'mayor',
      'munisipyo',
    ],
    'sports': [
      'sports',
      'sport',
      'intramurals',
      'athletics',
      'tournament',
      'palaro',
    ],
    'intramurals': [
      'intramurals',
      'sports',
      'intrams',
      'athletics',
    ],
    'electric': [
      'electric',
      'electricity',
      'electrical',
      'power',
      'cebeco',
      'outage',
      'blackout',
      'brownout',
      'grid',
    ],
    'power': [
      'power',
      'electric',
      'electricity',
      'cebeco',
      'outage',
      'blackout',
      'brownout',
    ],
    'cebeco': [
      'cebeco',
      'electric',
      'electricity',
      'power',
      'outage',
      'brownout',
      'blackout',
    ],
    'water': [
      'water',
      'waterworks',
      'pipeline',
      'leak',
      'aqueduct',
      'supply',
      'potable',
    ],
    'interruption': [
      'interruption',
      'outage',
      'shutdown',
    ],
    'health': [
      'health',
      'medical',
      'vaccine',
      'vaccination',
      'clinic',
      'doctor',
      'checkup',
      'medicine',
      'rabies',
      'dengue',
      'dental',
      'rhu',
    ],
    'weather': [
      'weather',
      'storm',
      'typhoon',
      'flood',
      'rain',
      'advisory',
      'bagyo',
      'signal',
      'wind',
      'landslide',
      'heavy rain',
    ],
    'traffic': [
      'traffic',
      'road',
      'closure',
      'transport',
      'rerouting',
      'highway',
      'street',
      'repair',
      'construction',
    ],
    'clean': [
      'clean',
      'cleanup',
      'clean-up',
      'garbage',
      'waste',
      'drainage',
      'environment',
      'recycling',
    ],
    'meeting': [
      'meeting',
      'assembly',
      'session',
      'hearing',
      'consultation',
      'gathering',
      'pulong',
    ],
    'urgent': [
      'urgent',
      'emergency',
      'alert',
      'critical',
      'warning',
      'important',
      'immediate',
    ],
  };

  /// Returns synonyms for a given search token, or the token itself if no synonyms exist.
  static List<String> getSynonyms(String token) {
    final clean = token.toLowerCase().trim();
    if (_synonyms.containsKey(clean)) {
      return _synonyms[clean]!;
    }
    for (final entry in _synonyms.entries) {
      if (entry.value.contains(clean)) {
        return entry.value;
      }
    }
    return [clean];
  }
}

/// Intelligent search engine for announcements with natural language time parsing
/// and civic domain keyword matching.
class SmartAnnouncementSearch {
  static const List<String> _months = [
    'january',
    'february',
    'march',
    'april',
    'may',
    'june',
    'july',
    'august',
    'september',
    'october',
    'november',
    'december',
  ];

  /// Parses a raw user string into a structured [SmartSearchQuery].
  ///
  /// Extracts relative time phrases like:
  /// - "today", "yesterday"
  /// - "this week", "last week", "3 days ago", "weeks ago"
  /// - "this month", "last month", "2 months ago", "months ago"
  /// - "this year", "last year", "year ago", "2025"
  /// - "August", "September"
  static SmartSearchQuery parse(
    String input, {
    SmartTimePreset preset = SmartTimePreset.anyTime,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    var working = input.trim().toLowerCase();
    DateTimeRange? computedRange = preset.computeRange(now);
    String? detectedLabel = preset == SmartTimePreset.anyTime ? null : preset.label;

    if (working.isEmpty) {
      return SmartSearchQuery(
        rawQuery: input,
        textQuery: '',
        tokens: const [],
        dateRange: computedRange,
        detectedTimeLabel: detectedLabel,
        preset: preset,
      );
    }

    // 1. Check for "today" / "tonight"
    final todayRegex = RegExp(r'\b(today|tonight)\b');
    if (todayRegex.hasMatch(working)) {
      computedRange = DateTimeRange(
        start: DateTime(now.year, now.month, now.day),
        end: now,
      );
      detectedLabel = 'Today';
      working = working.replaceAll(todayRegex, '');
    }

    // 2. Check for "yesterday"
    final yesterdayRegex = RegExp(r'\b(yesterday)\b');
    if (yesterdayRegex.hasMatch(working)) {
      final yStart = DateTime(now.year, now.month, now.day - 1);
      final yEnd = DateTime(now.year, now.month, now.day, 0, 0, 0);
      computedRange = DateTimeRange(start: yStart, end: yEnd);
      detectedLabel = 'Yesterday';
      working = working.replaceAll(yesterdayRegex, '');
    }

    // 3. Check for "[N] days ago" or "days ago"
    final daysAgoRegex = RegExp(r'\b(?:(\d+)\s*)?days?\s*ago\b');
    final daysMatch = daysAgoRegex.firstMatch(working);
    if (daysMatch != null) {
      final count = int.tryParse(daysMatch.group(1) ?? '7') ?? 7;
      computedRange = DateTimeRange(
        start: now.subtract(Duration(days: count)),
        end: now,
      );
      detectedLabel = count == 1 ? '1 Day Ago' : 'Past $count Days';
      working = working.replaceAll(daysAgoRegex, '');
    }

    // 4. Check for "this week" / "last week" / "[N] weeks ago" / "weeks ago"
    final thisWeekRegex = RegExp(r'\bthis\s*week\b');
    if (thisWeekRegex.hasMatch(working)) {
      final daysFromMonday = now.weekday - 1;
      computedRange = DateTimeRange(
        start: DateTime(now.year, now.month, now.day - daysFromMonday),
        end: now,
      );
      detectedLabel = 'This Week';
      working = working.replaceAll(thisWeekRegex, '');
    }

    final lastWeekRegex = RegExp(r'\blast\s*week\b');
    if (lastWeekRegex.hasMatch(working)) {
      computedRange = DateTimeRange(
        start: now.subtract(const Duration(days: 14)),
        end: now.subtract(const Duration(days: 7)),
      );
      detectedLabel = 'Last Week';
      working = working.replaceAll(lastWeekRegex, '');
    }

    final weeksAgoRegex = RegExp(r'\b(?:(\d+)\s*)?weeks?\s*ago\b');
    final weeksMatch = weeksAgoRegex.firstMatch(working);
    if (weeksMatch != null) {
      final count = int.tryParse(weeksMatch.group(1) ?? '2') ?? 2;
      computedRange = DateTimeRange(
        start: now.subtract(Duration(days: count * 7)),
        end: now,
      );
      detectedLabel = 'Past $count Weeks';
      working = working.replaceAll(weeksAgoRegex, '');
    }

    // 5. Check for "this month" / "last month" / "[N] months ago" / "months ago"
    final thisMonthRegex = RegExp(r'\bthis\s*month\b');
    if (thisMonthRegex.hasMatch(working)) {
      computedRange = DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: now,
      );
      detectedLabel = 'This Month';
      working = working.replaceAll(thisMonthRegex, '');
    }

    final lastMonthRegex = RegExp(r'\blast\s*month\b');
    if (lastMonthRegex.hasMatch(working)) {
      final prevMonthYear = now.month == 1 ? now.year - 1 : now.year;
      final prevMonth = now.month == 1 ? 12 : now.month - 1;
      computedRange = DateTimeRange(
        start: DateTime(prevMonthYear, prevMonth, 1),
        end: DateTime(now.year, now.month, 1),
      );
      detectedLabel = 'Last Month';
      working = working.replaceAll(lastMonthRegex, '');
    }

    final monthsAgoRegex = RegExp(r'\b(?:(\d+)\s*)?months?\s*ago\b');
    final monthsMatch = monthsAgoRegex.firstMatch(working);
    if (monthsMatch != null) {
      final count = int.tryParse(monthsMatch.group(1) ?? '2') ?? 2;
      computedRange = DateTimeRange(
        start: now.subtract(Duration(days: count * 30)),
        end: now,
      );
      detectedLabel = 'Past $count Months';
      working = working.replaceAll(monthsAgoRegex, '');
    }

    // 6. Check for "this year" / "last year" / "[N] years ago" / "years ago"
    final thisYearRegex = RegExp(r'\bthis\s*year\b');
    if (thisYearRegex.hasMatch(working)) {
      computedRange = DateTimeRange(
        start: DateTime(now.year, 1, 1),
        end: now,
      );
      detectedLabel = 'This Year (${now.year})';
      working = working.replaceAll(thisYearRegex, '');
    }

    final lastYearRegex = RegExp(r'\blast\s*year\b');
    if (lastYearRegex.hasMatch(working)) {
      computedRange = DateTimeRange(
        start: DateTime(now.year - 1, 1, 1),
        end: DateTime(now.year, 1, 1),
      );
      detectedLabel = 'Last Year (${now.year - 1})';
      working = working.replaceAll(lastYearRegex, '');
    }

    final yearsAgoRegex = RegExp(r'\b(?:(\d+)\s*)?years?\s*ago\b');
    final yearsMatch = yearsAgoRegex.firstMatch(working);
    if (yearsMatch != null) {
      final count = int.tryParse(yearsMatch.group(1) ?? '1') ?? 1;
      computedRange = DateTimeRange(
        start: now.subtract(Duration(days: count * 365)),
        end: now,
      );
      detectedLabel = '$count Year(s) Ago';
      working = working.replaceAll(yearsAgoRegex, '');
    }

    // 7. Check for specific 4-digit years (e.g. 2024, 2025, 2026, 2027)
    final explicitYearRegex = RegExp(r'\b(20[2-3]\d)\b');
    final yearMatch = explicitYearRegex.firstMatch(working);
    if (yearMatch != null) {
      final y = int.parse(yearMatch.group(1)!);
      computedRange = DateTimeRange(
        start: DateTime(y, 1, 1),
        end: DateTime(y, 12, 31, 23, 59, 59),
      );
      detectedLabel = 'Year $y';
      working = working.replaceAll(explicitYearRegex, '');
    }

    // 8. Check for specific month names (e.g. "January", "August")
    for (int i = 0; i < _months.length; i++) {
      final mName = _months[i];
      final monthRegex = RegExp('\\b$mName\\b');
      if (monthRegex.hasMatch(working)) {
        final mNumber = i + 1;
        final targetYear = computedRange?.start.year ?? now.year;
        final nextMonthYear = mNumber == 12 ? targetYear + 1 : targetYear;
        final nextMonth = mNumber == 12 ? 1 : mNumber + 1;
        computedRange = DateTimeRange(
          start: DateTime(targetYear, mNumber, 1),
          end: DateTime(nextMonthYear, nextMonth, 1),
        );
        detectedLabel = '${mName[0].toUpperCase()}${mName.substring(1)} $targetYear';
        working = working.replaceAll(monthRegex, '');
        break;
      }
    }

    // Clean remaining tokens
    final cleaned = working
        .replaceAll(RegExp(r'[^a-z0-9\s\-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final tokens = cleaned
        .split(' ')
        .where((t) => t.trim().isNotEmpty)
        .toList();

    return SmartSearchQuery(
      rawQuery: input,
      textQuery: cleaned,
      tokens: tokens,
      dateRange: computedRange,
      detectedTimeLabel: detectedLabel,
      preset: preset,
    );
  }

  /// Filters a list of posts according to a [SmartSearchQuery].
  static List<CommunityPost> filterPosts(
    List<CommunityPost> posts,
    SmartSearchQuery query,
  ) {
    if (query.isEmpty) return posts;

    return posts.where((post) => matchesPost(post, query)).toList();
  }

  /// Tests whether an individual post satisfies the given [SmartSearchQuery].
  static bool matchesPost(CommunityPost post, SmartSearchQuery query) {
    // 1. Time Range Boundary Check
    if (query.dateRange != null) {
      final range = query.dateRange!;
      final createdAt = post.createdAt;
      final inCreatedRange = !createdAt.isBefore(range.start) &&
          !createdAt.isAfter(range.end);

      bool inEventRange = false;
      if (post.eventDate != null) {
        final eventDate = post.eventDate!;
        inEventRange = !eventDate.isBefore(range.start) &&
            !eventDate.isAfter(range.end);
      }

      if (!inCreatedRange && !inEventRange) {
        return false;
      }
    }

    // If only time filter was specified and no keywords, post is a match!
    if (query.tokens.isEmpty) {
      return true;
    }

    // 2. Build multi-field searchable corpus
    final dateFormats = [
      DateFormat('MMMM yyyy').format(post.createdAt),
      DateFormat('MMMM d, yyyy').format(post.createdAt),
      DateFormat('yyyy').format(post.createdAt),
      DateFormat('EEEE').format(post.createdAt),
    ].join(' ').toLowerCase();

    // Broadcast scopes such as 'All Barangays' and 'All Residents' are public distribution
    // scopes, NOT specific content topics. They must not cause unrelated posts (e.g. CTU)
    // to match a search for 'barangay' or 'residents'.
    final specificTargetBarangay =
        (post.targetBarangay.trim().toLowerCase() != 'all barangays' &&
         post.targetBarangay.trim().toLowerCase() != 'all')
            ? post.targetBarangay.trim()
            : '';

    final specificTargetBarangays = post.targetBarangays
        .where((b) =>
            b.trim().toLowerCase() != 'all barangays' &&
            b.trim().toLowerCase() != 'all' &&
            b.trim().isNotEmpty)
        .join(' ');

    final specificAuthorBarangay =
        (post.authorBarangay.trim().toLowerCase() != 'all barangays' &&
         post.authorBarangay.trim().toLowerCase() != 'all')
            ? post.authorBarangay.trim()
            : '';

    final specificTargetAudience =
        (post.targetAudience.trim().toLowerCase() != 'all residents' &&
         post.targetAudience.trim().toLowerCase() != 'all')
            ? post.targetAudience.trim()
            : '';

    // If published by a barangay official, expand role keywords with 'barangay', 'brgy', 'bgy'
    final isBarangayAuthor = post.authorRole.trim().toLowerCase() == 'barangay' ||
        post.authorRole.trim().toLowerCase().startsWith('barangay_');
    final roleKeywords = isBarangayAuthor ? 'barangay brgy bgy' : post.authorRole;

    final corpus = [
      post.title,
      post.content,
      post.authorName,
      post.displayPublisher,
      post.authorOrganizationName,
      post.publisherEntityName,
      roleKeywords,
      post.displayCategory,
      post.category,
      post.customCategory,
      post.tag,
      specificTargetBarangay,
      specificTargetBarangays,
      specificAuthorBarangay,
      specificTargetAudience,
      post.location,
      post.priority,
      post.announcementType,
      dateFormats,
    ].where((s) => s.trim().isNotEmpty).join(' ').toLowerCase();

    // 3. Multi-token match with Civic Synonym Expansion
    // Each search token must have at least one of its synonyms present in the corpus (AND of ORs).
    for (final token in query.tokens) {
      final synonyms = CivicSynonymDictionary.getSynonyms(token);
      final hasMatch = synonyms.any((synonym) => corpus.contains(synonym));
      if (!hasMatch) {
        return false;
      }
    }

    return true;
  }
}
