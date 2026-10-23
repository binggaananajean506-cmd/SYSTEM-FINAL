import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

const String bariliBarangayBoundariesAsset =
    'assets/data/barili_barangay_boundaries.geojson';

/// An indicative PSA barangay boundary prepared for mobile map rendering.
class BariliBarangayBoundary {
  const BariliBarangayBoundary({
    required this.name,
    required this.psgcCode,
    required this.areaSquareKilometers,
    required this.parts,
  });

  final String name;
  final String psgcCode;
  final double areaSquareKilometers;
  final List<BariliBarangayPolygonPart> parts;

  Iterable<LatLng> get points sync* {
    for (final part in parts) {
      yield* part.outerRing;
    }
  }

  LatLngBounds get bounds => LatLngBounds.fromPoints(points.toList());

  bool contains(LatLng point) => parts.any(
    (part) =>
        _ringContainsPoint(part.outerRing, point) &&
        !part.holes.any((hole) => _ringContainsPoint(hole, point)),
  );

  /// The center is used only for the map marker. The actual selection is
  /// represented by [parts], never by this point.
  LatLng get markerPosition => bounds.center;
}

bool _ringContainsPoint(List<LatLng> ring, LatLng point) {
  var inside = false;
  for (
    var index = 0, previous = ring.length - 1;
    index < ring.length;
    previous = index++
  ) {
    final currentPoint = ring[index];
    final previousPoint = ring[previous];
    final crossesLatitude =
        (currentPoint.latitude > point.latitude) !=
        (previousPoint.latitude > point.latitude);
    if (!crossesLatitude) continue;
    final crossingLongitude =
        (previousPoint.longitude - currentPoint.longitude) *
            (point.latitude - currentPoint.latitude) /
            (previousPoint.latitude - currentPoint.latitude) +
        currentPoint.longitude;
    if (point.longitude < crossingLongitude) inside = !inside;
  }
  return inside;
}

class BariliBarangayPolygonPart {
  const BariliBarangayPolygonPart({
    required this.outerRing,
    required this.holes,
  });

  final List<LatLng> outerRing;
  final List<List<LatLng>> holes;
}

Future<List<BariliBarangayBoundary>> loadBariliBarangayBoundaries() async {
  final geoJson = await rootBundle.loadString(bariliBarangayBoundariesAsset);
  return parseBariliBarangayBoundaries(geoJson);
}

List<BariliBarangayBoundary> parseBariliBarangayBoundaries(String geoJson) {
  final root = jsonDecode(geoJson);
  if (root is! Map<String, dynamic> ||
      root['type'] != 'FeatureCollection' ||
      root['features'] is! List) {
    throw const FormatException('Invalid barangay boundary collection.');
  }

  final boundaries = <BariliBarangayBoundary>[];
  for (final rawFeature in root['features'] as List<dynamic>) {
    if (rawFeature is! Map<String, dynamic>) continue;
    final properties = rawFeature['properties'];
    final geometry = rawFeature['geometry'];
    if (properties is! Map<String, dynamic> ||
        geometry is! Map<String, dynamic>) {
      continue;
    }

    final name = (properties['brgy_name'] as String?)?.trim() ?? '';
    final psgcCode =
        (properties['psgc_10d'] as String?)?.trim() ??
        (properties['brgy_code'] as String?)?.trim() ??
        '';
    final area = (properties['bgyarea_sqkm'] as num?)?.toDouble() ?? 0;
    if (name.isEmpty || psgcCode.isEmpty) continue;

    final parts = _parseGeometry(geometry);
    if (parts.isEmpty) continue;
    boundaries.add(
      BariliBarangayBoundary(
        name: name,
        psgcCode: psgcCode,
        areaSquareKilometers: area,
        parts: parts,
      ),
    );
  }

  boundaries.sort((a, b) => a.name.compareTo(b.name));
  if (boundaries.isEmpty) {
    throw const FormatException('No Barili barangay boundaries were found.');
  }
  return List.unmodifiable(boundaries);
}

List<BariliBarangayPolygonPart> _parseGeometry(Map<String, dynamic> geometry) {
  final coordinates = geometry['coordinates'];
  if (coordinates is! List) return const [];

  final polygonCoordinates = switch (geometry['type']) {
    'Polygon' => <dynamic>[coordinates],
    'MultiPolygon' => coordinates,
    _ => const <dynamic>[],
  };

  final parts = <BariliBarangayPolygonPart>[];
  for (final rawPolygon in polygonCoordinates) {
    if (rawPolygon is! List || rawPolygon.isEmpty) continue;
    final rings = rawPolygon
        .whereType<List<dynamic>>()
        .map(_parseRing)
        .where((ring) => ring.length >= 3)
        .toList();
    if (rings.isEmpty) continue;
    parts.add(
      BariliBarangayPolygonPart(
        outerRing: List.unmodifiable(rings.first),
        holes: List.unmodifiable(
          rings.skip(1).map((ring) => List<LatLng>.unmodifiable(ring)),
        ),
      ),
    );
  }
  return List.unmodifiable(parts);
}

List<LatLng> _parseRing(List<dynamic> rawRing) {
  final points = <LatLng>[];
  for (final rawPoint in rawRing) {
    if (rawPoint is! List || rawPoint.length < 2) continue;
    final longitude = rawPoint[0];
    final latitude = rawPoint[1];
    if (longitude is! num || latitude is! num) continue;
    points.add(LatLng(latitude.toDouble(), longitude.toDouble()));
  }
  return points;
}
