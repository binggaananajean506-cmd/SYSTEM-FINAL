import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../map/data/barili_barangay_boundaries.dart';
import '../domain/barili_destination.dart';
import '../domain/explore_place.dart';

class BariliPlaceSearchException implements Exception {
  const BariliPlaceSearchException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class BariliPlaceProvider {
  Future<List<ExplorePlaceSuggestion>> search(String query);

  Future<ExplorePlace> loadPlace(ExplorePlaceSuggestion suggestion);

  void dispose();
}

/// OpenStreetMap-backed place search for the resident Explore Barili feature.
///
/// Photon provides type-ahead results. Its bounding box is the outer extent of
/// the municipality's bundled PSA barangay polygons, preventing distant Cebu
/// results from taking over the suggestion list. Nominatim is used only after
/// selection to retrieve optional OSM tags such as hours, phone and website.
class PhotonBariliPlaceProvider implements BariliPlaceProvider {
  PhotonBariliPlaceProvider({
    http.Client? client,
    Future<List<BariliBarangayBoundary>> Function() boundaryLoader =
        loadBariliBarangayBoundaries,
  }) : _boundaryFuture = boundaryLoader(),
       _client = client ?? http.Client(),
       _ownsClient = client == null;

  static const Duration _timeout = Duration(seconds: 10);
  static const double _minLongitude = 123.466798;
  static const double _minLatitude = 10.039378;
  static const double _maxLongitude = 123.600014;
  static const double _maxLatitude = 10.186907;
  static const String _userAgent =
      'E-SUGID-Mobile/1.0 (Barili resident local discovery)';

  final http.Client _client;
  final bool _ownsClient;
  final Future<List<BariliBarangayBoundary>> _boundaryFuture;

  @override
  Future<List<ExplorePlaceSuggestion>> search(String query) async {
    final input = query.trim();
    if (input.length < 2) return const [];

    final uri = Uri.https('photon.komoot.io', '/api/', {
      'q': input,
      'bbox': '$_minLongitude,$_minLatitude,$_maxLongitude,$_maxLatitude',
      'lat': '10.1114',
      'lon': '123.5113',
      'zoom': '11',
      'location_bias_scale': '0.15',
      'countrycode': 'PH',
      'limit': '8',
      'lang': 'en',
    });

    try {
      final response = await _client
          .get(uri, headers: const {'User-Agent': _userAgent})
          .timeout(_timeout);
      if (response.statusCode != 200) {
        throw const BariliPlaceSearchException(
          'Place search is temporarily unavailable.',
        );
      }
      final rectangularMatches = parsePhotonBariliSuggestions(response.body);
      final boundaries = await _boundaryFuture;
      return rectangularMatches
          .where(
            (place) =>
                place.position != null &&
                boundaries.any(
                  (boundary) => boundary.contains(place.position!),
                ),
          )
          .toList(growable: false);
    } on BariliPlaceSearchException {
      rethrow;
    } catch (_) {
      throw const BariliPlaceSearchException(
        'Could not search places. Check your connection and try again.',
      );
    }
  }

  @override
  Future<ExplorePlace> loadPlace(ExplorePlaceSuggestion suggestion) async {
    final basePlace = explorePlaceFromSuggestion(suggestion);
    Map<String, dynamic>? details;
    final osmType = suggestion.osmType.toUpperCase();
    if (const {'N', 'W', 'R'}.contains(osmType) &&
        suggestion.osmId.isNotEmpty) {
      final uri = Uri.https('nominatim.openstreetmap.org', '/lookup', {
        'osm_ids': '$osmType${suggestion.osmId}',
        'format': 'jsonv2',
        'addressdetails': '1',
        'extratags': '1',
        'namedetails': '1',
        'accept-language': 'en',
      });
      try {
        final response = await _client
            .get(uri, headers: const {'User-Agent': _userAgent})
            .timeout(_timeout);
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
            details = Map<String, dynamic>.from(decoded.first as Map);
          }
        }
      } catch (_) {
        // The selected Photon result already includes its authoritative ID,
        // address and coordinates, so optional enrichment may fail safely.
      }
    }

    final extra = details?['extratags'] is Map
        ? Map<String, dynamic>.from(details!['extratags'] as Map)
        : const <String, dynamic>{};
    final openingHours = _firstText(extra, const ['opening_hours']);
    final contact = _firstText(extra, const [
      'contact:phone',
      'phone',
      'contact:mobile',
    ]);
    final website = _safeWebUrl(
      _firstText(extra, const ['contact:website', 'website', 'url']),
    );
    final imageUrl = _safeImageUrl(_firstText(extra, const ['image']));
    final category =
        suggestion.category ??
        categoryForOsmFeature(suggestion.featureKey, suggestion.featureValue);

    return ExplorePlace(
      id: basePlace.id,
      name: basePlace.name,
      category: category,
      formattedAddress: basePlace.formattedAddress,
      summary: basePlace.summary,
      description: basePlace.description,
      position: basePlace.position,
      photos: imageUrl == null
          ? const []
          : [
              BariliDestinationPhoto.network(
                url: imageUrl,
                credit: 'OpenStreetMap place image',
                sourceUrl: suggestion.sourceUrl,
              ),
            ],
      openingHours: openingHours.isEmpty ? null : openingHours,
      contact: contact.isEmpty ? null : contact,
      officialPageUrl: website,
      sourceLabel: 'OpenStreetMap',
      sourceUrl: suggestion.sourceUrl,
    );
  }

  @override
  void dispose() {
    if (_ownsClient) _client.close();
  }
}

