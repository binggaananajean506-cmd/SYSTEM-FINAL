import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:esugid/app/theme/esugid_clay_theme.dart';
import 'package:esugid/features/explore/data/barili_place_search_service.dart';
import 'package:esugid/features/explore/domain/barili_destination.dart';
import 'package:esugid/features/explore/domain/explore_place.dart';
import 'package:esugid/pages/explore_barili_page.dart';

class _FakePlaceProvider implements BariliPlaceProvider {
  bool disposed = false;

  @override
  Future<List<ExplorePlaceSuggestion>> search(String query) async {
    return const [
      ExplorePlaceSuggestion(
        providerId: 'N:123',
        osmType: 'N',
        osmId: '123',
        name: 'Rural Cafe',
        formattedAddress: 'Poblacion, Barili, Cebu, Philippines',
        latitude: 10.11125,
        longitude: 123.511953,
        featureKey: 'amenity',
        featureValue: 'cafe',
        category: BariliDestinationCategory.food,
      ),
    ];
  }

  @override
  Future<ExplorePlace> loadPlace(ExplorePlaceSuggestion suggestion) async {
    return ExplorePlace(
      id: suggestion.providerId,
      name: suggestion.name,
      category: suggestion.category,
      formattedAddress: suggestion.formattedAddress,
      summary: suggestion.formattedAddress,
      description: 'A real place listed in Barili, Cebu on OpenStreetMap.',
      position: suggestion.position,
      photos: const [],
      sourceLabel: 'OpenStreetMap',
      sourceUrl: suggestion.sourceUrl,
    );
  }

  @override
  void dispose() => disposed = true;
}

void main() {
  test('curated destinations cover the advertised categories', () {
    expect(bariliDestinations, hasLength(20));
    expect(
      bariliDestinations.map((destination) => destination.id).toSet(),
      hasLength(bariliDestinations.length),
    );
    expect(
      bariliDestinations.map((destination) => destination.category).toSet(),
      BariliDestinationCategory.values.toSet(),
    );
    for (final destination in bariliDestinations) {
      expect(destination.name, isNotEmpty);
      expect(destination.description, isNotEmpty);
      expect(destination.position.latitude, inInclusiveRange(10.03, 10.19));
      expect(destination.position.longitude, inInclusiveRange(123.46, 123.61));
      expect(destination.addressText, contains('Barili'));
      expect(destination.tags, isNotEmpty);
      expect(Uri.parse(destination.informationSourceUrl).scheme, 'https');
      for (final photo in destination.photos) {
        expect(photo.assetPath != null || photo.networkUrl != null, isTrue);
        if (photo.networkUrl case final url?) {
          expect(Uri.parse(url).scheme, 'https');
        }
      }
    }
  });

  testWidgets('category filter opens details with an interactive place map', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildESugidClayTheme(Brightness.light),
        home: const ExploreBariliPage(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const ValueKey('destination-filter-beaches')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('destination-card-sayaw-beach')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('destination-card-mantayupan-falls')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('destination-card-sayaw-beach')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Sayaw Beach'), findsWidgets);
    expect(find.textContaining('Tañon Strait'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('directions-sayaw-beach')),
      findsOneWidget,
    );

    expect(find.byType(FlutterMap), findsNothing);
    final directions = tester.widget<FilledButton>(
      find.byKey(const ValueKey('directions-sayaw-beach')),
    );
    expect(directions.onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('local search matches destination tags and barangays', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildESugidClayTheme(Brightness.light),
        home: const ExploreBariliPage(),
      ),
    );

    expect(find.textContaining('curated local stops'), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('explore-place-search')),
      'waterfall',
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('destination-card-mantayupan-falls')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('explore-place-search')),
      'Nasipit',
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('destination-card-barili-atv-adventure')),
      findsOneWidget,
    );
  });

  testWidgets('live search opens the selected provider place', (tester) async {
    final provider = _FakePlaceProvider();
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildESugidClayTheme(Brightness.light),
        home: ExploreBariliPage(placeProvider: provider),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('explore-place-search')),
      'Rural Cafe',
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(find.text('Rural Cafe'), findsNWidgets(2));
    expect(find.text('Poblacion, Barili, Cebu, Philippines'), findsOneWidget);

    await tester.tap(find.text('Rural Cafe').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Rural Cafe'), findsWidgets);
    expect(find.byType(FlutterMap), findsNothing);
    expect(find.byKey(const ValueKey('directions-N:123')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('directions use exact coordinates as the destination', () {
    final uri = directionsUriFor(const LatLng(10.100923, 123.535769));
    expect(uri.host, 'www.google.com');
    expect(uri.path, '/maps/dir/');
    expect(uri.queryParameters['destination'], '10.100923,123.535769');
  });
}
