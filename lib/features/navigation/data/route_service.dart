import 'package:cloud_functions/cloud_functions.dart';
import 'package:latlong2/latlong.dart';

import '../domain/travel_route.dart';

class RouteException implements Exception {
  const RouteException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class RouteService {
  const RouteService();

  /// Loads one route per mode from [origin] to [destination]. Walking is left
  /// out by the server when the trip is too long to walk.
  Future<RouteOptions> routes({
    required LatLng origin,
    required LatLng destination,
  });
}

class FirebaseRouteService extends RouteService {
  const FirebaseRouteService();

  static const _connectionMessage =
      'The route could not be loaded. Check your connection and try again.';

  @override
  Future<RouteOptions> routes({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      final result = await FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('computeBariliRoute').call<Object?>({
        'origin': {'lat': origin.latitude, 'lng': origin.longitude},
        'destination': {
          'lat': destination.latitude,
          'lng': destination.longitude,
        },
        'modes': [for (final mode in TravelMode.values) mode.id],
      });
      final options = RouteOptions.fromResponse(result.data);
      if (options.isEmpty) {
        throw const RouteException('No road route was found to this place.');
      }
      return options;
    } on FirebaseFunctionsException catch (error) {
      throw RouteException(switch (error.code) {
        'unauthenticated' => 'Sign in to get directions.',
        'invalid-argument' => error.message ?? 'This place cannot be routed.',
        'failed-precondition' => 'Directions are not available right now.',
        _ => _connectionMessage,
      });
    } on RouteException {
      rethrow;
    } catch (_) {
      throw const RouteException(_connectionMessage);
    }
  }
}
