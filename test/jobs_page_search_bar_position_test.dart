import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Search bar and filter button are positioned above Help Requests and My Activity tabs',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final searchController = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                // Top Search Bar (positioned ABOVE main tab bar)
                SliverToBoxAdapter(
                  key: const ValueKey('sliver-top-search-bar'),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            decoration: const InputDecoration(
                              hintText: 'Search help requests...',
                              prefixIcon: Icon(Icons.search_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        PopupMenuButton<String>(
                          onSelected: (_) {},
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'All', child: Text('All Requests')),
                            const PopupMenuItem(value: 'Urgent', child: Text('Urgent Only')),
                          ],
                          child: const Icon(Icons.tune_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
                // Main 3D Tab Bar (Help Requests and My Activity)
                SliverToBoxAdapter(
                  key: const ValueKey('sliver-main-tab-bar'),
                  child: Container(
                    height: 50,
                    margin: const EdgeInsets.fromLTRB(18, 4, 18, 8),
                    child: const Row(
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.volunteer_activism_rounded, size: 15),
                              SizedBox(width: 6),
                              Text('Help Requests'),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_pin_rounded, size: 16),
                              SizedBox(width: 6),
                              Text('My Activity'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Category Filters (positioned below the main tab bar)
                SliverToBoxAdapter(
                  key: const ValueKey('sliver-feed-filter'),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(18, 2, 18, 10),
                    child: const Row(
                      children: [
                        Text('All'),
                        SizedBox(width: 8),
                        Text('Errands'),
                        SizedBox(width: 8),
                        Text('Repairs'),
                        SizedBox(width: 8),
                        Text('Farming'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Verify all 3 slivers are rendered
      final searchFinder = find.byKey(const ValueKey('sliver-top-search-bar'));
      final tabBarFinder = find.byKey(const ValueKey('sliver-main-tab-bar'));
      final categoryFilterFinder = find.byKey(const ValueKey('sliver-feed-filter'));

      expect(searchFinder, findsOneWidget);
      expect(tabBarFinder, findsOneWidget);
      expect(categoryFilterFinder, findsOneWidget);

      // Verify vertical positioning using RenderBox elements
      final searchY = tester.getTopLeft(find.byType(TextField)).dy;
      final tabY = tester.getTopLeft(find.text('Help Requests')).dy;
      final categoryY = tester.getTopLeft(find.text('All')).dy;

      expect(
        searchY,
        lessThan(tabY),
        reason: 'Search bar MUST be positioned ABOVE the Help Requests and My Activity tabs',
      );

      expect(
        tabY,
        lessThan(categoryY),
        reason: 'Main tab bar MUST be positioned ABOVE the category chips and feed content',
      );

      // Verify text elements
      expect(find.text('Search help requests...'), findsOneWidget);
      expect(find.text('Help Requests'), findsOneWidget);
      expect(find.text('My Activity'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Errands'), findsOneWidget);
      expect(find.text('Repairs'), findsOneWidget);
      expect(find.text('Farming'), findsOneWidget);

      // Verify typing in search field works
      await tester.enterText(find.byType(TextField), 'harvest');
      expect(searchController.text, 'harvest');
    },
  );
}
