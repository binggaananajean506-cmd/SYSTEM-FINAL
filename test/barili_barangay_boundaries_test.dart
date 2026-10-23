import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:esugid/barili_barangays.dart';
import 'package:esugid/features/map/data/barili_barangay_boundaries.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled boundary data covers every official Barili barangay', () async {
    final geoJson = await rootBundle.loadString(bariliBarangayBoundariesAsset);
    final boundaries = parseBariliBarangayBoundaries(geoJson);

    expect(boundaries, hasLength(42));
    expect(
      boundaries.map((barangay) => barangay.name).toSet(),
      bariliBarangays.toSet(),
    );
    expect(
      boundaries.map((barangay) => barangay.psgcCode).toSet(),
      hasLength(42),
    );
    for (final barangay in boundaries) {
      expect(barangay.areaSquareKilometers, greaterThan(0));
      expect(barangay.parts, isNotEmpty);
      expect(barangay.points, isNotEmpty);
    }
  });

  test(
    'Poblacion uses its PSA polygon instead of an estimated position',
    () async {
      final geoJson = await rootBundle.loadString(
        bariliBarangayBoundariesAsset,
      );
      final boundaries = parseBariliBarangayBoundaries(geoJson);
      final poblacion = boundaries.singleWhere(
        (barangay) => barangay.name == 'Poblacion',
      );

      expect(poblacion.psgcCode, '0702210038');
      expect(poblacion.areaSquareKilometers, closeTo(1.10266689, 0.00000001));
      expect(poblacion.parts, hasLength(1));
      expect(poblacion.parts.single.outerRing, hasLength(43));
      expect(poblacion.bounds.north, closeTo(10.118965, 0.000001));
      expect(poblacion.bounds.south, closeTo(10.105856, 0.000001));
      expect(poblacion.bounds.east, closeTo(123.515936, 0.000001));
      expect(poblacion.bounds.west, closeTo(123.498761, 0.000001));
      expect(poblacion.contains(const LatLng(10.1112404, 123.5112960)), isTrue);
      expect(poblacion.contains(const LatLng(10.30, 123.70)), isFalse);
    },
  );

  test('parser rejects a boundary collection without usable features', () {
    expect(
      () => parseBariliBarangayBoundaries(
        '{"type":"FeatureCollection","features":[]}',
      ),
      throwsFormatException,
    );
  });
}
