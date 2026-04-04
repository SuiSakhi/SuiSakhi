/// Online methods shown at checkout (customer pays advance only online).
enum OnlinePaymentMethod {
  card,
  upi,
  netbanking,
}

extension OnlinePaymentMethodLabel on OnlinePaymentMethod {
  String get label => switch (this) {
        OnlinePaymentMethod.card => 'Credit / debit card',
        OnlinePaymentMethod.upi => 'UPI',
        OnlinePaymentMethod.netbanking => 'Net banking',
      };
}

/// One line in the order’s payout ledger after a successful advance payment.
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
      out.add(OrderPayoutLine(
        role: m['role'] as String? ?? '',
        amount: (m['amount'] as num?)?.toDouble() ?? 0,
        percent: (m['percent'] as num?)?.toDouble() ?? 0,
        creditToUpi: m['creditToUpi'] as String?,
      ));
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

/// Shop-wide payout rules (`config/payouts`). Percents apply to the **advance** amount.
class ShopPayoutConfig {
  final double ownerPercent;
  final double tailorPercent;
  final double deliveryPercent;
  final double platformPercent;
  final bool sandboxMode;
  final String? razorpayKeyId;
  final String ownerUpiId;
  final String tailorUpiId;
  final String deliveryUpiId;

  const ShopPayoutConfig({
    this.ownerPercent = 18,
    this.tailorPercent = 52,
    this.deliveryPercent = 15,
    this.platformPercent = 15,
    this.sandboxMode = true,
    this.razorpayKeyId,
    this.ownerUpiId = '',
    this.tailorUpiId = '',
    this.deliveryUpiId = '',
  });

  static ShopPayoutConfig fromFirestore(Map<String, dynamic>? data) {
    if (data == null) return const ShopPayoutConfig();
    double g(String k, double d) =>
        (data[k] as num?)?.toDouble() ?? d;
    return ShopPayoutConfig(
      ownerPercent: g('ownerPercent', 18),
      tailorPercent: g('tailorPercent', 52),
      deliveryPercent: g('deliveryPercent', 15),
      platformPercent: g('platformPercent', 15),
      sandboxMode: data['sandboxMode'] is bool
          ? data['sandboxMode'] as bool
          : true,
      razorpayKeyId: data['razorpayKeyId'] as String?,
      ownerUpiId: (data['ownerUpiId'] as String?)?.trim() ?? '',
      tailorUpiId: (data['tailorUpiId'] as String?)?.trim() ?? '',
      deliveryUpiId: (data['deliveryUpiId'] as String?)?.trim() ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'ownerPercent': ownerPercent,
        'tailorPercent': tailorPercent,
        'deliveryPercent': deliveryPercent,
        'platformPercent': platformPercent,
        'sandboxMode': sandboxMode,
        if (razorpayKeyId != null && razorpayKeyId!.trim().isNotEmpty)
          'razorpayKeyId': razorpayKeyId!.trim(),
        'ownerUpiId': ownerUpiId,
        'tailorUpiId': tailorUpiId,
        'deliveryUpiId': deliveryUpiId,
      };

  /// Normalises slight rounding drift so shares sum to [advance].
  List<OrderPayoutLine> buildLedger(double advance) {
    if (advance <= 0) return [];
    final totalPct =
        ownerPercent + tailorPercent + deliveryPercent + platformPercent;
    if (totalPct <= 0) return [];
    final scale = 100.0 / totalPct;
    final o = ownerPercent * scale;
    final t = tailorPercent * scale;
    final d = deliveryPercent * scale;
    final p = platformPercent * scale;
    double rupees(double pct) => (advance * pct / 100.0 * 100).round() / 100.0;
    var lines = [
      OrderPayoutLine(
        role: 'owner',
        amount: rupees(o),
        percent: o,
        creditToUpi: ownerUpiId.isEmpty ? null : ownerUpiId,
      ),
      OrderPayoutLine(
        role: 'tailor',
        amount: rupees(t),
        percent: t,
        creditToUpi: tailorUpiId.isEmpty ? null : tailorUpiId,
      ),
      OrderPayoutLine(
        role: 'delivery',
        amount: rupees(d),
        percent: d,
        creditToUpi: deliveryUpiId.isEmpty ? null : deliveryUpiId,
      ),
      OrderPayoutLine(
        role: 'platform',
        amount: rupees(p),
        percent: p,
        creditToUpi: null,
      ),
    ];
    var sum = lines.fold<double>(0, (a, b) => a + b.amount);
    var diff = (advance * 100).round() / 100.0 - sum;
    if (diff.abs() >= 0.01 && lines.isNotEmpty) {
      final last = lines.last;
      lines = [
        ...lines.sublist(0, lines.length - 1),
        OrderPayoutLine(
          role: last.role,
          amount: last.amount + diff,
          percent: last.percent,
          creditToUpi: last.creditToUpi,
        ),
      ];
    }
    return lines;
  }
}
