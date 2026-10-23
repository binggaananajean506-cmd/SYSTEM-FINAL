import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'firestore_converters.dart';
import 'core/validation/esugid_validators.dart';

enum MarketplaceListingStatus {
  available,
  reserved,
  sold,
  unavailable;

  String get value => switch (this) {
    available => 'Available',
    reserved => 'Reserved',
    sold => 'Sold',
    unavailable => 'Unavailable',
  };

  static MarketplaceListingStatus fromValue(Object? value) {
    return switch (value?.toString().trim().toLowerCase()) {
      'reserved' => reserved,
      'sold' => sold,
      'unavailable' => unavailable,
      // "Limited stock" was previously stored as a lifecycle status. It is
      // still an available listing; quantity is the source of truth for stock.
      _ => available,
    };
  }
}

enum MarketplaceInterestStatus {
  pending,
  accepted,
  declined,
  completed;

  String get value => name;

  String get label => switch (this) {
    pending => 'Waiting for seller',
    accepted => 'Conversation accepted',
    declined => 'Request declined',
    completed => 'Transaction completed',
  };

  bool get canSendMessages => this == accepted;

  static MarketplaceInterestStatus fromValue(Object? value) {
    return switch (value?.toString().trim().toLowerCase()) {
      'accepted' => accepted,
      'declined' => declined,
      'completed' => completed,
      _ => pending,
    };
  }
}

class MarketplaceInterestRequest {
  const MarketplaceInterestRequest({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.itemImageUrl,
    required this.buyerId,
    required this.buyerName,
    this.buyerPhotoUrl,
    required this.sellerId,
    required this.sellerName,
    this.sellerPhotoUrl,
    required this.initialMessage,
    this.lastMessage,
    this.lastMessageAt,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.buyerConfirmed = false,
    this.sellerConfirmed = false,
    this.buyerUnreadCount = 0,
    this.sellerUnreadCount = 0,
  });

  final String id;
  final String itemId;
  final String itemName;
  final String itemImageUrl;
  final String buyerId;
  final String buyerName;
  final String? buyerPhotoUrl;
  final String sellerId;
  final String sellerName;
  final String? sellerPhotoUrl;
  final String initialMessage;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final MarketplaceInterestStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool buyerConfirmed;
  final bool sellerConfirmed;
  final int buyerUnreadCount;
  final int sellerUnreadCount;

  bool isBuyer(String userId) => buyerId == userId;
  bool isSeller(String userId) => sellerId == userId;
  int unreadCountFor(String userId) =>
      isSeller(userId) ? sellerUnreadCount : buyerUnreadCount;

