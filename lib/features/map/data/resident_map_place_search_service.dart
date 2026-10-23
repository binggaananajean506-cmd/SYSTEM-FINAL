import '../../explore/data/barili_place_search_service.dart';
import '../../explore/domain/barili_destination.dart';
import 'barili_barangay_boundaries.dart';
import '../domain/resident_map_place.dart';

/// Combines the map's local places with live, Barili-bounded OSM suggestions.
class ResidentMapPlaceSearchService {
  ResidentMapPlaceSearchService({
    BariliPlaceProvider? provider,
    List<BariliDestination> destinations = bariliDestinations,
  }) : _provider = provider ?? PhotonBariliPlaceProvider(),
       _ownsProvider = provider == null,
       _destinations = destinations;

  final BariliPlaceProvider _provider;
  final bool _ownsProvider;
  final List<BariliDestination> _destinations;

  List<ResidentMapPlace> localMatches(
    String query,
    List<BariliBarangayBoundary> boundaries,
  ) {
    final terms = query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .toList(growable: false);
    if (terms.isEmpty) return const [];

    bool matches(ResidentMapPlace place) =>
        terms.every(place.searchableText.contains);

    return [
      for (final destination in _destinations)
        if (destination.mapVisible)
          ResidentMapPlace.fromDestination(destination),
      for (final boundary in boundaries)
        ResidentMapPlace.fromBarangay(boundary),
    ].where(matches).toList(growable: false);
  }

  Future<List<ResidentMapPlace>> remoteMatches(String query) async {
    if (query.trim().length < 2) return const [];
    final suggestions = await _provider.search(query.trim());
    return [
      for (final suggestion in suggestions)
        ?ResidentMapPlace.fromSuggestion(suggestion),
    ];
  }

  /// Optional enrichment adds an OSM image, hours, phone, and website.
  Future<ResidentMapPlace> loadDetails(ResidentMapPlace place) async {
    final suggestion = place.suggestion;
    if (suggestion == null) return place;
    final details = await _provider.loadPlace(suggestion);
    if (details.position == null) return place;
    return ResidentMapPlace.fromExplorePlace(
      details,
      category: place.category,
      suggestion: suggestion,
    );
  }

  void dispose() {
    if (_ownsProvider) _provider.dispose();
  }
}
