import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../navigation/domain/travel_route.dart';

/// Progress along a route based on the resident's latest GPS position.
///
/// A position is drawn on the route only when it is close enough for map
/// matching. Arrival is always based on the actual GPS position instead.
class ResidentNavigationProgress {
  const ResidentNavigationProgress._({
    required this.remainingDistanceMeters,
    required this.remainingDuration,
    required this.nextInstruction,
    required this.arrived,
    required this.markerPosition,
    required this.offRoute,
    this.headingDegrees = 0.0,
  });

  factory ResidentNavigationProgress.fromPosition({
    required TravelRoute route,
    required LatLng current,
    required LatLng destination,
  }) {
    const distance = Distance();
    final destinationDistance = distance.as(
      LengthUnit.Meter,
      current,
      destination,
    );
    final arrived = destinationDistance <= _arrivalDistanceMeters;
    if (arrived) {
      return ResidentNavigationProgress._(
        remainingDistanceMeters: 0,
        remainingDuration: Duration.zero,
        nextInstruction: 'You have arrived',
        arrived: true,
        markerPosition: current,
        offRoute: false,
        headingDegrees: 0.0,
      );
    }

    final projection = _projectOntoRoute(route.points, current);
    if (projection == null) {
      final remaining = destinationDistance.round();
      return ResidentNavigationProgress._(
        remainingDistanceMeters: remaining,
        remainingDuration: _durationForDistance(route, remaining),
        nextInstruction: 'Continue to destination',
        arrived: false,
        markerPosition: current,
        offRoute: true,
        headingDegrees: 0.0,
      );
    }

    final offRoute = projection.distanceMeters > _snapDistanceMeters;
    final fractionTraveled = projection.traveledMeters / projection.totalMeters;
    final routeDistance = math.max(0, route.distanceMeters);
    final routeRemaining = (routeDistance * (1 - fractionTraveled))
        .round()
        .clamp(0, routeDistance);
    // If GPS is away from the route, the displayed distance must not imply
    // that the resident is already at the destination.
    final remaining = offRoute
        ? math.max(
            routeRemaining + projection.distanceMeters.round(),
            destinationDistance.round(),
          )
        : routeRemaining;
    final duration = _durationForDistance(route, remaining);

    return ResidentNavigationProgress._(
      remainingDistanceMeters: remaining,
      remainingDuration: duration,
      nextInstruction: offRoute
          ? 'Return to the route'
          : _instructionAt(route.steps, fractionTraveled),
      arrived: false,
      markerPosition: offRoute ? current : projection.position,
      offRoute: offRoute,
      headingDegrees: projection.headingDegrees,
    );
  }

  static const double _arrivalDistanceMeters = 30;
  static const double _snapDistanceMeters = 50;

  final int remainingDistanceMeters;
  final Duration remainingDuration;
  final String nextInstruction;
  final bool arrived;
  final LatLng markerPosition;
  final bool offRoute;
  final double headingDegrees;
}

Duration _durationForDistance(TravelRoute route, int remainingDistanceMeters) {
  if (route.distanceMeters <= 0 || route.duration <= Duration.zero) {
    return Duration.zero;
  }
  return Duration(
    seconds:
        (route.duration.inSeconds *
                remainingDistanceMeters /
                route.distanceMeters)
            .round(),
  );
}

String _instructionAt(List<RouteStep> steps, double fractionTraveled) {
  if (steps.isEmpty) return 'Continue to destination';
  final totalDistance = steps.fold<int>(
    0,
    (total, step) => total + math.max(0, step.distanceMeters),
  );
  if (totalDistance <= 0) {
    for (final step in steps) {
      final instruction = step.instruction.trim();
      if (instruction.isNotEmpty) return instruction;
    }
    return 'Continue to destination';
  }

  final covered = fractionTraveled * totalDistance;
  var stepEnd = 0;
  for (var index = 0; index < steps.length; index++) {
    stepEnd += math.max(0, steps[index].distanceMeters);
    if (covered < stepEnd || index == steps.length - 1) {
      for (var next = index; next < steps.length; next++) {
        final instruction = steps[next].instruction.trim();
        if (instruction.isNotEmpty) return instruction;
      }
      return 'Continue to destination';
    }
  }
  return 'Continue to destination';
}

_RouteProjection? _projectOntoRoute(List<LatLng> points, LatLng current) {
  if (points.length < 2) return null;

  // A local meter plane is sufficient for a route within Barili. Using the
  // same origin for every segment keeps nearest-point and progress consistent.
  const metersPerDegree = 111195.0;
  final longitudeScale =
      math.cos(current.latitude * math.pi / 180) * metersPerDegree;
  var totalMeters = 0.0;
  var nearestDistanceSquared = double.infinity;
  var nearestProgress = 0.0;
  var nearestBearing = 0.0;
  LatLng? nearestPosition;

  for (var index = 0; index < points.length - 1; index++) {
    final start = points[index];
    final end = points[index + 1];
    final ax = (start.longitude - current.longitude) * longitudeScale;
    final ay = (start.latitude - current.latitude) * metersPerDegree;
    final bx = (end.longitude - current.longitude) * longitudeScale;
    final by = (end.latitude - current.latitude) * metersPerDegree;
    final dx = bx - ax;
    final dy = by - ay;
    final lengthSquared = dx * dx + dy * dy;
    final length = math.sqrt(lengthSquared);
    if (lengthSquared <= 0) continue;

    final portion = ((-ax * dx - ay * dy) / lengthSquared).clamp(0.0, 1.0);
    final px = ax + portion * dx;
    final py = ay + portion * dy;
    final distanceSquared = px * px + py * py;
    if (distanceSquared < nearestDistanceSquared) {
      nearestDistanceSquared = distanceSquared;
      nearestProgress = totalMeters + portion * length;
      nearestPosition = LatLng(
        start.latitude + portion * (end.latitude - start.latitude),
        start.longitude + portion * (end.longitude - start.longitude),
      );
      final dLon = (end.longitude - start.longitude) * math.pi / 180;
      final lat1 = start.latitude * math.pi / 180;
      final lat2 = end.latitude * math.pi / 180;
      final y = math.sin(dLon) * math.cos(lat2);
      final x = math.cos(lat1) * math.sin(lat2) -
          math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
      nearestBearing = (math.atan2(y, x) * 180 / math.pi + 360) % 360;
    }
    totalMeters += length;
  }

  if (totalMeters <= 0 || nearestPosition == null) return null;
  return _RouteProjection(
    position: nearestPosition,
    distanceMeters: math.sqrt(nearestDistanceSquared),
    traveledMeters: nearestProgress,
    totalMeters: totalMeters,
    headingDegrees: nearestBearing,
  );
}

class _RouteProjection {
  const _RouteProjection({
    required this.position,
    required this.distanceMeters,
    required this.traveledMeters,
    required this.totalMeters,
    required this.headingDegrees,
  });

  final LatLng position;
  final double distanceMeters;
  final double traveledMeters;
  final double totalMeters;
  final double headingDegrees;
}
