import 'dart:async';

import 'package:esugid/core/widgets/app_feedback.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../features/explore/data/barili_place_search_service.dart';
import '../features/explore/domain/barili_destination.dart';
import '../features/explore/domain/explore_place.dart';
import '../features/navigation/data/google_maps_handoff.dart';
import '../widgets/esugid_page_header.dart';
import 'resident_map_page.dart';

class ExploreBariliPage extends StatefulWidget {
  const ExploreBariliPage({
    super.key,
    this.placeProvider,
    this.initialQuery,
    this.openFirstResult = false,
    this.initialCategory,
    this.returnDirections = false,
  });

  final BariliPlaceProvider? placeProvider;
  final String? initialQuery;
  final bool openFirstResult;
  final BariliDestinationCategory? initialCategory;

  /// When true, "Get Directions" on a curated place pops this page with that
  /// [BariliDestination] instead of opening a new map, for callers that
  /// already show the map.
  final bool returnDirections;

  @override
  State<ExploreBariliPage> createState() => _ExploreBariliPageState();
}

class _ExploreBariliPageState extends State<ExploreBariliPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  late final BariliPlaceProvider _placeProvider;
  late final bool _ownsPlaceProvider;
  BariliDestinationCategory? _selectedCategory;
  Timer? _searchDebounce;
  List<ExplorePlaceSuggestion> _suggestions = const [];
  String _query = '';
  String? _searchError;
  String? _loadingPlaceId;
  bool _searching = false;
  int _searchRequest = 0;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _ownsPlaceProvider = widget.placeProvider == null;
    _placeProvider = widget.placeProvider ?? PhotonBariliPlaceProvider();
    final initialQuery = widget.initialQuery?.trim() ?? '';
    if (initialQuery.isNotEmpty) _searchController.text = initialQuery;
    _searchController.addListener(_onSearchChanged);
    if (initialQuery.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openInitialPlace(initialQuery);
      });
    }
  }

  Future<void> _openInitialPlace(String query) async {
    final localMatch = _matchingDestinationsFor(query);
    if (widget.openFirstResult && localMatch.isNotEmpty) {
      await _showDestination(localMatch.first);
      return;
    }
    await _searchPlaces(query);
    if (!mounted || !widget.openFirstResult || _suggestions.isEmpty) return;
    await _selectSuggestion(_suggestions.first);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    if (_ownsPlaceProvider) _placeProvider.dispose();
    super.dispose();
  }

  List<BariliDestination> get _visibleDestinations {
    final selectedCategory = _selectedCategory;
    if (selectedCategory == null) return bariliDestinations;
    return bariliDestinations
        .where((destination) => destination.category == selectedCategory)
        .toList();
  }

  List<BariliDestination> _matchingDestinationsFor(String input) {
    final terms = input
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .toList();
    if (terms.isEmpty) return const [];
    return bariliDestinations
        .where(
          (destination) => terms.every(destination.searchableText.contains),
        )
        .toList();
  }

  bool get _showingSearch => _query.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final destinations = _visibleDestinations;
    return Scaffold(
      body: CustomScrollView(
        key: const ValueKey('explore-barili-scroll-view'),
        physics: const ClampingScrollPhysics(),
        slivers: [
          ESugidSliverPageHeader(
            pinned: true,
            showBackButton: true,
            onBack: () => Navigator.of(context).pop(),
            title: 'Explore Barili',
            subtitle: null,
            icon: null,
            iconWidget: null,
            sectionLabelWidget: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 3.5,
              ),
              decoration: BoxDecoration(
                color: context.colors.brand.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: context.colors.primaryGreen.withValues(alpha: 0.45),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 5.5,
                    height: 5.5,
                    decoration: BoxDecoration(
                      color: context.colors.brand,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: context.colors.brandStrong,
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 5.5),
                  Text(
                    'DISCOVER BARILI',
                    style: GoogleFonts.outfit(
                      color: context.colors.primaryGreen,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: _buildSearchField()),
          if (_showingSearch)
            SliverToBoxAdapter(child: _buildSearchResults())
          else ...[
            SliverToBoxAdapter(child: _buildCategoryFilters()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
              sliver: SliverList.separated(
                itemCount: destinations.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (context, index) => _DestinationCard(
                  destination: destinations[index],
                  onTap: () => _showDestination(destinations[index]),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
      child: TextField(
        key: const ValueKey('explore-place-search'),
        controller: _searchController,
        focusNode: _searchFocus,
        textInputAction: TextInputAction.search,
        autocorrect: false,
        decoration: InputDecoration(
          hintText: 'Search name, category or barangay',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: _searchController.clear,
                  icon: const Icon(Icons.close_rounded),
                ),
          filled: true,
          fillColor: context.colors.inputBackground,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(17),
            borderSide: BorderSide(
              color: context.colors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(17),
            borderSide: BorderSide(
              color: context.colors.primaryGreen,
              width: 1.5,
            ),
          ),
        ),
        style: GoogleFonts.outfit(
          color: context.colors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    final input = _query.trim();
    final localMatches = _matchingDestinationsFor(input);
    if (input.length < 2) {
      return _SearchMessage(
        icon: Icons.travel_explore_rounded,
        message: 'Type at least 2 characters to find a place in Barili.',
      );
    }
    if (_searching && localMatches.isEmpty) {
      return const _SearchMessage(
        loading: true,
        message: 'Searching real places in Barili...',
      );
    }
    if (_searchError != null && localMatches.isEmpty) {
      return _SearchMessage(
        icon: Icons.wifi_off_rounded,
        message: _searchError!,
        actionLabel: 'Retry',
        onAction: () => _searchPlaces(input),
      );
    }
    if (_suggestions.isEmpty && localMatches.isEmpty) {
      return const _SearchMessage(
        icon: Icons.location_off_outlined,
        message: 'No matching places were found within Barili.',
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (localMatches.isNotEmpty) ...[
            Text(
              'VERIFIED BARILI PLACES',
              style: GoogleFonts.outfit(
                color: context.colors.primaryGreen,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 9),
            for (var index = 0; index < localMatches.length; index++) ...[
              _DestinationCard(
                destination: localMatches[index],
                onTap: () => _showDestination(localMatches[index]),
              ),
              if (index != localMatches.length - 1) const SizedBox(height: 12),
            ],
          ],
          if (_suggestions.isNotEmpty) ...[
            SizedBox(height: localMatches.isEmpty ? 0 : 20),
            Text(
              'MORE MAP RESULTS',
              style: GoogleFonts.outfit(
                color: context.colors.primaryGreen,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 9),
            Material(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var index = 0; index < _suggestions.length; index++) ...[
                    _PlaceSuggestionTile(
                      suggestion: _suggestions[index],
                      loading:
                          _loadingPlaceId == _suggestions[index].providerId,
                      onTap: () => _selectSuggestion(_suggestions[index]),
                    ),
                    if (index != _suggestions.length - 1)
                      const Divider(height: 1, indent: 58),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Map search © OpenStreetMap contributors · Powered by Photon',
              style: GoogleFonts.outfit(
                color: context.colors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ] else if (_searching) ...[
            const SizedBox(height: 18),
            const LinearProgressIndicator(minHeight: 2),
          ] else if (_searchError != null) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => _searchPlaces(input),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Online map search unavailable · Retry'),
            ),
          ],
        ],
      ),
    );
  }

  void _onSearchChanged() {
    final nextQuery = _searchController.text;
    _searchDebounce?.cancel();
    final request = ++_searchRequest;
    setState(() {
      _query = nextQuery;
      _searchError = null;
      if (nextQuery.trim().length < 2) {
        _suggestions = const [];
        _searching = false;
      } else {
        _searching = true;
      }
    });
    if (nextQuery.trim().length < 2) return;
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (request == _searchRequest) _searchPlaces(nextQuery.trim(), request);
    });
  }

  Future<void> _searchPlaces(String query, [int? requestId]) async {
    final request = requestId ?? ++_searchRequest;
    if (requestId == null) {
      setState(() {
        _searching = true;
        _searchError = null;
      });
    }
    try {
      final places = await _placeProvider.search(query);
      if (!mounted || request != _searchRequest) return;
      setState(() {
        _suggestions = places;
        _searching = false;
      });
    } catch (error) {
      if (!mounted || request != _searchRequest) return;
      setState(() {
        _suggestions = const [];
        _searching = false;
        _searchError = error is BariliPlaceSearchException
            ? error.message
            : 'Could not search places. Check your connection and retry.';
      });
    }
  }

  Future<void> _selectSuggestion(ExplorePlaceSuggestion suggestion) async {
    if (_loadingPlaceId != null) return;
    setState(() => _loadingPlaceId = suggestion.providerId);
    try {
      final place = explorePlaceFromSuggestion(suggestion);
      final enrichedPlace = _placeProvider.loadPlace(suggestion);
      _searchFocus.unfocus();
      await _showPlace(place, detailsFuture: enrichedPlace);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        AppSnackBar(
          content: Text('Unable to load this place. Please try again.'),
          kind: FeedbackKind.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingPlaceId = null);
    }
  }

  Widget _buildCategoryFilters() {
    return SizedBox(
      height: 54,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        children: [
          _CategoryChip(
            key: const ValueKey('destination-filter-all'),
            label: 'All',
            icon: Icons.apps_rounded,
            selected: _selectedCategory == null,
            onSelected: () => setState(() => _selectedCategory = null),
          ),
          for (final category in BariliDestinationCategory.values) ...[
            const SizedBox(width: 8),
            _CategoryChip(
              key: ValueKey('destination-filter-${category.name}'),
              label: category.label,
              icon: category.icon,
              selected: _selectedCategory == category,
              onSelected: () => setState(() => _selectedCategory = category),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showDestination(BariliDestination destination) async {
    await _showPlace(ExplorePlace.fromDestination(destination));
  }

  Future<void> _showPlace(
    ExplorePlace place, {
    Future<ExplorePlace>? detailsFuture,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _DestinationDetails(
        place: place,
        showsRouteInApp: curatedDestinationFor(place) != null,
        onDirections: () => _openDirections(place),
        onOpenSource: _openSource,
        onCall: _callPlace,
        detailsFuture: detailsFuture,
      ),
    );
  }

  Future<void> _openDirections(ExplorePlace place) async {
    final curated = curatedDestinationFor(place);
    if (curated != null) {
      final navigator = Navigator.of(context);
      navigator.pop(); // The details sheet.
      if (widget.returnDirections) {
        navigator.pop(curated);
      } else {
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => ResidentMapPage(routeDestination: curated),
          ),
        );
      }
      return;
    }
    final position = place.position;
    if (position == null) return;
    final uri = directionsUriFor(position);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        AppSnackBar(
          content: Text('No navigation app is available on this device.'),
          kind: FeedbackKind.warning,
        ),
      );
    }
  }

  Future<void> _callPlace(String phone) async {
    final normalized = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (normalized.isEmpty) return;
    if (!await launchUrl(Uri(scheme: 'tel', path: normalized)) && mounted) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        AppSnackBar(content: Text('Calling is unavailable on this device.'),
          kind: FeedbackKind.error,
        ),
      );
    }
  }

  Future<void> _openSource(String value) async {
    final uri = Uri.parse(value);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        AppSnackBar(content: Text('Could not open the information source.'),
          kind: FeedbackKind.error,
        ),
      );
    }
  }
}

Uri directionsUriFor(LatLng destination) =>
    googleMapsDirectionsUri(destination);

/// The curated record behind [place], which gets in-app directions; live
/// search results have none.
BariliDestination? curatedDestinationFor(ExplorePlace place) {
  for (final destination in bariliDestinations) {
    if (destination.id == place.id) return destination;
  }
  return null;
}

class _SearchMessage extends StatelessWidget {
  const _SearchMessage({
    required this.message,
    this.icon,
    this.loading = false,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final IconData? icon;
  final bool loading;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              )
            else
              Icon(
                icon ?? Icons.place_outlined,
                color: context.colors.primaryGreen,
                size: 30,
              ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: context.colors.textSecondary,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 8),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlaceSuggestionTile extends StatelessWidget {
  const _PlaceSuggestionTile({
    required this.suggestion,
    required this.loading,
    required this.onTap,
  });

  final ExplorePlaceSuggestion suggestion;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: loading ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: context.colors.brand.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                suggestion.category?.icon ?? Icons.place_rounded,
                color: context.colors.primaryGreen,
                size: 19,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: context.colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    suggestion.formattedAddress,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: context.colors.textSecondary,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (loading)
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                color: context.colors.primaryGreen,
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: selected
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [context.colors.brand, context.colors.brand],
              )
            : null,
        color: selected
            ? null
            : (context.colors.surface),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: selected
              ? context.colors.border.withValues(alpha: 0.3)
              : (context.colors.border),
          width: 1.1,
        ),
        boxShadow: selected
            ? [
                // 3D bottom extrusion ledge
                BoxShadow(
                  color: context.colors.brandStrong,
                  offset: Offset(0, 2.4),
                  blurRadius: 0,
                ),
                BoxShadow(
                  color: context.colors.brandStrong.withValues(alpha: 0.28),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : [
                BoxShadow(
                  color: context.colors.shadow.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onSelected,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8.5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected ? context.colors.onAccent
                      : context.colors.primaryGreen,
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    color: selected ? context.colors.onAccent
                        : context.colors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DestinationCard extends StatelessWidget {
  const _DestinationCard({required this.destination, required this.onTap});

  final BariliDestination destination;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final place = ExplorePlace.fromDestination(destination);
    return Container(
      key: ValueKey('destination-card-${destination.id}'),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDark
              ? context.colors.border
              : context.colors.border.withValues(alpha: 0.9),
          width: 1.4,
        ),
        boxShadow: [
          // Specular top highlight
          BoxShadow(
            color: context.colors.highlight.withValues(alpha: 0.9),
            blurRadius: 2,
            offset: const Offset(0, -1),
          ),
          // Ambient emerald glow
          BoxShadow(
            color: context.colors.brandStrong.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
          // Grounding 3D contact shadow
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: 0.07),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 180,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _DestinationVisual(
                      place: place,
                      photo: place.photos.firstOrNull,
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              context.colors.shadow.withValues(alpha: 0.25),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DestinationCategoryPill(place: place),
                    const SizedBox(height: 11),
                    Text(
                      destination.name,
                      style: GoogleFonts.outfit(
                        color: context.colors.textPrimary,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          color: context.colors.primaryGreen,
                          size: 16,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${destination.barangay}, Barili',
                          style: GoogleFonts.outfit(
                            color: context.colors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Text(
                      destination.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: context.colors.textSecondary,
                        fontSize: 12.5,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              context.colors.surfaceAlt,
                              context.colors.surfaceAlt,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: context.colors.primaryGreen.withValues(alpha: 0.35,
                            ),
                            width: 1.1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: context.colors.brandStrong.withValues(alpha: 0.2,
                              ),
                              offset: const Offset(0, 2.5),
                              blurRadius: 0,
                            ),
                            BoxShadow(
                              color: context.colors.shadow.withValues(alpha: 0.04,
                              ),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'View Details',
                              style: GoogleFonts.poppins(
                                color: context.colors.primaryGreen,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 15,
                              color: context.colors.primaryGreen,
                            ),
                          ],
                        ),
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
}

class _DestinationDetails extends StatefulWidget {
  const _DestinationDetails({
    required this.place,
    required this.showsRouteInApp,
    required this.onDirections,
    required this.onOpenSource,
    required this.onCall,
    this.detailsFuture,
  });

  final ExplorePlace place;
  final bool showsRouteInApp;
  final VoidCallback onDirections;
  final ValueChanged<String> onOpenSource;
  final ValueChanged<String> onCall;
  final Future<ExplorePlace>? detailsFuture;

  @override
  State<_DestinationDetails> createState() => _DestinationDetailsState();
}

class _DestinationDetailsState extends State<_DestinationDetails> {
  int _photoIndex = 0;
  late ExplorePlace _place;
  bool _loadingDetails = false;

  @override
  void initState() {
    super.initState();
    _place = widget.place;
    final detailsFuture = widget.detailsFuture;
    if (detailsFuture != null) {
      _loadingDetails = true;
      unawaited(_loadDetails(detailsFuture));
    }
  }

  Future<void> _loadDetails(Future<ExplorePlace> detailsFuture) async {
    try {
      final place = await detailsFuture;
      if (!mounted) return;
      setState(() {
        _place = place;
        _loadingDetails = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingDetails = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final destination = _place;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.92,
      child: Material(
        color: context.colors.surfaceAlt,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  SizedBox(
                    height: 286,
                    child: Stack(
                      children: [
                        Positioned.fill(child: _buildGallery(destination)),
                        Positioned(
                          top: 12,
                          right: 12,
                          child: IconButton.filled(
                            tooltip: 'Close',
                            onPressed: () => Navigator.pop(context),
                            style: IconButton.styleFrom(
                              backgroundColor: context.colors.shadow.withValues(
                                alpha: 0.5412,
                              ),
                              foregroundColor: context.colors.onAccent,
                            ),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ),
                        if (destination.photos.length > 1)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 12,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                destination.photos.length,
                                (index) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  width: index == _photoIndex ? 18 : 6,
                                  height: 6,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: index == _photoIndex
                                        ? context.colors.surface
                                        : context.colors.surface.withValues(
                                            alpha: 0.5412,
                                          ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (destination.photos.isNotEmpty)
                          Positioned(
                            left: 12,
                            bottom: destination.photos.length > 1 ? 34 : 12,
                            child: _buildPhotoCredit(destination),
                          ),
                      ],
                    ),
                  ),
                  if (_loadingDetails)
                    const LinearProgressIndicator(minHeight: 2),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DestinationCategoryPill(place: destination),
                        const SizedBox(height: 12),
                        Text(
                          destination.name,
                          style: GoogleFonts.outfit(
                            color: context.colors.textPrimary,
                            fontSize: 27,
                            height: 1.1,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.7,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              color: context.colors.primaryGreen,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                destination.formattedAddress,
                                style: GoogleFonts.outfit(
                                  color: context.colors.primaryGreen,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          destination.description,
                          style: GoogleFonts.outfit(
                            color: context.colors.textPrimary,
                            fontSize: 15,
                            height: 1.65,
                          ),
                        ),
                        if (destination.visitNote case final note?) ...[
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: context.colors.warningSolid.withValues(
                                alpha: 0.08,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  color: context.colors.warning,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    note,
                                    style: GoogleFonts.outfit(
                                      color: context.colors.textPrimary,
                                      fontSize: 12,
                                      height: 1.45,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (destination.openingHours case final hours?)
                          _PlaceFactRow(
                            icon: Icons.schedule_rounded,
                            label: 'Opening hours',
                            value: hours,
                          ),
                        if (destination.contact case final contact?)
                          _PlaceFactRow(
                            icon: Icons.phone_outlined,
                            label: 'Contact',
                            value: contact,
                          ),
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: context.colors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: context.colors.primaryGreen.withValues(alpha: 0.16,
                              ),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: context.colors.brandStrong.withValues(alpha: 0.06,
                                ),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                              BoxShadow(
                                color: context.colors.shadow.withValues(
                                  alpha: 0.0314,
                                ),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      context.colors.surfaceAlt,
                                      context.colors.surfaceAlt,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: context.colors.brandStrong
                                          .withValues(alpha: 0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.near_me_rounded,
                                  color: context.colors.primaryGreen,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Direct Navigation Available',
                                      style: GoogleFonts.outfit(
                                        color: context.colors.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      destination.formattedAddress,
                                      style: GoogleFonts.outfit(
                                        color: context.colors.textSecondary,
                                        fontSize: 12,
                                        height: 1.35,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.navigation_rounded,
                                          size: 13,
                                          color: context.colors.primaryGreen,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            widget.showsRouteInApp
                                                ? 'Tap "Get Directions" to see the route on the Barili map'
                                                : 'Tap "Get Directions" below to launch Google Maps',
                                            style: GoogleFonts.outfit(
                                              color:
                                                  context.colors.primaryGreen,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () =>
                              widget.onOpenSource(destination.sourceUrl),
                          icon: const Icon(Icons.open_in_new_rounded, size: 17),
                          label: Text(
                            'Information: ${destination.sourceLabel}',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (destination.contact != null ||
                        destination.officialPageUrl != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            if (destination.contact case final phone?)
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => widget.onCall(phone),
                                  icon: const Icon(Icons.phone_outlined),
                                  label: const Text('Call'),
                                ),
                              ),
                            if (destination.contact != null &&
                                destination.officialPageUrl != null)
                              const SizedBox(width: 8),
                            if (destination.officialPageUrl case final page?)
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => widget.onOpenSource(page),
                                  icon: const Icon(Icons.language_rounded),
                                  label: const Text('Official Page'),
                                ),
                              ),
                          ],
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: ValueKey('directions-${destination.id}'),
                        onPressed: destination.position == null
                            ? null
                            : widget.onDirections,
                        icon: const Icon(Icons.directions_rounded),
                        label: Text(
                          destination.position == null
                              ? 'Location unavailable'
                              : 'Get Directions',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: context.colors.brand,
                          foregroundColor: context.colors.onAccent,
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17),
                          ),
                          textStyle: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGallery(ExplorePlace destination) {
    if (destination.photos.isEmpty) {
      return _DestinationVisual(place: destination);
    }
    return PageView.builder(
      itemCount: destination.photos.length,
      onPageChanged: (index) => setState(() => _photoIndex = index),
      itemBuilder: (context, index) => _DestinationVisual(
        place: destination,
        photo: destination.photos[index],
      ),
    );
  }

  Widget _buildPhotoCredit(ExplorePlace destination) {
    final photo = destination.photos[_photoIndex];
    return Material(
      color: context.colors.shadow.withValues(alpha: 0.5412),
      borderRadius: BorderRadius.circular(9),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => widget.onOpenSource(photo.sourceUrl),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.photo_outlined, color: context.colors.onAccent, size: 13,
              ),
              const SizedBox(width: 5),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 230),
                child: Text(
                  photo.credit,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: context.colors.onAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceFactRow extends StatelessWidget {
  const _PlaceFactRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: context.colors.primaryGreen, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    color: context.colors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    color: context.colors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DestinationCategoryPill extends StatelessWidget {
  const _DestinationCategoryPill({required this.place});

  final ExplorePlace place;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.colors.brand.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(place.categoryIcon, size: 15, color: context.colors.primaryGreen,
          ),
          const SizedBox(width: 6),
          Text(
            place.categoryLabel.toUpperCase(),
            style: GoogleFonts.outfit(
              color: context.colors.primaryGreen,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _DestinationVisual extends StatelessWidget {
  const _DestinationVisual({required this.place, this.photo});

  final ExplorePlace place;
  final BariliDestinationPhoto? photo;

  @override
  Widget build(BuildContext context) {
    final selectedPhoto = photo;
    if (selectedPhoto == null) return _buildUnavailablePhoto(context);

    final assetPath = selectedPhoto.assetPath;
    if (assetPath != null) {
      return Image.asset(
        assetPath,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildUnavailablePhoto(context),
      );
    }

    return Image.network(
      selectedPhoto.networkUrl!,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return ColoredBox(
          color: context.colors.surfaceAlt,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
      errorBuilder: (_, _, _) => _buildUnavailablePhoto(context),
    );
  }

  Widget _buildUnavailablePhoto(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: ESugidPalette.headerGradient),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(place.categoryIcon, color: context.colors.onAccent, size: 48),
            const SizedBox(height: 10),
            Text(
              'Photo unavailable',
              style: GoogleFonts.outfit(
                color: context.colors.onAccent,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
