import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'demo_mode_service.dart';

/// Central service for triggering automated transactional email notifications
/// via Supabase Edge Functions and PostgreSQL trigger queue.
class EmailNotificationService {
  static final EmailNotificationService _instance =
      EmailNotificationService._internal();
  factory EmailNotificationService() => _instance;
  EmailNotificationService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  /// Trigger New User Registration email notifications
  /// Dispatches Welcome Email to the user and Alert to BlueFarm Admin.
  Future<void> notifyUserRegistration({
    required String userId,
    required String fullName,
    required String role,
    String? email,
    String? phone,
    String? region,
  }) async {
    if (DemoModeService.isDemoMode) {
      debugPrint('[EmailNotificationService] Demo mode: Skipping registration email dispatch.');
      return;
    }

    try {
      debugPrint('[EmailNotificationService] Triggering registration notification for: $fullName');
      await _client.functions.invoke(
        'send-notification-email',
        body: {
          'action': 'process_queue',
          'event_type': 'user_registration',
          'data': {
            'user_id': userId,
            'full_name': fullName,
            'role': role,
            'email': email,
            'phone': phone,
            'region': region,
          },
        },
      );
    } catch (e) {
      debugPrint('[EmailNotificationService] Warning: Could not trigger registration email: $e');
    }
  }

  /// Trigger New Order email notifications
  /// Dispatches Order Confirmation to Buyer, New Order Alert to Farmer, and Admin Notice.
  Future<void> notifyNewOrder({
    required String orderId,
    required String buyerId,
    required String species,
    required double quantityKg,
    required double pricePerKg,
    required double totalPrice,
    required String paymentMethod,
    String? deliveryAddress,
    String? farmerId,
  }) async {
    if (DemoModeService.isDemoMode) {
      debugPrint('[EmailNotificationService] Demo mode: Skipping order email dispatch.');
      return;
    }

    try {
      debugPrint('[EmailNotificationService] Triggering new order notification for order: $orderId');
      await _client.functions.invoke(
        'send-notification-email',
        body: {
          'action': 'process_queue',
          'event_type': 'new_order',
          'data': {
            'order_id': orderId,
            'buyer_id': buyerId,
            'farmer_id': farmerId,
            'species': species,
            'quantity_kg': quantityKg,
            'price_per_kg': pricePerKg,
            'total_price': totalPrice,
            'payment_method': paymentMethod,
            'delivery_address': deliveryAddress,
          },
        },
      );
    } catch (e) {
      debugPrint('[EmailNotificationService] Warning: Could not trigger new order email: $e');
    }
  }

  /// Trigger Order Cancellation email notifications
  /// Dispatches cancellation notice to Buyer, Farmer, and Admin.
  Future<void> notifyOrderCancellation({
    required String orderId,
    String? reason,
  }) async {
    if (DemoModeService.isDemoMode) {
      debugPrint('[EmailNotificationService] Demo mode: Skipping cancellation email dispatch.');
      return;
    }

    try {
      debugPrint('[EmailNotificationService] Triggering order cancellation notification: $orderId');
      await _client.functions.invoke(
        'send-notification-email',
        body: {
          'action': 'process_queue',
          'event_type': 'order_cancellation',
          'data': {
            'order_id': orderId,
            'reason': reason,
          },
        },
      );
    } catch (e) {
      debugPrint('[EmailNotificationService] Warning: Could not trigger cancellation email: $e');
    }
  }

  /// Trigger New Harvest / Listing email notifications
  /// Dispatches listing confirmation to Farmer and Alert to BlueFarm Admin.
  Future<void> notifyNewHarvest({
    required String listingId,
    required String species,
    required double quantityKg,
    required double pricePerKg,
    String? pondNumber,
    int? fishCount,
  }) async {
    if (DemoModeService.isDemoMode) {
      debugPrint('[EmailNotificationService] Demo mode: Skipping harvest email dispatch.');
      return;
    }

    try {
      debugPrint('[EmailNotificationService] Triggering harvest listing notification: $listingId');
      await _client.functions.invoke(
        'send-notification-email',
        body: {
          'action': 'process_queue',
          'event_type': 'new_harvest',
          'data': {
            'listing_id': listingId,
            'species': species,
            'quantity_kg': quantityKg,
            'price_per_kg': pricePerKg,
            'pond_number': pondNumber,
            'fish_count': fishCount,
          },
        },
      );
    } catch (e) {
      debugPrint('[EmailNotificationService] Warning: Could not trigger harvest email: $e');
    }
  }
}
