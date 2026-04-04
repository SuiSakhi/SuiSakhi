import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'payment_models.dart';
import 'prd_catalog.dart';

String? _parseOrderDeliveryAddress(Object? raw) {
  if (raw == null) return null;
  if (raw is String) {
    final t = raw.trim();
    return t.isEmpty ? null : t;
  }
  if (raw is List) {
    final t = raw.map((e) => e.toString()).join('\n').trim();
    return t.isEmpty ? null : t;
  }
  final t = raw.toString().trim();
  return t.isEmpty ? null : t;
}

enum DressCategory { ladies, gents }

class DressType {
  final String id;
  final String name;
  final String description;
  final DressCategory category;
  final IconData icon;
  final Color color;
  final List<String> measurements;

  const DressType({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.icon,
    required this.color,
    required this.measurements,
  });
}

enum PaymentStatus { pendingPayment, unpaid, advancePaid, fullyPaid }

extension PaymentStatusLabel on PaymentStatus {
  String get label {
    switch (this) {
      case PaymentStatus.pendingPayment:
        return 'Pay online';
      case PaymentStatus.unpaid:
        return 'Unpaid';
      case PaymentStatus.advancePaid:
        return 'Advance paid';
      case PaymentStatus.fullyPaid:
        return 'Fully paid';
    }
  }

  Color get color {
    switch (this) {
      case PaymentStatus.pendingPayment:
        return const Color(0xFFFF9800);
      case PaymentStatus.unpaid:
        return const Color(0xFFE53935);
      case PaymentStatus.advancePaid:
        return const Color(0xFFF5A623);
      case PaymentStatus.fullyPaid:
        return const Color(0xFF4CAF50);
    }
  }
}

class DressOrder {
  final String id;
  final String dressType;
  final String tailorName;
  final OrderStatus status;
  final DateTime orderDate;
  final DateTime? deliveryDate;
  final double price;
  final String? fabricDescription;
  final String? customerId;
  final String? deliveryAddress;
  final String? deliveryPartnerId;
  final double deliveryFee;
  final PaymentStatus paymentStatus;
  /// PRD Step 11 — advance share (30–50%). Persisted for payment breakdown.
  final int advancePercent;
  final double advanceAmount;
  final double balanceAmount;
  /// PRD module: core tailoring, quick fix, bulk, or marketplace referral.
  final OrderModuleType orderModuleType;
  /// PRD occasion (e.g. dailyWear) when [orderModuleType] is core.
  final String? occasionCategory;
  final bool kidsFlow;
  /// Core tailoring: customer name, fit, structured measurements, free-form notes (Firestore).
  final String? clientName;
  final String? fit;
  final Map<String, String>? measurements;
  final String? notes;
  /// After online advance: how much was charged and provider metadata.
  final double? amountPaid;
  final DateTime? paidAt;
  final String? paymentMethod;
  final String? paymentProvider;
  final List<OrderPayoutLine>? payoutLedger;

  const DressOrder({
    required this.id,
    required this.dressType,
    required this.tailorName,
    required this.status,
    required this.orderDate,
    this.deliveryDate,
    required this.price,
    this.fabricDescription,
    this.customerId,
    this.deliveryAddress,
    this.deliveryPartnerId,
    this.deliveryFee = 0,
    this.paymentStatus = PaymentStatus.unpaid,
    this.advancePercent = 40,
    this.advanceAmount = 0,
    this.balanceAmount = 0,
    this.orderModuleType = OrderModuleType.coreTailoring,
    this.occasionCategory,
    this.kidsFlow = false,
    this.clientName,
    this.fit,
    this.measurements,
    this.notes,
    this.amountPaid,
    this.paidAt,
    this.paymentMethod,
    this.paymentProvider,
    this.payoutLedger,
  });

  static Map<String, String>? _stringMapFromFirestore(dynamic raw) {
    if (raw == null || raw is! Map) return null;
    final out = <String, String>{};
    for (final e in raw.entries) {
      if (e.value == null) continue;
      out[e.key.toString()] = e.value.toString();
    }
    return out.isEmpty ? null : out;
  }

  static PaymentStatus _parsePaymentStatus(String? s) {
    switch (s) {
      case 'pending_payment':
        return PaymentStatus.pendingPayment;
      case 'advancePaid':
        return PaymentStatus.advancePaid;
      case 'fullyPaid':
        return PaymentStatus.fullyPaid;
      case 'unpaid':
      default:
        return PaymentStatus.unpaid;
    }
  }

