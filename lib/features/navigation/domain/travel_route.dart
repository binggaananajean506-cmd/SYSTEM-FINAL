import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

enum TravelMode {
  car('car', 'Car', Icons.directions_car_rounded, 'd', 'driving'),
  motorcycle('motorcycle', 'Motorcycle', Icons.two_wheeler_rounded, 'l', 'driving'),
  walk('walk', 'Walk', Icons.directions_walk_rounded, 'w', 'walking');

  const TravelMode(
    this.id,
    this.label,
    this.icon,
    this.googleNavigationMode,
    this.googleWebTravelMode,
  );

  /// The value exchanged with the `computeBariliRoute` function.
  final String id;
  final String label;
  final IconData icon;

  /// The `mode` parameter of a `google.navigation:` intent.
  final String googleNavigationMode;

  /// The `travelmode` parameter of a Google Maps web directions link.
  final String googleWebTravelMode;

  static TravelMode? fromId(Object? id) {
    for (final mode in values) {
      if (mode.id == id) return mode;
    }
    return null;
  }
}

class RouteStep {
  const RouteStep({
    required this.instruction,
    required this.maneuver,
    required this.distanceMeters,
    required this.duration,
    required this.points,
  });

  final String instruction;
  final String maneuver;
  final int distanceMeters;
  final Duration duration;
  final List<LatLng> points;
}

class TravelRoute {
  const TravelRoute({
    required this.mode,
    required this.distanceMeters,
    required this.duration,
    required this.description,
    required this.points,
    required this.steps,
    this.estimated = false,
  });

  final TravelMode mode;
  final int distanceMeters;
  final Duration duration;

  /// Google's short route summary, such as the main road taken.
  final String description;
  final List<LatLng> points;
  final List<RouteStep> steps;

  /// True when Google has no route for [mode] here and this one is adapted
  /// from the car route.
  final bool estimated;

  static TravelRoute? fromMap(TravelMode mode, Object? value) {
    if (value is! Map) return null;
    final points = decodePolyline('${value['encodedPolyline'] ?? ''}');
    if (points.length < 2) return null;
    final rawSteps = value['steps'];
    return TravelRoute(
      mode: mode,
      distanceMeters: _int(value['distanceMeters']),
      duration: Duration(seconds: _int(value['durationSeconds'])),
      description: '${value['description'] ?? ''}'.trim(),
      points: points,
      estimated: value['estimated'] == true,
      steps: rawSteps is List
          ? rawSteps.whereType<Map>().map((step) {
              return RouteStep(
                instruction: '${step['instruction'] ?? ''}'.trim(),
                maneuver: '${step['maneuver'] ?? ''}',
                distanceMeters: _int(step['distanceMeters']),
                duration: Duration(seconds: _int(step['durationSeconds'])),
                points: decodePolyline('${step['encodedPolyline'] ?? ''}'),
              );
            }).toList(growable: false)
          : const [],
    );
  }

  static int _int(Object? value) => value is num ? value.round() : 0;
}

/// The routes available from one origin to one destination, one per mode.
class RouteOptions {
  const RouteOptions(this.routes);

  final Map<TravelMode, TravelRoute> routes;

  factory RouteOptions.fromResponse(Object? data) {
    final raw = data is Map ? data['routes'] : null;
    final routes = <TravelMode, TravelRoute>{};
    if (raw is Map) {
      for (final mode in TravelMode.values) {
        final route = TravelRoute.fromMap(mode, raw[mode.id]);
        if (route != null) routes[mode] = route;
      }
    }
    return RouteOptions(routes);
  }

  bool get isEmpty => routes.isEmpty;

  TravelRoute? operator [](TravelMode mode) => routes[mode];
}

/// Decodes a Google encoded polyline (precision 5).
List<LatLng> decodePolyline(String encoded) {
  final points = <LatLng>[];
  var index = 0;
  var lat = 0;
  var lng = 0;
  int? nextValue() {
    var result = 0;
    var shift = 0;
    while (index < encoded.length) {
      final byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
      if (byte < 0x20) {
        return (result & 1) != 0 ? ~(result >> 1) : result >> 1;
      }
    }
    return null;
  }

  while (index < encoded.length) {
    final dLat = nextValue();
    final dLng = nextValue();
    if (dLat == null || dLng == null) break;
    lat += dLat;
    lng += dLng;
    points.add(LatLng(lat / 1e5, lng / 1e5));
  }
  return points;
}

String formatRouteDistance(int meters) {
  if (meters < 1000) return '${(meters / 10).round() * 10} m';
  final km = meters / 1000;
  return km < 10 ? '${km.toStringAsFixed(1)} km' : '${km.round()} km';
}

String formatRouteDuration(Duration duration) {
  final minutes = (duration.inSeconds / 60).ceil();
  if (minutes < 1) return '1 min';
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours h' : '$hours h $rest min';
}
