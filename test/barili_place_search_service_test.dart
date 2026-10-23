import 'package:esugid/features/explore/data/barili_place_search_service.dart';
import 'package:esugid/features/explore/domain/barili_destination.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses real Photon places and drops coordinates outside Barili', () {
    const response = '''
    {
      "features": [
        {
          "properties": {
            "osm_type": "N",
            "osm_id": 3646256795,
            "osm_key": "waterway",
            "osm_value": "waterfall",
            "name": "Mantayupan Falls",
            "city": "Campangga",
            "state": "Cebu",
            "country": "Philippines"
          },
          "geometry": {
            "type": "Point",
            "coordinates": [123.5357685, 10.1009225]
          }
        },
        {
          "properties": {
            "osm_type": "N",
            "osm_id": 999,
            "osm_key": "amenity",
            "osm_value": "cafe",
            "name": "Outside Cafe"
          },
          "geometry": {
            "type": "Point",
            "coordinates": [123.90, 10.40]
          }
        }
      ]
    }
    ''';

    final results = parsePhotonBariliSuggestions(response);

    expect(results, hasLength(1));
    expect(results.single.providerId, 'N:3646256795');
    expect(results.single.name, 'Mantayupan Falls');
    expect(
      results.single.formattedAddress,
      'Campangga, Barili, Cebu, Philippines',
    );
    expect(results.single.category, BariliDestinationCategory.nature);
    expect(results.single.position?.latitude, closeTo(10.1009225, 0.0000001));
    expect(results.single.position?.longitude, closeTo(123.5357685, 0.0000001));
  });

  test('maps supported OSM tags to the existing Explore categories', () {
    expect(
      categoryForOsmFeature('tourism', 'resort'),
      BariliDestinationCategory.stays,
    );
    expect(
      categoryForOsmFeature('amenity', 'restaurant'),
      BariliDestinationCategory.food,
    );
    expect(
      categoryForOsmFeature('amenity', 'place_of_worship'),
      BariliDestinationCategory.culture,
    );
    expect(
      categoryForOsmFeature('shop', 'gift'),
      BariliDestinationCategory.culture,
    );
  });
}
