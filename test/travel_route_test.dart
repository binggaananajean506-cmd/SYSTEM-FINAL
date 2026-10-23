import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:esugid/features/navigation/data/google_maps_handoff.dart';
import 'package:esugid/features/navigation/domain/travel_route.dart';

void main() {
  test('decodes Google encoded polylines', () {
    final points = decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
    expect(points, const [
      LatLng(38.5, -120.2),
      LatLng(40.7, -120.95),
      LatLng(43.252, -126.453),
    ]);
    expect(decodePolyline(''), isEmpty);
    expect(decodePolyline('_p~iF'), isEmpty);
  });

  test('parses function responses and skips unusable modes', () {
    final options = RouteOptions.fromResponse({
      'routes': {
        'car': {
          'distanceMeters': 4300,
          'durationSeconds': 640,
          'description': 'Barili–Mantayupan Rd',
          'encodedPolyline': '_p~iF~ps|U_ulLnnqC_mqNvxq`@',
          'estimated': false,
          'steps': [
            {
              'instruction': 'Turn right',
              'maneuver': 'TURN_RIGHT',
              'distanceMeters': 300,
              'durationSeconds': 40,
              'encodedPolyline': '_p~iF~ps|U_ulLnnqC',
            },
          ],
        },
        'motorcycle': {
          'distanceMeters': 4300,
          'durationSeconds': 576,
          'encodedPolyline': '_p~iF~ps|U_ulLnnqC_mqNvxq`@',
          'estimated': true,
        },
        'walk': null,
      },
    });
    expect(options.routes.keys, [TravelMode.car, TravelMode.motorcycle]);
    expect(options[TravelMode.car]!.duration, const Duration(seconds: 640));
    expect(options[TravelMode.car]!.steps.single.points, hasLength(2));
    expect(options[TravelMode.motorcycle]!.estimated, isTrue);
    expect(options[TravelMode.walk], isNull);
    expect(RouteOptions.fromResponse('nonsense').isEmpty, isTrue);
  });

  test('formats distances and durations for the preview', () {
    expect(formatRouteDistance(347), '350 m');
    expect(formatRouteDistance(4300), '4.3 km');
    expect(formatRouteDistance(61400), '61 km');
    expect(formatRouteDuration(const Duration(seconds: 20)), '1 min');
    expect(formatRouteDuration(const Duration(seconds: 545)), '10 min');
    expect(formatRouteDuration(const Duration(minutes: 95)), '1 h 35 min');
    expect(formatRouteDuration(const Duration(hours: 2)), '2 h');
  });

  test('Google Maps links carry the chosen travel mode', () {
    const falls = LatLng(10.1009225, 123.5357685);
    final walk = googleMapsDirectionsUri(falls, mode: TravelMode.walk);
    expect(walk.queryParameters['travelmode'], 'walking');
    expect(walk.queryParameters['destination'], '10.1009225,123.5357685');
    expect(TravelMode.motorcycle.googleNavigationMode, 'l');
  });
}
