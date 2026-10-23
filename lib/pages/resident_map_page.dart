import 'dart:async';
import '../app/theme/map_style.dart';
import 'dart:ui' as ui;

import 'package:esugid/core/widgets/app_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart' as geo;
import 'package:shared_preferences/shared_preferences.dart';

import '../auth_service.dart';
import '../barili_barangays.dart';
import '../core/location/location_service.dart';
import '../features/explore/domain/barili_destination.dart';
import '../features/map/data/barili_barangay_boundaries.dart';
import '../features/map/data/resident_map_place_search_service.dart';
import '../features/map/domain/resident_map_place.dart';
import '../features/map/domain/resident_navigation_progress.dart';
import '../features/map/presentation/resident_map_place_details_page.dart';
import '../features/navigation/data/route_service.dart';
import '../features/navigation/domain/travel_route.dart';
import '../features/navigation/presentation/places_to_visit_sheet.dart';
import '../features/navigation/presentation/route_preview_card.dart';
import '../submission_service.dart';
import '../widgets/esugid_page_header.dart';

class ResidentMapPage extends StatefulWidget {
  const ResidentMapPage({
    super.key,
    this.initialFocus,
    this.focusLabel,
    this.routeDestination,
    this.boundaryLoader = loadBariliBarangayBoundaries,
    this.locationService = const LocationService(),
    this.routeService = const FirebaseRouteService(),
    this.placeSearchService,
    this.travelMarkerFactory,
  });

  final geo.LatLng? initialFocus;
  final String? focusLabel;

  /// Opens the map showing the route from the resident to this place.
  final BariliDestination? routeDestination;
  final Future<List<BariliBarangayBoundary>> Function() boundaryLoader;
  final LocationService locationService;
  final RouteService routeService;
  final ResidentMapPlaceSearchService? placeSearchService;

  /// Allows the platform-rendered travel icon to be replaced in widget tests.
  final gmaps.BitmapDescriptor Function(TravelMode)? travelMarkerFactory;

  @override
  State<ResidentMapPage> createState() => _ResidentMapPageState();
}

enum _MapStyle { street, satellite }


class _ResidentMapPageState extends State<ResidentMapPage> {
  static const geo.LatLng _bariliCenter = geo.LatLng(10.1114, 123.5113);
  static const double _minZoom = 10;
  static const double _maxZoom = 21;

  gmaps.GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionSubscription;
  late final ResidentMapPlaceSearchService _placeSearchService;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  List<BariliBarangayBoundary> _barangays = const [];
  geo.LatLng? _currentLocation;
  String? _selectedBarangayName;
  String? _boundaryLoadError;
  String? _locationError;
  _MapStyle _mapStyle = _MapStyle.street;
  bool _isLoadingBoundaries = true;
  bool _isLocating = true;
  bool _mapReady = false;
  bool _showBarangayMarkers = false;
  bool _showIssueMarkers = false;
  bool _showPlaceMarkers = false;
  ResidentMapPlaceCategory? _selectedPlaceCategory;
  List<ResidentMapPlace> _categoryPlaces = const [];
  bool _categoryLoading = false;
  List<ResidentMapPlace> _remoteSuggestions = const [];
  bool _searchLoading = false;
  String? _searchError;
  int _searchRequest = 0;
  int _categoryRequest = 0;
  double _currentZoom = 12.2;

  static const String _travelModePreferenceKey = 'resident_map.travel_mode';
  ResidentMapPlace? _routeDestination;
  RouteOptions? _routeOptions;
  String? _routeError;
  bool _routeLoading = false;
  int _routeRequest = 0;
  TravelMode _travelMode = TravelMode.motorcycle;
  bool _isNavigating = false;
  bool _hasArrived = false;
  bool _isNavigationMinimized = false;
  bool _isAudioMuted = false;
  ResidentNavigationProgress? _navigationProgress;
  gmaps.BitmapDescriptor? _travelMarkerIcon;
  gmaps.BitmapDescriptor? _currentLocationMarkerIcon;

  TravelRoute? get _selectedRoute => _routeOptions?[_travelMode];

  BariliBarangayBoundary? get _selectedBarangay {
    final selectedName = _selectedBarangayName;
    if (selectedName == null) return null;
    for (final barangay in _barangays) {
      if (barangay.name == selectedName) return barangay;
    }
    return null;
  }

