import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:esugid/app/theme/esugid_clay_theme.dart';
import 'package:esugid/auth_service.dart';
import 'package:esugid/core/location/location_service.dart';
import 'package:esugid/features/explore/data/barili_place_search_service.dart';
import 'package:esugid/features/explore/domain/barili_destination.dart';
import 'package:esugid/features/explore/domain/explore_place.dart';
import 'package:esugid/features/map/data/barili_barangay_boundaries.dart';
import 'package:esugid/features/map/data/resident_map_place_search_service.dart';
import 'package:esugid/features/navigation/data/route_service.dart';
import 'package:esugid/features/navigation/domain/travel_route.dart';
import 'package:esugid/pages/resident_map_page.dart';

class _UnavailableLocationService extends LocationService {
  const _UnavailableLocationService();

  @override
  Future<Position> currentPosition() async {
    throw const LocationException('Location unavailable in widget tests.');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Google map retains all barangay boundaries and filters', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AuthService.currentUser = null;
    final geoJson = await tester.runAsync(
      () => rootBundle.loadString(bariliBarangayBoundariesAsset),
    );
    final boundaries = parseBariliBarangayBoundaries(geoJson!);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildESugidClayTheme(Brightness.light),
        home: ResidentMapPage(
          boundaryLoader: () async => boundaries,
          locationService: const _UnavailableLocationService(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(gmaps.GoogleMap), findsOneWidget);
    final initialMap = tester.widget<gmaps.GoogleMap>(
      find.byType(gmaps.GoogleMap),
    );
    expect(
      initialMap.markers.map((marker) => marker.markerId.value),
      isNot(contains('resident-current-location')),
    );
    expect(
      initialMap.polygons.map((polygon) => polygon.polygonId.value).toSet(),
      containsAll(
        boundaries.expand(
          (boundary) => List.generate(
            boundary.parts.length,
            (index) => '${boundary.psgcCode}-$index',
          ),
        ),
      ),
    );
    final selector = tester.widget<InkWell>(
      find.byKey(const ValueKey('barangay-map-selector')),
    );
    expect(selector.onTap, isNotNull);

    selector.onTap!();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TextField),
      ),
      'Poblacion',
    );
    await tester.pump();
    final poblacionTile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'Poblacion'),
    );
    poblacionTile.onTap!();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    final selectedMap = tester.widget<gmaps.GoogleMap>(
      find.byType(gmaps.GoogleMap),
    );
    final poblacionBoundary = boundaries.singleWhere(
      (boundary) => boundary.name == 'Poblacion',
    );
    final poblacion = selectedMap.polygons.singleWhere(
      (polygon) => polygon.polygonId.value == '${poblacionBoundary.psgcCode}-0',
    );
    expect(poblacion.points, hasLength(43));
    expect(poblacion.strokeWidth, greaterThan(1));
    expect(
      find.text('Indicative boundary • PSA / GeoRisk Philippines'),
      findsOneWidget,
    );

    final markerFilter = tester.widget<InkWell>(
      find.byKey(const ValueKey('map-marker-filter')),
    );
    markerFilter.onTap!();
    await tester.pump(const Duration(milliseconds: 400));
    final hideAll = tester.widget<TextButton>(
      find.byKey(const ValueKey('hide-all-map-markers')),
    );
    hideAll.onPressed!();
    await tester.pump();

    final filteredMap = tester.widget<gmaps.GoogleMap>(
      find.byType(gmaps.GoogleMap),
    );
    expect(filteredMap.markers, isEmpty);
    expect(tester.takeException(), isNull);
  });

  group('directions to places to visit', () {
    late List<BariliBarangayBoundary> boundaries;
    final falls = bariliDestinations.singleWhere(
      (place) => place.id == 'mantayupan-falls',
    );

    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> pumpMap(
      WidgetTester tester, {
      BariliDestination? routeDestination,
      LocationService? locationService,
      _FakePlaceProvider? placeProvider,
      Size viewport = const Size(390, 844),
      required _FakeRouteService routeService,
    }) async {
      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      AuthService.currentUser = null;
      final geoJson = await tester.runAsync(
        () => rootBundle.loadString(bariliBarangayBoundariesAsset),
      );
      boundaries = parseBariliBarangayBoundaries(geoJson!);
      final source =
          locationService ?? _FakeLocationService(_position(10.1112, 123.5113));
      if (source is _FakeLocationService) addTearDown(source.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildESugidClayTheme(Brightness.light),
          home: ResidentMapPage(
            routeDestination: routeDestination,
            boundaryLoader: () async => boundaries,
            locationService: source,
            routeService: routeService,
            placeSearchService: ResidentMapPlaceSearchService(
              provider: placeProvider ?? _FakePlaceProvider(),
            ),
            travelMarkerFactory: (_) => gmaps.BitmapDescriptor.defaultMarker,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    Set<String> polylineIds(WidgetTester tester) => tester
        .widget<gmaps.GoogleMap>(find.byType(gmaps.GoogleMap))
        .polylines
        .map((line) => line.polylineId.value)
        .toSet();

    testWidgets('current marker follows GPS and recenter refreshes the fix', (
      tester,
    ) async {
      final locations = _FakeLocationService(_position(10.1112, 123.5113));
      await pumpMap(
        tester,
        locationService: locations,
        routeService: _FakeRouteService(),
      );

      expect(locations.requests, 1);
      expect(
        _mapMarker(tester, 'resident-current-location').position,
        const gmaps.LatLng(10.1112, 123.5113),
      );
      expect(
        _mapMarker(tester, 'resident-current-location').infoWindow.title,
        'You are here',
      );

      locations.moveTo(_position(10.1060, 123.5240));
      await tester.pump();
      expect(
        _mapMarker(tester, 'resident-current-location').position,
        const gmaps.LatLng(10.1060, 123.5240),
      );

      locations.latest = _position(10.1090, 123.5190);
      await tester.tap(find.byKey(const ValueKey('center-current-location')));
      await tester.pump();
      expect(locations.requests, 2);
      expect(
        _mapMarker(tester, 'resident-current-location').position,
        const gmaps.LatLng(10.1090, 123.5190),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('local and live place suggestions open a route preview', (
      tester,
    ) async {
      final provider = _FakePlaceProvider();
      final routes = _FakeRouteService();
      await pumpMap(tester, routeService: routes, placeProvider: provider);

      final search = find.byKey(const ValueKey('resident-map-search'));
      await tester.enterText(search, 'Mantayupan');
      await tester.pump();
      expect(
        find.byKey(
          const ValueKey('resident-map-suggestion-curated:mantayupan-falls'),
        ),
        findsOneWidget,
      );

      await tester.enterText(search, 'Sample Health Station');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump();
      expect(provider.queries, contains('Sample Health Station'));
      final suggestion = find.byKey(
        const ValueKey('resident-map-suggestion-osm:N:42'),
      );
      expect(suggestion, findsOneWidget);
      await tester.tap(suggestion);
      await tester.pump();
      await tester.pump();

      expect(
        routes.requests.single.destination,
        const LatLng(10.1101, 123.5150),
      );
      expect(find.byKey(const ValueKey('route-preview-card')), findsOneWidget);
      expect(find.text('Poblacion, Barili, Cebu'), findsOneWidget);
      expect(find.textContaining('4.3 km'), findsOneWidget);
      expect(find.byKey(const ValueKey('start-navigation')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('unmatched search has a clear empty state', (tester) async {
      final provider = _FakePlaceProvider();
      await pumpMap(
        tester,
        routeService: _FakeRouteService(),
        placeProvider: provider,
      );

      await tester.enterText(
        find.byKey(const ValueKey('resident-map-search')),
        'no-place-zzzx',
      );
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump();
      expect(provider.queries, contains('no-place-zzzx'));
      expect(find.text('No matching places found'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('route preview draws the chosen mode and switches modes', (
      tester,
    ) async {
      final routes = _FakeRouteService();
      await pumpMap(tester, routeDestination: falls, routeService: routes);

      expect(routes.requests.single.destination, falls.position);
      expect(find.byKey(const ValueKey('route-preview-card')), findsOneWidget);
      expect(polylineIds(tester), {'route-outline', 'route'});
      expect(find.byKey(const ValueKey('route-mode-walk')), findsOneWidget);
      // Motorcycle is the default and its time came from the car route.
      expect(find.text('9 min'), findsOneWidget);
      expect(
        find.text('Motorcycle time is estimated from the car route.'),
        findsOneWidget,
      );
      final map = tester.widget<gmaps.GoogleMap>(find.byType(gmaps.GoogleMap));
      expect(
        map.markers.map((marker) => marker.markerId.value),
        containsAll({
          'route-destination-curated:${falls.id}',
          'resident-current-location',
        }),
      );
      expect(find.textContaining('4.3 km'), findsOneWidget);
      expect(find.byKey(const ValueKey('start-navigation')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('places-to-visit-button')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('route-mode-car')));
      await tester.pump();
      expect(
        find.text('Motorcycle time is estimated from the car route.'),
        findsNothing,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('resident_map.travel_mode'), 'car');

      await tester.tap(find.byTooltip('Close directions'));
      await tester.pump();
      expect(find.byKey(const ValueKey('route-preview-card')), findsNothing);
      expect(polylineIds(tester), isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('unavailable walking routes are shown without a fake route', (
      tester,
    ) async {
      await pumpMap(
        tester,
        routeDestination: falls,
        routeService: _FakeRouteService(includeWalk: false),
      );

      expect(find.text('Walk'), findsOneWidget);
      expect(find.text('Unavailable'), findsOneWidget);
      expect(
        find.text('Walking directions are unavailable for this trip.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('route-mode-walk')), findsNothing);
      expect(polylineIds(tester), {'route-outline', 'route'});
    });

    testWidgets('navigation follows GPS, ends, and announces arrival', (
      tester,
    ) async {
      final locations = _FakeLocationService(_position(10.1112, 123.5113));
      await pumpMap(
        tester,
        routeDestination: falls,
        locationService: locations,
        routeService: _FakeRouteService(),
      );
      await tester.tap(find.byKey(const ValueKey('start-navigation')));
      await tester.pump();
      await tester.pump();
      expect(
        find.byKey(const ValueKey('live-navigation-card')),
        findsOneWidget,
      );
      expect(find.text('Turn right'), findsOneWidget);
      expect(find.text('4.3 km remaining'), findsOneWidget);
      expect(
        _mapMarker(tester, 'resident-travel-motorcycle').position,
        const gmaps.LatLng(10.1112, 123.5113),
      );

      locations.moveTo(_position(10.1060, 123.5240));
      await tester.pumpAndSettle();
      expect(
        _mapMarker(tester, 'resident-current-location').position,
        const gmaps.LatLng(10.1060, 123.5240),
      );
      expect(
        _mapMarker(tester, 'resident-travel-motorcycle').position,
        const gmaps.LatLng(10.1060, 123.5240),
      );
      expect(find.text('Continue straight'), findsOneWidget);
      expect(find.text('4.3 km remaining'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('end-navigation')));
      await tester.pump();
      expect(find.byKey(const ValueKey('route-preview-card')), findsOneWidget);
      expect(
        tester
            .widget<gmaps.GoogleMap>(find.byType(gmaps.GoogleMap))
            .markers
            .map((marker) => marker.markerId.value),
        isNot(contains('resident-travel-motorcycle')),
      );

      await tester.tap(find.byKey(const ValueKey('start-navigation')));
      await tester.pump();
      await tester.pump();
      locations.moveTo(
        _position(falls.position.latitude, falls.position.longitude),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('navigation-arrival-card')),
        findsOneWidget,
      );
      expect(find.text('You have arrived'), findsOneWidget);
      expect(
        _mapMarker(tester, 'resident-current-location').infoWindow.title,
        'You are here',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'lost GPS clears the marker and recenter restores a fresh fix',
      (tester) async {
        final locations = _FakeLocationService(_position(10.1112, 123.5113));
        await pumpMap(
          tester,
          routeDestination: falls,
          locationService: locations,
          routeService: _FakeRouteService(),
        );

        await tester.tap(find.byKey(const ValueKey('start-navigation')));
        await tester.pump();
        await tester.pump();
        expect(
          find.byKey(const ValueKey('live-navigation-card')),
          findsOneWidget,
        );
        expect(
          _mapMarker(tester, 'resident-current-location').infoWindow.title,
          'You are here',
        );

        locations.fail(
          const LocationException('Your live location is unavailable.'),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('live-navigation-card')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('route-preview-card')),
          findsOneWidget,
        );
        expect(
          tester
              .widget<gmaps.GoogleMap>(find.byType(gmaps.GoogleMap))
              .markers
              .map((marker) => marker.markerId.value),
          isNot(contains('resident-current-location')),
        );

        locations.latest = _position(10.1090, 123.5190);
        await tester.tap(find.byKey(const ValueKey('center-current-location')));
        await tester.pumpAndSettle();
        expect(locations.requests, 2);
        expect(
          _mapMarker(tester, 'resident-current-location').position,
          const gmaps.LatLng(10.1090, 123.5190),
        );
        locations.moveTo(_position(10.1060, 123.5240));
        await tester.pumpAndSettle();
        expect(
          _mapMarker(tester, 'resident-current-location').position,
          const gmaps.LatLng(10.1060, 123.5240),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('route and navigation controls fit a compact viewport', (
      tester,
    ) async {
      const viewport = Size(320, 568);
      void expectWithinViewport(Finder finder) {
        final rect = tester.getRect(finder);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(viewport.width));
        expect(rect.bottom, lessThanOrEqualTo(viewport.height));
      }

      await pumpMap(
        tester,
        routeDestination: falls,
        routeService: _FakeRouteService(),
        viewport: viewport,
      );
      expect(find.byKey(const ValueKey('route-preview-card')), findsOneWidget);
      expect(find.byKey(const ValueKey('start-navigation')), findsOneWidget);
      expectWithinViewport(find.byKey(const ValueKey('start-navigation')));
      expect(tester.takeException(), isNull);

      final start = tester.widget<FilledButton>(
        find.byKey(const ValueKey('start-navigation')),
      );
      start.onPressed!();
      await tester.pump();
      await tester.pump();
      expect(
        find.byKey(const ValueKey('live-navigation-card')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('end-navigation')), findsOneWidget);
      expectWithinViewport(find.byKey(const ValueKey('end-navigation')));
      expect(
        find.byKey(const ValueKey('center-current-location')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('places to visit list opens a route preview', (tester) async {
      final routes = _FakeRouteService();
      await pumpMap(tester, routeService: routes);

      await tester.tap(find.byKey(const ValueKey('map-place-category-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('places-to-visit-button')));
      await tester.pumpAndSettle();
      expect(
        find.text('Nearest first · straight-line distance'),
        findsOneWidget,
      );
      // From Poblacion, the church is the nearest place.
      final firstTile = tester.widget<ListTile>(find.byType(ListTile).first);
      expect(firstTile.key, const ValueKey('place-to-visit-st-anne-shrine'));

      await tester.tap(find.byKey(const ValueKey('places-filter-nature')));
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('place-to-visit-mantayupan-falls')),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      expect(routes.requests.single.destination, falls.position);
      expect(find.byKey(const ValueKey('route-preview-card')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('missing location explains why there is no route', (
      tester,
    ) async {
      final routes = _FakeRouteService();
      await pumpMap(
        tester,
        routeDestination: falls,
        routeService: routes,
        locationService: const _UnavailableLocationService(),
      );

      expect(routes.requests, isEmpty);
      expect(
        find.text('Location unavailable in widget tests.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('route errors offer a retry', (tester) async {
      final routes = _FakeRouteService(
        error: const RouteException('Directions are not available right now.'),
      );
      await pumpMap(tester, routeDestination: falls, routeService: routes);

      expect(
        find.text('Directions are not available right now.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();
      expect(routes.requests, hasLength(2));
      expect(tester.takeException(), isNull);
    });
  });
}

String _encodePolyline(List<LatLng> points) {
  final out = StringBuffer();
  void write(int value) {
    var v = value < 0 ? ~(value << 1) : value << 1;
    while (v >= 0x20) {
      out.writeCharCode((0x20 | (v & 0x1f)) + 63);
      v >>= 5;
    }
    out.writeCharCode(v + 63);
  }

  var lat = 0;
  var lng = 0;
  for (final point in points) {
    final nextLat = (point.latitude * 1e5).round();
    final nextLng = (point.longitude * 1e5).round();
    write(nextLat - lat);
    write(nextLng - lng);
    lat = nextLat;
    lng = nextLng;
  }
  return out.toString();
}

gmaps.Marker _mapMarker(WidgetTester tester, String id) => tester
    .widget<gmaps.GoogleMap>(find.byType(gmaps.GoogleMap))
    .markers
    .singleWhere((marker) => marker.markerId.value == id);

Position _position(double latitude, double longitude) => Position(
  latitude: latitude,
  longitude: longitude,
  timestamp: DateTime(2026, 10, 5),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

class _FakeLocationService extends LocationService {
  _FakeLocationService(this.latest);

  Position latest;
  int requests = 0;
  final StreamController<Position> _updates =
      StreamController<Position>.broadcast(sync: true);

  @override
  Future<Position> currentPosition() async {
    requests++;
    return latest;
  }

  @override
  Stream<Position> positionStream() => _updates.stream;

  void moveTo(Position position) {
    latest = position;
    _updates.add(position);
  }

  void fail(LocationException error) => _updates.addError(error);

  Future<void> dispose() => _updates.close();
}

class _FakePlaceProvider implements BariliPlaceProvider {
  final List<String> queries = [];

  @override
  Future<List<ExplorePlaceSuggestion>> search(String query) async {
    queries.add(query);
    if (query != 'Sample Health Station') return const [];
    return const [
      ExplorePlaceSuggestion(
        providerId: 'N:42',
        osmType: 'N',
        osmId: '42',
        name: 'Sample Health Station',
        formattedAddress: 'Poblacion, Barili, Cebu',
        latitude: 10.1101,
        longitude: 123.5150,
        featureKey: 'amenity',
        featureValue: 'clinic',
      ),
    ];
  }

  @override
  Future<ExplorePlace> loadPlace(ExplorePlaceSuggestion suggestion) async =>
      explorePlaceFromSuggestion(suggestion);

  @override
  void dispose() {}
}

class _FakeRouteService extends RouteService {
  _FakeRouteService({this.error, this.includeWalk = true});

  final RouteException? error;
  final bool includeWalk;
  final List<({LatLng origin, LatLng destination})> requests = [];

  static Map<String, Object?> _route(int seconds, {bool estimated = false}) => {
    'distanceMeters': 4300,
    'durationSeconds': seconds,
    'description': 'Barili–Mantayupan Rd',
    'encodedPolyline': _encodePolyline(const [
      LatLng(10.1112, 123.5113),
      LatLng(10.1060, 123.5240),
      LatLng(10.10092, 123.53577),
    ]),
    'estimated': estimated,
    'steps': [
      {
        'instruction': 'Turn right',
        'maneuver': 'TURN_RIGHT',
        'distanceMeters': 2000,
        'durationSeconds': 240,
        'encodedPolyline': _encodePolyline(const [
          LatLng(10.1112, 123.5113),
          LatLng(10.1060, 123.5240),
        ]),
      },
      {
        'instruction': 'Continue straight',
        'maneuver': 'STRAIGHT',
        'distanceMeters': 2300,
        'durationSeconds': 360,
        'encodedPolyline': _encodePolyline(const [
          LatLng(10.1060, 123.5240),
          LatLng(10.10092, 123.53577),
        ]),
      },
    ],
  };

  @override
  Future<RouteOptions> routes({
    required LatLng origin,
    required LatLng destination,
  }) async {
    requests.add((origin: origin, destination: destination));
    if (error case final error?) throw error;
    return RouteOptions.fromResponse({
      'routes': {
        'car': _route(600),
        'motorcycle': _route(540, estimated: true),
        if (includeWalk) 'walk': _route(3000),
      },
    });
  }
}
