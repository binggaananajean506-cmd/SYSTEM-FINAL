import 'package:flutter/material.dart';

import 'explore_barili_page.dart';

/// Compatibility route for the existing Tourist Spots entry point.
/// All content is provided by the normalized, source-backed Explore directory.
class TouristSpotsPage extends StatelessWidget {
  const TouristSpotsPage({super.key});

  @override
  Widget build(BuildContext context) => const ExploreBariliPage();
}