  BariliBarangayBoundary? get _currentBarangay {
    final current = _currentLocation;
    if (current == null) return null;
    for (final barangay in _barangays) {
      if (barangay.contains(current)) return barangay;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _placeSearchService =
        widget.placeSearchService ?? ResidentMapPlaceSearchService();
    _searchController.addListener(_onSearchChanged);
    _prepareCurrentLocationMarker();
    _loadBoundaries();
    _restoreTravelMode();
    final routeDestination = widget.routeDestination;
    if (routeDestination != null) {
      _showRouteTo(ResidentMapPlace.fromDestination(routeDestination));
    } else {
      _loadCurrentLocation();
    }
  }

  Future<void> _restoreTravelMode() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = TravelMode.fromId(
        preferences.getString(_travelModePreferenceKey),
      );
      if (saved != null && mounted) setState(() => _travelMode = saved);
    } catch (_) {
      // Keep the default mode when preferences are unavailable.
    }
  }

  Future<void> _loadBoundaries() async {
    try {
      final boundaries = await widget.boundaryLoader();
      final loadedNames = boundaries.map((item) => item.name).toSet();
      final expectedNames = bariliBarangays.toSet();
      if (boundaries.length != expectedNames.length ||
          !loadedNames.containsAll(expectedNames)) {
        throw StateError('The Barili boundary file is incomplete.');
      }
      if (!mounted) return;
      setState(() {
        _barangays = boundaries;
        _isLoadingBoundaries = false;
        _boundaryLoadError = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_mapReady || _routeDestination != null) return;
        if (widget.initialFocus != null) {
          _moveCamera(widget.initialFocus!, 16);
        } else if (_currentLocation != null) {
          _moveCamera(_currentLocation!, 16);
        } else if (!_isLocating) {
          _fitAllBarangays();
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingBoundaries = false;
        _boundaryLoadError =
            'Barangay boundaries are unavailable. Try reopening the map.';
      });
    }
  }

  Future<void> _loadCurrentLocation({bool showError = false}) async {
    if (mounted) {
      setState(() {
        _isLocating = true;
        _locationError = null;
      });
    }
    try {
      final position = await widget.locationService.currentPosition();
      if (!mounted) return;
      final location = geo.LatLng(position.latitude, position.longitude);
      _applyLivePosition(location);
      _startLocationUpdates();
      if (_mapReady &&
          widget.initialFocus == null &&
          _routeDestination == null) {
        await _moveCamera(location, 16);
      }
    } on LocationException catch (error) {
      if (!mounted) return;
      _clearLiveLocation(error.message);
      if (_mapReady &&
          widget.initialFocus == null &&
          _routeDestination == null &&
          _barangays.isNotEmpty) {
        await _fitAllBarangays();
      }
      if (showError) _showLocationMessage(error.message);
    }
  }

  void _startLocationUpdates() {
    if (_positionSubscription != null) return;
    _positionSubscription = widget.locationService.positionStream().listen(
      (position) =>
          _applyLivePosition(geo.LatLng(position.latitude, position.longitude)),
      onError: (Object error) {
        if (!mounted) return;
        _positionSubscription = null;
        _clearLiveLocation(
          error is LocationException
              ? error.message
              : 'Your live location is unavailable. Try again.',
        );
      },
      onDone: () {
        _positionSubscription = null;
        if (mounted) {
          _clearLiveLocation(
            'Live location stopped. Tap Recenter to try again.',
          );
        }
      },
      cancelOnError: true,
    );
  }

  void _clearLiveLocation(String message) {
    setState(() {
      _currentLocation = null;
      _isLocating = false;
      _locationError = message;
      _isNavigating = false;
      _hasArrived = false;
      _navigationProgress = null;
      if (_routeDestination != null) _routeError = message;
    });
  }

  void _applyLivePosition(geo.LatLng location) {
    if (!mounted) return;
    final route = _selectedRoute;
    final destination = _routeDestination;
    final progress = _isNavigating && route != null && destination != null
        ? ResidentNavigationProgress.fromPosition(
            route: route,
            current: location,
            destination: destination.position,
          )
        : null;
    setState(() {
      _currentLocation = location;
      _isLocating = false;
      _locationError = null;
      if (_routeOptions != null) _routeError = null;
      _navigationProgress = progress;
      if (progress?.arrived == true) {
        _isNavigating = false;
        _hasArrived = true;
      }
    });
    if (_isNavigating || _hasArrived) {
      _moveCamera(location, 17);
    }
    if (_mapReady && _currentLocationMarkerIcon == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (mounted && _currentLocation != null) {
          try {
            await _mapController?.showMarkerInfoWindow(
              const gmaps.MarkerId('resident-current-location'),
            );
          } catch (_) {
            // The marker may still be arriving on the native map.
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedBarangay = _selectedBarangay;
    final routeDestination = _routeDestination;
    final bottomControlOffset = routeDestination != null
        ? _isNavigating || _hasArrived
              ? (_isNavigationMinimized ? 72.0 : 170.0)
              : 292.0
        : selectedBarangay == null
        ? (_currentLocation != null ? 76.0 : 28.0)
        : 154.0;
    final mediaQuery = MediaQuery.of(context);
    final headerExtent = responsiveCompactESugidPageHeaderExtent(mediaQuery);

    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            StreamBuilder<List<Submission>>(
              stream: AuthService.currentUser == null
                  ? Stream<List<Submission>>.value(const [])
                  : SubmissionService.submissionsForUser(
                      AuthService.currentUser!.uid,
                    ),
              builder: (context, snapshot) {
                final issueMarkers =
                    _showIssueMarkers && routeDestination == null
                    ? (snapshot.data ?? const <Submission>[])
                          .where(
                            (item) => item.status.toLowerCase() != 'resolved',
                          )
                          .take(30)
                          .map(_buildIssueMapMarker)
                    : const Iterable<gmaps.Marker>.empty();
                return gmaps.GoogleMap(
                  key: const ValueKey('resident-google-map'),
                  initialCameraPosition: gmaps.CameraPosition(
                    target: _toGoogle(widget.initialFocus ?? _bariliCenter),
                    zoom: widget.initialFocus != null ? 16 : 13.2,
                  ),
                  mapType: _mapStyle == _MapStyle.satellite
                      ? gmaps.MapType.hybrid
                      : gmaps.MapType.normal,
                  style: _mapStyle == _MapStyle.satellite
                      ? null
                      : buildESugidMapStyle(Theme.of(context).brightness),
                  minMaxZoomPreference: const gmaps.MinMaxZoomPreference(
                    _minZoom,
                    _maxZoom,
                  ),
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  buildingsEnabled: true,
                  indoorViewEnabled: true,
                  compassEnabled: true,
                  trafficEnabled: false,
                  padding: EdgeInsets.only(
                    top: headerExtent + 112,
                    bottom: bottomControlOffset + 54,
                  ),
                  polygons: _boundaryPolygons,
                  polylines: _routePolylines,
                  markers: routeDestination != null
                      ? {
                          _buildRouteDestinationMarker(routeDestination),
                          if (_currentLocation != null)
                            _buildCurrentLocationMarker(),
                          if (_isNavigating && _navigationProgress != null)
                            _buildTravelMarker(),
                        }
                      : {
                          if (_currentLocation != null)
                            _buildCurrentLocationMarker(),
                          if (_showBarangayMarkers &&
                              (_selectedPlaceCategory == null ||
                                  _selectedPlaceCategory ==
                                      ResidentMapPlaceCategory.barangay))
                            ..._barangayMarkers,
                          if (_showPlaceMarkers) ..._placeMarkers,
                          ...issueMarkers,
                        },
                  onCameraMove: (position) {
                    if ((position.zoom - _currentZoom).abs() < 0.05) return;
                    setState(() => _currentZoom = position.zoom);
                  },
                  onMapCreated: (controller) async {
                    _mapController = controller;
                    _mapReady = true;
                    if (_routeDestination != null) {
                      await _fitRoute();
                    } else if (widget.initialFocus != null) {
                      await _moveCamera(widget.initialFocus!, 16);
                    } else if (_currentLocation != null) {
                      await _moveCamera(_currentLocation!, 16);
                    } else if (!_isLocating && _barangays.isNotEmpty) {
                      await _fitAllBarangays();
                    }
                    if (_currentLocation != null &&
                        _currentLocationMarkerIcon == null) {
                      try {
                        await controller.showMarkerInfoWindow(
                          const gmaps.MarkerId('resident-current-location'),
                        );
                      } catch (_) {
                        // The marker may still be arriving on the native map.
                      }
                    }
                  },
                );
              },
            ),
            Positioned(left: 0, right: 0, top: 0, child: _buildMapHeader()),
            Positioned(
              top: headerExtent - 4,
              left: 12,
              right: 12,
              child: _buildMapControls(),
            ),
            if (_searchController.text.trim().isNotEmpty)
              Positioned(
                top: headerExtent + 108,
                left: 12,
                right: 12,
                child: _buildSearchSuggestions(),
              ),
            if (_isNavigating)
              Positioned(
                top: headerExtent + 112,
                left: 12,
                right: 12,
                child: _buildNavigationBanner(),
              ),
            if (_isLoadingBoundaries || _boundaryLoadError != null)
              Positioned(
                top: headerExtent + 164,
                left: 12,
                right: 12,
                child: _buildBoundaryStatus(),
              ),
            Positioned(
              right: 12,
              bottom: bottomControlOffset,
              child: _buildZoomControls(),
            ),
            if (routeDestination != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: SafeArea(
                  top: false,
                  child: _hasArrived
                      ? _buildArrivalCard(routeDestination)
                      : _isNavigating
                      ? _buildNavigationCard(routeDestination)
                      : RoutePreviewCard(
                          destination: routeDestination,
                          options: _routeOptions,
                          selectedMode: _travelMode,
                          loading: _routeLoading,
                          error: _routeError,
                          onModeChanged: _selectTravelMode,
                          onRetry: () => _showRouteTo(routeDestination),
                          onClose: _closeRoute,
                          onDirections: _fitRoute,
                          onStartNavigation: _startNavigation,
                          onShowDetails: () =>
                              _openDestination(routeDestination),
                        ),
                ),
              )
            else if (selectedBarangay != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: SafeArea(
                  top: false,
                  child: _buildSelectedBarangayCard(selectedBarangay),
                ),
              )
            else if (_currentLocation != null)
              Positioned(
                left: 12,
                right: 76,
                bottom: 12,
                child: SafeArea(
                  top: false,
                  child: _buildCurrentLocationCard()),
              )
            else if (_currentLocation == null)
              Positioned(
                left: 12,
                right: 72,
                bottom: 12,
                child: SafeArea(top: false, child: _buildLocationStatus()),
              ),
          ],
        ),
      ),
    );
  }

  Set<gmaps.Polygon> get _boundaryPolygons {
    final polygons = <gmaps.Polygon>{};
    for (final barangay in _barangays) {
      for (var index = 0; index < barangay.parts.length; index++) {
        final part = barangay.parts[index];
        final selected = _selectedBarangayName == barangay.name;
        polygons.add(
          gmaps.Polygon(
            polygonId: gmaps.PolygonId('${barangay.psgcCode}-$index'),
            points: part.outerRing.map(_toGoogle).toList(growable: false),
            holes: part.holes
                .map((hole) => hole.map(_toGoogle).toList(growable: false))
                .toList(growable: false),
            fillColor: selected
                ? context.colors.inputBackground.withValues(alpha: 0.18)
                : Colors.transparent,
            strokeColor: selected
                ? context.colors.textPrimary
                : Colors.transparent,
            strokeWidth: selected ? 3 : 1,
            consumeTapEvents: true,
            onTap: () {
              // Keep the route in view; the picker still changes barangay.
              if (_routeDestination == null) _selectBarangay(barangay);
            },
          ),
        );
      }
    }
    return polygons;
  }

  Set<gmaps.Marker> get _barangayMarkers {
    final selectedBarangay = _selectedBarangay;
    if (selectedBarangay == null &&
        _selectedPlaceCategory != ResidentMapPlaceCategory.barangay &&
        _currentZoom < 13.5) {
      return const {};
    }
    final visibleBarangays = selectedBarangay == null
        ? _barangays
        : <BariliBarangayBoundary>[selectedBarangay];
    return visibleBarangays.map((barangay) {
      final selected = selectedBarangay?.name == barangay.name;
      return gmaps.Marker(
        markerId: gmaps.MarkerId('barangay-${barangay.psgcCode}'),
        position: _toGoogle(barangay.markerPosition),
        icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
          selected
              ? gmaps.BitmapDescriptor.hueGreen
              : gmaps.BitmapDescriptor.hueAzure,
        ),
        infoWindow: gmaps.InfoWindow(
          title: barangay.name,
          snippet: 'Barangay of Barili',
        ),
        onTap: () => _selectBarangay(barangay),
      );
    }).toSet();
  }

  List<ResidentMapPlace> get _visiblePlaces {
    final selected = _selectedBarangayName;
    final curated = bariliDestinations
        .where(
          (place) =>
              place.mapVisible &&
              (selected == null || place.barangay == selected),
        )
        .map(ResidentMapPlace.fromDestination);
    final places = <ResidentMapPlace>[
      ...curated,
      ..._categoryPlaces.where(
        (place) =>
            selected == null ||
            place.address.toLowerCase().contains(selected.toLowerCase()),
      ),
    ];
    final seen = <String>{};
    return places
        .where(
          (place) =>
              (_selectedPlaceCategory == null ||
                  place.category == _selectedPlaceCategory) &&
              seen.add(place.id),
        )
        .toList(growable: false);
  }

  Set<gmaps.Marker> get _placeMarkers {
    if (_selectedPlaceCategory == ResidentMapPlaceCategory.barangay) {
      return const {};
    }
    if (_currentZoom < 14 &&
        widget.focusLabel == null &&
        _selectedPlaceCategory == null) {
      return const {};
    }
    return _visiblePlaces.map(_buildPlaceMapMarker).toSet();
  }

  gmaps.Marker _buildPlaceMapMarker(ResidentMapPlace place) {
    final focused = widget.focusLabel == place.name;
    return gmaps.Marker(
      markerId: gmaps.MarkerId('place-${place.id}'),
      position: _toGoogle(place.position),
      zIndexInt: focused ? 3 : 1,
      icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
        focused
            ? gmaps.BitmapDescriptor.hueGreen
            : gmaps.BitmapDescriptor.hueViolet,
      ),
      infoWindow: gmaps.InfoWindow(
        title: place.name,
        snippet: 'Tap for directions · ${place.category.label}',
        onTap: () => _showRouteTo(place),
      ),
      onTap: () => _showRouteTo(place),
    );
  }

  gmaps.Marker _buildCurrentLocationMarker() {
    final hasCustomIcon = _currentLocationMarkerIcon != null;
    return gmaps.Marker(
      markerId: const gmaps.MarkerId('resident-current-location'),
      position: _toGoogle(_currentLocation!),
      zIndexInt: 5,
      visible: !_isNavigating,
      anchor: hasCustomIcon
          ? const Offset(54.0 / 170.0, 88.0 / 98.0)
          : const Offset(0.5, 1.0),
      icon:
          _currentLocationMarkerIcon ??
          gmaps.BitmapDescriptor.defaultMarkerWithHue(
            gmaps.BitmapDescriptor.hueRed,
          ),
      infoWindow: const gmaps.InfoWindow(title: 'You are here'),
      onTap: _showCurrentLocationDetails,
    );
  }

  Future<void> _prepareCurrentLocationMarker() async {
    try {
      // High-DPI canvas scaling for retina-sharp, anti-aliased rendering
      const double scale = 2.0;
      const double logicalWidth = 170.0;
      const double logicalHeight = 98.0;
      final pixelWidth = (logicalWidth * scale).round();
      final pixelHeight = (logicalHeight * scale).round();

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.scale(scale, scale);

      // Pin tip anchors precisely on the map surface
      const double pinTipX = 54.0;
      const double pinTipY = 88.0;
      const double pinHeadCy = 64.0;
      const double pinHeadRadius = 12.0;

      // =======================================================================
      // 1. GROUND LANDING ZONE & 3D CONTACT OCCLUSION (Map surface depth)
      // =======================================================================
      // Soft translucent green radar landing halo on the asphalt
      canvas.drawCircle(
        const Offset(pinTipX, pinTipY),
        16.0,
        Paint()
          ..shader = ui.Gradient.radial(
            const Offset(pinTipX, pinTipY),
            16.0,
            const [
              Color(0x3510B981),
              Color(0x1810B981),
              Color(0x0010B981)],
            const [0.0, 0.6, 1.0],
          ),
      );

      // Delicate concentric radar ring
      canvas.drawCircle(
        const Offset(pinTipX, pinTipY),
        11.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0x5010B981),
      );

      // Deep ground contact shadow directly under the needle tip
      canvas.drawOval(
        Rect.fromCenter(
          center: const Offset(pinTipX, pinTipY + 1.2),
          width: 14.0,
          height: 4.5,
        ),
        Paint()
          ..color = const Color(0x40000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: const Offset(pinTipX, pinTipY + 0.5),
          width: 6.0,
          height: 2.2,
        ),
        Paint()..color = const Color(0x60000000),
      );

      // =======================================================================
      // 2. 3D VOLUMETRIC RED LOCATION PIN (Spherical Shading & Enamel Luster)
      // =======================================================================
      // Curving teardrop needle path
      final pinPath = Path();
      pinPath.moveTo(pinTipX, pinTipY);
      // Left waist curve up to head tangent
      pinPath.cubicTo(
        pinTipX - 1.2,
        pinTipY - 7.0,
        pinTipX - pinHeadRadius,
        pinTipY - 14.0,
        pinTipX - pinHeadRadius,
        pinHeadCy,
      );
      // Crown arc around head
      pinPath.arcToPoint(
        const Offset(pinTipX + pinHeadRadius, pinHeadCy),
        radius: const Radius.circular(pinHeadRadius),
        clockwise: true,
      );
      // Right waist curve down to needle tip
      pinPath.cubicTo(
        pinTipX + pinHeadRadius,
        pinTipY - 14.0,
        pinTipX + 1.2,
        pinTipY - 7.0,
        pinTipX,
        pinTipY,
      );
      pinPath.close();

      // Soft ambient pin drop shadow on the ground
      canvas.drawPath(
        pinPath.shift(const Offset(1.5, 2.5)),
        Paint()
          ..color = const Color(0x30000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5),
      );

      // Volumetric 3D spherical gradient shader (Key light from upper-left)
      final pinShader = ui.Gradient.radial(
        const Offset(pinTipX - 4.5, pinHeadCy - 4.5),
        22.0,
        const [
          Color(0xFFFF6E6E), // bright coral/vermilion highlight
          Color(0xFFEF4444), // vibrant rich red
          Color(0xFFDC2626), // deep red body
          Color(0xFFB91C1C), // rich crimson
          Color(0xFF7F1D1D), // dark ambient edge shadow
        ],
        const [0.0, 0.25, 0.6, 0.85, 1.0],
      );
      canvas.drawPath(
        pinPath,
        Paint()
          ..shader = pinShader
          ..isAntiAlias = true,
      );

      // Polished top-left specular reflection rim on head
      final highlightPath = Path();
      highlightPath.arcTo(
        Rect.fromCircle(
          center: const Offset(pinTipX, pinHeadCy),
          radius: pinHeadRadius - 0.7,
        ),
        2.8,
        1.8,
        false,
      );
      canvas.drawPath(
        highlightPath,
        Paint()
          ..color = const Color(0x80FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..strokeCap = StrokeCap.round,
      );

      // Deep recessed aperture hole with bevel shadow
      canvas.drawCircle(
        const Offset(pinTipX, pinHeadCy),
        5.2,
        Paint()..color = const Color(0x35450A0A),
      );
      // Crisp white circular core
      canvas.drawCircle(
        const Offset(pinTipX, pinHeadCy),
        4.5,
        Paint()..color = Colors.white,
      );
      // Inner shadow in top-left of hole for true 3D depth
      final innerHoleShadow = Path();
      innerHoleShadow.arcTo(
        Rect.fromCircle(
          center: const Offset(pinTipX, pinHeadCy),
          radius: 4.5),
        2.6,
        2.0,
        false,
      );
      canvas.drawPath(
        innerHoleShadow,
        Paint()
          ..color = const Color(0x20000000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );

      // Sharp white contact point at tip
      canvas.drawCircle(
        const Offset(pinTipX, pinTipY),
        1.2,
        Paint()..color = const Color(0xCCFFFFFF),
      );

      // =======================================================================
      // 3. FLOATING 3D EMERALD SPEECH BUBBLE ("You are here")
      // =======================================================================
      const bubbleLeft = 48.0;
      const bubbleRight = 162.0; // width = 114
      const bubbleTop = 6.0;
      const bubbleBottom = 38.0; // height = 32
      const bubbleRadius = 16.0;

      // Pointer tail connecting the bubble down to the pin head
      const tailLeftX = 66.0;
      const tailRightX = 78.0;
      const tailTipX = 57.0;
      const tailTipY = 49.0;

      final bubblePath = Path();
      // Start at top edge after left corner
      bubblePath.moveTo(bubbleLeft + bubbleRadius, bubbleTop);
      // Top horizontal line
      bubblePath.lineTo(bubbleRight - bubbleRadius, bubbleTop);
      // Right circular end cap
      bubblePath.arcToPoint(
        const Offset(bubbleRight, bubbleTop + bubbleRadius),
        radius: const Radius.circular(bubbleRadius),
        clockwise: true,
      );
      bubblePath.arcToPoint(
        const Offset(bubbleRight - bubbleRadius, bubbleBottom),
        radius: const Radius.circular(bubbleRadius),
        clockwise: true,
      );
      // Bottom edge towards tail
      bubblePath.lineTo(tailRightX, bubbleBottom);
      // Smooth curve down to tail tip
      bubblePath.quadraticBezierTo(68.0, 44.0, tailTipX, tailTipY);
      // Smooth curve back up to bottom edge
      bubblePath.quadraticBezierTo(60.5, 43.5, tailLeftX, bubbleBottom);
      // Bottom edge to left cap
      bubblePath.lineTo(bubbleLeft + bubbleRadius, bubbleBottom);
      // Left circular end cap
      bubblePath.arcToPoint(
        const Offset(bubbleLeft, bubbleBottom - bubbleRadius),
        radius: const Radius.circular(bubbleRadius),
        clockwise: true,
      );
      bubblePath.arcToPoint(
        const Offset(bubbleLeft + bubbleRadius, bubbleTop),
        radius: const Radius.circular(bubbleRadius),
        clockwise: true,
      );
      bubblePath.close();

      // Dual-layer realistic drop shadow (Atmospheric elevation above map)
      canvas.drawPath(
        bubblePath.shift(const Offset(2.0, 4.0)),
        Paint()
          ..color = const Color(0x35000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
      canvas.drawPath(
        bubblePath.shift(const Offset(0.8, 2.0)),
        Paint()
          ..color = const Color(0x25000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      );

      // Rich emerald forest luxury gradient fill
      final bubbleGradient = ui.Gradient.linear(
        const Offset(bubbleLeft, bubbleTop),
        const Offset(bubbleRight, bubbleBottom + 10),
        const [
          Color(0xFF059669), // vibrant emerald highlight (top-left)
          Color(0xFF047857), // classic rich emerald
          Color(0xFF065F46), // deep forest green tone
          Color(0xFF064E3B), // rich deep shadow (bottom-right)
        ],
        const [0.0, 0.35, 0.75, 1.0],
      );
      canvas.drawPath(
        bubblePath,
        Paint()
          ..shader = bubbleGradient
          ..isAntiAlias = true,
      );

      // Subtle frosted glass rim stroke
      canvas.drawPath(
        bubblePath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = const Color(0x5534D399)
          ..isAntiAlias = true,
      );

      // Polished top specular highlight glint
      final glintPath = Path();
      glintPath.moveTo(bubbleLeft + bubbleRadius + 6, bubbleTop + 1.2);
      glintPath.lineTo(bubbleRight - bubbleRadius - 6, bubbleTop + 1.2);
      canvas.drawPath(
        glintPath,
        Paint()
          ..color = const Color(0x60FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round,
      );

      // =======================================================================
      // 4. ELEGANT CRISP TYPOGRAPHY ("You are here")
      // =======================================================================
      final textPainter = TextPainter(
        text: const TextSpan(
          text: 'You are here',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            shadows: [
              Shadow(
                offset: Offset(0, 1.0),
                blurRadius: 2.0,
                color: Color(0x60000000),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      // Perfectly center text horizontally & vertically inside the pill body
      final textX = (bubbleLeft + bubbleRight - textPainter.width) / 2;
      final textY = (bubbleTop + bubbleBottom - textPainter.height) / 2;
      textPainter.paint(canvas, Offset(textX, textY));

      // =======================================================================
      // 5. FINALIZE HIGH-DEFINITION BITMAP DESCRIPTOR
      // =======================================================================
      final picture = recorder.endRecording();
      final image = await picture.toImage(pixelWidth, pixelHeight);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      picture.dispose();
      if (!mounted || bytes == null) return;
      setState(() {
        _currentLocationMarkerIcon = gmaps.BitmapDescriptor.bytes(
          bytes.buffer.asUint8List(),
          width: logicalWidth,
          height: logicalHeight,
        );
      });
      try {
        await _mapController?.hideMarkerInfoWindow(
          const gmaps.MarkerId('resident-current-location'),
        );
      } catch (_) {
        // Nothing to hide if the marker is not on the native map yet.
      }
    } catch (_) {
      // Fallback to default red marker if bitmap rendering fails.
    }
  }

  gmaps.Marker _buildTravelMarker() => gmaps.Marker(
    markerId: gmaps.MarkerId('resident-travel-${_travelMode.id}'),
    position: _toGoogle(_navigationProgress!.markerPosition),
    zIndexInt: 6,
    anchor: const Offset(0.5, 0.5),
    rotation: _navigationProgress?.headingDegrees ?? 0.0,
    flat: true,
    icon:
        _travelMarkerIcon ??
        gmaps.BitmapDescriptor.defaultMarkerWithHue(
          gmaps.BitmapDescriptor.hueGreen,
        ),
    infoWindow: gmaps.InfoWindow(title: '${_travelMode.label} (Tap to change)'),
    onTap: _showTransportationAvatarPicker,
  );

  gmaps.Marker _buildIssueMapMarker(Submission item) {
    return gmaps.Marker(
      markerId: gmaps.MarkerId('concern-${item.id}'),
      position: _toGoogle(_positionForSubmission(item)),
      icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
        gmaps.BitmapDescriptor.hueOrange,
      ),
      infoWindow: gmaps.InfoWindow(title: item.title, snippet: item.status),
      onTap: () => _showIssueSheet(item),
    );
  }

  Set<gmaps.Polyline> get _routePolylines {
    final route = _selectedRoute;
    if (_routeDestination == null || route == null) return const {};
    final points = route.points.map(_toGoogle).toList(growable: false);
    return {
      gmaps.Polyline(
        polylineId: const gmaps.PolylineId('route-outline'),
        points: points,
        color: context.colors.onAccent,
        width: 10,
        zIndex: 1,
        jointType: gmaps.JointType.round,
        startCap: gmaps.Cap.roundCap,
        endCap: gmaps.Cap.roundCap,
      ),
      gmaps.Polyline(
        polylineId: const gmaps.PolylineId('route'),
        points: points,
        color: context.colors.info,
        width: 6,
        zIndex: 2,
        jointType: gmaps.JointType.round,
        startCap: gmaps.Cap.roundCap,
        endCap: gmaps.Cap.roundCap,
        patterns: _travelMode == TravelMode.walk
            ? [gmaps.PatternItem.dot, gmaps.PatternItem.gap(8)]
            : const [],
      ),
    };
  }

  gmaps.Marker _buildRouteDestinationMarker(ResidentMapPlace place) {
    return gmaps.Marker(
      markerId: gmaps.MarkerId('route-destination-${place.id}'),
      position: _toGoogle(place.position),
      zIndexInt: 3,
      icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
        gmaps.BitmapDescriptor.hueGreen,
      ),
      infoWindow: gmaps.InfoWindow(
        title: place.name,
        snippet: '${place.category.label} · ${place.address}',
      ),
    );
  }

  Future<void> _showPlacesToVisit() async {
    final place = await showModalBottomSheet<BariliDestination>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => PlacesToVisitSheet(
        destinations: bariliDestinations
            .where((place) => place.mapVisible)
            .toList(growable: false),
        currentLocation: _currentLocation,
      ),
    );
    if (!mounted || place == null) return;
    await _showRouteTo(ResidentMapPlace.fromDestination(place));
  }

  Future<void> _showRouteTo(ResidentMapPlace place) async {
    final request = ++_routeRequest;
    setState(() {
      _routeDestination = place;
      _selectedBarangayName = null;
      _routeOptions = null;
      _routeError = null;
      _routeLoading = true;
      _isNavigating = false;
      _hasArrived = false;
      _navigationProgress = null;
    });
    _searchController.clear();
    if (_currentLocation == null) await _loadCurrentLocation();
    if (!mounted || request != _routeRequest) return;
    final origin = _currentLocation;
    if (origin == null) {
      setState(() {
        _routeLoading = false;
        _routeError =
            _locationError ?? 'Your location is needed to show directions.';
      });
      await _moveCamera(place.position, 15);
      return;
    }
    try {
      final options = await widget.routeService.routes(
        origin: origin,
        destination: place.position,
      );
      if (!mounted || request != _routeRequest) return;
      setState(() {
        _routeOptions = options;
        _routeLoading = false;
        if (options.isEmpty) {
          _routeError = 'No route was found for this place.';
        } else if (options[_travelMode] == null) {
          _travelMode = TravelMode.values.firstWhere(
            (mode) => options[mode] != null,
          );
        }
      });
      await _fitRoute();
    } on RouteException catch (error) {
      if (!mounted || request != _routeRequest) return;
      setState(() {
        _routeLoading = false;
        _routeError = error.message;
      });
    }
  }

  void _selectTravelMode(TravelMode mode) {
    if (mode == _travelMode) return;
    setState(() => _travelMode = mode);
    _fitRoute();
    if (_isNavigating) {
      final factory = widget.travelMarkerFactory;
      if (factory != null) {
        setState(() => _travelMarkerIcon = factory(mode));
      } else {
        _createTravelMarkerIcon(mode).then((icon) {
          if (mounted && _isNavigating && _travelMode == mode) {
            setState(() => _travelMarkerIcon = icon);
          }
        });
      }
    }
    SharedPreferences.getInstance()
        .then((preferences) {
          return preferences.setString(_travelModePreferenceKey, mode.id);
        })
        .catchError((_) => false);
  }

  void _closeRoute() {
    _clearRoute();
    final location = _currentLocation;
    if (location != null) _moveCamera(location, 15);
  }

  void _clearRoute() {
    _routeRequest++;
    setState(() {
      _routeDestination = null;
      _routeOptions = null;
      _routeError = null;
      _routeLoading = false;
      _isNavigating = false;
      _hasArrived = false;
      _isNavigationMinimized = false;
      _navigationProgress = null;
    });
  }

  Future<void> _fitRoute() async {
    final points = [
      ...?_selectedRoute?.points,
      ?_currentLocation,
      ?_routeDestination?.position,
    ];
    if (!_mapReady || points.length < 2) return;
    var south = points.first.latitude;
    var north = points.first.latitude;
    var west = points.first.longitude;
    var east = points.first.longitude;
    for (final point in points.skip(1)) {
      if (point.latitude < south) south = point.latitude;
      if (point.latitude > north) north = point.latitude;
      if (point.longitude < west) west = point.longitude;
      if (point.longitude > east) east = point.longitude;
    }
    await _mapController?.animateCamera(
      gmaps.CameraUpdate.newLatLngBounds(
        gmaps.LatLngBounds(
          southwest: gmaps.LatLng(south, west),
          northeast: gmaps.LatLng(north, east),
        ),
        48,
      ),
    );
  }

  Future<void> _startNavigation() async {
    final route = _selectedRoute;
    final destination = _routeDestination;
    if (route == null || destination == null) return;
    if (_currentLocation == null) await _loadCurrentLocation(showError: true);
    final location = _currentLocation;
    if (!mounted || location == null) return;
    try {
      gmaps.BitmapDescriptor markerIcon;
      try {
        markerIcon =
            widget.travelMarkerFactory?.call(_travelMode) ??
            await _createTravelMarkerIcon(_travelMode);
      } catch (iconError) {
        debugPrint('Navigation marker creation failed: $iconError');
        markerIcon = gmaps.BitmapDescriptor.defaultMarkerWithHue(
          gmaps.BitmapDescriptor.hueAzure,
        );
      }
      if (!mounted || _routeDestination != destination) return;
      final progress = ResidentNavigationProgress.fromPosition(
        route: route,
        current: location,
        destination: destination.position,
      );
      setState(() {
        _travelMarkerIcon = markerIcon;
        _navigationProgress = progress;
        _isNavigating = !progress.arrived;
        _hasArrived = progress.arrived;
        _isNavigationMinimized = false;
      });
      await _moveCamera(location, 17);
    } catch (_) {
      if (mounted) {
        _showLocationMessage('Navigation could not start. Please try again.');
      }
    }
  }

  Future<gmaps.BitmapDescriptor> _createTravelMarkerIcon(
    TravelMode mode,
  ) async {
    switch (mode) {
      case TravelMode.motorcycle:
        return _drawMotorcycleRiderMarker();
      case TravelMode.walk:
        return _drawWalkingPersonMarker();
      case TravelMode.car:
        return _drawCarMarker();
    }
  }

  Future<gmaps.BitmapDescriptor> _drawMotorcycleRiderMarker() async {
    const double width = 200.0;
    const double height = 240.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    const double cx = width / 2; // 100.0
    const double cy = 135.0;     // Rider center

    // =========================================================================
    // 1. DYNAMIC GROUND SHADOW & AMBIENT OCCLUSION (Real 3D Ground Clearance)
    // =========================================================================
    // Deep ground shadow directly under the chassis and wheels
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(cx, cy + 12), width: 56, height: 168,
      ),
      Paint()
        ..color = const Color(0x38000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    // Dark core contact shadow directly beneath tires
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(cx, cy + 16), width: 34, height: 140,
      ),
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // =========================================================================
    // 2. FORWARD ROAD ILLUMINATION (Volumetric Xenon Headlight Projection)
    // =========================================================================
    final beamPath = Path();
    beamPath.moveTo(cx - 10, cy - 54);
    beamPath.lineTo(cx - 68, 10);
    beamPath.quadraticBezierTo(cx, -6, cx + 68, 10);
    beamPath.lineTo(cx + 10, cy - 54);
    beamPath.close();

    canvas.drawPath(
      beamPath,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(cx, cy - 54),
          const Offset(cx, 10),
          const [
            Color(0xB593C5FD), // vibrant xenon blue-white
            Color(0x453B82F6),
            Color(0x001D4ED8),
          ],
          const [0.0, 0.45, 1.0],
        ),
    );

    // Intense central hot-spot beam on asphalt
    final innerBeam = Path();
    innerBeam.moveTo(cx - 5, cy - 54);
    innerBeam.lineTo(cx - 28, 16);
    innerBeam.quadraticBezierTo(cx, 4, cx + 28, 16);
    innerBeam.lineTo(cx + 5, cy - 54);
    innerBeam.close();

    canvas.drawPath(
      innerBeam,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(cx, cy - 54),
          const Offset(cx, 16),
          const [Color(0xCCE0F2FE), Color(0x00E0F2FE)],
        ),
    );

    // =========================================================================
    // 3. MOTORCYCLE HARDWARE & UNDERCARRIAGE (Tires, Forks, Exhausts)
    // =========================================================================
    // Rear Sport Radial Tire (Wide 190-section profile)
    final rearTireRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(cx, cy + 64), width: 18, height: 38),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      rearTireRect,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(cx - 9, cy + 64),
          const Offset(cx + 9, cy + 64),
          const [Color(0xFF0F172A), Color(0xFF334155), Color(0xFF0F172A)],
          const [0.0, 0.5, 1.0],
        ),
    );
    // Rear tire center tread line
    canvas.drawLine(
      const Offset(cx, cy + 48),
      const Offset(cx, cy + 80),
      Paint()
        ..color = const Color(0xFF020617)
        ..strokeWidth = 2,
    );

    // Twin High-Performance Titanium Exhaust Cannisters (Left & Right)
    for (final dir in [-1.0, 1.0]) {
      final exPath = Path();
      exPath.moveTo(cx + (dir * 12), cy + 18);
      exPath.lineTo(cx + (dir * 18), cy + 42);
      exPath.lineTo(cx + (dir * 16), cy + 68);
      canvas.drawPath(
        exPath,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(cx + (dir * 12), cy + 18),
            Offset(cx + (dir * 16), cy + 68),
            const [Color(0xFF94A3B8), Color(0xFF475569), Color(0xFF1E293B)],
            const [0.0, 0.5, 1.0],
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.5
          ..strokeCap = StrokeCap.round,
      );
      // Carbon-fiber angled exhaust tip
      canvas.drawCircle(
        Offset(cx + (dir * 16), cy + 68),
        3.2,
        Paint()..color = const Color(0xFF020617),
      );
    }

    // Front Sport Tire
    final frontTireRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(cx, cy - 60), width: 14, height: 36),
      const Radius.circular(6),
    );
    canvas.drawRRect(
      frontTireRect,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(cx - 7, cy - 60),
          const Offset(cx + 7, cy - 60),
          const [Color(0xFF0F172A), Color(0xFF334155), Color(0xFF0F172A)],
          const [0.0, 0.5, 1.0],
        ),
    );
    // Front rim silver alloy center
    canvas.drawLine(
      const Offset(cx, cy - 72),
      const Offset(cx, cy - 48),
      Paint()
        ..color = const Color(0xFF94A3B8)
        ..strokeWidth = 2.2,
    );

    // Inverted Gold Suspension Forks (Left & Right)
    for (final dir in [-1.0, 1.0]) {
      canvas.drawLine(
        Offset(cx + (dir * 9), cy - 72),
        Offset(cx + (dir * 9), cy - 46),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(cx + (dir * 9), cy - 72),
            Offset(cx + (dir * 9), cy - 46),
            const [Color(0xFFFBBF24), Color(0xFFD97706)],
          )
          ..strokeWidth = 3.6
          ..strokeCap = StrokeCap.round,
      );
    }

    // Front Aerodynamic Carbon Fender
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(cx, cy - 54), width: 18, height: 16,
        ),
        const Radius.circular(5),
      ),
      Paint()..color = const Color(0xFF0F172A),
    );

    // =========================================================================
    // 4. CHASSIS, FUEL TANK & COCKPIT (Sculpted 3D Metallic Curves)
    // =========================================================================
    // Aerodynamic Tail Cowl (Tapering to rear)
    final tailPath = Path();
    tailPath.moveTo(cx - 10, cy + 18);
    tailPath.lineTo(cx - 6, cy + 54);
    tailPath.lineTo(cx + 6, cy + 54);
    tailPath.lineTo(cx + 10, cy + 18);
    tailPath.close();
    canvas.drawPath(
      tailPath,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(cx, cy + 18),
          const Offset(cx, cy + 54),
          const [Color(0xFF1E3A8A), Color(0xFF0F172A)],
        ),
    );

    // Twin Slash LED Tail / Brake Lights (Ruby Red with ambient bloom)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(cx, cy + 54), width: 12, height: 4,
        ),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFFEF4444),
    );
    canvas.drawCircle(
      const Offset(cx, cy + 54),
      6,
      Paint()..color = const Color(0x60EF4444),
    );

    // Textured Leather Rider Saddle / Seat
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(cx, cy + 14), width: 18, height: 22,
        ),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xFF1E293B),
    );

    // Sculpted 3D Metallic Fuel Tank
    final tankPath = Path();
    tankPath.moveTo(cx - 10, cy - 26);
    tankPath.quadraticBezierTo(cx - 20, cy - 8, cx - 14, cy + 6);
    tankPath.lineTo(cx + 14, cy + 6);
    tankPath.quadraticBezierTo(cx + 20, cy - 8, cx + 10, cy - 26);
    tankPath.close();

    canvas.drawPath(
      tankPath,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(cx - 20, cy - 26),
          const Offset(cx + 20, cy + 6),
          const [
            Color(0xFF1D4ED8),
            Color(0xFF3B82F6),
            Color(0xFF1E3A8A),
            Color(0xFF0F172A),
          ],
          const [0.0, 0.35, 0.75, 1.0],
        ),
    );
    // Tank spine highlight
    canvas.drawLine(
      const Offset(cx, cy - 22),
      const Offset(cx, cy + 4),
      Paint()
        ..color = const Color(0x55FFFFFF)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    // Front Cockpit Cowling & Triple Tree
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(cx, cy - 36), width: 26, height: 14,
        ),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF0F172A),
    );

    // Twin Projector LED Headlights (Glowing Crystal White)
    canvas.drawCircle(const Offset(cx - 7, cy - 48), 3.5, Paint()..color = Colors.white,
    );
    canvas.drawCircle(const Offset(cx - 7, cy - 48), 5.5, Paint()..color = const Color(0x5538BDF8),
    );
    canvas.drawCircle(const Offset(cx + 7, cy - 48), 3.5, Paint()..color = Colors.white,
    );
    canvas.drawCircle(const Offset(cx + 7, cy - 48), 5.5, Paint()..color = const Color(0x5538BDF8),
    );

    // Digital TFT Dashboard (Cyan Glow with Speedo bar)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(cx, cy - 35), width: 14, height: 7,
        ),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF06B6D4),
    );
    canvas.drawLine(
      const Offset(cx - 5, cy - 35),
      const Offset(cx + 3, cy - 35),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 1.2,
    );

    // Tinted Bubble Windscreen with Specular Glint
    final screenPath = Path();
    screenPath.moveTo(cx - 10, cy - 44);
    screenPath.quadraticBezierTo(cx, cy - 56, cx + 10, cy - 44);
    screenPath.lineTo(cx + 7, cy - 36);
    screenPath.quadraticBezierTo(cx, cy - 40, cx - 7, cy - 36);
    screenPath.close();
    canvas.drawPath(screenPath, Paint()..color = const Color(0xAA020617));
    // Windscreen top curved reflection glint
    canvas.drawArc(
      Rect.fromCenter(center: const Offset(cx, cy - 46), width: 16, height: 10),
      3.14,
      3.14,
      false,
      Paint()
        ..color = const Color(0xDDFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // Clip-On Sport Handlebars & Grips
    canvas.drawLine(
      const Offset(cx - 34, cy - 30),
      const Offset(cx + 34, cy - 30),
      Paint()
        ..color = const Color(0xFF94A3B8)
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round,
    );
    // Textured Grips
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(cx - 32, cy - 30), width: 7, height: 12,
        ),
        const Radius.circular(2.5),
      ),
      Paint()..color = const Color(0xFF020617),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(cx + 32, cy - 30), width: 7, height: 12,
        ),
        const Radius.circular(2.5),
      ),
      Paint()..color = const Color(0xFF020617),
    );

    // Aerodynamic Bar-End Mirrors with Sky-Blue Reflective Glass
    canvas.drawCircle(const Offset(cx - 38, cy - 35), 4.2, Paint()..color = const Color(0xFF0F172A),
    );
    canvas.drawCircle(const Offset(cx - 38, cy - 35), 3.0, Paint()..color = const Color(0xFF38BDF8),
    );
    canvas.drawCircle(const Offset(cx + 38, cy - 35), 4.2, Paint()..color = const Color(0xFF0F172A),
    );
    canvas.drawCircle(const Offset(cx + 38, cy - 35), 3.0, Paint()..color = const Color(0xFF38BDF8),
    );

    // =========================================================================
    // 5. THE REAL 3D HUMAN RIDER (Anatomical Leather Suit, Armor & Helmet)
    // =========================================================================
    // Rider Lower Body & Knees Hugging Tank Flanks
    for (final dir in [-1.0, 1.0]) {
      // Leather thigh
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx + (dir * 18), cy + 4), width: 9, height: 24,
          ),
          const Radius.circular(4),
        ),
        Paint()..color = const Color(0xFF1E293B),
      );
      // White knee slider puck
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx + (dir * 22), cy + 2), width: 4.5, height: 8,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = Colors.white,
      );
    }

    // Volumetric 3D Racing Leather Torso (V-taper shape leaning forward)
    final torsoPath = Path();
    torsoPath.moveTo(cx - 22, cy - 10);
    torsoPath.quadraticBezierTo(cx - 18, cy + 12, cx - 12, cy + 26);
    torsoPath.lineTo(cx + 12, cy + 26);
    torsoPath.quadraticBezierTo(cx + 18, cy + 12, cx + 22, cy - 10);
    torsoPath.close();

    canvas.drawPath(
      torsoPath,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(cx - 22, cy - 10),
          const Offset(cx + 22, cy + 26),
          const [Color(0xFF3B82F6), Color(0xFF1D4ED8), Color(0xFF1E3A8A)],
          const [0.0, 0.5, 1.0],
        ),
    );

    // 3D Aerodynamic Speed Hump on Upper Back (MotoGP style)
    final humpPath = Path();
    humpPath.moveTo(cx - 6, cy - 4);
    humpPath.lineTo(cx - 5, cy + 18);
    humpPath.quadraticBezierTo(cx, cy + 22, cx + 5, cy + 18);
    humpPath.lineTo(cx + 6, cy - 4);
    humpPath.close();

    canvas.drawPath(
      humpPath,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(cx - 6, cy - 4),
          const Offset(cx + 6, cy + 22),
          const [Color(0xFF60A5FA), Color(0xFF1E40AF), Color(0xFF0F172A)],
          const [0.0, 0.5, 1.0],
        ),
    );
    // Speed hump white aerodynamic racing stripe
    canvas.drawLine(
      const Offset(cx, cy - 2),
      const Offset(cx, cy + 18),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    // 3D Molded Shoulder Armor Plates (Deltoids)
    for (final dir in [-1.0, 1.0]) {
      final shoulderCenter = Offset(cx + (dir * 21), cy - 9);
      canvas.drawCircle(
        shoulderCenter,
        8.5,
        Paint()
          ..shader = ui.Gradient.radial(
            shoulderCenter - const Offset(2, 2),
            8.5,
            const [Color(0xFF60A5FA), Color(0xFF1E40AF), Color(0xFF0F172A)],
            const [0.0, 0.55, 1.0],
          ),
      );
      // Titanium shoulder slider plate
      canvas.drawCircle(
        shoulderCenter,
        4.0,
        Paint()..color = const Color(0xFFCBD5E1),
      );
    }

    // 3D Anatomical Bent Arms with Elbow Sliders
    for (final dir in [-1.0, 1.0]) {
      // Upper arm to elbow
      final armPath = Path();
      armPath.moveTo(cx + (dir * 20), cy - 8);
      armPath.lineTo(cx + (dir * 29), cy - 20); // elbow joint
      armPath.lineTo(cx + (dir * 32), cy - 29); // wrist/grip
      canvas.drawPath(
        armPath,
        Paint()
          ..color = const Color(0xFF2563EB)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7.5
          ..strokeCap = StrokeCap.round,
      );

      // Elbow armor slider pad
      canvas.drawCircle(
        Offset(cx + (dir * 29), cy - 20),
        4.5,
        Paint()..color = const Color(0xFF0F172A),
      );
      canvas.drawCircle(
        Offset(cx + (dir * 29), cy - 20),
        2.2,
        Paint()..color = Colors.white,
      );

      // Leather racing glove gripping the handlebar
      canvas.drawCircle(
        Offset(cx + (dir * 32), cy - 30),
        5.2,
        Paint()..color = const Color(0xFF020617),
      );
      // Carbon-fiber knuckle plate highlight
      canvas.drawCircle(
        Offset(cx + (dir * 32), cy - 30),
        2.5,
        Paint()..color = const Color(0xFF94A3B8),
      );
    }

    // =========================================================================
    // 6. 3D FULL-FACE AERODYNAMIC RACING HELMET (Curved Glass Visor & Specular)
    // =========================================================================
    // Aerodynamic Teardrop Helmet Shell with Rear Fin
    final helmetPath = Path();
    helmetPath.moveTo(cx - 13, cy - 14);
    // Left curve around crown
    helmetPath.cubicTo(cx - 16, cy - 24, cx - 11, cy - 33, cx, cy - 33);
    // Right curve around crown
    helmetPath.cubicTo(cx + 11, cy - 33, cx + 16, cy - 24, cx + 13, cy - 14);
    // Tapering back to rear aerodynamic spoiler
    helmetPath.cubicTo(cx + 10, cy - 6, cx + 4, cy - 3, cx, cy - 3);
    helmetPath.cubicTo(cx - 4, cy - 3, cx - 10, cy - 6, cx - 13, cy - 14);
    helmetPath.close();

    // 3D Spherical Volumetric Helmet Shader (Upper-left light source)
    canvas.drawPath(
      helmetPath,
      Paint()
        ..shader = ui.Gradient.radial(
          const Offset(cx - 4, cy - 24),
          20,
          const [
            Color(0xFF93C5FD), // bright primary highlight on crown
            Color(0xFF3B82F6),
            Color(0xFF1E40AF),
            Color(0xFF0F172A),
          ],
          const [0.0, 0.35, 0.7, 1.0],
        ),
    );

    // Helmet Top Air Intake Vents
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(cx - 4, cy - 28), width: 3.5, height: 5,
        ),
        const Radius.circular(1.5),
      ),
      Paint()..color = const Color(0xFF020617),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(cx + 4, cy - 28), width: 3.5, height: 5,
        ),
        const Radius.circular(1.5),
      ),
      Paint()..color = const Color(0xFF020617),
    );

    // Curved Glossy Dark Iridium Visor (Bubble Glass Curve)
    final visorPath = Path();
    visorPath.moveTo(cx - 11, cy - 22);
    visorPath.quadraticBezierTo(cx, cy - 26, cx + 11, cy - 22);
    visorPath.lineTo(cx + 9, cy - 15);
    visorPath.quadraticBezierTo(cx, cy - 19, cx - 9, cy - 15);
    visorPath.close();

    canvas.drawPath(visorPath, Paint()..color = const Color(0xFF020617));

    // Realistic Curved Glass Specular Reflections on Visor
    // Primary horizon reflection streak
    canvas.drawArc(
      Rect.fromCenter(center: const Offset(cx, cy - 22), width: 18, height: 8),
      3.2,
      2.9,
      false,
      Paint()
        ..color = const Color(0xF0FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
    // Secondary subtle rim reflection
    canvas.drawArc(
      Rect.fromCenter(center: const Offset(cx, cy - 19), width: 14, height: 5),
      3.3,
      2.7,
      false,
      Paint()
        ..color = const Color(0x60FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..strokeCap = StrokeCap.round,
    );

    // =========================================================================
    // 7. FINALIZE HIGH-RESOLUTION BITMAP
    // =========================================================================
    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    if (bytes == null) throw StateError('Motorcycle rider marker unavailable.');
    return gmaps.BitmapDescriptor.bytes(
      bytes.buffer.asUint8List(),
      width: 98,
      height: 118,
    );
  }

  Future<gmaps.BitmapDescriptor> _drawWalkingPersonMarker() async {
    const double size = 140.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const double cx = size / 2;
    const double cy = size / 2;

    // Directional radar accuracy pulse
    canvas.drawCircle(
      const Offset(cx, cy),
      48,
      Paint()..color = const Color(0x202563EB),
    );
    canvas.drawCircle(
      const Offset(cx, cy),
      46,
      Paint()
        ..color = const Color(0x403B82F6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Ground contact shadow
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(cx, cy + 6), width: 34, height: 46),
      Paint()
        ..color = const Color(0x35000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // 3D athletic torso & shoulders
    final torso = Path();
    torso.moveTo(cx - 16, cy - 6);
    torso.lineTo(cx + 16, cy - 6);
    torso.lineTo(cx + 11, cy + 18);
    torso.lineTo(cx - 11, cy + 18);
    torso.close();
    canvas.drawPath(
      torso,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(cx - 16, cy - 6),
          const Offset(cx + 16, cy + 18),
          const [Color(0xFF3B82F6), Color(0xFF1D4ED8), Color(0xFF1E3A8A)],
          const [0.0, 0.5, 1.0],
        ),
    );

    // 3D Backpack with dual shoulder straps
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(cx, cy + 8), width: 17, height: 20,
        ),
        const Radius.circular(5),
      ),
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(cx, cy - 2),
          const Offset(cx, cy + 18),
          const [Color(0xFF1E293B), Color(0xFF0F172A)],
        ),
    );
    // Dual backpack strap highlights
    canvas.drawLine(const Offset(cx - 7, cy - 4), const Offset(cx - 5, cy + 14), Paint()..color = const Color(0xFF475569)..strokeWidth = 2,
    );
    canvas.drawLine(const Offset(cx + 7, cy - 4), const Offset(cx + 5, cy + 14), Paint()..color = const Color(0xFF475569)..strokeWidth = 2,
    );

    // Swinging arms in dynamic stride (one forward, one backward)
    // Left arm swinging forward
    final leftArm = Path();
    leftArm.moveTo(cx - 15, cy - 4);
    leftArm.lineTo(cx - 22, cy + 8);
    canvas.drawPath(
      leftArm,
      Paint()
        ..color = const Color(0xFF2563EB)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(const Offset(cx - 22, cy + 8), 3.5, Paint()..color = const Color(0xFFFBBF24),
    ); // hand

    // Right arm swinging back
    final rightArm = Path();
    rightArm.moveTo(cx + 15, cy - 4);
    rightArm.lineTo(cx + 22, cy - 14);
    canvas.drawPath(
      rightArm,
      Paint()
        ..color = const Color(0xFF2563EB)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(const Offset(cx + 22, cy - 14), 3.5, Paint()..color = const Color(0xFFFBBF24),
    ); // hand

    // 3D Head with sporty baseball cap
    canvas.drawCircle(
      const Offset(cx, cy - 14),
      11.5,
      Paint()
        ..shader = ui.Gradient.radial(
          const Offset(cx - 3, cy - 17),
          12,
          const [Color(0xFF334155), Color(0xFF0F172A),
        ]),
    );
    // Cap visor facing forward
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(cx, cy - 24), width: 12, height: 6,
        ),
        const Radius.circular(2.5),
      ),
      Paint()..color = const Color(0xFF2563EB),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    if (bytes == null) throw StateError('Walking marker unavailable.');
    return gmaps.BitmapDescriptor.bytes(
      bytes.buffer.asUint8List(),
      width: 78,
      height: 78,
    );
  }

  Future<gmaps.BitmapDescriptor> _drawCarMarker() async {
    const double width = 160.0;
    const double height = 220.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const double cx = width / 2;
    const double cy = height / 2 + 10;

    // Twin Projector Xenon Headlights Road Illumination
    for (final offset in [-18.0, 18.0]) {
      final lightPath = Path();
      lightPath.moveTo(cx + offset - 4, cy - 46);
      lightPath.lineTo(cx + offset - 30, 10);
      lightPath.lineTo(cx + offset + 30, 10);
      lightPath.lineTo(cx + offset + 4, cy - 46);
      lightPath.close();

      canvas.drawPath(
        lightPath,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(cx + offset, cy - 46),
            Offset(cx + offset, 10),
            const [Color(0x9560A5FA), Color(0x303B82F6), Color(0x002563EB)],
            const [0.0, 0.5, 1.0],
          ),
      );
    }

    // Volumetric 3D Ground Shadow & Ambient Occlusion
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(cx, cy + 4), width: 56, height: 114,
        ),
        const Radius.circular(18),
      ),
      Paint()
        ..color = const Color(0x45000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    // Car Body Aerodynamic Silhouette with Sculpted Wheel Arches
    final carBody = Path();
    carBody.moveTo(cx - 16, cy - 50); // front nose left
    carBody.quadraticBezierTo(cx, cy - 54, cx + 16, cy - 50,
    ); // front bumper curve
    carBody.lineTo(cx + 24, cy - 36); // front right fender
    carBody.lineTo(cx + 23, cy + 34); // right side haunch
    carBody.lineTo(cx + 25, cy + 48); // rear right bumper
    carBody.quadraticBezierTo(cx, cy + 54, cx - 25, cy + 48); // rear bumper
    carBody.lineTo(cx - 23, cy + 34); // left side haunch
    carBody.lineTo(cx - 24, cy - 36); // front left fender
    carBody.close();

    // 3D Metallic Royal Blue Car Paint
    canvas.drawPath(
      carBody,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(cx - 24, cy - 50),
          const Offset(cx + 24, cy + 50),
          const [
            Color(0xFF1E3A8A),
            Color(0xFF3B82F6), // specular highlight along body spine
            Color(0xFF1D4ED8),
            Color(0xFF0F172A),
          ],
          const [0.0, 0.35, 0.75, 1.0],
        ),
    );

    // Hood Sculpted Power Creases
    canvas.drawLine(
      const Offset(cx - 8, cy - 48),
      const Offset(cx - 12, cy - 26),
      Paint()..color = const Color(0x55FFFFFF)..strokeWidth = 1.4,
    );
    canvas.drawLine(
      const Offset(cx + 8, cy - 48),
      const Offset(cx + 12, cy - 26),
      Paint()..color = const Color(0x55FFFFFF)..strokeWidth = 1.4,
    );

    // Curved Panoramic Front Windshield with Horizon Reflection
    final windshield = Path();
    windshield.moveTo(cx - 18, cy - 24);
    windshield.quadraticBezierTo(cx, cy - 27, cx + 18, cy - 24);
    windshield.lineTo(cx + 16, cy - 2);
    windshield.quadraticBezierTo(cx, cy - 4, cx - 16, cy - 2);
    windshield.close();
    canvas.drawPath(windshield, Paint()..color = const Color(0xFF0A0F1D));
    // Windshield diagonal specular sky streak
    canvas.drawLine(
      const Offset(cx - 12, cy - 22),
      const Offset(cx + 6, cy - 6),
      Paint()..color = const Color(0xBBFFFFFF)..strokeWidth = 2.2..strokeCap = StrokeCap.round,
    );

    // Glossy Tinted Glass Sunroof
    final sunroof = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(cx, cy + 10), width: 28, height: 18),
      const Radius.circular(4),
    );
    canvas.drawRRect(sunroof, Paint()..color = const Color(0xFF0F172A));
    canvas.drawRRect(
      sunroof,
      Paint()..style = PaintingStyle.stroke..strokeWidth = 1.0..color = const Color(0x4460A5FA),
    );

    // Rear Window Glass with Specular Rim
    final rearWindow = Path();
    rearWindow.moveTo(cx - 15, cy + 22);
    rearWindow.quadraticBezierTo(cx, cy + 20, cx + 15, cy + 22);
    rearWindow.lineTo(cx + 14, cy + 36);
    rearWindow.quadraticBezierTo(cx, cy + 38, cx - 14, cy + 36);
    rearWindow.close();
    canvas.drawPath(rearWindow, Paint()..color = const Color(0xFF0A0F1D));

    // Aerodynamic Side Mirrors with Sky-Blue Glass
    for (final dir in [-1.0, 1.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx + (dir * 26), cy - 20), width: 6, height: 12,
          ),
          const Radius.circular(2.5),
        ),
        Paint()..color = const Color(0xFF1E3A8A),
      );
      canvas.drawCircle(
        Offset(cx + (dir * 26), cy - 22),
        2.5,
        Paint()..color = const Color(0xFF38BDF8),
      );
    }

    // Rear Continuous Ruby-Red LED Lightbar
    final lightbar = Path();
    lightbar.moveTo(cx - 20, cy + 47);
    lightbar.quadraticBezierTo(cx, cy + 50, cx + 20, cy + 47);
    canvas.drawPath(
      lightbar,
      Paint()
        ..color = const Color(0xFFEF4444)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(const Offset(cx, cy + 48), 6, Paint()..color = const Color(0x60EF4444),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    if (bytes == null) throw StateError('Car marker unavailable.');
    return gmaps.BitmapDescriptor.bytes(
      bytes.buffer.asUint8List(),
      width: 90,
      height: 114,
    );
  }

  Widget _buildNavigationBanner() {
    final progress = _navigationProgress;
    return Material(
      key: const ValueKey('navigation-instruction'),
      color: context.colors.brandStrong,
      elevation: 8,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.colors.surface.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.turn_right_rounded,
                color: context.colors.onAccent,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                progress?.nextInstruction ?? 'Continue to destination',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  color: context.colors.onAccent,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: _isAudioMuted ? 'Unmute voice' : 'Mute voice',
              onPressed: () => setState(() => _isAudioMuted = !_isAudioMuted),
              icon: Icon(
                _isAudioMuted
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
                color: context.colors.onAccent,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationCard(ResidentMapPlace destination) {
    final progress = _navigationProgress;
    final remainingMeters = progress?.remainingDistanceMeters ?? 0;
    final remainingDuration = progress?.remainingDuration ?? Duration.zero;

    if (_isNavigationMinimized) {
      // Screen 12: Mini navigation controls
      return Material(
        key: const ValueKey('live-navigation-card'),
        color: Theme.of(context).colorScheme.surface,
        elevation: 10,
        shadowColor: context.colors.shadow.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => setState(() => _isNavigationMinimized = false),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.navigation_rounded,
                  color: context.colors.primaryGreen,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${formatRouteDistance(remainingMeters)} · ${formatRouteDuration(remainingDuration)}',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Expand controls',
                  onPressed: () =>
                      setState(() => _isNavigationMinimized = false),
                  icon: const Icon(
                    Icons.keyboard_arrow_up_rounded,
                    size: 24),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Screen 5: Live Navigation (Full)
    return _MapTripCard(
      key: const ValueKey('live-navigation-card'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${formatRouteDistance(remainingMeters)} remaining',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                formatRouteDuration(remainingDuration),
                style: GoogleFonts.outfit(
                  color: context.colors.primaryGreen,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Minimize navigation controls',
                onPressed: () => setState(() => _isNavigationMinimized = true),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Interactive Avatar / Transportation Switcher
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Theme.of(context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                for (final mode in TravelMode.values)
                  Expanded(
                    child: _buildAvatarNavChoice(mode)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('end-navigation'),
              onPressed: () => setState(() {
                _isNavigating = false;
                _navigationProgress = null;
              }),
              style: FilledButton.styleFrom(
                backgroundColor: context.colors.errorSurface,
                foregroundColor: context.colors.error,
                elevation: 0,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'End Navigation',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarNavChoice(TravelMode mode) {
    final selected = _travelMode == mode;
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _selectTravelMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? context.colors.brandStrong : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: context.colors.brandStrong.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  mode.icon,
                  size: 16,
                  color: selected ? context.colors.onAccent
                      : colors.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  mode == TravelMode.motorcycle ? 'Moto' : mode.label,
                  style: GoogleFonts.outfit(
                    color: selected ? context.colors.onAccent
                        : colors.onSurfaceVariant,
                    fontSize: 12.0,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showCurrentLocationDetails() async {
    final loc = _currentLocation;
    if (loc == null) return;
    final colors = Theme.of(context).colorScheme;
    final nearestBarangay = _selectedBarangayName ?? 'Barili Central';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: context.colors.shadow.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: context.colors.brand.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.my_location_rounded,
                        color: context.colors.primaryGreen,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Current Location',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: colors.onSurface,
                            ),
                          ),
                          Text(
                            '$nearestBarangay, Barili, Cebu',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: context.colors.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(bottomSheetContext),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest.withValues(alpha: 0.4,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.gps_fixed_rounded,
                        size: 18,
                        color: context.colors.primaryGreen,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'GPS Coordinates: ${loc.latitude.toStringAsFixed(4)}° N, ${loc.longitude.toStringAsFixed(4)}° E',
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.center_focus_strong_rounded, size: 18,
                        ),
                        label: const Text('Recenter'),
                        onPressed: () {
                          Navigator.pop(bottomSheetContext);
                          _moveCamera(loc, 17);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.colors.primaryGreen,
                          side: BorderSide(color: context.colors.primaryGreen),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.directions_bike_rounded, size: 18,
                        ),
                        label: const Text('Avatar / Mode'),
                        onPressed: () {
                          Navigator.pop(bottomSheetContext);
                          _showTransportationAvatarPicker();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: context.colors.brandStrong,
                          foregroundColor: context.colors.onAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showTransportationAvatarPicker() async {
    final colors = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: modalContext.colors.shadow.withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.onSurfaceVariant.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: modalContext.colors.brand.withValues(alpha: 0.14,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.directions_bike_rounded,
                            color: modalContext.colors.primaryGreen,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Choose Transportation Avatar',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: colors.onSurface,
                                ),
                              ),
                              Text(
                                'Select your active vehicle or walking avatar',
                                style: GoogleFonts.outfit(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(bottomSheetContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    for (final mode in TravelMode.values) ...[
                      _buildAvatarPickerTile(
                        mode,
                        () {
                          _selectTravelMode(mode);
                          setModalState(() {});
                          Navigator.pop(bottomSheetContext);
                        },
                        context: modalContext),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAvatarPickerTile(
    TravelMode mode,
    VoidCallback onTap, {
    required BuildContext context,
  }) {
    final selected = _travelMode == mode;
    final colors = Theme.of(context).colorScheme;

    final String title;
    final String description;
    final String badge;
    switch (mode) {
      case TravelMode.motorcycle:
        title = 'Motorcycle Rider';
        description = 'Rider with full helmet, racing jacket & forward beam';
        badge = 'Popular in Barili';
        break;
      case TravelMode.car:
        title = 'Car / Vehicle';
        description = 'Aerodynamic car with dual headlights & glass roof';
        badge = 'Highway Cruising';
        break;
      case TravelMode.walk:
        title = 'Walking Pedestrian';
        description = 'Active stride pedestrian with directional radar halo';
        badge = 'Scenic & Trails';
        break;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? context.colors.brand.withValues(alpha: 0.08)
                : colors.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? context.colors.primaryGreen
                  : colors.outlineVariant.withValues(alpha: 0.4),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected
                      ? context.colors.brandStrong
                      : colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  mode.icon,
                  color: selected ? context.colors.onAccent : colors.onSurface,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: context.colors.brand.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected
                    ? context.colors.primaryGreen
                    : colors.onSurfaceVariant.withValues(alpha: 0.4),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationStatus() => Material(
    color: Theme.of(context).colorScheme.surface,
    elevation: 8,
    shadowColor: context.colors.shadow.withValues(alpha: 0.15),
    borderRadius: BorderRadius.circular(20),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: context.colors.brand.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.location_on_rounded,
              color: context.colors.primaryGreen,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isLocating ? 'Finding your location…' : 'Location Access Needed',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  _isLocating
                      ? 'Acquiring GPS fix in Barili'
                      : _locationError ?? 'Enable GPS to see your location and routes.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (!_isLocating)
            TextButton(
              onPressed: () => _loadCurrentLocation(showError: true),
              child: const Text('Enable'),
            ),
        ],
      ),
    ),
  );

  Widget _buildArrivalCard(ResidentMapPlace destination) => _MapTripCard(
    key: const ValueKey('navigation-arrival-card'),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: context.colors.brand.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
            ),
            Icon(
              Icons.check_circle_rounded,
              color: context.colors.primaryGreen,
              size: 46,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'You have arrived',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          destination.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (destination.address.isNotEmpty)
          Text(
            destination.address,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: context.colors.textSecondary,
            ),
          ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _closeRoute,
            style: FilledButton.styleFrom(
              foregroundColor: context.colors.onAccent,

              backgroundColor: context.colors.brandStrong,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              'Done',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildCurrentLocationCard() {
    final barangay = _currentBarangay?.name ?? 'Poblacion';
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 8,
      shadowColor: context.colors.shadow.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          if (_currentLocation != null) {
            _moveCamera(_currentLocation!, 16.5);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: context.colors.infoSurface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.location_on_rounded,
                  color: context.colors.info,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Current Location',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '$barangay, Barili, Cebu',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: context.colors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapHeader() {
    final routeName = _routeDestination?.name;
    final destinationName = routeName ?? widget.focusLabel?.trim();
    return ESugidPageHeader(
      sectionLabel: 'Explore Barili',
      title: destinationName == null || destinationName.isEmpty
          ? 'Barangay Map'
          : destinationName,
      icon: Icons.map_rounded,
      showBackButton: true,
      collapseProgress: 1,
      showBodyCrown: false,
    );
  }

  Widget _buildMapControls() {
    final hasBarangay = _selectedBarangayName != null;
    final hasCategory = _selectedPlaceCategory != null;
    final hasMarkerFilter = _visibleMarkerLayerCount > 0;

    return Column(
      children: [
        _MapControlSurface(
          borderRadius: 22,
          child: TextField(
            key: const ValueKey('resident-map-search'),
            controller: _searchController,
            textInputAction: TextInputAction.search,
            style: GoogleFonts.outfit(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'Search a place in Barili...',
              hintStyle: GoogleFonts.outfit(
                color: Theme.of(context,
                )
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: 0.75),
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 10, right: 10),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [context.colors.brand, context.colors.brand],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: context.colors.brandStrong.withValues(alpha: 0.35,
                        ),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.search_rounded,
                    color: context.colors.onAccent,
                    size: 20,
                  ),
                ),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 56,
                minHeight: 48,
              ),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear place search',
                      onPressed: _searchController.clear,
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
              filled: false,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MapControlSurface(
                isActive: hasBarangay,
                borderRadius: 18,
                child: InkWell(
                  key: const ValueKey('barangay-map-selector'),
                  onTap: _isLoadingBoundaries || _barangays.isEmpty
                      ? null
                      : _showBarangayPicker,
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 11,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: hasBarangay
                                ? context.colors.brand
                                : context.colors.brand.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            hasBarangay
                                ? Icons.location_on_rounded
                                : Icons.location_on_outlined,
                            color: hasBarangay ? context.colors.onAccent
                                : context.colors.primaryGreen,
                            size: 15,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            _selectedBarangayName ?? 'All Barangays',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              color: hasBarangay
                                  ? context.colors.primaryGreen
                                  : context.colors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: context.colors.primaryGreen,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MapControlSurface(
                isActive: hasCategory,
                borderRadius: 18,
                child: InkWell(
                  key: const ValueKey('map-place-category-selector'),
                  onTap: _showPlaceCategoryPicker,
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 11,
                    ),
                    child: Row(
                      children: [
                        if (_categoryLoading)
                          const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: hasCategory
                                  ? context.colors.brand
                                  : context.colors.brand.withValues(alpha: 0.12,
                                    ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _selectedPlaceCategory?.icon ??
                                  Icons.category_outlined,
                              color: hasCategory ? context.colors.onAccent
                                  : context.colors.primaryGreen,
                              size: 15,
                            ),
                          ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            _selectedPlaceCategory?.label ?? 'Place Categories',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              color: hasCategory
                                  ? context.colors.primaryGreen
                                  : context.colors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: context.colors.primaryGreen,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _MapControlSurface(
              isActive: hasMarkerFilter,
              borderRadius: 18,
              child: Tooltip(
                message: 'Filter map markers',
                child: InkWell(
                  key: const ValueKey('map-marker-filter'),
                  onTap: _showMarkerFilters,
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 11,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: hasMarkerFilter
                                ? context.colors.brand
                                : context.colors.brand.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            hasMarkerFilter
                                ? Icons.filter_alt_rounded
                                : Icons.filter_alt_outlined,
                            color: hasMarkerFilter ? context.colors.onAccent
                                : context.colors.primaryGreen,
                            size: 15,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Filter',
                          style: GoogleFonts.outfit(
                            color: hasMarkerFilter
                                ? context.colors.primaryGreen
                                : context.colors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (hasMarkerFilter) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  context.colors.brand,
                                  context.colors.brand,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$_visibleMarkerLayerCount',
                              style: TextStyle(
                                color: context.colors.onAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    final request = ++_searchRequest;
    final query = _searchController.text.trim();
    setState(() {
      _remoteSuggestions = const [];
      _searchError = null;
      _searchLoading = query.length >= 2;
    });
    if (query.length < 2) return;
    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final results = await _placeSearchService.remoteMatches(query);
        if (!mounted || request != _searchRequest) return;
        setState(() {
          _remoteSuggestions = results;
          _searchLoading = false;
        });
      } catch (error) {
        if (!mounted || request != _searchRequest) return;
        setState(() {
          _searchError = error.toString();
          _searchLoading = false;
        });
      }
    });
  }

  Widget _buildSearchSuggestions() {
    final query = _searchController.text.trim();
    final mediaQuery = MediaQuery.of(context);
    final searchTop = responsiveCompactESugidPageHeaderExtent(mediaQuery) + 108;
    final availableHeight =
        mediaQuery.size.height - mediaQuery.viewInsets.bottom - searchTop - 12;
    final seen = <String>{};
    final matches =
        [
              ..._placeSearchService.localMatches(query, _barangays),
              ..._remoteSuggestions,
            ]
            .where((place) {
              if (_selectedPlaceCategory != null &&
                  place.category != _selectedPlaceCategory) {
                return false;
              }
              final selectedBarangay = _selectedBarangayName;
              if (selectedBarangay != null &&
                  !place.address.toLowerCase().contains(
                    selectedBarangay.toLowerCase(),
                  )) {
                return false;
              }
              final key = place.id.trim().isNotEmpty
                  ? place.id.trim()
                  : '${place.name.toLowerCase()}_${place.position.latitude.toStringAsFixed(4)}_${place.position.longitude.toStringAsFixed(4)}';
              return seen.add(key);
            })
            .take(8)
            .toList(growable: false);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 10,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: availableHeight.clamp(72.0, 340.0),
        ),
        child: matches.isNotEmpty
            ? ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 5),
                itemCount: matches.length + (_searchLoading ? 1 : 0),
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  if (index == matches.length) {
                    return const ListTile(
                      dense: true,
                      leading: SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      title: Text('Searching more places...'),
                    );
                  }
                  final place = matches[index];
                  return ListTile(
                    key: ValueKey('resident-map-suggestion-${place.id}'),
                    dense: true,
                    leading: Icon(
                      place.category.icon,
                      color: context.colors.primaryGreen,
                    ),
                    title: Text(
                      place.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${place.category.label} · ${place.address}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      FocusScope.of(context).unfocus();
                      _showRouteTo(place);
                    },
                  );
                },
              )
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _searchLoading
                            ? Icons.search_rounded
                            : Icons.search_off_rounded,
                        color: context.colors.primaryGreen,
                        size: 28,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _searchLoading
                            ? 'Searching places in Barili...'
                            : _searchError ??
                                  (query.length < 2
                                      ? 'Keep typing to search places'
                                      : 'No matching places found'),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _showPlaceCategoryPicker() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Place Categories',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Filter places and services around Barili',
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              key: const ValueKey('places-to-visit-button'),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.colors.brand.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.explore_rounded,
                  color: context.colors.primaryGreen,
                  size: 20,
                ),
              ),
              title: Text(
                'Places to visit',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                ),
              ),
              subtitle: Text(
                'Featured tourist spots & popular destinations',
                style: GoogleFonts.outfit(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: () => Navigator.pop(context, '__places_to_visit__'),
            ),
            const Divider(indent: 16, endIndent: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _selectedPlaceCategory == null
                      ? context.colors.brand.withValues(alpha: 0.12)
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.apps_rounded,
                  color: _selectedPlaceCategory == null
                      ? context.colors.primaryGreen
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ),
              title: Text(
                'All Categories',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              trailing: _selectedPlaceCategory == null
                  ? Icon(
                      Icons.check_rounded,
                      color: context.colors.primaryGreen,
                    )
                  : null,
              onTap: () => Navigator.pop(context, 'all'),
            ),
            for (final category in ResidentMapPlaceCategory.values)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _selectedPlaceCategory == category
                        ? context.colors.brand.withValues(alpha: 0.12)
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    category.icon,
                    color: _selectedPlaceCategory == category
                        ? context.colors.primaryGreen
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                ),
                title: Text(
                  category.label,
                  style: GoogleFonts.outfit(
                    fontWeight: _selectedPlaceCategory == category
                        ? FontWeight.w700
                        : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                trailing: _selectedPlaceCategory == category
                    ? Icon(
                        Icons.check_rounded,
                        color: context.colors.primaryGreen,
                      )
                    : null,
                onTap: () => Navigator.pop(context, category.name),
              ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null) return;
    if (selected == '__places_to_visit__') {
      await _showPlacesToVisit();
      return;
    }
    final category = selected == 'all'
        ? null
        : ResidentMapPlaceCategory.values.byName(selected);
    final request = ++_categoryRequest;
    setState(() {
      _selectedPlaceCategory = category;
      _categoryPlaces = const [];
      _categoryLoading =
          category != null && category != ResidentMapPlaceCategory.barangay;
    });
    if (category == null || category == ResidentMapPlaceCategory.barangay) {
      return;
    }
    const terms = <ResidentMapPlaceCategory, String>{
      ResidentMapPlaceCategory.governmentOffice: 'municipal hall',
      ResidentMapPlaceCategory.school: 'school',
      ResidentMapPlaceCategory.healthFacility: 'hospital',
      ResidentMapPlaceCategory.touristSpot: 'falls',
      ResidentMapPlaceCategory.market: 'market',
      ResidentMapPlaceCategory.religiousPlace: 'church',
      ResidentMapPlaceCategory.organization: 'community centre',
      ResidentMapPlaceCategory.foodAndDining: 'restaurant',
      ResidentMapPlaceCategory.accommodation: 'hotel',
      ResidentMapPlaceCategory.barangay: 'barangay',
      ResidentMapPlaceCategory.other: 'place',
    };
    try {
      final places = await _placeSearchService.remoteMatches(terms[category]!);
      if (!mounted || request != _categoryRequest) return;
      setState(() {
        _categoryPlaces = places;
        _categoryLoading = false;
      });
    } catch (_) {
      if (!mounted || request != _categoryRequest) return;
      setState(() => _categoryLoading = false);
      _showLocationMessage('Could not load places in this category.');
    }
  }

  int get _visibleMarkerLayerCount {
    var count = 0;
    if (_showBarangayMarkers) count++;
    if (_showIssueMarkers) count++;
    if (_showPlaceMarkers) count++;
    return count;
  }

  Future<void> _showMarkerFilters() async {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          void update(VoidCallback change) {
            setState(change);
            setSheetState(() {});
          }

          void setAll(bool visible) {
            update(() {
              _showBarangayMarkers = visible;
              _showIssueMarkers = visible;
              _showPlaceMarkers = visible;
            });
          }

          final allHidden = !_showBarangayMarkers && !_showIssueMarkers && !_showPlaceMarkers;
          final allVisible = _showBarangayMarkers && _showIssueMarkers && _showPlaceMarkers;

          Widget buildLayerCard({
            required String title,
            required String subtitle,
            required IconData icon,
            required Color iconColor,
            required bool value,
            required ValueChanged<bool> onChanged,
          }) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? context.colors.surfaceAlt
                    : (value ? context.colors.surfaceAlt
                          : context.colors.surface),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: value
                      ? context.colors.primaryGreen.withValues(alpha: 0.45)
                      : (isDark
                          ? context.colors.border.withValues(alpha: 0.10)
                          : context.colors.border.withValues(alpha: 0.06)),
                  width: value ? 1.5 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: context.colors.shadow.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2,
                ),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                title: Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
                subtitle: Text(
                  subtitle,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                trailing: Switch.adaptive(
                  value: value,
                  activeThumbColor: context.colors.brand,
                  activeTrackColor: context.colors.brand,
                  onChanged: onChanged,
                ),
              ),
            );
          }

          return Container(
            decoration: BoxDecoration(
              color: isDark ? context.colors.infoSolid : context.colors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: context.colors.shadow.withValues(alpha: 0.25),
                  blurRadius: 24,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: colors.onSurfaceVariant.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              context.colors.brand,
                              context.colors.brand,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: context.colors.brandStrong.withValues(alpha: 0.3,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.tune_rounded,
                          color: context.colors.onAccent,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Map Markers & Layers',
                              style: GoogleFonts.outfit(
                                color: colors.onSurface,
                                fontSize: 18.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                            Text(
                              'Choose which pins are visible on the map',
                              style: GoogleFonts.outfit(
                                color: colors.onSurfaceVariant,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          key: const ValueKey('hide-all-map-markers'),
                          onPressed: () => setAll(false),
                          style: TextButton.styleFrom(
                            foregroundColor: context.colors.onAccent,

                            backgroundColor: allHidden
                                ? context.colors.brand.withValues(alpha: 0.12)
                                : (context.colors.surfaceAlt),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: allHidden
                                    ? context.colors.primaryGreen
                                    : (isDark
                                        ? context.colors.border.withValues(alpha: 0.1,
                                            )
                                        : context.colors.border.withValues(alpha: 0.06,
                                            )),
                                width: allHidden ? 1.5 : 1.0,
                              ),
                            ),
                          ),
                          icon: Icon(
                            Icons.visibility_off_outlined,
                            size: 17,
                            color: allHidden
                                ? context.colors.primaryGreen
                                : colors.onSurfaceVariant,
                          ),
                          label: Text(
                            'Hide all',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: allHidden
                                  ? context.colors.primaryGreen
                                  : colors.onSurface,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextButton.icon(
                          key: const ValueKey('show-all-map-markers'),
                          onPressed: () => setAll(true),
                          style: TextButton.styleFrom(
                            backgroundColor: allVisible
                                ? context.colors.brand
                                : (context.colors.surfaceAlt),
                            foregroundColor: context.colors.onAccent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: allVisible
                                    ? context.colors.primaryGreen
                                    : (isDark
                                        ? context.colors.border.withValues(alpha: 0.1,
                                            )
                                        : context.colors.border.withValues(alpha: 0.06,
                                            )),
                                width: allVisible ? 1.5 : 1.0,
                              ),
                            ),
                          ),
                          icon: Icon(
                            Icons.visibility_outlined,
                            size: 17,
                            color: allVisible
                                ? context.colors.onAccent
                                : context.colors.primaryGreen,
                          ),
                          label: Text(
                            'Show all',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: allVisible
                                  ? context.colors.onAccent
                                  : context.colors.primaryGreen,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  buildLayerCard(
                    title: 'Barangay markers',
                    subtitle: 'Shown individually when zoomed in',
                    icon: Icons.location_on_rounded,
                    iconColor: context.colors.primaryGreen,
                    value: _showBarangayMarkers,
                    onChanged: (value) =>
                        update(() => _showBarangayMarkers = value),
                  ),
                  buildLayerCard(
                    title: 'Explore places',
                    subtitle: 'Verified places grouped at lower zoom',
                    icon: Icons.explore_rounded,
                    iconColor: context.colors.info,
                    value: _showPlaceMarkers,
                    onChanged: (value) =>
                        update(() => _showPlaceMarkers = value),
                  ),
                  buildLayerCard(
                    title: 'Community report markers',
                    subtitle: 'Unresolved reports near Barili',
                    icon: Icons.report_problem_rounded,
                    iconColor: context.colors.warning,
                    value: _showIssueMarkers,
                    onChanged: (value) =>
                        update(() => _showIssueMarkers = value),
                  ),
                  buildLayerCard(
                    title: 'Satellite photography',
                    subtitle: 'High-resolution aerial satellite imagery',
                    icon: Icons.satellite_alt_rounded,
                    iconColor: context.colors.purple,
                    value: _mapStyle == _MapStyle.satellite,
                    onChanged: (value) => update(
                      () => _mapStyle =
                          value ? _MapStyle.satellite : _MapStyle.street,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBoundaryStatus() {
    final failed = _boundaryLoadError != null;
    return Material(
      color: failed
          ? Theme.of(context).colorScheme.errorContainer
          : Theme.of(context).colorScheme.surface,
      elevation: 4,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            if (_isLoadingBoundaries)
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                Icons.map_outlined,
                color: Theme.of(context).colorScheme.onErrorContainer,
                size: 20,
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _isLoadingBoundaries
                    ? 'Loading accurate barangay boundaries…'
                    : _boundaryLoadError!,
                style: GoogleFonts.outfit(
                  color: failed
                      ? Theme.of(context).colorScheme.onErrorContainer
                      : Theme.of(context).colorScheme.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (failed)
              TextButton(
                onPressed: _retryBoundaryLoad,
                child: const Text('Retry'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoomControls() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? context.colors.border.withValues(alpha: 0.1)
              : context.colors.border.withValues(alpha: 0.07),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Zoom in',
            onPressed: () => _changeZoom(1),
            color: context.colors.brand,
            iconSize: 22,
            icon: const Icon(Icons.add_rounded),
          ),
          SizedBox(
            width: 28,
            child: Divider(
              height: 1,
              thickness: 1,
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
            ),
          ),
          IconButton(
            tooltip: 'Zoom out',
            onPressed: () => _changeZoom(-1),
            color: context.colors.brand,
            iconSize: 22,
            icon: const Icon(Icons.remove_rounded),
          ),
          SizedBox(
            width: 28,
            child: Divider(
              height: 1,
              thickness: 1,
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
            ),
          ),
          IconButton(
            key: const ValueKey('center-current-location'),
            tooltip: _locationError ?? 'Show my current location',
            onPressed: _isLocating ? null : _centerOnCurrentLocation,
            color: _currentLocation != null
                ? context.colors.brand
                : context.colors.disabledBackground,
            iconSize: 22,
            icon: _isLocating
                ? SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: context.colors.brand,
                    ),
                  )
                : Icon(
                    _currentLocation == null
                        ? Icons.location_searching_rounded
                        : Icons.my_location_rounded,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedBarangayCard(BariliBarangayBoundary barangay) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: context.colors.primaryGreen.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [context.colors.brandStrong, context.colors.brand],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: context.colors.brandStrong.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.location_city_rounded,
                color: context.colors.onAccent,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    barangay.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Barangay of Barili • '
                    '${barangay.areaSquareKilometers.toStringAsFixed(2)} km²',
                    style: GoogleFonts.outfit(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Indicative boundary • PSA / GeoRisk Philippines',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: context.colors.primaryGreen,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Clear barangay selection',
              onPressed: _clearSelection,
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(context,
                )
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.5),
              ),
              icon: const Icon(Icons.close_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBarangayPicker() async {
    final selectedName = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _BarangayPickerSheet(
        barangays: _barangays,
        selectedName: _selectedBarangayName,
      ),
    );
    if (!mounted || selectedName == null) return;
    if (_routeDestination != null) _clearRoute();
    if (selectedName.isEmpty) {
      _clearSelection();
    } else {
      _selectBarangay(
        _barangays.firstWhere((item) => item.name == selectedName),
      );
    }
  }

  void _selectBarangay(BariliBarangayBoundary barangay) {
    setState(() => _selectedBarangayName = barangay.name);
    if (!_mapReady) return;
    final bounds = barangay.bounds;
    _mapController?.animateCamera(
      gmaps.CameraUpdate.newLatLngBounds(
        gmaps.LatLngBounds(
          southwest: _toGoogle(bounds.southWest),
          northeast: _toGoogle(bounds.northEast),
        ),
        72,
      ),
    );
  }

  void _clearSelection() {
    if (_selectedBarangayName != null) {
      setState(() => _selectedBarangayName = null);
    }
    if (_mapReady && _barangays.isNotEmpty) {
      _fitAllBarangays();
    }
  }

  Future<void> _fitAllBarangays() async {
    final points = _barangays.expand((barangay) => barangay.points).toList();
    if (points.isEmpty) {
      await _moveCamera(_bariliCenter, 13.2);
      return;
    }
    var minLatitude = points.first.latitude;
    var maxLatitude = points.first.latitude;
    var minLongitude = points.first.longitude;
    var maxLongitude = points.first.longitude;
    for (final point in points.skip(1)) {
      minLatitude = point.latitude < minLatitude ? point.latitude : minLatitude;
      maxLatitude = point.latitude > maxLatitude ? point.latitude : maxLatitude;
      minLongitude = point.longitude < minLongitude
          ? point.longitude
          : minLongitude;
      maxLongitude = point.longitude > maxLongitude
          ? point.longitude
          : maxLongitude;
    }
    await _mapController?.animateCamera(
      gmaps.CameraUpdate.newLatLngBounds(
        gmaps.LatLngBounds(
          southwest: gmaps.LatLng(minLatitude, minLongitude),
          northeast: gmaps.LatLng(maxLatitude, maxLongitude),
        ),
        42,
      ),
    );
  }

  Future<void> _openDestination(ResidentMapPlace destination) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ResidentMapPlaceDetailsPage(
          place: destination,
          detailsFuture: _placeSearchService.loadDetails(destination),
          onDirections: () => _showRouteTo(destination),
        ),
      ),
    );
  }

  Future<void> _changeZoom(double delta) async {
    await _mapController?.animateCamera(gmaps.CameraUpdate.zoomBy(delta));
  }

  Future<void> _centerOnCurrentLocation() async {
    await _loadCurrentLocation(showError: true);
    final location = _currentLocation;
    if (location != null) await _moveCamera(location, _isNavigating ? 17 : 16);
  }

  Future<void> _moveCamera(geo.LatLng target, double zoom) async {
    await _mapController?.animateCamera(
      gmaps.CameraUpdate.newCameraPosition(
        gmaps.CameraPosition(target: _toGoogle(target), zoom: zoom),
      ),
    );
  }

  void _showLocationMessage(String message) {
    ScaffoldMessenger.of(context).showAppSnackBar(
      AppSnackBar(content: Text(message), kind: FeedbackKind.warning),
    );
  }

  Future<void> _retryBoundaryLoad() async {
    setState(() {
      _isLoadingBoundaries = true;
      _boundaryLoadError = null;
    });
    await _loadBoundaries();
  }

  geo.LatLng _positionForSubmission(Submission item) {
    final location = (item.location ?? item.category).toLowerCase();
    for (final barangay in _barangays) {
      if (location.contains(barangay.name.toLowerCase())) {
        return barangay.markerPosition;
      }
    }
    final hash = item.id.codeUnits.fold<int>(0, (value, code) => value + code);
    final offsetLat = ((hash % 80) - 40) / 10000;
    final offsetLng = (((hash ~/ 3) % 80) - 40) / 10000;
    return geo.LatLng(
      _bariliCenter.latitude + offsetLat,
      _bariliCenter.longitude + offsetLng,
    );
  }

  static gmaps.LatLng _toGoogle(geo.LatLng point) =>
      gmaps.LatLng(point.latitude, point.longitude);

  void _showIssueSheet(Submission item) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final statusColor = item.status.toLowerCase() == 'in progress'
            ? context.colors.info
            : context.colors.warning;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.report_problem_rounded,
                    color: statusColor,
                    size: 30,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.title,
                      style: GoogleFonts.outfit(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                item.description,
                style: GoogleFonts.outfit(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Status: ${item.status}',
                style: GoogleFonts.outfit(
                  color: statusColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              if (item.department != null)
                Text(
                  'Routed to: ${item.department}',
                  style: GoogleFonts.outfit(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _positionSubscription?.cancel();
    _placeSearchService.dispose();
    _mapController?.dispose();
    super.dispose();
  }
}

class _MapControlSurface extends StatelessWidget {
  const _MapControlSurface({
    required this.child,
    this.isActive = false,
    this.borderRadius = 18,
  });

  final Widget child;
  final bool isActive;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: isActive
            ? (LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [context.colors.surfaceAlt, context.colors.surfaceAlt],
                  ))
            : (LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [context.colors.surface, context.colors.surface],
                  )),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: isActive
              ? (context.colors.primaryGreen)
              : (isDark
                  ? context.colors.border.withValues(alpha: 0.14)
                  : context.colors.border),
          width: isActive ? 1.5 : 1.2,
        ),
        boxShadow: [
          // Volumetric ambient soft shadow
          BoxShadow(
            color: isActive
                ? context.colors.brandStrong.withValues(alpha: 0.1882)
                : context.colors.shadow.withValues(alpha: 0.11),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          // Deep contact occlusion
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: child),
    );
  }
}

class _MapTripCard extends StatelessWidget {
  const _MapTripCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    elevation: 10,
    shadowColor: context.colors.shadow.withValues(alpha: 0.2),
    borderRadius: BorderRadius.circular(22),
    child: Padding(padding: const EdgeInsets.all(14), child: child),
  );
}

class _BarangayPickerSheet extends StatefulWidget {
  const _BarangayPickerSheet({
    required this.barangays,
    required this.selectedName,
  });

  final List<BariliBarangayBoundary> barangays;
  final String? selectedName;

  @override
  State<_BarangayPickerSheet> createState() => _BarangayPickerSheetState();
}

class _BarangayPickerSheetState extends State<_BarangayPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.barangays.where((barangay) {
      return barangay.name.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    return FractionallySizedBox(
      heightFactor: 0.78,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose a barangay',
                        style: GoogleFonts.outfit(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Only the selected boundary will be highlighted.',
                        style: GoogleFonts.outfit(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              autofocus: false,
              onChanged: (value) => setState(() => _query = value.trim()),
              decoration: const InputDecoration(
                hintText: 'Search Barili barangays',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              itemCount: filtered.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return ListTile(
                    leading: const Icon(Icons.public_rounded),
                    title: const Text('All Barangays'),
                    subtitle: const Text('Clear the current highlight'),
                    selected: widget.selectedName == null,
                    onTap: () => Navigator.pop(context, ''),
                  );
                }
                final barangay = filtered[index - 1];
                return ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(barangay.name),
                  subtitle: Text(
                    '${barangay.areaSquareKilometers.toStringAsFixed(2)} km²',
                  ),
                  trailing: widget.selectedName == barangay.name
                      ? Icon(
                          Icons.check_circle_rounded,
                          color: context.colors.primaryGreen,
                        )
                      : null,
                  selected: widget.selectedName == barangay.name,
                  onTap: () => Navigator.pop(context, barangay.name),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
