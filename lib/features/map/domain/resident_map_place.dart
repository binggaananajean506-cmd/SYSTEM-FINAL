import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../explore/domain/barili_destination.dart';
import '../../explore/domain/explore_place.dart';
import '../data/barili_barangay_boundaries.dart';

/// Categories shown by the resident map. Explore keeps its own categories.
enum ResidentMapPlaceCategory {
  barangay('Barangays', Icons.location_city_rounded),
  governmentOffice('Government Offices', Icons.account_balance_rounded),
  school('Schools', Icons.school_rounded),
  healthFacility('Health Facilities', Icons.local_hospital_rounded),
  touristSpot('Tourist Spots', Icons.landscape_rounded),
  market('Markets', Icons.storefront_rounded),
  religiousPlace('Religious Places', Icons.church_rounded),
  organization('Organizations', Icons.groups_rounded),
  foodAndDining('Food & Dining', Icons.restaurant_rounded),
  accommodation('Accommodation', Icons.hotel_rounded),
  other('Other Places', Icons.place_rounded);

  const ResidentMapPlaceCategory(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// A place the map can search, select, route to, and show in its details page.
class ResidentMapPlace {
  const ResidentMapPlace({
    required this.id,
    required this.name,
    required this.address,
    required this.category,
    required this.position,
    required this.description,
    this.photos = const [],
    this.sourceLabel,
    this.sourceUrl,
    this.openingHours,
    this.contact,
    this.officialPageUrl,
    this.suggestion,
    this.searchKeywords = '',
  });

  final String id;
  final String name;
  final String address;
  final ResidentMapPlaceCategory category;
  final LatLng position;
  final String description;
  final List<BariliDestinationPhoto> photos;
  final String? sourceLabel;
  final String? sourceUrl;
  final String? openingHours;
  final String? contact;
  final String? officialPageUrl;

  /// Kept only for optional detail enrichment after selecting a live result.
  final ExplorePlaceSuggestion? suggestion;
  final String searchKeywords;

  String get searchableText =>
      '$name $address ${category.label} $description $searchKeywords'
          .toLowerCase();

  factory ResidentMapPlace.fromDestination(BariliDestination destination) {
    final tags = destination.tags.join(' ').toLowerCase();
    final category = switch (destination.category) {
      BariliDestinationCategory.food =>
        tags.contains('market')
            ? ResidentMapPlaceCategory.market
            : ResidentMapPlaceCategory.foodAndDining,
      BariliDestinationCategory.stays => ResidentMapPlaceCategory.accommodation,
      BariliDestinationCategory.culture =>
        tags.contains('government') || tags.contains('municipal hall')
            ? ResidentMapPlaceCategory.governmentOffice
            : tags.contains('market')
            ? ResidentMapPlaceCategory.market
            : tags.contains('church') || tags.contains('shrine')
            ? ResidentMapPlaceCategory.religiousPlace
            : ResidentMapPlaceCategory.touristSpot,
      _ => ResidentMapPlaceCategory.touristSpot,
    };
    return ResidentMapPlace(
      id: 'curated:${destination.id}',
      name: destination.name,
      address: destination.addressText,
      category: category,
      position: destination.position,
      description: destination.description,
      photos: destination.photos,
      sourceLabel: destination.informationSourceLabel,
      sourceUrl: destination.informationSourceUrl,
      searchKeywords: '${destination.summary} ${destination.tags.join(' ')}',
    );
  }

  /// Returns null when an external suggestion has no usable coordinates.
  static ResidentMapPlace? fromSuggestion(ExplorePlaceSuggestion suggestion) {
    final position = suggestion.position;
    if (position == null) return null;
    return ResidentMapPlace(
      id: 'osm:${suggestion.providerId}',
      name: suggestion.name,
      address: suggestion.formattedAddress,
      category: residentMapCategoryForOsmFeature(
        suggestion.featureKey,
        suggestion.featureValue,
      ),
      position: position,
      description: 'A place listed in Barili, Cebu on OpenStreetMap.',
      sourceLabel: 'OpenStreetMap',
      sourceUrl: suggestion.sourceUrl,
      suggestion: suggestion,
    );
  }

  factory ResidentMapPlace.fromExplorePlace(
    ExplorePlace place, {
    ResidentMapPlaceCategory? category,
    ExplorePlaceSuggestion? suggestion,
  }) {
    final position = place.position;
    if (position == null) {
      throw ArgumentError.value(place.position, 'place.position');
    }
    return ResidentMapPlace(
      id: place.id.startsWith('osm:') || place.id.startsWith('curated:')
          ? place.id
          : 'osm:${place.id}',
      name: place.name,
      address: place.formattedAddress,
      category: category ?? ResidentMapPlaceCategory.other,
      position: position,
      description: place.description,
      photos: place.photos,
      sourceLabel: place.sourceLabel,
      sourceUrl: place.sourceUrl,
      openingHours: place.openingHours,
      contact: place.contact,
      officialPageUrl: place.officialPageUrl,
      suggestion: suggestion,
      searchKeywords: place.summary,
    );
  }

  factory ResidentMapPlace.fromBarangay(BariliBarangayBoundary barangay) {
    return ResidentMapPlace(
      id: 'barangay:${barangay.psgcCode}',
      name: barangay.name,
      address: 'Barangay ${barangay.name}, Barili, Cebu',
      category: ResidentMapPlaceCategory.barangay,
      position: barangay.markerPosition,
      description: 'Barangay ${barangay.name} in Barili, Cebu.',
      searchKeywords: 'barangay Barili',
    );
  }
}

ResidentMapPlaceCategory residentMapCategoryForOsmFeature(
  String featureKey,
  String featureValue,
) {
  final key = featureKey.trim().toLowerCase();
  final value = featureValue.trim().toLowerCase();
  if ((key == 'amenity' &&
          const {
            'townhall',
            'public_building',
            'courthouse',
            'police',
            'fire_station',
            'post_office',
          }.contains(value)) ||
      (key == 'office' &&
          const {'government', 'administrative'}.contains(value))) {
    return ResidentMapPlaceCategory.governmentOffice;
  }
  if (key == 'amenity' &&
      const {
        'school',
        'college',
        'university',
        'kindergarten',
        'childcare',
      }.contains(value)) {
    return ResidentMapPlaceCategory.school;
  }
  if ((key == 'amenity' &&
          const {
            'hospital',
            'clinic',
            'doctors',
            'dentist',
            'pharmacy',
          }.contains(value)) ||
      key == 'healthcare') {
    return ResidentMapPlaceCategory.healthFacility;
  }
  if ((key == 'amenity' && value == 'marketplace') ||
      (key == 'shop' &&
          const {
            'supermarket',
            'convenience',
            'mall',
            'department_store',
            'general',
            'greengrocer',
          }.contains(value))) {
    return ResidentMapPlaceCategory.market;
  }
  if ((key == 'amenity' && value == 'place_of_worship') ||
      (key == 'building' &&
          const {'church', 'chapel', 'mosque', 'temple'}.contains(value))) {
    return ResidentMapPlaceCategory.religiousPlace;
  }
  if ((key == 'office' &&
          const {
            'ngo',
            'association',
            'company',
            'foundation',
          }.contains(value)) ||
      (key == 'amenity' &&
          const {'community_centre', 'social_facility'}.contains(value)) ||
      key == 'club') {
    return ResidentMapPlaceCategory.organization;
  }
  if (key == 'amenity' &&
      const {
        'restaurant',
        'cafe',
        'fast_food',
        'food_court',
        'bar',
        'ice_cream',
      }.contains(value)) {
    return ResidentMapPlaceCategory.foodAndDining;
  }
  if ((key == 'tourism' &&
          const {
            'hotel',
            'guest_house',
            'hostel',
            'motel',
            'resort',
            'chalet',
            'camp_site',
          }.contains(value)) ||
      (key == 'building' && value == 'hotel')) {
    return ResidentMapPlaceCategory.accommodation;
  }
  if (const {
    'tourism',
    'historic',
    'heritage',
    'natural',
    'waterway',
    'leisure',
  }.contains(key)) {
    return ResidentMapPlaceCategory.touristSpot;
  }
  return ResidentMapPlaceCategory.other;
}
