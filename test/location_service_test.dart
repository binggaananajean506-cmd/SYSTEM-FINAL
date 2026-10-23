import 'package:flutter_test/flutter_test.dart';

import 'package:esugid/core/location/location_service.dart';

void main() {
  test('reverse-geocode response uses barangay and municipality', () {
    expect(
      locationLabelFromResponse(
        '{"address":{"village":"Cabcaban","municipality":"Barili"}}',
        latitude: 10.1,
        longitude: 123.5,
      ),
      'Cabcaban, Barili',
    );
  });

  test('invalid reverse-geocode data safely falls back to coordinates', () {
    expect(
      locationLabelFromResponse(
        'not-json',
        latitude: 10.123456,
        longitude: 123.987654,
      ),
      '10.1235, 123.9877',
    );
  });
}
