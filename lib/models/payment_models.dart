/// Online methods shown at checkout (customer pays advance only online).
enum OnlinePaymentMethod { card, upi, netbanking }

extension OnlinePaymentMethodLabel on OnlinePaymentMethod {
  String get label => switch (this) {
    OnlinePaymentMethod.card => 'Credit / debit card',
    OnlinePaymentMethod.upi => 'UPI',
    OnlinePaymentMethod.netbanking => 'Net banking',
  };
}

/// Legacy line retained for reading historical advance payout ledgers.
class OrderPayoutLine {
  final String role;
  final double amount;
  final double percent;
  final String? creditToUpi;

  const OrderPayoutLine({
    required this.role,
    required this.amount,
    required this.percent,
    this.creditToUpi,
  });

  Map<String, dynamic> toMap() => {
    'role': role,
    'amount': amount,
    'percent': percent,
    if (creditToUpi != null && creditToUpi!.isNotEmpty)
      'creditToUpi': creditToUpi,
  };

  static List<OrderPayoutLine>? parseLedger(dynamic raw) {
    if (raw is! List) return null;
    final out = <OrderPayoutLine>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      out.add(
        OrderPayoutLine(
          role: m['role'] as String? ?? '',
          amount: (m['amount'] as num?)?.toDouble() ?? 0,
          percent: (m['percent'] as num?)?.toDouble() ?? 0,
          creditToUpi: m['creditToUpi'] as String?,
        ),
      );
    }
    return out.isEmpty ? null : out;
  }

  String get roleLabel => switch (role) {
    'owner' => 'Shop owner',
    'tailor' => 'Tailor',
    'delivery' => 'Delivery',
    'platform' => 'Platform',
    _ => role,
  };
}

/// Shop-wide payment configuration (`config/payouts`).
class ShopPayoutConfig {
  final bool sandboxMode;
  final String? razorpayKeyId;
  final String ownerUpiId;
  final String tailorUpiId;
  final String deliveryUpiId;
  final double partnerJoiningSecurityDeposit;

  const ShopPayoutConfig({
    this.sandboxMode = true,
    this.razorpayKeyId,
    this.ownerUpiId = '',
    this.tailorUpiId = '',
    this.deliveryUpiId = '',
    this.partnerJoiningSecurityDeposit = 0,
  });

  static ShopPayoutConfig fromFirestore(Map<String, dynamic>? data) {
    if (data == null) return const ShopPayoutConfig();
    final rawJoiningDeposit =
        (data['partnerJoiningSecurityDeposit'] as num?)?.toDouble() ?? 0;
    return ShopPayoutConfig(
      sandboxMode: data['sandboxMode'] is bool
          ? data['sandboxMode'] as bool
          : true,
      razorpayKeyId: data['razorpayKeyId'] as String?,
      ownerUpiId: (data['ownerUpiId'] as String?)?.trim() ?? '',
      tailorUpiId: (data['tailorUpiId'] as String?)?.trim() ?? '',
      deliveryUpiId: (data['deliveryUpiId'] as String?)?.trim() ?? '',
      partnerJoiningSecurityDeposit:
          rawJoiningDeposit.isFinite && rawJoiningDeposit >= 0
          ? rawJoiningDeposit
          : 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'sandboxMode': sandboxMode,
    if (razorpayKeyId != null && razorpayKeyId!.trim().isNotEmpty)
      'razorpayKeyId': razorpayKeyId!.trim(),
    'ownerUpiId': ownerUpiId,
    'tailorUpiId': tailorUpiId,
    'deliveryUpiId': deliveryUpiId,
    'partnerJoiningSecurityDeposit': partnerJoiningSecurityDeposit,
  };
}
