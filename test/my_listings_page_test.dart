import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:esugid/auth_service.dart';
import 'package:esugid/marketplace_service.dart';
import 'package:esugid/pages/my_listings_page.dart';

void main() {
  final testUser = User(
    uid: 'seller_test_1',
    email: 'seller@test.com',
    role: UserRole.resident,
    name: 'Ana Jean',
  );

  final activeItem = MarketplaceItem(
    id: 'item_active_1',
    name: 'Librotech Modern Edition',
    price: '200.00',
    priceUnit: 'piece',
    description: 'Educational reference set.',
    imageUrl: '',
    sellerId: 'seller_test_1',
    sellerName: 'Ana Jean',
    category: 'Household',
    condition: 'Like New',
    location: 'Cagay',
    quantity: 1,
    createdAt: DateTime.now().subtract(const Duration(days: 8)),
    status: 'Available',
  );

  final soldItem = MarketplaceItem(
    id: 'item_sold_1',
    name: 'Vintage Wooden Lamp',
    price: '450.00',
    priceUnit: 'piece',
    description: 'Classic table lamp.',
    imageUrl: '',
    sellerId: 'seller_test_1',
    sellerName: 'Ana Jean',
    category: 'Household',
    condition: 'Good',
    location: 'Poblacion',
    quantity: 1,
    createdAt: DateTime.now().subtract(const Duration(days: 15)),
    status: 'Sold',
  );

  testWidgets(
    'MyListingsPage renders collapsible header, active card, and Sold History button',
    (tester) async {
      AuthService.currentUser = testUser;
      addTearDown(() => AuthService.currentUser = null);

      await tester.pumpWidget(
        MaterialApp(
          home: MyListingsPage(
            itemsStream: Stream.value([activeItem, soldItem]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify collapsible header
      expect(find.text('LOCAL MARKET'), findsOneWidget);
      expect(find.text('My Listings'), findsOneWidget);

      // Verify sub-bar stats
      expect(find.text('1 Active Listing'), findsOneWidget);
      expect(find.text('Sold History'), findsOneWidget);

      // Verify Barili Finds 3D card layout
      expect(find.text('Librotech Modern Edition'), findsOneWidget);
      expect(find.text('HOUSEHOLD'), findsOneWidget);
      expect(find.text('MANAGE'), findsOneWidget);
      expect(find.text('MARK AS SOLD'), findsOneWidget);

      // Tap on "Sold History" button
      await tester.tap(find.text('Sold History'));
      await tester.pumpAndSettle();

      // Verify Sold History bottom sheet opened and displays sold item
      expect(find.text('Marketplace items marked as sold'), findsOneWidget);
      expect(find.text('Vintage Wooden Lamp'), findsOneWidget);
      expect(find.text('MAKE AVAILABLE'), findsOneWidget);
    },
  );
}
