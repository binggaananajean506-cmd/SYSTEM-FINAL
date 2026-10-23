import 'package:esugid/app/theme/semantic_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme/app_colors.dart';
import '../../map/domain/resident_map_place.dart';
import '../domain/travel_route.dart';

/// Trips longer than this suggest handing off to Google Maps.
const int longTripMeters = 25000;

class RoutePreviewCard extends StatelessWidget {
  const RoutePreviewCard({
    super.key,
    required this.destination,
    required this.options,
    required this.selectedMode,
    required this.loading,
    required this.error,
    required this.onModeChanged,
    required this.onRetry,
    required this.onClose,
    required this.onDirections,
    required this.onShowDetails,
    required this.onStartNavigation,
  });

  final ResidentMapPlace destination;
  final RouteOptions? options;
  final TravelMode selectedMode;
  final bool loading;
  final String? error;
  final ValueChanged<TravelMode> onModeChanged;
  final VoidCallback onRetry;
  final VoidCallback onClose;
  final VoidCallback onDirections;
  final VoidCallback onShowDetails;
  final VoidCallback onStartNavigation;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final route = options?[selectedMode];
    return Material(
      key: const ValueKey('route-preview-card'),
      color: colors.surface,
      elevation: 10,
      shadowColor: context.colors.shadow.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.colors.brand.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    destination.category.icon,
                    color: context.colors.primaryGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        destination.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: colors.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        destination.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close directions',
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildBody(context, route),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, TravelRoute? route) {
    final colors = Theme.of(context).colorScheme;
    final textStyle = GoogleFonts.outfit(
      color: colors.onSurfaceVariant,
      fontSize: 12,
      fontWeight: FontWeight.w500,
    );
    if (loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LinearProgressIndicator(minHeight: 3),
            const SizedBox(height: 8),
            Text('Finding the route from your location…', style: textStyle),
          ],
        ),
      );
    }
    if (error != null || route == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                error ??
                    'No ${selectedMode.label.toLowerCase()} route was found.',
                style: textStyle.copyWith(color: colors.error),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'Directions',
          style: GoogleFonts.outfit(
            color: colors.onSurface,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final mode in TravelMode.values)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: mode == TravelMode.values.last ? 0 : 6,
                  ),
                  child: _modeChoice(mode),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          [
            formatRouteDistance(route.distanceMeters),
            if (route.description.isNotEmpty) 'via ${route.description}',
          ].join(' '),
          style: textStyle,
        ),
        if (route.estimated)
          Text(
            'Motorcycle time is estimated from the car route.',
            style: textStyle.copyWith(fontSize: 11),
          ),
        if (options?[TravelMode.walk] == null)
          Text(
            'Walking directions are unavailable for this trip.',
            style: textStyle.copyWith(fontSize: 11),
          ),
        if (route.distanceMeters > longTripMeters)
          Text(
            'This is a long trip. Google Maps can guide you with voice on the way.',
            style: textStyle.copyWith(
              fontSize: 11,
              color: context.colors.warning,
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: FilledButton.icon(
                key: const ValueKey('route-directions'),
                onPressed: onDirections,
                icon: const Icon(Icons.alt_route_rounded),
                label: const Text('Directions'),
                style: FilledButton.styleFrom(
                  backgroundColor: context.colors.brand,
                  foregroundColor: context.colors.onAccent,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: OutlinedButton(
                onPressed: onShowDetails,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text('View Details'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const ValueKey('start-navigation'),
          onPressed: onStartNavigation,
          icon: const Icon(Icons.navigation_rounded),
          label: const Text('Start Navigation'),
          style: FilledButton.styleFrom(
            backgroundColor: context.colors.brandStrong,
            foregroundColor: context.colors.onAccent,
            minimumSize: const Size.fromHeight(44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        ),
      ],
    );
  }

  Widget _modeChoice(TravelMode mode) {
    final option = options?[mode];
    if (option == null) return _UnavailableModeChoice(mode: mode);
    return _ModeChoice(
      route: option,
      selected: mode == selectedMode,
      onTap: () => onModeChanged(mode),
    );
  }
}

class _ModeChoice extends StatelessWidget {
  const _ModeChoice({
    required this.route,
    required this.selected,
    required this.onTap,
  });

  final TravelRoute route;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = selected ? context.colors.primaryGreen
        : colors.onSurfaceVariant;
    return Semantics(
      selected: selected,
      button: true,
      label: '${route.mode.label}, ${formatRouteDuration(route.duration)}',
      child: InkWell(
        key: ValueKey('route-mode-${route.mode.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? context.colors.brand.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? context.colors.primaryGreen
                  : colors.outlineVariant,
              width: 1.5,
            ),
          ),
          child: ExcludeSemantics(
            child: Row(
              children: [
                Icon(route.mode.icon, color: accent, size: 22),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatRouteDuration(route.duration),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: colors.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        route.mode.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: colors.onSurfaceVariant,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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

class _UnavailableModeChoice extends StatelessWidget {
  const _UnavailableModeChoice({required this.mode});

  final TravelMode mode;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(mode.icon, color: colors.onSurfaceVariant, size: 22),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unavailable',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: colors.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  mode.label,
                  style: GoogleFonts.outfit(
                    color: colors.onSurfaceVariant,
                    fontSize: 10.5,
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
