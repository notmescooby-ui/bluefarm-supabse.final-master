import 'payment_types.dart';

/// Data model representing an order with payment lifecycle metadata.
/// Maintains full backward-compatibility with existing Supabase order rows.
class PaymentOrder {
  final String? id;
  final String buyerId;
  final String? farmerId;
  final String? listingId;
  final String species;
  final String farmName;
  final double quantityKg;
  final double pricePerKg;
  final double totalPrice;
  final int amountPaise;
  final String currency;
  final String deliveryAddress;
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final String status;
  final String? paymentRef;
  final String? idempotencyKey;
  final DateTime? createdAt;
  final DateTime? paidAt;

  const PaymentOrder({
    this.id,
    required this.buyerId,
    this.farmerId,
    this.listingId,
    required this.species,
    required this.farmName,
    required this.quantityKg,
    required this.pricePerKg,
    required this.totalPrice,
    required this.amountPaise,
    this.currency = 'INR',
    required this.deliveryAddress,
    required this.paymentMethod,
    required this.paymentStatus,
    this.status = 'confirmed',
    this.paymentRef,
    this.idempotencyKey,
    this.createdAt,
    this.paidAt,
  });

  /// Calculates amount in paise from rupees safely using rounding to avoid IEEE 754 float drift.
  static int toPaise(double rupees) => (rupees * 100).round();

  /// Converts to Map for Supabase insertion/update.
  /// Only includes fields compatible with the schema, with safe fallbacks.
  Map<String, dynamic> toSupabaseMap() {
    final map = <String, dynamic>{
      'buyer_id': buyerId,
      'species': species,
      'farm_name': farmName,
      'quantity_kg': quantityKg,
      'price_per_kg': pricePerKg,
      'total_price': totalPrice,
      'delivery_address': deliveryAddress,
      'payment_method': paymentMethod.value,
      'status': status,
      'payment_status': paymentStatus.value,
      'currency': currency,
      'amount_paise': amountPaise,
    };

    if (id != null) map['id'] = id;
    if (farmerId != null && farmerId!.isNotEmpty) map['farmer_id'] = farmerId;
    if (listingId != null && listingId!.isNotEmpty) map['listing_id'] = listingId;
    if (paymentRef != null) map['payment_ref'] = paymentRef;
    if (idempotencyKey != null) map['idempotency_key'] = idempotencyKey;
    if (paidAt != null) map['paid_at'] = paidAt!.toIso8601String();

    return map;
  }

  /// Parses a Map from Supabase with full backward-compatibility.
  factory PaymentOrder.fromSupabaseMap(Map<String, dynamic> map) {
    final rawTotal = (map['total_price'] as num?)?.toDouble() ?? 0.0;
    final parsedPaise = (map['amount_paise'] as num?)?.toInt() ?? toPaise(rawTotal);
    final rawStatus = map['status'] as String? ?? 'pending';
    final rawPaymentMethod = map['payment_method'] as String? ?? 'cod';
    final rawPaymentStatus = map['payment_status'] as String?;

    return PaymentOrder(
      id: map['id']?.toString(),
      buyerId: map['buyer_id']?.toString() ?? '',
      farmerId: map['farmer_id']?.toString(),
      listingId: map['listing_id']?.toString(),
      species: map['species'] as String? ?? 'Fish Order',
      farmName: map['farm_name'] as String? ?? 'BlueFarm Partner',
      quantityKg: (map['quantity_kg'] as num?)?.toDouble() ?? 0.0,
      pricePerKg: (map['price_per_kg'] as num?)?.toDouble() ?? 0.0,
      totalPrice: rawTotal,
      amountPaise: parsedPaise,
      currency: map['currency'] as String? ?? 'INR',
      deliveryAddress: map['delivery_address'] as String? ?? '',
      paymentMethod: PaymentMethodX.fromString(rawPaymentMethod),
      paymentStatus: PaymentStatusX.fromString(
        rawPaymentStatus,
        orderStatus: rawStatus,
        paymentMethod: rawPaymentMethod,
      ),
      status: rawStatus,
      paymentRef: map['payment_ref'] as String?,
      idempotencyKey: map['idempotency_key'] as String?,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
      paidAt: map['paid_at'] != null ? DateTime.tryParse(map['paid_at'].toString()) : null,
    );
  }

  PaymentOrder copyWith({
    String? id,
    String? buyerId,
    String? farmerId,
    String? listingId,
    String? species,
    String? farmName,
    double? quantityKg,
    double? pricePerKg,
    double? totalPrice,
    int? amountPaise,
    String? currency,
    String? deliveryAddress,
    PaymentMethod? paymentMethod,
    PaymentStatus? paymentStatus,
    String? status,
    String? paymentRef,
    String? idempotencyKey,
    DateTime? createdAt,
    DateTime? paidAt,
  }) {
    return PaymentOrder(
      id: id ?? this.id,
      buyerId: buyerId ?? this.buyerId,
      farmerId: farmerId ?? this.farmerId,
      listingId: listingId ?? this.listingId,
      species: species ?? this.species,
      farmName: farmName ?? this.farmName,
      quantityKg: quantityKg ?? this.quantityKg,
      pricePerKg: pricePerKg ?? this.pricePerKg,
      totalPrice: totalPrice ?? this.totalPrice,
      amountPaise: amountPaise ?? this.amountPaise,
      currency: currency ?? this.currency,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      status: status ?? this.status,
      paymentRef: paymentRef ?? this.paymentRef,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      createdAt: createdAt ?? this.createdAt,
      paidAt: paidAt ?? this.paidAt,
    );
  }
}
