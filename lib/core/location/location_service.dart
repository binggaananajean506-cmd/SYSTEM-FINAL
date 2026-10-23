import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class LocationException implements Exception {
  final String message;

  const LocationException(this.message);

  @override
  String toString() => message;
}

class LocationService {
  static const Duration _timeout = Duration(seconds: 12);

  const LocationService();

  Future<Position> currentPosition() async {
    await _ensureLocationAccess();

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: _timeout,
        ),
      );
    } catch (_) {
      throw const LocationException(
        'Your location could not be found. Check your connection and try again.',
      );
    }
  }

  Stream<Position> positionStream() async* {
    await _ensureLocationAccess();

    try {
      yield* Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (_) {
      throw const LocationException(
        'Your location could not be found. Check your connection and try again.',
      );
    }
  }

  Future<void> _ensureLocationAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(
        'Turn on location services, then try again.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException(
        'Location permission is needed to use your current location.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        'Allow location access in your device settings, then try again.',
      );
    }
  }

  Future<String> currentAddress() async {
    final position = await currentPosition();
    try {
      final response = await http
          .get(
            Uri.https('nominatim.openstreetmap.org', '/reverse', {
              'format': 'json',
              'lat': '${position.latitude}',
              'lon': '${position.longitude}',
              'zoom': '18',
              'addressdetails': '1',
            }),
            headers: const {'User-Agent': 'E-Sugid-Mobile/1.0'},
          )
          .timeout(_timeout);
      return locationLabelFromResponse(
        response.statusCode == 200 ? response.body : null,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (_) {
      throw const LocationException(
        'Your location could not be found. Check your connection and try again.',
      );
    }
  }
}

String locationLabelFromResponse(
  String? responseBody, {
  required double latitude,
  required double longitude,
}) {
  final coordinates =
      '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
  if (responseBody == null || responseBody.isEmpty) return coordinates;
  try {
    final decoded = jsonDecode(responseBody);
    if (decoded is! Map) return coordinates;
    final address = decoded['address'];
    if (address is! Map) return coordinates;
    final barangay = _firstText(address, const [
      'village',
      'suburb',
      'neighbourhood',
      'hamlet',
    ]);
    final municipality = _firstText(address, const [
      'city',
      'town',
      'municipality',
    ]);
    final parts = [
      if (barangay.isNotEmpty) barangay,
      if (municipality.isNotEmpty) municipality,
    ];
    return parts.isEmpty ? coordinates : parts.join(', ');
  } catch (_) {
    return coordinates;
  }
}

String _firstText(Map<dynamic, dynamic> values, List<String> keys) {
  for (final key in keys) {
    final value = values[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return '';
}
