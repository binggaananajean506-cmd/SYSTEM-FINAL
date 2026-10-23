import 'dart:async';

import 'package:esugid/core/widgets/app_feedback.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/theme/app_colors.dart';
import '../../../auth_service.dart';
import '../domain/resident_map_place.dart';

class ResidentMapPlaceDetailsPage extends StatefulWidget {
  const ResidentMapPlaceDetailsPage({
    super.key,
    required this.place,
    required this.onDirections,
    this.detailsFuture,
  });

  final ResidentMapPlace place;

  /// Called after this page closes so the map can show directions.
  final VoidCallback onDirections;
  final Future<ResidentMapPlace>? detailsFuture;

  @override
  State<ResidentMapPlaceDetailsPage> createState() =>
      _ResidentMapPlaceDetailsPageState();
}

class _ResidentMapPlaceDetailsPageState
    extends State<ResidentMapPlaceDetailsPage> {
  late ResidentMapPlace _place;
  late final String _savedPreferenceKey;
  bool _saved = false;
  bool _saving = false;
  bool _loadingDetails = false;

  @override
  void initState() {
    super.initState();
    _place = widget.place;
    _savedPreferenceKey =
        'resident_map.saved_places.${AuthService.currentUser?.uid ?? 'guest'}';
    unawaited(_loadSaved());
    final detailsFuture = widget.detailsFuture;
    if (detailsFuture != null) {
      _loadingDetails = true;
      unawaited(_loadDetails(detailsFuture));
    }
  }

  Future<void> _loadSaved() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _saved = (preferences.getStringList(_savedPreferenceKey) ?? const [])
            .contains(widget.place.id);
      });
    } catch (_) {
      // Saving remains available; the button will report any write failure.
    }
  }

  Future<void> _loadDetails(Future<ResidentMapPlace> detailsFuture) async {
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

  Future<void> _toggleSaved() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final preferences = await SharedPreferences.getInstance();
      final ids = (preferences.getStringList(_savedPreferenceKey) ?? const [])
          .toSet();
      final nextSaved = !_saved;
      if (nextSaved) {
        ids.add(widget.place.id);
      } else {
        ids.remove(widget.place.id);
      }
      final written = await preferences.setStringList(
        _savedPreferenceKey,
        ids.toList(growable: false),
      );
      if (!written) throw StateError('Place save failed.');
      if (!mounted) return;
      setState(() => _saved = nextSaved);
      ScaffoldMessenger.of(context).showAppSnackBar(
        AppSnackBar(
          content: Text(
            nextSaved ? 'Place saved.' : 'Place removed from saved.',
          ),
          kind: FeedbackKind.success,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        AppSnackBar(
          content: Text('Could not update saved places. Please try again.'),
          kind: FeedbackKind.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final place = _place;
    final colors = Theme.of(context).colorScheme;
    final photoHeight = MediaQuery.sizeOf(context).height < 650 ? 190.0 : 260.0;
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        titleTextStyle: Theme.of(
          context,
        ).appBarTheme.titleTextStyle?.copyWith(color: context.colors.onAccent),

        title: Text(
          'Place Details',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700,
            color: context.colors.onAccent,
          ),
        ),
        backgroundColor: context.colors.brandStrong,
        foregroundColor: context.colors.onAccent,
      ),
      body: ListView(
        children: [
          SizedBox(
            height: photoHeight,
            child: _PlacePhoto(place: place),
          ),
          if (_loadingDetails) const LinearProgressIndicator(minHeight: 3),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.brand.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        place.category.icon,
                        color: context.colors.primaryGreen,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        place.category.label,
                        style: GoogleFonts.outfit(
                          color: context.colors.primaryGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 13),
                Text(
                  place.name,
                  style: GoogleFonts.outfit(
                    color: colors.onSurface,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    height: 1.12,
                  ),
                ),
                const SizedBox(height: 13),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      color: context.colors.primaryGreen,
                      size: 19,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        place.address,
                        style: GoogleFonts.outfit(
                          color: colors.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Divider(color: colors.outlineVariant),
                const SizedBox(height: 12),
                Text(
                  'About this place',
                  style: GoogleFonts.outfit(
                    color: colors.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  place.description,
                  style: GoogleFonts.outfit(
                    color: colors.onSurfaceVariant,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                if (place.openingHours case final hours?)
                  _InfoRow(
                    icon: Icons.schedule_rounded,
                    label: 'Hours',
                    value: hours,
                  ),
                if (place.contact case final contact?)
                  _InfoRow(
                    icon: Icons.call_outlined,
                    label: 'Contact',
                    value: contact,
                  ),
                if (place.officialPageUrl case final website?)
                  _InfoRow(
                    icon: Icons.language_rounded,
                    label: 'Website',
                    value: website,
                  ),
                if (place.sourceLabel case final source?) ...[
                  const SizedBox(height: 22),
                  Text(
                    'Information source: $source',
                    style: GoogleFonts.outfit(
                      color: colors.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: FilledButton.icon(
                  key: const ValueKey('map-place-directions'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onDirections();
                  },
                  icon: const Icon(Icons.directions_rounded),
                  label: const Text('Directions'),
                  style: FilledButton.styleFrom(
                    backgroundColor: context.colors.brand,
                    foregroundColor: context.colors.onAccent,
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  key: const ValueKey('map-place-save'),
                  onPressed: _saving ? null : _toggleSaved,
                  icon: Icon(
                    _saved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_outline_rounded,
                  ),
                  label: Text(_saved ? 'Saved' : 'Save'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.colors.primaryGreen,
                    minimumSize: const Size.fromHeight(50),
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

class _PlacePhoto extends StatelessWidget {
  const _PlacePhoto({required this.place});

  final ResidentMapPlace place;

  @override
  Widget build(BuildContext context) {
    final photo = place.photos.firstOrNull;
    final image = photo?.assetPath != null
        ? Image.asset(
            photo!.assetPath!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _PhotoFallback(category: place.category),
          )
        : photo?.networkUrl != null
        ? Image.network(
            photo!.networkUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _PhotoFallback(category: place.category),
          )
        : _PhotoFallback(category: place.category);
    return Stack(
      fit: StackFit.expand,
      children: [
        image,
        if (photo != null)
          Positioned(
            left: 12,
            bottom: 12,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.colors.shadow.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                child: Text(
                  photo.credit,
                  style: GoogleFonts.outfit(color: context.colors.onAccent, fontSize: 10,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback({required this.category});

  final ResidentMapPlaceCategory category;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(gradient: ESugidPalette.headerGradient),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(category.icon, color: context.colors.onAccent, size: 54),
          const SizedBox(height: 9),
          Text(
            'Photo unavailable',
            style: GoogleFonts.outfit(
              color: context.colors.onAccent,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 13),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: context.colors.primaryGreen, size: 18),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            '$label: $value',
            style: GoogleFonts.outfit(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ),
      ],
    ),
  );
}
