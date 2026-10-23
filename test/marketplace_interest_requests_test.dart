import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:esugid/auth_service.dart';
import 'package:esugid/marketplace_service.dart';
import 'package:esugid/pages/marketplace_interest_requests_page.dart';

void main() {
  final testUser = User(
    uid: 'seller_123',
    email: 'seller@example.com',
    role: UserRole.resident,
    name: 'Barili Seller',
  );

  final sampleRequest = MarketplaceInterestRequest(
    id: 'req_1',
    itemId: 'item_101',
    itemName: 'Fresh Organic Mangoes',
    itemImageUrl: '',
    buyerId: 'buyer_456',
    buyerName: 'Juan Dela Cruz',
    sellerId: 'seller_123',
    sellerName: 'Barili Seller',
    initialMessage: 'Hi! Is this still available? Can we meet at the plaza?',
    status: MarketplaceInterestStatus.pending,
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  );

  testWidgets(
    'MarketplaceInterestRequestsPage renders collapsible header, tabs, and empty state without removed icon/subtitle',
    (tester) async {
      AuthService.currentUser = testUser;
      addTearDown(() => AuthService.currentUser = null);

      await tester.pumpWidget(
        MaterialApp(
          home: MarketplaceInterestRequestsPage(
            requestsStream: Stream.value(const []),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify header contents
      expect(find.text('LOCAL MARKET'), findsOneWidget);
      expect(find.text('Buyer Requests'), findsOneWidget);

      // Verify removed elements are NOT present
      expect(find.text('Review messages from interested buyers'), findsNothing);
      expect(find.text('BUYER REQUESTS'), findsNothing);

      // Verify 3D segmented tabs
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Archive'), findsOneWidget);

      // Verify initial empty state for pending tab
      expect(find.text('No pending buyer requests'), findsOneWidget);
    },
  );

  testWidgets(
    'MarketplaceInterestRequestsPage renders 3D pending buyer request card with action buttons',
    (tester) async {
      AuthService.currentUser = testUser;
      addTearDown(() => AuthService.currentUser = null);

      await tester.pumpWidget(
        MaterialApp(
          home: MarketplaceInterestRequestsPage(
            requestsStream: Stream.value([sampleRequest]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify item name & buyer details
      expect(find.text('Fresh Organic Mangoes'), findsOneWidget);
      expect(find.text('Juan Dela Cruz'), findsOneWidget);
      expect(find.text('Waiting for your review'), findsOneWidget);
      expect(
        find.text('Hi! Is this still available? Can we meet at the plaza?'),
        findsOneWidget,
      );

      // Verify pending action buttons
      expect(find.text('Decline'), findsOneWidget);
      expect(find.text('Accept & Chat'), findsOneWidget);

      // Verify avatar shows buyer initials 'JD'
      expect(find.text('JD'), findsOneWidget);
    },
  );

  testWidgets(
    'MarketplaceInterestRequestsPage renders Active tab with buyer name on top, Active Chat badge, and Open conversation',
    (tester) async {
      AuthService.currentUser = testUser;
      addTearDown(() => AuthService.currentUser = null);

      final activeRequest = MarketplaceInterestRequest(
        id: 'req_2',
        itemId: 'item_102',
        itemName: 'Ginamos',
        itemImageUrl: '',
        buyerId: 'buyer_789',
        buyerName: 'Julie Mae Tenebroso Dumapias',
        sellerId: 'seller_123',
        sellerName: 'Barili Seller',
        initialMessage: 'Hi! Interested ko sa Ginamos. Available pa ni?',
        status: MarketplaceInterestStatus.accepted,
        createdAt: DateTime.now().subtract(const Duration(days: 4)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MarketplaceInterestRequestsPage(
            requestsStream: Stream.value([activeRequest]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Active tab
      await tester.tap(find.text('Active'));
      await tester.pumpAndSettle();

      // Verify Buyer Name is prominently rendered
      expect(find.text('Julie Mae Tenebroso Dumapias'), findsOneWidget);

      // Verify Item name is rendered as subtitle
      expect(find.text('Ginamos'), findsOneWidget);

      // Verify Active Chat badge
      expect(find.text('Active Chat'), findsOneWidget);

      // Verify message snippet
      expect(
        find.text('Hi! Interested ko sa Ginamos. Available pa ni?'),
        findsOneWidget,
      );

      // Verify Open conversation action
      expect(find.text('Open conversation'), findsOneWidget);
    },
  );
}
