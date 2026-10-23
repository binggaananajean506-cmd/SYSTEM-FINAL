import 'package:flutter/material.dart';

import '../features/explore/domain/barili_destination.dart';
import 'explore_barili_page.dart';

/// Compatibility route for existing navigation entry points.
///
/// Beach content now comes from the same verified directory used by Explore,
/// search, place details, and the barangay map.
class BeachesPage extends StatelessWidget {
  const BeachesPage({super.key});

  @override
  Widget build(BuildContext context) => const ExploreBariliPage(
    initialCategory: BariliDestinationCategory.beaches,
  );
}
