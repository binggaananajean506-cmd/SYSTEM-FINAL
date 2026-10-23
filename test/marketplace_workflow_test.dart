import 'package:esugid/marketplace_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('marketplace listing lifecycle', () {
    test('new and legacy available values do not appear sold', () {
      expect(
        MarketplaceListingStatus.fromValue('Available'),
        MarketplaceListingStatus.available,
      );
      expect(
        MarketplaceListingStatus.fromValue('Limited stock'),
        MarketplaceListingStatus.available,
      );
      expect(
        MarketplaceListingStatus.fromValue(null),
        MarketplaceListingStatus.available,
      );
    });

    test('reserved and sold remain distinct lifecycle states', () {
      expect(
        MarketplaceListingStatus.fromValue('Reserved'),
        MarketplaceListingStatus.reserved,
      );
      expect(
        MarketplaceListingStatus.fromValue('Sold'),
        MarketplaceListingStatus.sold,
      );
    });

    test('item map normalizes legacy limited-stock status as available', () {
      final item = MarketplaceItem(
        id: 'item-1',
        name: 'Native chicken',
        price: '450',
        description: 'Healthy native chicken',
        imageUrl: 'https://example.com/chicken.jpg',
        sellerId: 'seller-1',
        category: 'Livestock',
        location: 'Vito',
        createdAt: DateTime(2026, 8, 28),
        status: 'Limited stock',
      );

      expect(item.isAvailable, isTrue);
      expect(item.isSold, isFalse);
      expect(item.toMap()['status'], 'Available');
    });

    test('listing ownership is based on the authenticated user id', () {
      final item = MarketplaceItem(
        id: 'item-1',
        name: 'Native chicken',
        price: '450',
        description: 'Healthy native chicken',
        imageUrl: 'https://example.com/chicken.jpg',
        sellerId: 'seller-1',
        category: 'Livestock',
        location: 'Vito',
        createdAt: DateTime(2026, 8, 28),
      );

      expect(item.isOwnedBy('seller-1'), isTrue);
      expect(item.isOwnedBy('buyer-1'), isFalse);
      expect(item.isOwnedBy(null), isFalse);
    });

    test(
      'owner listings are sorted newest first without a composite index',
      () {
        MarketplaceItem item(String id, DateTime createdAt) => MarketplaceItem(
          id: id,
          name: id,
          price: '100',
          description: 'Local item',
          imageUrl: '',
          sellerId: 'seller-1',
          category: 'Other',
          location: 'Barili',
          createdAt: createdAt,
        );

        final sorted = MarketplaceService.newestFirst([
          item('older', DateTime(2026, 8, 1)),
          item('newest', DateTime(2026, 9, 1)),
          item('middle', DateTime(2026, 8, 15)),
        ]);

        expect(sorted.map((item) => item.id), ['newest', 'middle', 'older']);
      },
    );
  });

  group('marketplace interest workflow', () {
    test('only accepted requests unlock normal messages', () {
      expect(MarketplaceInterestStatus.pending.canSendMessages, isFalse);
      expect(MarketplaceInterestStatus.declined.canSendMessages, isFalse);
      expect(MarketplaceInterestStatus.completed.canSendMessages, isFalse);
      expect(MarketplaceInterestStatus.accepted.canSendMessages, isTrue);
    });

    test('conversation id is stable regardless of user order', () {
      final first = MarketplaceService.marketConversationId(
        itemId: 'item-1',
        firstUserId: 'buyer-1',
        secondUserId: 'seller-1',
      );
      final second = MarketplaceService.marketConversationId(
        itemId: 'item-1',
        firstUserId: 'seller-1',
        secondUserId: 'buyer-1',
      );

      expect(first, second);
    });
  });
}