  factory DressOrder.fromFirestore(String id, Map<String, dynamic> data) {
    final rawStatus = data['status'] as String? ?? 'pending';
    final migrated = rawStatus == 'inProgress' ? 'inStitching' : rawStatus;
    final price = (data['price'] as num?)?.toDouble() ?? 0;
    final advPct = (data['advancePercent'] as num?)?.round() ?? 40;
    final advAmt = (data['advanceAmount'] as num?)?.toDouble();
    final balAmt = (data['balanceAmount'] as num?)?.toDouble();
    final computedAdvance = advAmt ?? (price * advPct / 100.0);
    final computedBalance = balAmt ?? (price - computedAdvance).clamp(0.0, double.infinity);
    return DressOrder(
      id: id,
      dressType: data['dressType'] as String? ?? '',
      tailorName: data['tailorName'] as String? ?? '',
      customerId: data['customerId'] as String?,
      status: OrderStatus.values.firstWhere(
        (s) => s.name == migrated,
        orElse: () => OrderStatus.pending,
      ),
      orderDate: (data['orderDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      deliveryDate: (data['deliveryDate'] as Timestamp?)?.toDate(),
      price: price,
      fabricDescription: data['fabricDescription'] as String?,
      deliveryAddress: _parseOrderDeliveryAddress(data['deliveryAddress']),
      deliveryPartnerId: data['deliveryPartnerId'] as String?,
      deliveryFee: (data['deliveryFee'] as num?)?.toDouble() ?? 0,
      paymentStatus: _parsePaymentStatus(data['paymentStatus'] as String?),
      advancePercent: advPct.clamp(30, 50).toInt(),
      advanceAmount: computedAdvance,
      balanceAmount: computedBalance,
      orderModuleType: orderModuleTypeFromFirestore(data['orderModuleType'] as String?),
      occasionCategory: data['occasionCategory'] as String?,
      kidsFlow: data['kidsFlow'] as bool? ?? false,
      clientName: data['clientName'] as String?,
      fit: data['fit'] as String?,
      measurements: _stringMapFromFirestore(data['measurements']),
      notes: data['notes'] as String?,
      amountPaid: (data['amountPaid'] as num?)?.toDouble(),
      paidAt: (data['paidAt'] as Timestamp?)?.toDate(),
      paymentMethod: data['paymentMethod'] as String?,
      paymentProvider: data['paymentProvider'] as String?,
      payoutLedger: OrderPayoutLine.parseLedger(data['payoutLedger']),
    );
  }
}

/// PRD tracking — Module 1 core flow (Step 12) + handoff to delivery.
/// Legacy Firestore value `inProgress` is migrated to [inStitching] in [DressOrder.fromFirestore].
enum OrderStatus {
  pending,
  pickedUp,
  atTailor,
  inStitching,
  qcPending,
  qcPassed,
  readyForPickup,
  outForDelivery,
  delivered,
  cancelled,
}

extension OrderStatusLabel on OrderStatus {
  String get label {
    switch (this) {
      case OrderStatus.pending:
        return 'Order placed';
      case OrderStatus.pickedUp:
        return 'Picked up';
      case OrderStatus.atTailor:
        return 'At tailor';
      case OrderStatus.inStitching:
        return 'In stitching';
      case OrderStatus.qcPending:
        return 'QC review';
      case OrderStatus.qcPassed:
        return 'QC passed';
      case OrderStatus.readyForPickup:
        return 'Ready for delivery';
      case OrderStatus.outForDelivery:
        return 'Out for delivery';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color get color {
    switch (this) {
      case OrderStatus.pending:
        return const Color(0xFFFF9800);
      case OrderStatus.pickedUp:
        return const Color(0xFF795548);
      case OrderStatus.atTailor:
        return const Color(0xFF5C6BC0);
      case OrderStatus.inStitching:
        return const Color(0xFF2196F3);
      case OrderStatus.qcPending:
        return const Color(0xFFFF5722);
      case OrderStatus.qcPassed:
        return const Color(0xFF4CAF50);
      case OrderStatus.readyForPickup:
        return const Color(0xFF9C27B0);
      case OrderStatus.outForDelivery:
        return const Color(0xFF00BCD4);
      case OrderStatus.delivered:
        return const Color(0xFF2E7D32);
      case OrderStatus.cancelled:
        return const Color(0xFFE53935);
    }
  }
}

extension OrderStatusPipeline on OrderStatus {
  /// Linear PRD pipeline positions for progress UI (0.0–1.0).
  static const List<OrderStatus> _pipeline = [
    OrderStatus.pending,
    OrderStatus.pickedUp,
    OrderStatus.atTailor,
    OrderStatus.inStitching,
    OrderStatus.qcPending,
    OrderStatus.qcPassed,
    OrderStatus.readyForPickup,
    OrderStatus.outForDelivery,
    OrderStatus.delivered,
  ];

  double get pipelineProgress {
    if (this == OrderStatus.cancelled) return 0;
    final i = _pipeline.indexOf(this);
    if (i < 0) return 0.5;
    return (i + 1) / _pipeline.length;
  }

  /// Next status when updated by tailor (until ready for courier).
  OrderStatus? get nextForTailor {
    switch (this) {
      case OrderStatus.pending:
        return OrderStatus.pickedUp;
      case OrderStatus.pickedUp:
        return OrderStatus.atTailor;
      case OrderStatus.atTailor:
        return OrderStatus.inStitching;
      case OrderStatus.inStitching:
        return OrderStatus.qcPending;
      case OrderStatus.qcPending:
        return OrderStatus.qcPassed;
      case OrderStatus.qcPassed:
        return OrderStatus.readyForPickup;
      default:
        return null;
    }
  }

  /// Next status when updated by delivery partner.
  OrderStatus? get nextForDelivery {
    switch (this) {
      case OrderStatus.readyForPickup:
        return OrderStatus.outForDelivery;
      case OrderStatus.outForDelivery:
        return OrderStatus.delivered;
      default:
        return null;
    }
  }

  String get nextActionLabelTailor {
    final n = nextForTailor;
    if (n == null) return '';
    return 'Mark: ${n.label}';
  }

  String get nextActionLabelDelivery {
    final n = nextForDelivery;
    if (n == null) return '';
    return 'Mark: ${n.label}';
  }
}
