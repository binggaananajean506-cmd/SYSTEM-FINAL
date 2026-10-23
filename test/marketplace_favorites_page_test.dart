import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:esugid/auth_service.dart';
import 'package:esugid/marketplace_service.dart';
import 'package:esugid/pages/marketplace_favorites_page.dart';

void main() {
  final testUser = User(
    uid: 'user_123',
    email: 'buyer@example.com',
    role: UserRole.resident,
    name: 'Barili Resident',
  );

  final sampleItem = MarketplaceItem(
    id: 'item_banana_1',
    name: 'Organic Cavendish Bananas',
    price: '120.00',
    priceUnit: 'bunch',
    description: 'Freshly harvested bananas from Barangay Candikit.',
    imageUrl: '',
    sellerId: 'seller_456',
    sellerName: 'Maria Santos',
    category: 'Farm Produce',
    condition: 'Fresh Harvest',
    location: 'Candikit',
    quantity: 10,
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
    status: 'Available',
  );

  testWidgets(
    'MarketplaceFavoritesPage renders collapsible header and empty state without removed icon/subtitle',
    (tester) async {
      AuthService.currentUser = testUser;
      addTearDown(() => AuthService.currentUser = null);

      await tester.pumpWidget(
        MaterialApp(
          home: MarketplaceFavoritesPage(
            onOpenListing: (_) {},
            favoritesStream: Stream.value(const <String>{}),
            itemsStream: Stream.value(const <MarketplaceItem>[]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify header contents
      expect(find.text('LOCAL MARKET'), findsOneWidget);
      expect(find.text('Favorites'), findsOneWidget);

      // Verify removed elements are NOT present
      expect(find.text('Items you saved for later'), findsNothing);

      // Verify 3D empty state
      expect(find.text('No favorites saved yet'), findsOneWidget);
      expect(find.text('Explore Barili Finds'), findsOneWidget);
    },
  );

  testWidgets(
    'MarketplaceFavoritesPage renders Barili Finds style 3D card and unviewed indicator',
    (tester) async {
      AuthService.currentUser = testUser;
      addTearDown(() => AuthService.currentUser = null);

      MarketplaceItem? openedItem;

      // Ensure item is initially unviewed
      MarketplaceService.viewedFavoritesNotifier.value = <String>{};

      await tester.pumpWidget(
        MaterialApp(
          home: MarketplaceFavoritesPage(
            onOpenListing: (item) => openedItem = item,
            favoritesStream: Stream.value({sampleItem.id}),
            itemsStream: Stream.value([sampleItem]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Barili Finds 3D card content
      expect(find.text('Organic Cavendish Bananas'), findsOneWidget);
      expect(find.text('Maria Santos'), findsOneWidget);
      expect(find.text('FARM PRODUCE'), findsOneWidget);
      expect(find.text("I'M INTERESTED"), findsOneWidget);

      // Verify "NEW" unviewed badge sign
      expect(find.text('NEW'), findsOneWidget);

      // Tap on card to open listing
      await tester.tap(find.text('Organic Cavendish Bananas'));
      await tester.pumpAndSettle();

      expect(openedItem, equals(sampleItem));
      // Verify that item is now marked as viewed
      expect(
        MarketplaceService.viewedFavoritesNotifier.value.contains(sampleItem.id),
        isTrue,
      );
    },
  );
}
