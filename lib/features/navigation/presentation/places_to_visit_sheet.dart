import 'package:esugid/app/theme/semantic_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/theme/app_colors.dart';
import '../../explore/domain/barili_destination.dart';
import '../domain/travel_route.dart';

/// Lists the curated Explore Barili places, nearest first when the resident's
/// location is known, and pops with the chosen [BariliDestination].
class PlacesToVisitSheet extends StatefulWidget {
  const PlacesToVisitSheet({
    super.key,
    required this.destinations,
    this.currentLocation,
  });

  final List<BariliDestination> destinations;
  final LatLng? currentLocation;

  @override
  State<PlacesToVisitSheet> createState() => _PlacesToVisitSheetState();
}

class _PlacesToVisitSheetState extends State<PlacesToVisitSheet> {
  static const Distance _distance = Distance();

  BariliDestinationCategory? _category;

  int? _metersTo(BariliDestination destination) {
    final origin = widget.currentLocation;
    if (origin == null) return null;
    return _distance.as(LengthUnit.Meter, origin, destination.position).round();
  }

  @override
  Widget build(BuildContext context) {
    final categories = BariliDestinationCategory.values
        .where((category) =>
            widget.destinations.any((place) => place.category == category),
        )
        .toList();
    final places = widget.destinations
        .where((place) => _category == null || place.category == _category)
        .map((place) => (place: place, meters: _metersTo(place)))
        .toList();
    if (widget.currentLocation != null) {
      places.sort((a, b) => a.meters!.compareTo(b.meters!));
    }
    final colors = Theme.of(context).colorScheme;

    return FractionallySizedBox(
      heightFactor: 0.78,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Places to visit',
                        style: GoogleFonts.outfit(
                          color: colors.onSurface,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        widget.currentLocation == null
                            ? 'Turn on location to see the nearest places first.'
                            : 'Nearest first · straight-line distance',
                        style: GoogleFonts.outfit(
                          color: colors.onSurfaceVariant,
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
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                _CategoryChoice(
                  label: 'All',
                  selected: _category == null,
                  onSelected: () => setState(() => _category = null),
                ),
                for (final category in categories)
                  _CategoryChoice(
                    key: ValueKey('places-filter-${category.name}'),
                    label: category.label,
                    icon: category.icon,
                    selected: _category == category,
                    onSelected: () => setState(() => _category = category),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
              itemCount: places.length,
              itemBuilder: (context, index) {
                final (:place, :meters) = places[index];
                return ListTile(
                  key: ValueKey('place-to-visit-${place.id}'),
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: context.colors.brand.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(place.category.icon, color: context.colors.primaryGreen,
                    ),
                  ),
                  title: Text(
                    place.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text('${place.barangay} · ${place.category.label}'),
                  trailing: meters == null
                      ? const Icon(Icons.chevron_right_rounded)
                      : Text(
                          formatRouteDistance(meters),
                          style: GoogleFonts.outfit(
                            color: context.colors.primaryGreen,
                            fontWeight: FontWeight.w800,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                  onTap: () => Navigator.pop(context, place),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChoice extends StatelessWidget {
  const _CategoryChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        avatar: icon == null ? null : Icon(icon, size: 16),
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}