  factory MarketplaceInterestRequest.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    return MarketplaceInterestRequest(
      id: document.id,
      itemId: data['itemId']?.toString() ?? '',
      itemName: data['itemName']?.toString() ?? 'Marketplace item',
      itemImageUrl: data['itemImageUrl']?.toString() ?? '',
      buyerId: data['buyerId']?.toString() ?? '',
      buyerName: data['buyerName']?.toString() ?? 'Interested buyer',
      buyerPhotoUrl: data['buyerPhotoUrl']?.toString() ??
          data['buyerPhoto']?.toString() ??
          data['buyerAvatarUrl']?.toString(),
      sellerId: data['sellerId']?.toString() ?? '',
      sellerName: data['sellerName']?.toString() ?? 'Local seller',
      sellerPhotoUrl: data['sellerPhotoUrl']?.toString() ??
          data['sellerPhoto']?.toString() ??
          data['sellerAvatarUrl']?.toString(),
      initialMessage: data['initialMessage']?.toString() ?? '',
      lastMessage: data['lastMessage']?.toString(),
      lastMessageAt: data['lastMessageAt'] == null
          ? null
          : dateTimeFromFirestore(data['lastMessageAt']),
      status: MarketplaceInterestStatus.fromValue(data['status']),
      createdAt: dateTimeFromFirestore(data['createdAt']),
      updatedAt: data['updatedAt'] == null
          ? null
          : dateTimeFromFirestore(data['updatedAt']),
      buyerConfirmed: data['buyerConfirmedAt'] != null,
      sellerConfirmed: data['sellerConfirmedAt'] != null,
      buyerUnreadCount: (data['buyerUnreadCount'] as num?)?.toInt() ?? 0,
      sellerUnreadCount: (data['sellerUnreadCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class MarketplaceItem {
  final String id;
  final String name;
  final String price;
  final String priceUnit;
  final String description;
  final String imageUrl;
  final List<String> additionalImages;
  final String imageStoragePath;
  final String sellerId;
  final String sellerName;
  final String category;
  final String condition;
  final String location;
  final String meetupArea;
  final String contact;
  final int quantity;
  final DateTime createdAt;
  final String status;

  MarketplaceItem({
    required this.id,
    required this.name,
    required this.price,
    this.priceUnit = 'piece',
    required this.description,
    required this.imageUrl,
    this.additionalImages = const [],
    this.imageStoragePath = '',
    required this.sellerId,
    this.sellerName = '',
    required this.category,
    this.condition = 'New',
    required this.location,
    this.meetupArea = '',
    this.contact = '',
    this.quantity = 1,
    required this.createdAt,
    this.status = 'Available',
  });

  MarketplaceListingStatus get listingStatus =>
      MarketplaceListingStatus.fromValue(status);

  bool get isAvailable => listingStatus == MarketplaceListingStatus.available;
  bool get isReserved => listingStatus == MarketplaceListingStatus.reserved;
  bool get isSold => listingStatus == MarketplaceListingStatus.sold;
  bool isOwnedBy(String? userId) =>
      userId != null && userId.isNotEmpty && sellerId == userId;
  String get formattedPrice => ESugidValidators.formatPeso(price);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'priceUnit': priceUnit,
      'description': description,
      'imageUrl': imageUrl,
      'additionalImages': additionalImages,
      'imageStoragePath': imageStoragePath,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'category': category,
      'condition': condition,
      'location': location,
      'meetupArea': meetupArea,
      'contact': contact,
      'quantity': quantity,
      'createdAt': createdAt.toIso8601String(),
      'status': listingStatus.value,
    };
  }

  factory MarketplaceItem.fromMap(Map<String, dynamic> map) {
    return MarketplaceItem(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      price: map['price'] ?? '',
      priceUnit: map['priceUnit'] ?? 'piece',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      additionalImages: List<String>.from(map['additionalImages'] ?? []),
      imageStoragePath: map['imageStoragePath'] ?? '',
      sellerId: map['sellerId'] ?? '',
      sellerName: map['sellerName'] ?? '',
      category: map['category'] ?? 'Others',
      condition: map['condition'] ?? 'New',
      location: map['location'] ?? '',
      meetupArea: map['meetupArea'] ?? '',
      contact: map['contact'] ?? '',
      quantity: map['quantity'] ?? 1,
      createdAt: dateTimeFromFirestore(map['createdAt']),
      status: MarketplaceListingStatus.fromValue(map['status']).value,
    );
  }
}

class MarketplaceService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Stream<List<MarketplaceItem>> get itemsStream => _firestore
      .collection('marketplace')
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => MarketplaceItem.fromMap(doc.data()))
            .toList(),
      );

  static Stream<List<MarketplaceItem>> userItemsStream(String userId) =>
      _firestore
          .collection('marketplace')
          .where('sellerId', isEqualTo: userId)
          .snapshots()
          .map(
            (snapshot) => newestFirst(
              snapshot.docs.map((doc) => MarketplaceItem.fromMap(doc.data())),
            ),
          );

  /// Keeps owner-only listing queries independent from a composite Firestore
  /// index while preserving the newest-first presentation used by the market.
  static List<MarketplaceItem> newestFirst(Iterable<MarketplaceItem> items) {
    final sorted = items.toList(growable: false);
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  static Stream<Set<String>> favoriteItemIdsStream(String userId) => _firestore
      .collection('users')
      .doc(userId)
      .collection('marketplace_favorites')
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc.id).toSet());

  static Future<void> setFavorite({
    required String userId,
    required String itemId,
    required bool isFavorite,
  }) async {
    final favorite = _firestore
        .collection('users')
        .doc(userId)
        .collection('marketplace_favorites')
        .doc(itemId);
    if (isFavorite) {
      await favorite.set({
        'itemId': itemId,
        'savedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await favorite.delete();
    }
  }

  static Future<void> addItem(MarketplaceItem item) async {
    if (AuthService.currentUser?.isRestricted == true) {
      throw StateError('Account Restricted: Your account currently has limited access. Please contact your barangay office for assistance.');
    }
    final data = item.toMap();
    data['status'] = MarketplaceListingStatus.available.value;
    await _firestore.collection('marketplace').doc(item.id).set(data);
  }

  static Future<void> updateItemStatus(String itemId, String status) async {
    final normalized = MarketplaceListingStatus.fromValue(status);
    await _firestore.collection('marketplace').doc(itemId).update({
      'status': normalized.value,
      'statusUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteItem(String itemId) async {
    await _firestore.collection('marketplace').doc(itemId).delete();
  }

  static Future<void> updateItem(MarketplaceItem item) async {
    await _firestore
        .collection('marketplace')
        .doc(item.id)
        .update(item.toMap());
  }

  static String marketConversationId({
    required String itemId,
    required String firstUserId,
    required String secondUserId,
  }) {
    final users = [firstUserId, secondUserId]..sort();
    return 'market_${itemId}_${users.join('_')}';
  }

  static Stream<MarketplaceInterestRequest?> interestRequestStream({
    required MarketplaceItem item,
    required String buyerId,
  }) {
    final id = marketConversationId(
      itemId: item.id,
      firstUserId: buyerId,
      secondUserId: item.sellerId,
    );
    return conversationStream(id);
  }

  static Stream<MarketplaceInterestRequest?> conversationStream(String id) =>
      _firestore
          .collection('marketplace_conversations')
          .doc(id)
          .snapshots()
          .map(
            (document) => document.exists
                ? MarketplaceInterestRequest.fromDocument(document)
                : null,
          );

  static Stream<List<MarketplaceInterestRequest>> sellerInterestRequests(
    String sellerId,
  ) => _firestore
      .collection('marketplace_conversations')
      .where('sellerId', isEqualTo: sellerId)
      .snapshots()
      .map((snapshot) {
        final requests = snapshot.docs
            .map(MarketplaceInterestRequest.fromDocument)
            .toList(growable: false);
        return [...requests]..sort((a, b) {
          final aDate = a.updatedAt ?? a.createdAt;
          final bDate = b.updatedAt ?? b.createdAt;
          return bDate.compareTo(aDate);
        });
      });

  static Future<String> sendInterestRequest({
    required MarketplaceItem item,
    required String buyerId,
    required String buyerName,
    String? buyerPhotoUrl,
    required String message,
  }) async {
    if (item.isOwnedBy(buyerId)) {
      throw StateError(
        'You cannot send an interest request for your own item.',
      );
    }
    final initialMessage = message.trim();
    if (initialMessage.isEmpty) {
      throw ArgumentError.value(message, 'message', 'Message is required.');
    }
    if (initialMessage.length > ESugidInputLimits.chatMessage) {
      throw ArgumentError.value(
        message,
        'message',
        'Keep your message within 500 characters.',
      );
    }

    final id = marketConversationId(
      itemId: item.id,
      firstUserId: buyerId,
      secondUserId: item.sellerId,
    );
    final reference = _firestore
        .collection('marketplace_conversations')
        .doc(id);

    await _firestore.runTransaction<bool>((transaction) async {
      final itemReference = _firestore.collection('marketplace').doc(item.id);
      final itemSnapshot = await transaction.get(itemReference);
      final listingStatus = MarketplaceListingStatus.fromValue(
        itemSnapshot.data()?['status'],
      );
      if (!itemSnapshot.exists ||
          listingStatus != MarketplaceListingStatus.available) {
        throw StateError('This item is no longer available.');
      }

      final conversationSnapshot = await transaction.get(reference);
      if (conversationSnapshot.exists) return false;

      final messageReference =
          reference.collection('messages').doc('interest_request');

      transaction.set(reference, {
        'itemId': item.id,
        'itemName': item.name,
        'itemImageUrl': item.imageUrl,
        'buyerId': buyerId,
        'buyerName': buyerName,
        'buyerPhotoUrl': buyerPhotoUrl ?? '',
        'sellerId': item.sellerId,
        'sellerName': item.sellerName,
        'participantIds': [buyerId, item.sellerId],
        'initialMessage': initialMessage,
        'lastMessage': initialMessage,
        'status': MarketplaceInterestStatus.pending.value,
        'buyerMessageCount': 1,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(messageReference, {
        'senderId': buyerId,
        'text': initialMessage,
        'createdAt': FieldValue.serverTimestamp(),
        'kind': 'interest',
      });

      return true;
    });

    return id;
  }

  static Future<void> acceptInterestRequest({
    required String conversationId,
    required String sellerId,
  }) => _updatePendingRequest(
    conversationId: conversationId,
    sellerId: sellerId,
    status: MarketplaceInterestStatus.accepted,
  );

  static Future<void> declineInterestRequest({
    required String conversationId,
    required String sellerId,
  }) => _updatePendingRequest(
    conversationId: conversationId,
    sellerId: sellerId,
    status: MarketplaceInterestStatus.declined,
  );

  static Future<void> confirmTrade(String conversationId) async {
    try {
      await FirebaseFunctions.instanceFor(region: 'asia-southeast1')
          .httpsCallable('confirmMarketplaceTrade')
          .call<Object?>({'conversationId': conversationId});
    } on FirebaseFunctionsException catch (error) {
      throw StateError(error.message ?? 'Could not confirm the handoff.');
    }
  }

  static Future<void> _updatePendingRequest({
    required String conversationId,
    required String sellerId,
    required MarketplaceInterestStatus status,
  }) async {
    final reference = _firestore
        .collection('marketplace_conversations')
        .doc(conversationId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final data = snapshot.data();
      if (!snapshot.exists || data == null || data['sellerId'] != sellerId) {
        throw StateError('Only the seller can review this request.');
      }
      if (MarketplaceInterestStatus.fromValue(data['status']) !=
          MarketplaceInterestStatus.pending) {
        return;
      }
      transaction.update(reference, {
        'status': status.value,
        status == MarketplaceInterestStatus.accepted
                ? 'acceptedAt'
                : 'declinedAt':
            FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static Stream<List<Map<String, dynamic>>> messagesStream(
    String conversationId,
  ) => _firestore
      .collection('marketplace_conversations')
      .doc(conversationId)
      .collection('messages')
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList(),
      );

  static Future<void> sendMessage(
    String conversationId, {
    required String senderId,
    required String text,
  }) async {
    final value = text.trim();
    if (value.isEmpty) return;
    if (value.length > ESugidInputLimits.chatMessage) {
      throw StateError('Keep your message within 500 characters.');
    }
    await _postMessageInternal(
      conversationId: conversationId,
      senderId: senderId,
      kind: 'message',
      text: value,
    );
  }

  static Future<void> sendImageMessage(
    String conversationId, {
    required String senderId,
    required String imageUrl,
    String? caption,
  }) async {
    final cleanUrl = imageUrl.trim();
    if (cleanUrl.isEmpty) {
      throw ArgumentError.value(imageUrl, 'imageUrl', 'Image URL cannot be empty.');
    }
    final text = caption?.trim() ?? '';
    if (text.length > ESugidInputLimits.chatMessage) {
      throw StateError('Keep your caption within 500 characters.');
    }
    await _postMessageInternal(
      conversationId: conversationId,
      senderId: senderId,
      kind: 'image',
      text: text,
      imageUrl: cleanUrl,
    );
  }

  static Future<void> _postMessageInternal({
    required String conversationId,
    required String senderId,
    required String kind,
    required String text,
    String? imageUrl,
  }) async {
    final reference = _firestore
        .collection('marketplace_conversations')
        .doc(conversationId);

    final initialSnapshot = await reference.get();
    final initialData = initialSnapshot.data();
    if (!initialSnapshot.exists || initialData == null) {
      throw StateError('This conversation no longer exists.');
    }

    int? fallbackBuyerCount;
    if (initialData['buyerMessageCount'] == null &&
        MarketplaceInterestStatus.fromValue(initialData['status']) ==
            MarketplaceInterestStatus.pending &&
        senderId == initialData['buyerId']) {
      final buyerMessagesSnapshot = await reference
          .collection('messages')
          .where('senderId', isEqualTo: senderId)
          .get();
      fallbackBuyerCount = buyerMessagesSnapshot.size;
    }

    await _firestore.runTransaction((transaction) async {
      final conversation = await transaction.get(reference);
      final data = conversation.data();
      if (!conversation.exists || data == null) {
        throw StateError('This conversation no longer exists.');
      }
      final status = MarketplaceInterestStatus.fromValue(data['status']);
      if (status == MarketplaceInterestStatus.completed) {
        throw StateError(
          'This trade has been completed. Conversation is closed.',
        );
      }
      if (status == MarketplaceInterestStatus.declined) {
        throw StateError('This request was declined. Conversation is closed.');
      }
      if (!status.canSendMessages &&
          status != MarketplaceInterestStatus.pending) {
        throw StateError('Messaging is not available for this conversation.');
      }
      final participants =
          List<String>.from(data['participantIds'] ?? const []);
      if (!participants.contains(senderId)) {
        throw StateError('You are not part of this conversation.');
      }

      int? newBuyerCount;
      if (status == MarketplaceInterestStatus.pending) {
        if (senderId != data['buyerId']) {
          throw StateError(
            'Only the buyer can send messages while waiting for approval.',
          );
        }
        final existingCount = (data['buyerMessageCount'] as num?)?.toInt();
        final currentCount = existingCount ?? fallbackBuyerCount ?? 0;
        if (currentCount >= 3) {
          throw StateError(
            'You have reached the 3-message limit while waiting for seller approval.',
          );
        }
        newBuyerCount = currentCount + 1;
      }

      final isBuyerSending = senderId == data['buyerId'];
      final messageRef = reference.collection('messages').doc();

      final messageData = <String, dynamic>{
        'senderId': senderId,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
        'kind': kind,
        if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
      };

      final lastMessageSummary = kind == 'image'
          ? (text.isNotEmpty ? '📷 $text' : '📷 Sent a photo')
          : text;

      transaction.set(messageRef, messageData);
      final updates = <String, dynamic>{
        'lastMessage': lastMessageSummary,
        'updatedAt': FieldValue.serverTimestamp(),
        if (isBuyerSending)
          'sellerUnreadCount': FieldValue.increment(1)
        else
          'buyerUnreadCount': FieldValue.increment(1),
      };
      if (newBuyerCount != null) {
        updates['buyerMessageCount'] = newBuyerCount;
      }
      transaction.update(reference, updates);
    });
  }

  static Future<void> markRead(String conversationId, String userId) async {
    try {
      final ref = _firestore
          .collection('marketplace_conversations')
          .doc(conversationId);
      final snap = await ref.get();
      if (!snap.exists) return;
      final data = snap.data();
      if (data == null) return;
      final isSeller = data['sellerId'] == userId;
      await ref.update({
        if (isSeller) 'sellerUnreadCount': 0 else 'buyerUnreadCount': 0,
      });
    } catch (_) {}
  }

  static Future<void> editMessage(
    String conversationId,
    String messageId,
    String newText,
  ) async {
    final normalized = newText.trim();
    if (normalized.isEmpty || normalized.length > ESugidInputLimits.chatMessage) {
      throw StateError('Keep your message within 500 characters.');
    }
    await _firestore
        .collection('marketplace_conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({
          'text': normalized,
          'isEdited': true,
          'editedAt': FieldValue.serverTimestamp(),
        });
  }

  static Future<void> unsendMessage(
    String conversationId,
    String messageId,
  ) async {
    await _firestore
        .collection('marketplace_conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({
          'isUnsent': true,
          'unsentAt': FieldValue.serverTimestamp(),
          'text': '',
        });
  }

  static Future<void> toggleReaction(
    String conversationId,
    String messageId,
    String userId,
    String emoji,
  ) async {
    final messageRef = _firestore
        .collection('marketplace_conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(messageRef);
      if (!snap.exists) return;
      final data = snap.data() ?? {};
      final reactions = Map<String, dynamic>.from(data['reactions'] as Map? ?? {});
      if (reactions[userId] == emoji) {
        reactions.remove(userId);
      } else {
        reactions[userId] = emoji;
      }
      tx.update(messageRef, {'reactions': reactions});
    });
  }

  static Future<void> clearConversationMessages(
    String conversationId,
    String userId,
  ) async {
    final snap = await _firestore
        .collection('marketplace_conversations')
        .doc(conversationId)
        .collection('messages')
        .get();
    for (final doc in snap.docs) {
      if (doc.data()['senderId'] == userId) {
        await doc.reference.update({
          'isUnsent': true,
          'unsentAt': FieldValue.serverTimestamp(),
          'text': '',
        });
      }
    }
  }

  static final ValueNotifier<Set<String>> viewedFavoritesNotifier =
      ValueNotifier<Set<String>>(<String>{});

  static Future<void> loadViewedFavorites(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('viewed_favorites_$userId') ?? [];
      viewedFavoritesNotifier.value = list.toSet();
    } catch (_) {}
  }

  static Future<void> markFavoriteViewed({
    required String userId,
    required String itemId,
  }) async {
    final current = Set<String>.from(viewedFavoritesNotifier.value)
      ..add(itemId);
    viewedFavoritesNotifier.value = current;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('viewed_favorites_$userId', current.toList());
    } catch (_) {}
  }

  static Future<void> markAllFavoritesViewed({
    required String userId,
    required Iterable<String> itemIds,
  }) async {
    final current = Set<String>.from(viewedFavoritesNotifier.value)
      ..addAll(itemIds);
    viewedFavoritesNotifier.value = current;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('viewed_favorites_$userId', current.toList());
    } catch (_) {}
  }
}
