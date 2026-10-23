import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/travel_route.dart';

Uri googleMapsDirectionsUri(
  LatLng destination, {
  TravelMode mode = TravelMode.car,
}) {
  return Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': '${destination.latitude},${destination.longitude}',
    'travelmode': mode.googleWebTravelMode,
  });
}

/// Starts turn-by-turn navigation in the Google Maps app, falling back to the
/// Google Maps directions page. Returns false when neither could be opened.
Future<bool> openGoogleMapsNavigation(
  LatLng destination, {
  TravelMode mode = TravelMode.car,
}) async {
  final navigationUri = Uri.parse(
    'google.navigation:q=${destination.latitude},${destination.longitude}'
    '&mode=${mode.googleNavigationMode}',
  );
  try {
    if (await launchUrl(navigationUri, mode: LaunchMode.externalApplication)) {
      return true;
    }
  } catch (_) {
    // No app handles google.navigation: links; use the web link instead.
  }
  return launchUrl(
    googleMapsDirectionsUri(destination, mode: mode),
    mode: LaunchMode.externalApplication,
  );
}
