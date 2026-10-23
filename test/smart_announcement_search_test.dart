import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:esugid/community_service.dart';
import 'package:esugid/services/smart_announcement_search.dart';

void main() {
  group('SmartAnnouncementSearch - Natural Language Time Parsing', () {
    final fixedRef = DateTime(2026, 9, 17, 12, 0, 0);

    test('parses "yesterday" correctly and strips from text query', () {
      final query = SmartAnnouncementSearch.parse(
        'electric yesterday',
        referenceDate: fixedRef,
      );

      expect(query.hasTimeFilter, isTrue);
      expect(query.detectedTimeLabel, 'Yesterday');
      expect(query.tokens, ['electric']);
      expect(query.dateRange, isNotNull);
      expect(query.dateRange!.start.day, 16);
      expect(query.dateRange!.start.month, 9);
      expect(query.dateRange!.start.year, 2026);
    });

    test('parses "3 days ago" correctly', () {
      final query = SmartAnnouncementSearch.parse(
        'water 3 days ago',
        referenceDate: fixedRef,
      );

      expect(query.hasTimeFilter, isTrue);
      expect(query.detectedTimeLabel, 'Past 3 Days');
      expect(query.tokens, ['water']);
      expect(query.dateRange!.start.isBefore(fixedRef), isTrue);
    });

    test('parses "last week" correctly', () {
      final query = SmartAnnouncementSearch.parse(
        'meeting last week',
        referenceDate: fixedRef,
      );

      expect(query.hasTimeFilter, isTrue);
      expect(query.detectedTimeLabel, 'Last Week');
      expect(query.tokens, ['meeting']);
    });

    test('parses "2 months ago" and "months ago"', () {
      final query1 = SmartAnnouncementSearch.parse(
        'typhoon 2 months ago',
        referenceDate: fixedRef,
      );
      expect(query1.hasTimeFilter, isTrue);
      expect(query1.detectedTimeLabel, 'Past 2 Months');
      expect(query1.tokens, ['typhoon']);

      final query2 = SmartAnnouncementSearch.parse(
        'months ago',
        referenceDate: fixedRef,
      );
      expect(query2.hasTimeFilter, isTrue);
      expect(query2.detectedTimeLabel, 'Past 2 Months');
      expect(query2.tokens, isEmpty);
    });

    test('parses "last year" and explicit year "2025"', () {
      final query1 = SmartAnnouncementSearch.parse(
        'fiesta last year',
        referenceDate: fixedRef,
      );
      expect(query1.hasTimeFilter, isTrue);
      expect(query1.detectedTimeLabel, contains('Last Year'));
      expect(query1.tokens, ['fiesta']);

      final query2 = SmartAnnouncementSearch.parse(
        'scholarship 2025',
        referenceDate: fixedRef,
      );
      expect(query2.hasTimeFilter, isTrue);
      expect(query2.detectedTimeLabel, 'Year 2025');
      expect(query2.dateRange!.start.year, 2025);
      expect(query2.dateRange!.end.year, 2025);
      expect(query2.tokens, ['scholarship']);
    });

    test('parses specific month "August"', () {
      final query = SmartAnnouncementSearch.parse(
        'health August',
        referenceDate: fixedRef,
      );
      expect(query.hasTimeFilter, isTrue);
      expect(query.detectedTimeLabel, 'August 2026');
      expect(query.tokens, ['health']);
      expect(query.dateRange!.start.month, 8);
    });
  });

  group('CivicSynonymDictionary', () {
    test('expands "electric" to cebeco, power, outage, blackout', () {
      final synonyms = CivicSynonymDictionary.getSynonyms('electric');
      expect(synonyms, contains('cebeco'));
      expect(synonyms, contains('power'));
      expect(synonyms, contains('outage'));
      expect(synonyms, contains('grid'));
    });

    test('expands "water" to waterworks, pipeline, supply', () {
      final synonyms = CivicSynonymDictionary.getSynonyms('water');
      expect(synonyms, contains('waterworks'));
      expect(synonyms, contains('pipeline'));
      expect(synonyms, contains('supply'));
    });

    test('expands "health" to vaccine, medical, clinic, rabies, dengue', () {
      final synonyms = CivicSynonymDictionary.getSynonyms('health');
      expect(synonyms, contains('vaccine'));
      expect(synonyms, contains('medical'));
      expect(synonyms, contains('clinic'));
      expect(synonyms, contains('rabies'));
    });

    test('expands "weather" to typhoon, flood, bagyo, storm', () {
      final synonyms = CivicSynonymDictionary.getSynonyms('weather');
      expect(synonyms, contains('typhoon'));
      expect(synonyms, contains('flood'));
      expect(synonyms, contains('bagyo'));
    });
  });

  group('SmartAnnouncementSearch - Post Filtering', () {
    final fixedRef = DateTime(2026, 9, 17, 12, 0, 0);

    CommunityPost makePost({
      required String id,
      required String title,
      required String content,
      required DateTime createdAt,
      String authorName = 'Barili LGU',
      String targetBarangay = 'Poblacion',
    }) {
      return CommunityPost(
        id: id,
        title: title,
        content: content,
        authorId: 'auth-$id',
        authorName: authorName,
        authorRole: 'barangay',
        authorBarangay: 'Poblacion',
        authorOrganizationName: 'Barili LGU',
        targetAudience: 'All Residents',
        targetBarangay: targetBarangay,
        visibility: 'public',
        targetBarangays: const [],
        createdAt: createdAt,
        status: 'approved',
        tag: 'Advisory',
      );
    }

    final postElectric = makePost(
      id: 'p1',
      title: 'CEBECO III Advisory',
      content: 'Scheduled power outage in Barangay Poblacion for maintenance.',
      createdAt: DateTime(2026, 9, 16, 14, 0, 0), // 22 hours before fixedRef
    );

    final postWater = makePost(
      id: 'p2',
      title: 'Waterworks Pipeline Repair',
      content: 'Low pressure water supply expected across Barangay Japitan.',
      createdAt: DateTime(2026, 9, 13, 8, 0, 0), // 4 days ago
      targetBarangay: 'Japitan',
    );

    final postVaccine = makePost(
      id: 'p3',
      title: 'Free Anti-Rabies Vaccination',
      content: 'Rural Health Unit RHU medical mission bringing free dog shots.',
      createdAt: DateTime(2026, 8, 15, 9, 0, 0), // August 2026
    );

    final postOld2025 = makePost(
      id: 'p4',
      title: 'Annual Municipal Cultural Showcase',
      content: 'A celebration of heritage and folk dance in the town plaza.',
      createdAt: DateTime(2025, 11, 20, 14, 0, 0), // Year 2025
    );

    final allPosts = [postElectric, postWater, postVaccine, postOld2025];

    test('matches "electric" to CEBECO post via civic synonym', () {
      final query = SmartAnnouncementSearch.parse(
        'electric',
        referenceDate: fixedRef,
      );
      final results = SmartAnnouncementSearch.filterPosts(allPosts, query);

      expect(results.length, 1);
      expect(results.first.id, 'p1');
    });

    test('matches "yesterday electric" to yesterday\'s CEBECO post', () {
      final query = SmartAnnouncementSearch.parse(
        'electric yesterday',
        referenceDate: fixedRef,
      );
      final results = SmartAnnouncementSearch.filterPosts(allPosts, query);

      expect(results.length, 1);
      expect(results.first.id, 'p1');
    });

    test('matches "water" to waterworks post', () {
      final query = SmartAnnouncementSearch.parse(
        'water',
        referenceDate: fixedRef,
      );
      final results = SmartAnnouncementSearch.filterPosts(allPosts, query);

      expect(results.length, 1);
      expect(results.first.id, 'p2');
    });

    test('matches "health" to anti-rabies vaccine post via synonym', () {
      final query = SmartAnnouncementSearch.parse(
        'health',
        referenceDate: fixedRef,
      );
      final results = SmartAnnouncementSearch.filterPosts(allPosts, query);

      expect(results.length, 1);
      expect(results.first.id, 'p3');
    });

    test('matches "2025" to old 2025 post', () {
      final query = SmartAnnouncementSearch.parse(
        '2025',
        referenceDate: fixedRef,
      );
      final results = SmartAnnouncementSearch.filterPosts(allPosts, query);

      expect(results.length, 1);
      expect(results.first.id, 'p4');
    });

    test('preset past24Hours matches only yesterday electric post within 24h', () {
      final query = SmartAnnouncementSearch.parse(
        '',
        preset: SmartTimePreset.past24Hours,
        referenceDate: fixedRef,
      );
      final results = SmartAnnouncementSearch.filterPosts(allPosts, query);

      expect(results.map((p) => p.id), contains('p1'));
      expect(results.map((p) => p.id), isNot(contains('p2')));

      final query7Days = SmartAnnouncementSearch.parse(
        '',
        preset: SmartTimePreset.past7Days,
        referenceDate: fixedRef,
      );
      final results7Days = SmartAnnouncementSearch.filterPosts(allPosts, query7Days);

      expect(results7Days.map((p) => p.id), contains('p1'));
      expect(results7Days.map((p) => p.id), contains('p2'));
      expect(results7Days.map((p) => p.id), isNot(contains('p4')));
    });

    test('preset pastYear matches 2026 posts and excludes 2025 post older than 365d', () {
      final query = SmartAnnouncementSearch.parse(
        '',
        preset: SmartTimePreset.pastYear,
        referenceDate: fixedRef,
      );
      final results = SmartAnnouncementSearch.filterPosts(allPosts, query);

      expect(results.map((p) => p.id), contains('p1'));
      expect(results.map((p) => p.id), contains('p2'));
      expect(results.map((p) => p.id), contains('p3'));
      // p4 is Nov 20, 2025 which is ~300 days before Sep 17, 2026
      expect(results.map((p) => p.id), contains('p4'));
    });

    test('searching "barangay" matches Barangay Vito and excludes CTU with All Barangays scope', () {
      final postVito = makePost(
        id: 'vito_1',
        title: 'Sports Activity',
        content: 'Kabatan-onan sa Vito, lihok ug api! Maghiusa kita sa pagpalig-on sa lawas.',
        authorName: 'Barangay Vito',
        targetBarangay: 'All Barangays',
        createdAt: DateTime(2026, 9, 15),
      );

      final postCTU = CommunityPost(
        id: 'ctu_1',
        title: '🔥 FOUR UNITS. ONE FLAME. ONE SIKLAB.',
        content: 'The stage is set, the spirit is ignited, and the four competing units of CTU-Barili are ready to bring...',
        authorId: 'ctu',
        authorName: 'CTU',
        authorRole: 'organization',
        authorBarangay: '',
        authorOrganizationName: 'CTU',
        publisherEntityName: 'CTU',
        targetAudience: 'All Residents',
        targetBarangay: 'All Barangays',
        visibility: 'public',
        targetBarangays: const [],
        createdAt: DateTime(2026, 9, 15),
        status: 'approved',
        tag: 'PARTNER',
        category: 'Sports',
      );

      final feed = [postVito, postCTU];

      // 1. Searching "barangay" must find Barangay Vito and EXCLUDE CTU
      final queryBarangay = SmartAnnouncementSearch.parse('barangay');
      final resultsBarangay = SmartAnnouncementSearch.filterPosts(feed, queryBarangay);
      expect(resultsBarangay.map((p) => p.id), contains('vito_1'));
      expect(resultsBarangay.map((p) => p.id), isNot(contains('ctu_1')));

      // 2. Searching "brgy" must also find Barangay Vito via synonym and EXCLUDE CTU
      final queryBrgy = SmartAnnouncementSearch.parse('brgy');
      final resultsBrgy = SmartAnnouncementSearch.filterPosts(feed, queryBrgy);
      expect(resultsBrgy.map((p) => p.id), contains('vito_1'));
      expect(resultsBrgy.map((p) => p.id), isNot(contains('ctu_1')));

      // 3. Searching "ctu" must find CTU and EXCLUDE Barangay Vito
      final queryCTU = SmartAnnouncementSearch.parse('ctu');
      final resultsCTU = SmartAnnouncementSearch.filterPosts(feed, queryCTU);
      expect(resultsCTU.map((p) => p.id), contains('ctu_1'));
      expect(resultsCTU.map((p) => p.id), isNot(contains('vito_1')));

      // 4. Searching "sports" matches both
      final querySports = SmartAnnouncementSearch.parse('sports');
      final resultsSports = SmartAnnouncementSearch.filterPosts(feed, querySports);
      expect(resultsSports.map((p) => p.id), contains('vito_1'));
      expect(resultsSports.map((p) => p.id), contains('ctu_1'));
    });
  });

  group('Smart Announcement Search Bar Widget Test', () {
    testWidgets('renders search bar and active filter pill when preset is active',
        (tester) async {
      SmartTimePreset currentPreset = SmartTimePreset.anyTime;
      String currentQuery = '';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                final parsedQuery = SmartAnnouncementSearch.parse(
                  currentQuery,
                  preset: currentPreset,
                );
                return Column(
                  children: [
                    TextField(
                      key: const ValueKey('search-field'),
                      onChanged: (val) {
                        setState(() => currentQuery = val);
                      },
                    ),
                    InkWell(
                      key: const ValueKey('set-7-days-preset'),
                      onTap: () {
                        setState(() {
                          currentPreset = SmartTimePreset.past7Days;
                        });
                      },
                      child: const Text('Set 7 Days'),
                    ),
                    if (parsedQuery.hasTimeFilter)
                      Container(
                        key: const ValueKey('active-time-filter-pill'),
                        child: Row(
                          children: [
                            Text('Time: ${parsedQuery.displayFilterLabel}'),
                            InkWell(
                              key: const ValueKey('clear-time-filter-pill'),
                              onTap: () {
                                setState(() {
                                  currentPreset = SmartTimePreset.anyTime;
                                  if (parsedQuery.textQuery.isNotEmpty) {
                                    currentQuery = parsedQuery.textQuery;
                                  }
                                });
                              },
                              child: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // Initially no pill
      expect(find.byKey(const ValueKey('active-time-filter-pill')), findsNothing);

      // Tap preset button
      await tester.tap(find.byKey(const ValueKey('set-7-days-preset')));
      await tester.pumpAndSettle();

      // Active filter pill appears with "Past 7 Days"
      expect(find.byKey(const ValueKey('active-time-filter-pill')), findsOneWidget);
      expect(find.text('Time: Past 7 Days'), findsOneWidget);

      // Tap clear on pill
      await tester.tap(find.byKey(const ValueKey('clear-time-filter-pill')));
      await tester.pumpAndSettle();

      // Pill disappears
      expect(find.byKey(const ValueKey('active-time-filter-pill')), findsNothing);
    });
  });
}
