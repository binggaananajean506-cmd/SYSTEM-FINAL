import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:esugid/features/map/domain/resident_navigation_progress.dart';
import 'package:esugid/features/navigation/domain/travel_route.dart';

void main() {
  const start = LatLng(10.1, 123.5);
  const destination = LatLng(10.1, 123.51);
  const route = TravelRoute(
    mode: TravelMode.car,
    distanceMeters: 1000,
    duration: Duration(minutes: 10),
    description: 'Main road',
    points: [start, destination],
    steps: [
      RouteStep(
        instruction: 'Head east',
        maneuver: 'DEPART',
        distanceMeters: 500,
        duration: Duration(minutes: 5),
        points: [start],
      ),
      RouteStep(
        instruction: 'Turn right',
        maneuver: 'TURN_RIGHT',
        distanceMeters: 500,
        duration: Duration(minutes: 5),
        points: [destination],
      ),
    ],
  );

  test('starts with full route distance, time, and first direction', () {
    final progress = ResidentNavigationProgress.fromPosition(
      route: route,
      current: start,
      destination: destination,
    );

    expect(progress.remainingDistanceMeters, 1000);
    expect(progress.remainingDuration, const Duration(minutes: 10));
    expect(progress.nextInstruction, 'Head east');
    expect(progress.markerPosition, start);
    expect(progress.arrived, isFalse);
    expect(progress.offRoute, isFalse);
  });

  test('projects nearby GPS onto route and advances to the next step', () {
    const current = LatLng(10.10015, 123.506);
    final progress = ResidentNavigationProgress.fromPosition(
      route: route,
      current: current,
      destination: destination,
    );

    expect(progress.remainingDistanceMeters, closeTo(400, 2));
    expect(progress.remainingDuration.inSeconds, closeTo(240, 2));
    expect(progress.nextInstruction, 'Turn right');
    expect(progress.markerPosition.latitude, closeTo(start.latitude, 0.000001));
    expect(
      progress.markerPosition.longitude,
      closeTo(current.longitude, 0.000001),
    );
    expect(progress.offRoute, isFalse);
  });

  test('arrival uses actual GPS proximity and ends navigation progress', () {
    // About 22 meters from the destination, even though the GPS point is not
    // precisely on the route line.
    const current = LatLng(10.1002, 123.51);
    final progress = ResidentNavigationProgress.fromPosition(
      route: route,
      current: current,
      destination: destination,
    );

    expect(progress.arrived, isTrue);
    expect(progress.remainingDistanceMeters, 0);
    expect(progress.remainingDuration, Duration.zero);
    expect(progress.nextInstruction, 'You have arrived');
    expect(progress.markerPosition, current);
  });

  test(
    'off-route GPS stays at its real position and is not marked arrived',
    () {
      const current = LatLng(10.102, 123.506);
      final progress = ResidentNavigationProgress.fromPosition(
        route: route,
        current: current,
        destination: destination,
      );

      expect(progress.offRoute, isTrue);
      expect(progress.arrived, isFalse);
      expect(progress.markerPosition, current);
      expect(progress.nextInstruction, 'Return to the route');
      expect(progress.remainingDistanceMeters, greaterThan(400));
      expect(
        progress.remainingDuration,
        greaterThan(const Duration(minutes: 4)),
      );
    },
  );

  test('degenerate routes fall back to real GPS and destination distance', () {
    const unusableRoute = TravelRoute(
      mode: TravelMode.walk,
      distanceMeters: 0,
      duration: Duration.zero,
      description: '',
      points: [start, start],
      steps: [],
    );
    final progress = ResidentNavigationProgress.fromPosition(
      route: unusableRoute,
      current: start,
      destination: destination,
    );

    expect(progress.offRoute, isTrue);
    expect(progress.markerPosition, start);
    expect(progress.remainingDistanceMeters, greaterThan(1000));
    expect(progress.remainingDuration, Duration.zero);
    expect(progress.nextInstruction, 'Continue to destination');
  });

  test('valid routes without steps give a useful fallback direction', () {
    const noSteps = TravelRoute(
      mode: TravelMode.walk,
      distanceMeters: 1000,
      duration: Duration(minutes: 15),
      description: '',
      points: [start, destination],
      steps: [],
    );
    final progress = ResidentNavigationProgress.fromPosition(
      route: noSteps,
      current: start,
      destination: destination,
    );

    expect(progress.nextInstruction, 'Continue to destination');
  });
}
