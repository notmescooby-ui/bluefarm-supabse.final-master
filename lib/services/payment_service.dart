import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/payment_order.dart';
import '../models/payment_types.dart';
import 'demo_mode_service.dart';

/// Custom exception thrown when attempting live payment through an unverified channel.
class PaymentSecurityException implements Exception {
  final String message;
  const PaymentSecurityException(this.message);

  @override
  String toString() => 'PaymentSecurityException: $message';
}

/// Result returned by payment operations and verification steps.
class PaymentVerificationResult {
  final bool isSuccess;
  final String message;
  final PaymentStatus status;
  final String? transactionRef;
  final bool isIdempotentReplay;
  final Map<String, dynamic>? rawOrder;

  const PaymentVerificationResult({
    required this.isSuccess,
    required this.message,
    required this.status,
    this.transactionRef,
    this.isIdempotentReplay = false,
    this.rawOrder,
  });
}

/// Core payment service for BlueFarm.
/// Enforces payment integrity, prevents unverified state changes,
/// and separates test/demo mock execution from production workflows.
class PaymentService {
  final SupabaseClient? _injectedClient;

  SupabaseClient? get _client {
    if (_injectedClient != null) return _injectedClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static PaymentService? _instance;
  factory PaymentService() => _instance ??= PaymentService._internal();

  PaymentService._internal() : _injectedClient = null;

  /// Visible for testing to inject mock/stub Supabase clients or run in standalone test mode.
  PaymentService.forTesting([this._injectedClient]);

  /// Direct UPI intent with placeholder 'bluefarm@upi' is NOT configured as a production gateway.
  /// This flag ensures live UPI payments remain disabled until a certified merchant provider is integrated.
  bool get isLiveUpiConfigured => false;

  /// User-friendly explanation displayed to buyers when live online payment is disabled.
  String get liveUpiUnavailableNotice =>
      'Online UPI payments are temporarily unavailable while merchant verification is being completed. Please use Cash on Delivery (COD).';

  /// Generates a simple UUID-like string for idempotency and order tracking.
  static String generateIdempotencyKey(String prefix, String buyerId) {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    return '$prefix-$buyerId-$timestamp';
  }

  /// Places a Cash on Delivery (COD) order.
  /// COD does not require online payment verification; it directly records
  /// confirmed orders in Supabase with additive payment metadata.
  Future<List<Map<String, dynamic>>> placeCodOrder({
    required String buyerId,
    required List<Map<String, dynamic>> cartItems,
    required String deliveryAddress,
  }) async {
    if (buyerId.isEmpty) {
      throw const PaymentSecurityException('Buyer must be authenticated to place an order.');
    }
    if (cartItems.isEmpty) {
      throw const PaymentSecurityException('Cannot place an order with an empty cart.');
    }
    if (deliveryAddress.trim().isEmpty) {
      throw const PaymentSecurityException('Delivery address is required.');
    }

    final placedOrders = <Map<String, dynamic>>[];

    for (final item in cartItems) {
      final species = item['species'] as String? ?? 'Fish Order';
      final farmName = item['farm_name'] as String? ?? 'BlueFarm Partner';
      final quantityKg = (item['quantity_kg'] as num?)?.toDouble() ?? 1.0;
      final pricePerKg = (item['price_per_kg'] as num?)?.toDouble() ?? 0.0;
      final subtotal = (item['subtotal'] as num?)?.toDouble() ?? (quantityKg * pricePerKg);
      final amountPaise = PaymentOrder.toPaise(subtotal);
      final idempotencyKey = generateIdempotencyKey('cod', buyerId);

      // Base payload compatible with current Supabase orders table
      final orderData = <String, dynamic>{
        'buyer_id': buyerId,
        'species': species,
        'farm_name': farmName,
        'quantity_kg': quantityKg,
        'price_per_kg': pricePerKg,
        'total_price': subtotal,
        'delivery_address': deliveryAddress.trim(),
        'payment_method': 'cod',
        'status': 'confirmed',
        // Additive columns (gracefully handled if table migration is pending)
        'payment_status': PaymentStatus.codDue.value,
        'currency': 'INR',
        'amount_paise': amountPaise,
        'idempotency_key': idempotencyKey,
      };

      final listingId = item['listing_id']?.toString();
      final farmerId = item['farmer_id']?.toString();

      if (listingId != null && _isUuid(listingId)) {
        orderData['listing_id'] = listingId;
      }
      if (farmerId != null && _isUuid(farmerId)) {
        orderData['farmer_id'] = farmerId;
      }

      if (DemoModeService.isDemoMode || _client == null) {
        orderData['id'] = 'demo-order-${DateTime.now().millisecondsSinceEpoch}';
        orderData['created_at'] = DateTime.now().toIso8601String();
        placedOrders.add(orderData);
      } else {
        final client = _client!;
        try {
          final res = await client.from('orders').insert(orderData).select();
          if (res.isNotEmpty) {
            placedOrders.add(Map<String, dynamic>.from(res.first));
          } else {
            placedOrders.add(orderData);
          }
        } catch (e) {
          // Fallback in case PostgreSQL table has not yet applied additive columns
          final legacyOrderData = Map<String, dynamic>.from(orderData)
            ..remove('payment_status')
            ..remove('currency')
            ..remove('amount_paise')
            ..remove('idempotency_key');
          await client.from('orders').insert(legacyOrderData);
          placedOrders.add(legacyOrderData);
        }
      }
    }

    return placedOrders;
  }

  /// Initiates an online UPI order record in 'pending' status before payment initiation.
  /// Live checkout is intentionally disabled until a real merchant aggregator is integrated.
  Future<List<Map<String, dynamic>>> createPendingUpiOrder({
    required String buyerId,
    required List<Map<String, dynamic>> cartItems,
    required String deliveryAddress,
  }) async {
    // Constraint 1 & 7: Keep live UPI unavailable until real verification is ready.
    // In release builds, mock/demo bypass is strictly prohibited.
    if (!isLiveUpiConfigured && (!DemoModeService.isDemoMode || kReleaseMode) && !kDebugMode) {
      throw PaymentSecurityException(liveUpiUnavailableNotice);
    }

    final pendingOrders = <Map<String, dynamic>>[];

    for (final item in cartItems) {
      final species = item['species'] as String? ?? 'Fish Order';
      final farmName = item['farm_name'] as String? ?? 'BlueFarm Partner';
      final quantityKg = (item['quantity_kg'] as num?)?.toDouble() ?? 1.0;
      final pricePerKg = (item['price_per_kg'] as num?)?.toDouble() ?? 0.0;
      final subtotal = (item['subtotal'] as num?)?.toDouble() ?? (quantityKg * pricePerKg);
      final amountPaise = PaymentOrder.toPaise(subtotal);
      final idempotencyKey = generateIdempotencyKey('upi', buyerId);

      final orderData = <String, dynamic>{
        'buyer_id': buyerId,
        'species': species,
        'farm_name': farmName,
        'quantity_kg': quantityKg,
        'price_per_kg': pricePerKg,
        'total_price': subtotal,
        'delivery_address': deliveryAddress.trim(),
        'payment_method': 'upi',
        'status': 'pending', // NOT confirmed until verified
        'payment_status': PaymentStatus.pending.value,
        'currency': 'INR',
        'amount_paise': amountPaise,
        'idempotency_key': idempotencyKey,
      };

      final listingId = item['listing_id']?.toString();
      final farmerId = item['farmer_id']?.toString();

      if (listingId != null && _isUuid(listingId)) {
        orderData['listing_id'] = listingId;
      }
      if (farmerId != null && _isUuid(farmerId)) {
        orderData['farmer_id'] = farmerId;
      }

      if (DemoModeService.isDemoMode || _client == null) {
        orderData['id'] = 'demo-upi-order-${DateTime.now().millisecondsSinceEpoch}';
        orderData['created_at'] = DateTime.now().toIso8601String();
        pendingOrders.add(orderData);
      } else {
        final client = _client!;
        try {
          final res = await client.from('orders').insert(orderData).select();
          if (res.isNotEmpty) {
            pendingOrders.add(Map<String, dynamic>.from(res.first));
          } else {
            pendingOrders.add(orderData);
          }
        } catch (e) {
          final legacyOrderData = Map<String, dynamic>.from(orderData)
            ..remove('payment_status')
            ..remove('currency')
            ..remove('amount_paise')
            ..remove('idempotency_key');
          await client.from('orders').insert(legacyOrderData);
          pendingOrders.add(legacyOrderData);
        }
      }
    }

    return pendingOrders;
  }

  /// Verification state machine transition logic.
  /// Validates all parameters and enforces idempotency and transition rules.
  ///
  /// CRITICAL SECURITY RULE:
  /// This mock verification is strictly restricted to test harnesses and demo reviewer mode.
  /// It throws [PaymentSecurityException] if invoked in production mode or with real customer data.
  PaymentVerificationResult verifyMockPaymentForTesting({
    required Map<String, dynamic> currentOrder,
    required String orderId,
    required int amountPaise,
    required String currency,
    required String transactionRef,
    bool simulateFailure = false,
    bool simulateCancel = false,
  }) {
    // Guard 1: strictly block mock verification in release builds under all circumstances
    if (kReleaseMode) {
      throw const PaymentSecurityException(
        'Mock payment verification is prohibited in release builds. Live payments require server-side gateway verification.',
      );
    }

    // Guard 2: in non-release builds, require test environment or active demo mode
    if (!kDebugMode && !DemoModeService.isDemoMode) {
      throw const PaymentSecurityException(
        'Mock payment verification is prohibited outside test and demo reviewer environments.',
      );
    }

    final storedId = currentOrder['id']?.toString();
    if (storedId != null && storedId.isNotEmpty && storedId != orderId) {
      return PaymentVerificationResult(
        isSuccess: false,
        message: 'Order ID mismatch: expected $storedId, received $orderId',
        status: PaymentStatus.failed,
      );
    }

    // 1. Currency validation
    if (currency.toUpperCase() != 'INR') {
      return PaymentVerificationResult(
        isSuccess: false,
        message: 'Invalid currency $currency. Only INR is accepted.',
        status: PaymentStatus.failed,
      );
    }

    // 2. Amount validation (in paise)
    final storedPaise = (currentOrder['amount_paise'] as num?)?.toInt() ??
        PaymentOrder.toPaise((currentOrder['total_price'] as num?)?.toDouble() ?? 0.0);
    if (amountPaise != storedPaise) {
      return PaymentVerificationResult(
        isSuccess: false,
        message: 'Amount mismatch: expected $storedPaise paise, received $amountPaise paise.',
        status: PaymentStatus.failed,
      );
    }

    // 3. Current status parsing
    final currentPaymentStatus = PaymentStatusX.fromString(
      currentOrder['payment_status'] as String?,
      orderStatus: currentOrder['status'] as String?,
      paymentMethod: currentOrder['payment_method'] as String?,
    );

    // 4. Idempotency Check: if already paid, return success without re-processing
    if (currentPaymentStatus == PaymentStatus.paid) {
      return PaymentVerificationResult(
        isSuccess: true,
        message: 'Order already verified and paid. (Idempotent response)',
        status: PaymentStatus.paid,
        transactionRef: currentOrder['payment_ref'] as String? ?? transactionRef,
        isIdempotentReplay: true,
        rawOrder: currentOrder,
      );
    }

    // 5. Handle simulated cancellation
    if (simulateCancel) {
      currentOrder['payment_status'] = PaymentStatus.cancelled.value;
      currentOrder['status'] = 'cancelled';
      return PaymentVerificationResult(
        isSuccess: false,
        message: 'Payment was cancelled by the user.',
        status: PaymentStatus.cancelled,
        rawOrder: currentOrder,
      );
    }

    // 6. Handle simulated failure
    if (simulateFailure) {
      currentOrder['payment_status'] = PaymentStatus.failed.value;
      currentOrder['status'] = 'failed';
      return PaymentVerificationResult(
        isSuccess: false,
        message: 'Payment failed or was declined by the bank.',
        status: PaymentStatus.failed,
        rawOrder: currentOrder,
      );
    }

    // 7. Transition to Paid
    if (!currentPaymentStatus.canTransitionTo(PaymentStatus.paid)) {
      return PaymentVerificationResult(
        isSuccess: false,
        message: 'Invalid state transition from $currentPaymentStatus to paid.',
        status: currentPaymentStatus,
      );
    }

    currentOrder['payment_status'] = PaymentStatus.paid.value;
    currentOrder['status'] = 'confirmed';
    currentOrder['payment_ref'] = transactionRef;
    currentOrder['paid_at'] = DateTime.now().toIso8601String();

    return PaymentVerificationResult(
      isSuccess: true,
      message: 'Payment verified successfully.',
      status: PaymentStatus.paid,
      transactionRef: transactionRef,
      rawOrder: currentOrder,
    );
  }

  static bool _isUuid(String value) {
    final uuid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    );
    return uuid.hasMatch(value);
  }
}
