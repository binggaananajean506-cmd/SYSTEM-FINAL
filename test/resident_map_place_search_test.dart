import 'package:esugid/features/explore/data/barili_place_search_service.dart';
import 'package:esugid/features/explore/domain/barili_destination.dart';
import 'package:esugid/features/explore/domain/explore_place.dart';
import 'package:esugid/features/map/data/barili_barangay_boundaries.dart';
import 'package:esugid/features/map/data/resident_map_place_search_service.dart';
import 'package:esugid/features/map/domain/resident_map_place.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('OSM tags use the resident map place categories', () {
    const examples = <(String, String, ResidentMapPlaceCategory)>[
      ('office', 'government', ResidentMapPlaceCategory.governmentOffice),
      ('amenity', 'school', ResidentMapPlaceCategory.school),
      ('amenity', 'clinic', ResidentMapPlaceCategory.healthFacility),
      ('tourism', 'attraction', ResidentMapPlaceCategory.touristSpot),
      ('amenity', 'marketplace', ResidentMapPlaceCategory.market),
      ('amenity', 'place_of_worship', ResidentMapPlaceCategory.religiousPlace),
      ('office', 'ngo', ResidentMapPlaceCategory.organization),
    ];

    for (final (key, value, expected) in examples) {
      expect(
        residentMapCategoryForOsmFeature(key, value),
        expected,
        reason: '$key=$value',
      );
    }
  });

  test('local search includes curated places and barangays', () {
    final hall = bariliDestinations.singleWhere(
      (place) => place.id == 'barili-municipal-hall',
    );
    final market = bariliDestinations.singleWhere(
      (place) => place.id == 'barili-public-market',
    );
    final provider = _FakePlaceProvider();
    final service = ResidentMapPlaceSearchService(
      provider: provider,
      destinations: [hall, market],
    );
    final boundaries = [_poblacionBoundary()];

    final government = service.localMatches('municipal hall', boundaries);
    expect(government.map((place) => place.id), contains('curated:${hall.id}'));
    expect(
      government.single.category,
      ResidentMapPlaceCategory.governmentOffice,
    );

    final barangay = service.localMatches('poblacion', boundaries);
    expect(barangay.map((place) => place.id), contains('barangay:0123456789'));
    expect(barangay.map((place) => place.id), contains('curated:${market.id}'));
    expect(
      barangay
          .singleWhere((place) => place.id == 'curated:${market.id}')
          .category,
      ResidentMapPlaceCategory.market,
    );
    expect(service.localMatches('nowhere at all', boundaries), isEmpty);
    expect(provider.searchCalls, 0);
    service.dispose();
    expect(provider.disposed, isFalse);
  });

  test(
    'live results become routable places and empty searches stay empty',
    () async {
      const school = ExplorePlaceSuggestion(
        providerId: 'N:123',
        osmType: 'N',
        osmId: '123',
        name: 'Barili National High School',
        formattedAddress: 'Poblacion, Barili, Cebu',
        latitude: 10.1,
        longitude: 123.5,
        featureKey: 'amenity',
        featureValue: 'school',
      );
      const missingCoordinates = ExplorePlaceSuggestion(
        providerId: 'N:456',
        osmType: 'N',
        osmId: '456',
        name: 'Unknown Place',
        formattedAddress: 'Barili, Cebu',
        latitude: null,
        longitude: null,
        featureKey: 'amenity',
        featureValue: 'school',
      );
      final provider = _FakePlaceProvider(
        results: {
          'school': [school, missingCoordinates],
        },
      );
      final service = ResidentMapPlaceSearchService(provider: provider);

      expect(await service.remoteMatches('s'), isEmpty);
      expect(provider.searchCalls, 0);

      final places = await service.remoteMatches('school');
      expect(places, hasLength(1));
      expect(places.single.id, 'osm:N:123');
      expect(places.single.name, school.name);
      expect(places.single.address, school.formattedAddress);
      expect(places.single.category, ResidentMapPlaceCategory.school);
      expect(places.single.position, const LatLng(10.1, 123.5));
      expect(places.single.sourceUrl, school.sourceUrl);

      expect(await service.remoteMatches('no matches'), isEmpty);
      expect(provider.searchCalls, 2);
      service.dispose();
      expect(provider.disposed, isFalse);
    },
  );
}

BariliBarangayBoundary _poblacionBoundary() => BariliBarangayBoundary(
  name: 'Poblacion',
  psgcCode: '0123456789',
  areaSquareKilometers: 1,
  parts: [
    BariliBarangayPolygonPart(
      outerRing: const [
        LatLng(10.1, 123.5),
        LatLng(10.1, 123.51),
        LatLng(10.11, 123.51),
        LatLng(10.11, 123.5),
      ],
      holes: const [],
    ),
  ],
);

class _FakePlaceProvider implements BariliPlaceProvider {
  _FakePlaceProvider({this.results = const {}});

  final Map<String, List<ExplorePlaceSuggestion>> results;
  int searchCalls = 0;
  bool disposed = false;

  @override
  Future<List<ExplorePlaceSuggestion>> search(String query) async {
    searchCalls++;
    return results[query] ?? const [];
  }

  @override
  Future<ExplorePlace> loadPlace(ExplorePlaceSuggestion suggestion) async =>
      explorePlaceFromSuggestion(suggestion);

  @override
  void dispose() => disposed = true;
}