ExplorePlace explorePlaceFromSuggestion(ExplorePlaceSuggestion suggestion) {
  final category =
      suggestion.category ??
      categoryForOsmFeature(suggestion.featureKey, suggestion.featureValue);
  return ExplorePlace(
    id: suggestion.providerId,
    name: suggestion.name,
    category: category,
    formattedAddress: suggestion.formattedAddress,
    summary: suggestion.formattedAddress,
    description: 'A real place listed in Barili, Cebu on OpenStreetMap.',
    position: suggestion.position,
    photos: const [],
    sourceLabel: 'OpenStreetMap',
    sourceUrl: suggestion.sourceUrl,
  );
}

List<ExplorePlaceSuggestion> parsePhotonBariliSuggestions(String responseBody) {
  final decoded = jsonDecode(responseBody);
  if (decoded is! Map || decoded['features'] is! List) return const [];

  final results = <ExplorePlaceSuggestion>[];
  final seenIds = <String>{};
  for (final rawFeature in decoded['features'] as List<dynamic>) {
    if (rawFeature is! Map || rawFeature['properties'] is! Map) continue;
    final properties = Map<String, dynamic>.from(
      rawFeature['properties'] as Map,
    );
    final geometry = rawFeature['geometry'];
    final coordinates = geometry is Map ? geometry['coordinates'] : null;
    final longitude = coordinates is List && coordinates.isNotEmpty
        ? _asDouble(coordinates[0])
        : null;
    final latitude = coordinates is List && coordinates.length > 1
        ? _asDouble(coordinates[1])
        : null;
    if (longitude == null ||
        latitude == null ||
        longitude < PhotonBariliPlaceProvider._minLongitude ||
        longitude > PhotonBariliPlaceProvider._maxLongitude ||
        latitude < PhotonBariliPlaceProvider._minLatitude ||
        latitude > PhotonBariliPlaceProvider._maxLatitude) {
      continue;
    }

    final name = _firstText(properties, const ['name']);
    final osmType = _firstText(properties, const ['osm_type']);
    final osmId = _firstText(properties, const ['osm_id']);
    if (name.isEmpty || osmType.isEmpty || osmId.isEmpty) continue;
    final providerId = '${osmType.toUpperCase()}:$osmId';
    if (!seenIds.add(providerId)) continue;

    final featureKey = _firstText(properties, const ['osm_key']);
    final featureValue = _firstText(properties, const ['osm_value']);
    results.add(
      ExplorePlaceSuggestion(
        providerId: providerId,
        osmType: osmType,
        osmId: osmId,
        name: name,
        formattedAddress: _bariliAddress(properties),
        latitude: latitude,
        longitude: longitude,
        featureKey: featureKey,
        featureValue: featureValue,
        category: categoryForOsmFeature(featureKey, featureValue),
      ),
    );
  }
  return List.unmodifiable(results.take(8));
}

BariliDestinationCategory? categoryForOsmFeature(String key, String value) {
  final normalizedKey = key.trim().toLowerCase();
  final normalizedValue = value.trim().toLowerCase();
  if (normalizedKey == 'tourism' &&
      const {
        'hotel',
        'guest_house',
        'hostel',
        'motel',
        'resort',
        'chalet',
        'camp_site',
      }.contains(normalizedValue)) {
    return BariliDestinationCategory.stays;
  }
  if (const {'natural', 'waterway', 'leisure'}.contains(normalizedKey)) {
    if (normalizedValue == 'beach') {
      return BariliDestinationCategory.beaches;
    }
    if (const {'sports_centre', 'pitch', 'fishing'}.contains(normalizedValue)) {
      return BariliDestinationCategory.activities;
    }
    return BariliDestinationCategory.nature;
  }
  if (normalizedKey == 'amenity' &&
      const {
        'restaurant',
        'cafe',
        'fast_food',
        'food_court',
        'bar',
        'ice_cream',
      }.contains(normalizedValue)) {
    return BariliDestinationCategory.food;
  }
  if (const {'historic', 'heritage'}.contains(normalizedKey) ||
      (normalizedKey == 'amenity' && normalizedValue == 'place_of_worship')) {
    return BariliDestinationCategory.culture;
  }
  if (normalizedKey == 'shop' ||
      (normalizedKey == 'amenity' && normalizedValue == 'marketplace')) {
    return BariliDestinationCategory.culture;
  }
  return null;
}

String _bariliAddress(Map<String, dynamic> properties) {
  final locality = _firstText(properties, const [
    'district',
    'locality',
    'city',
    'county',
  ]);
  final parts = <String>[];
  void add(String value) {
    final cleaned = value.trim();
    if (cleaned.isEmpty ||
        parts.any((item) => item.toLowerCase() == cleaned.toLowerCase())) {
      return;
    }
    parts.add(cleaned);
  }

  if (locality.toLowerCase() != 'barili') add(locality);
  add('Barili');
  add('Cebu');
  add('Philippines');
  return parts.join(', ');
}

String _firstText(Map<String, dynamic> values, List<String> keys) {
  for (final key in keys) {
    final value = values[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return '';
}

double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

String? _safeWebUrl(String value) {
  if (value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  if (uri == null || !const {'http', 'https'}.contains(uri.scheme)) return null;
  return uri.toString();
}

String? _safeImageUrl(String value) {
  final url = _safeWebUrl(value);
  if (url == null) return null;
  final path = Uri.parse(url).path.toLowerCase();
  if (!RegExp(r'\.(jpe?g|png|webp)$').hasMatch(path)) return null;
  return url;
}
