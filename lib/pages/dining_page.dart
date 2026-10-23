import 'package:flutter/material.dart';

import '../features/explore/domain/barili_destination.dart';
import 'explore_barili_page.dart';

/// Compatibility route for the existing Food & Dining entry point.
class DiningPage extends StatelessWidget {
  const DiningPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const ExploreBariliPage(initialCategory: BariliDestinationCategory.food);
}
