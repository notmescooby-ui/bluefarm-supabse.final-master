/// Explicit payment state model for BlueFarm
/// Represents the lifecycle states of an order payment.
enum PaymentStatus {
  /// Order created in database, waiting for payment initiation.
  pending,

  /// Cash on Delivery: Order confirmed, but payment is DUE upon delivery (unpaid).
  codDue,

  /// Buyer has initiated payment (e.g. app launched or intent sent).
  initiated,

  /// Payment intent dispatched, awaiting trusted server/webhook verification.
  verificationPending,

  /// Payment confirmed by trusted backend verification or cash collected upon delivery.
  paid,

  /// Transaction failed, declined, or timed out.
  failed,

  /// Payment aborted or cancelled by the user.
  cancelled,
}

extension PaymentStatusX on PaymentStatus {
  String get value {
    switch (this) {
      case PaymentStatus.pending:
        return 'pending';
      case PaymentStatus.codDue:
        return 'cod_due';
      case PaymentStatus.initiated:
        return 'initiated';
      case PaymentStatus.verificationPending:
        return 'verification_pending';
      case PaymentStatus.paid:
        return 'paid';
      case PaymentStatus.failed:
        return 'failed';
      case PaymentStatus.cancelled:
        return 'cancelled';
    }
  }

  String get displayName {
    switch (this) {
      case PaymentStatus.pending:
        return 'Payment Pending';
      case PaymentStatus.codDue:
        return 'Cash Due on Delivery';
      case PaymentStatus.initiated:
        return 'Payment Initiated';
      case PaymentStatus.verificationPending:
        return 'Verification Pending';
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.failed:
        return 'Payment Failed';
      case PaymentStatus.cancelled:
        return 'Cancelled';
    }
  }

  bool get isTerminal =>
      this == PaymentStatus.paid ||
      this == PaymentStatus.failed ||
      this == PaymentStatus.cancelled;

  /// Validates allowed state transitions to prevent invalid or out-of-order jumps.
  bool canTransitionTo(PaymentStatus next) {
    if (this == next) return true; // Idempotent self-transition allowed
    switch (this) {
      case PaymentStatus.pending:
        return next == PaymentStatus.initiated ||
            next == PaymentStatus.codDue ||
            next == PaymentStatus.cancelled ||
            next == PaymentStatus.failed;
      case PaymentStatus.codDue:
        // COD payment is due until courier records cash collected (paid) or order is cancelled
        return next == PaymentStatus.paid ||
            next == PaymentStatus.cancelled;
      case PaymentStatus.initiated:
        return next == PaymentStatus.verificationPending ||
            next == PaymentStatus.cancelled ||
            next == PaymentStatus.failed;
      case PaymentStatus.verificationPending:
        return next == PaymentStatus.paid ||
            next == PaymentStatus.failed ||
            next == PaymentStatus.cancelled;
      case PaymentStatus.paid:
        // Terminal: once paid, an order cannot transition to failed or cancelled
        return false;
      case PaymentStatus.failed:
      case PaymentStatus.cancelled:
        // Retries must create a new attempt or transition via initiated
        return next == PaymentStatus.initiated;
    }
  }

  /// Parses a string into [PaymentStatus] with full backward-compatibility
  /// for legacy database records that only had order [status] and [paymentMethod].
  static PaymentStatus fromString(
    String? rawStatus, {
    String? orderStatus,
    String? paymentMethod,
  }) {
    if (rawStatus != null && rawStatus.isNotEmpty) {
      switch (rawStatus.toLowerCase()) {
        case 'pending':
          return PaymentStatus.pending;
        case 'cod_due':
        case 'coddue':
          return PaymentStatus.codDue;
        case 'initiated':
          return PaymentStatus.initiated;
        case 'verification_pending':
        case 'verificationpending':
          return PaymentStatus.verificationPending;
        case 'paid':
          return PaymentStatus.paid;
        case 'failed':
          return PaymentStatus.failed;
        case 'cancelled':
          return PaymentStatus.cancelled;
      }
    }

    // Backward-compatibility fallback for legacy orders without payment_status:
    // If order is COD:
    // - CRITICAL AUDIT FIX: Delivery is NOT proof of cash collection.
    // - Legacy database records contain no cash collection receipt or paid_at timestamp.
    // - Therefore, delivered COD orders without an explicit 'paid' status remain 'cod_due'.
    if (paymentMethod == 'cod') {
      if (orderStatus == 'cancelled') {
        return PaymentStatus.cancelled;
      }
      return PaymentStatus.codDue;
    }

    if (orderStatus == 'cancelled') {
      return PaymentStatus.cancelled;
    }

    return PaymentStatus.pending;
  }
}

/// Supported payment methods in BlueFarm
enum PaymentMethod {
  cod,
  upi,
  mock, // For isolated test/demo environments only
}

extension PaymentMethodX on PaymentMethod {
  String get value {
    switch (this) {
      case PaymentMethod.cod:
        return 'cod';
      case PaymentMethod.upi:
        return 'upi';
      case PaymentMethod.mock:
        return 'mock';
    }
  }

  String get displayName {
    switch (this) {
      case PaymentMethod.cod:
        return 'Cash on Delivery';
      case PaymentMethod.upi:
        return 'UPI Payment';
      case PaymentMethod.mock:
        return 'Demo / Mock Payment';
    }
  }

  static PaymentMethod fromString(String? val) {
    if (val == null) return PaymentMethod.cod;
    switch (val.toLowerCase()) {
      case 'upi':
        return PaymentMethod.upi;
      case 'mock':
        return PaymentMethod.mock;
      case 'cod':
      default:
        return PaymentMethod.cod;
    }
  }
}
