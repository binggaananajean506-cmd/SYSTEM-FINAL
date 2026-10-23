import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'barili_destination.dart';

class ExplorePlaceSuggestion {
  const ExplorePlaceSuggestion({
    required this.providerId,
    required this.osmType,
    required this.osmId,
    required this.name,
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
    required this.featureKey,
    required this.featureValue,
    this.category,
  });

  final String providerId;
  final String osmType;
  final String osmId;
  final String name;
  final String formattedAddress;
  final double? latitude;
  final double? longitude;
  final String featureKey;
  final String featureValue;
  final BariliDestinationCategory? category;

  LatLng? get position {
    final lat = latitude;
    final lon = longitude;
    return lat == null || lon == null ? null : LatLng(lat, lon);
  }

  String get sourceUrl {
    final type = switch (osmType.toUpperCase()) {
      'N' => 'node',
      'W' => 'way',
      'R' => 'relation',
      _ => '',
    };
    return type.isEmpty || osmId.isEmpty
        ? 'https://www.openstreetmap.org/'
        : 'https://www.openstreetmap.org/$type/$osmId';
  }
}

class ExplorePlace {
  const ExplorePlace({
    required this.id,
    required this.name,
    required this.formattedAddress,
    required this.summary,
    required this.description,
    required this.photos,
    required this.sourceLabel,
    required this.sourceUrl,
    this.category,
    this.position,
    this.visitNote,
    this.openingHours,
    this.contact,
    this.officialPageUrl,
  });

  factory ExplorePlace.fromDestination(BariliDestination destination) {
    return ExplorePlace(
      id: destination.id,
      name: destination.name,
      category: destination.category,
      formattedAddress: destination.addressText,
      summary: destination.summary,
      description: destination.description,
      visitNote: destination.visitNote,
      position: destination.position,
      photos: destination.photos,
      sourceLabel: destination.informationSourceLabel,
      sourceUrl: destination.informationSourceUrl,
    );
  }

  final String id;
  final String name;
  final BariliDestinationCategory? category;
  final String formattedAddress;
  final String summary;
  final String description;
  final String? visitNote;
  final LatLng? position;
  final List<BariliDestinationPhoto> photos;
  final String? openingHours;
  final String? contact;
  final String? officialPageUrl;
  final String sourceLabel;
  final String sourceUrl;

  String get categoryLabel => category?.label ?? 'Local Place';

  IconData get categoryIcon => category?.icon ?? Icons.place_rounded;
}
