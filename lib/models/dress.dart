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
  final String? designTemplateTitle;
  final String? designImageUrl;
  final String? designDescription;
  final String? catalogueVersionId;
  final String? catalogueCommercialType;
  final double approvedDesignCharge;
  final String? fabricChoice;
  final String? fabricImageUrl;
  final Map<String, dynamic>? customerFabricAssets;
  final Map<String, dynamic>? fabricPurchaseEstimate;
  final Map<String, dynamic>? fabricRequirementReview;
  final String? customerId;
  final String? customerPhone;
  final String? deliveryAddress;
  final String? deliveryPartnerId;
  final double deliveryFee;
  final PaymentStatus paymentStatus;

  /// Production assignment is separate from the fulfillment [status].
  final String? assignmentVersion;
  final String? assignmentStatus;
  final String? orderTrackingId;
  final String? measurementStatus;
  final String? measurementMethod;
  final String? measurementPartnerAccountId;
  final String? measurementPartnerProfileId;
  final String? measurementPartnerName;
  final DateTime? measurementAppointmentAt;
  final String? measurementAppointmentLink;
  final String? measurementNotes;
  final String? measurementSubmissionStatus;
  final Map<String, String>? measurementSubmittedValues;
  final String? measurementSubmittedUnit;
  final String? measurementPartnerCompletionNote;
  final DateTime? measurementAppointmentScheduledAt;
  final DateTime? measurementPartnerCompletedAt;
  final DateTime? measurementConfirmedAt;
  final String? inboundPickupStatus;
  final DateTime? inboundPickupAssignedAt;
  final DateTime? inboundPickupCollectedAt;
  final DateTime? inboundPickupReceivedAt;
  final String? inboundPickupPartnerType;
  final String? inboundPickupPartnerAccountId;
  final String? inboundPickupPartnerProfileId;
  final String? inboundPickupPartnerName;
  final String? inboundPickupPartnerPhone;
  final String? inboundPickupPhotoPath;
  final String? outboundHandoverStatus;
  final DateTime? outboundHandoverAssignedAt;
  final DateTime? outboundHandoverAcceptedAt;
  final String? outboundHandoverPartnerType;
  final String? outboundHandoverPartnerAccountId;
  final String? outboundHandoverPartnerProfileId;
  final String? deliveryPartnerType;
  final String? deliveryPartnerAccountId;
  final String? deliveryPartnerProfileId;
  final String? deliveryPartnerName;
  final String? deliveryPartnerPhone;
  final Map<String, dynamic>? garmentRecordDraft;
  final Map<String, dynamic>? garmentRecord;
  final DateTime? garmentRecordPublishedAt;
  final String? assignedTailorName;
  final String? adminQueueReason;
  final DateTime? nextDispatchAt;
  final DateTime? customerDecisionExpiresAt;
  final DateTime? orderFinalizedAt;
  final DateTime? expectedReadyAt;
  final DateTime? deliveredAt;
  final DateTime? closedAt;
  final DateTime? warrantyEndsAt;
  final DateTime? warrantyIssueReportedAt;
  final DateTime? feedbackSubmittedAt;
  final int? feedbackRating;
  final String? feedbackText;
  final String? warrantyClaimStatus;
  final String? warrantyIssueDescription;
  final String? warrantyResolution;
  final double cancellationFeeAmount;
  final double cancellationFeePercent;
  final double cancellationRefundDue;
  final double cancellationFeeOutstanding;
  final bool cancellationFeeWaived;

  /// Shared account/profile ownership for new orders. Older documents may omit these.
  final String? customerAccountId;
  final String? customerProfileId;

  /// Delivery-area snapshot used for Partner service-area eligibility.
  final String? deliveryPincode;

  /// PRD Step 11 — advance share (30–50%). Persisted for payment breakdown.
  final int advancePercent;
  final double advanceAmount;
  final double balanceAmount;

  /// PRD module: core tailoring, quick fix, bulk, or marketplace referral.
  final OrderModuleType orderModuleType;

  /// PRD occasion (e.g. dailyWear) when [orderModuleType] is core.
  final String? occasionCategory;
  final bool kidsFlow;

  /// Core tailoring: selected person/customer name, fit, structured measurements, free-form notes (Firestore).
  final String? clientName;

  /// Multi-profile / family-member order ownership snapshot.
  /// These fields are stored directly on the order so historical orders remain readable
  /// even if a family member is archived later.
  final String? personId;
  final String? personName;
  final String? relationship;

  /// Bulk order / event consultation snapshot fields.
  final String? requestedByName;
  final String? eventType;
  final String? consultationType;
  final DateTime? eventDate;

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
    this.designTemplateTitle,
    this.designImageUrl,
    this.designDescription,
    this.catalogueVersionId,
    this.catalogueCommercialType,
    this.approvedDesignCharge = 0,
    this.fabricChoice,
    this.fabricImageUrl,
    this.customerFabricAssets,
    this.fabricPurchaseEstimate,
    this.fabricRequirementReview,
    this.customerId,
    this.customerPhone,
    this.deliveryAddress,
    this.deliveryPartnerId,
    this.deliveryFee = 0,
    this.paymentStatus = PaymentStatus.unpaid,
    this.assignmentVersion,
    this.assignmentStatus,
    this.orderTrackingId,
    this.measurementStatus,
    this.measurementMethod,
    this.measurementPartnerAccountId,
    this.measurementPartnerProfileId,
    this.measurementPartnerName,
    this.measurementAppointmentAt,
    this.measurementAppointmentLink,
    this.measurementNotes,
    this.measurementSubmissionStatus,
    this.measurementSubmittedValues,
    this.measurementSubmittedUnit,
    this.measurementPartnerCompletionNote,
    this.measurementAppointmentScheduledAt,
    this.measurementPartnerCompletedAt,
    this.measurementConfirmedAt,
    this.inboundPickupStatus,
    this.inboundPickupAssignedAt,
    this.inboundPickupCollectedAt,
    this.inboundPickupReceivedAt,
    this.inboundPickupPartnerType,
    this.inboundPickupPartnerAccountId,
    this.inboundPickupPartnerProfileId,
    this.inboundPickupPartnerName,
    this.inboundPickupPartnerPhone,
    this.inboundPickupPhotoPath,
    this.outboundHandoverStatus,
    this.outboundHandoverAssignedAt,
    this.outboundHandoverAcceptedAt,
    this.outboundHandoverPartnerType,
    this.outboundHandoverPartnerAccountId,
    this.outboundHandoverPartnerProfileId,
    this.deliveryPartnerType,
    this.deliveryPartnerAccountId,
    this.deliveryPartnerProfileId,
    this.deliveryPartnerName,
    this.deliveryPartnerPhone,
    this.garmentRecordDraft,
    this.garmentRecord,
    this.garmentRecordPublishedAt,
    this.assignedTailorName,
    this.adminQueueReason,
    this.nextDispatchAt,
    this.customerDecisionExpiresAt,
    this.orderFinalizedAt,
    this.expectedReadyAt,
    this.deliveredAt,
    this.closedAt,
    this.warrantyEndsAt,
    this.warrantyIssueReportedAt,
    this.feedbackSubmittedAt,
    this.feedbackRating,
    this.feedbackText,
    this.warrantyClaimStatus,
    this.warrantyIssueDescription,
    this.warrantyResolution,
    this.cancellationFeeAmount = 0,
    this.cancellationFeePercent = 10,
    this.cancellationRefundDue = 0,
    this.cancellationFeeOutstanding = 0,
    this.cancellationFeeWaived = false,
    this.customerAccountId,
    this.customerProfileId,
    this.deliveryPincode,
    this.advancePercent = 50,
    this.advanceAmount = 0,
    this.balanceAmount = 0,
    this.orderModuleType = OrderModuleType.coreTailoring,
    this.occasionCategory,
    this.kidsFlow = false,
    this.clientName,
    this.personId,
    this.personName,
    this.relationship,
    this.requestedByName,
    this.eventType,
    this.consultationType,
    this.eventDate,
    this.fit,
    this.measurements,
    this.notes,
    this.amountPaid,
    this.paidAt,
    this.paymentMethod,
    this.paymentProvider,
    this.payoutLedger,
  });

  String get orderForText {
    final name = (personName?.trim().isNotEmpty == true)
        ? personName!.trim()
        : (clientName?.trim().isNotEmpty == true)
        ? clientName!.trim()
        : '';

    final rel = relationship?.trim() ?? '';

    if (name.isEmpty) {
      return 'Customer';
    }

    if (rel.isNotEmpty && rel.toLowerCase() != 'self') {
      return '$name ($rel)';
    }

    return name;
  }

  String? get customerFabricPhotoPath =>
      _dynamicMapFromFirestore(customerFabricAssets?['fabricPhoto'])?['storagePath']
          ?.toString();

  String? get customerFabricPreviewPath =>
      _dynamicMapFromFirestore(customerFabricAssets?['selectedPreview'])?['storagePath']
          ?.toString();

  List<Map<String, dynamic>> get customerFabricPreviewAssets {
    final rawPreviews = customerFabricAssets?['previews'];
    final previews = rawPreviews is Iterable
        ? rawPreviews
              .whereType<Map>()
              .map(
                (preview) => Map<String, dynamic>.fromEntries(
                  preview.entries.map(
                    (entry) => MapEntry(entry.key.toString(), entry.value),
                  ),
                ),
              )
              .where(
                (preview) =>
                    preview['storagePath']?.toString().trim().isNotEmpty ==
                    true,
              )
              .toList(growable: false)
        : const <Map<String, dynamic>>[];
    if (previews.isNotEmpty) return previews;
    final selectedPreview =
        _dynamicMapFromFirestore(customerFabricAssets?['selectedPreview']);
    return selectedPreview?['storagePath']?.toString().trim().isNotEmpty == true
        ? [selectedPreview!]
        : const [];
  }

  bool get usesProductionAssignment => assignmentVersion == 'v1';

  bool get canCancelBeforeStitching =>
      usesProductionAssignment &&
      status != OrderStatus.inStitching &&
      status != OrderStatus.qcPending &&
      status != OrderStatus.qcPassed &&
      status != OrderStatus.readyForPickup &&
      status != OrderStatus.outForDelivery &&
      status != OrderStatus.delivered &&
      status != OrderStatus.cancelled;

  String get requestedByText {
    final name = requestedByName?.trim();

    if (name != null && name.isNotEmpty) {
      return name;
    }

    final fallbackClient = clientName?.trim();

    if (fallbackClient != null && fallbackClient.isNotEmpty) {
      return fallbackClient;
    }

    final fallbackPerson = personName?.trim();

    if (fallbackPerson != null && fallbackPerson.isNotEmpty) {
      return fallbackPerson;
    }

    return 'Customer';
  }

  String? get eventText {
    final value = eventType?.trim();

    if (value == null || value.isEmpty) return null;

    return value;
  }

  String? get consultationText {
    final value = consultationType?.trim();

    if (value == null || value.isEmpty) return null;

    return value;
  }

  static Map<String, String>? _stringMapFromFirestore(dynamic raw) {
    if (raw == null || raw is! Map) return null;
    final out = <String, String>{};
    for (final e in raw.entries) {
      if (e.value == null) continue;
      out[e.key.toString()] = e.value.toString();
    }
    return out.isEmpty ? null : out;
  }

  static Map<String, dynamic>? _dynamicMapFromFirestore(dynamic raw) {
    if (raw == null || raw is! Map) return null;
    return Map<String, dynamic>.fromEntries(
      raw.entries.map((entry) => MapEntry(entry.key.toString(), entry.value)),
    );
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
    final advPct = (data['advancePercent'] as num?)?.round() ?? 50;
    final advAmt = (data['advanceAmount'] as num?)?.toDouble();
    final balAmt = (data['balanceAmount'] as num?)?.toDouble();
    final computedAdvance = advAmt ?? (price * advPct / 100.0);
    final computedBalance =
        balAmt ?? (price - computedAdvance).clamp(0.0, double.infinity);
    final customerFabricAssets =
        _dynamicMapFromFirestore(data['customerFabricAssets']);
    return DressOrder(
      id: id,
      dressType: data['dressType'] as String? ?? '',
      tailorName: data['tailorName'] as String? ?? '',
      customerId: data['customerId'] as String?,
      customerPhone:
          (data['customerPhone'] ??
                  data['warrantyCustomerPhone'] ??
                  data['phone'] ??
                  data['mobileE164'])
              as String?,
      status: OrderStatus.values.firstWhere(
        (s) => s.name == migrated,
        orElse: () => OrderStatus.pending,
      ),
      orderDate: (data['orderDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      deliveryDate: (data['deliveryDate'] as Timestamp?)?.toDate(),
      price: price,
      fabricDescription: data['fabricDescription'] as String?,
      designTemplateTitle: data['designTemplateTitle'] as String?,
      designImageUrl: data['designImageUrl'] as String?,
      designDescription: data['designDescription'] as String?,
      catalogueVersionId: data['catalogueVersionId'] as String?,
      catalogueCommercialType: data['catalogueCommercialType'] as String?,
      approvedDesignCharge:
          (data['approvedDesignCharge'] as num?)?.toDouble() ?? 0,
      fabricChoice: data['fabricChoice'] as String?,
      fabricImageUrl:
          (data['fabricImageUrl'] ?? data['materialImageUrl']) as String?,
      customerFabricAssets: customerFabricAssets,
      fabricPurchaseEstimate:
          _dynamicMapFromFirestore(data['fabricPurchaseEstimate']),
      fabricRequirementReview:
          _dynamicMapFromFirestore(data['fabricRequirementReview']),
      deliveryAddress: _parseOrderDeliveryAddress(data['deliveryAddress']),
      deliveryPartnerId: data['deliveryPartnerId'] as String?,
      deliveryFee: (data['deliveryFee'] as num?)?.toDouble() ?? 0,
      paymentStatus: _parsePaymentStatus(data['paymentStatus'] as String?),
      assignmentVersion: data['assignmentVersion'] as String?,
      assignmentStatus: data['assignmentStatus'] as String?,
      orderTrackingId: data['orderTrackingId'] as String?,
      measurementStatus: data['measurementStatus'] as String?,
      measurementMethod: data['measurementMethod'] as String?,
      measurementPartnerAccountId:
          data['measurementPartnerAccountId'] as String?,
      measurementPartnerProfileId:
          data['measurementPartnerProfileId'] as String?,
      measurementPartnerName: data['measurementPartnerName'] as String?,
      measurementAppointmentAt: (data['measurementAppointmentAt'] as Timestamp?)
          ?.toDate(),
      measurementAppointmentLink: data['measurementAppointmentLink'] as String?,
      measurementNotes: data['measurementNotes'] as String?,
      measurementSubmissionStatus:
          data['measurementSubmissionStatus'] as String?,
      measurementSubmittedValues: _stringMapFromFirestore(
        data['measurementSubmittedValues'],
      ),
      measurementSubmittedUnit: data['measurementSubmittedUnit'] as String?,
      measurementPartnerCompletionNote:
          data['measurementPartnerCompletionNote'] as String?,
      measurementAppointmentScheduledAt:
          (data['measurementAppointmentScheduledAt'] as Timestamp?)?.toDate(),
      measurementPartnerCompletedAt:
          (data['measurementPartnerCompletedAt'] as Timestamp?)?.toDate(),
      measurementConfirmedAt: (data['measurementConfirmedAt'] as Timestamp?)
          ?.toDate(),
      inboundPickupStatus: data['inboundPickupStatus'] as String?,
      inboundPickupAssignedAt: (data['inboundPickupAssignedAt'] as Timestamp?)
          ?.toDate(),
      inboundPickupCollectedAt: (data['inboundPickupCollectedAt'] as Timestamp?)
          ?.toDate(),
      inboundPickupReceivedAt: (data['inboundPickupReceivedAt'] as Timestamp?)
          ?.toDate(),
      inboundPickupPartnerType: data['inboundPickupPartnerType'] as String?,
      inboundPickupPartnerAccountId:
          data['inboundPickupPartnerAccountId'] as String?,
      inboundPickupPartnerProfileId:
          data['inboundPickupPartnerProfileId'] as String?,
      inboundPickupPartnerName: data['inboundPickupPartnerName'] as String?,
      inboundPickupPartnerPhone: data['inboundPickupPartnerPhone'] as String?,
      inboundPickupPhotoPath: data['inboundPickupPhotoPath'] as String?,
      outboundHandoverStatus: data['outboundHandoverStatus'] as String?,
      outboundHandoverAssignedAt:
          (data['outboundHandoverAssignedAt'] as Timestamp?)?.toDate(),
      outboundHandoverAcceptedAt:
          (data['outboundHandoverAcceptedAt'] as Timestamp?)?.toDate(),
      outboundHandoverPartnerType:
          data['outboundHandoverPartnerType'] as String?,
      outboundHandoverPartnerAccountId:
          data['outboundHandoverPartnerAccountId'] as String?,
      outboundHandoverPartnerProfileId:
          data['outboundHandoverPartnerProfileId'] as String?,
      deliveryPartnerType: data['deliveryPartnerType'] as String?,
      deliveryPartnerAccountId: data['deliveryPartnerAccountId'] as String?,
      deliveryPartnerProfileId: data['deliveryPartnerProfileId'] as String?,
      deliveryPartnerName: data['deliveryPartnerName'] as String?,
      deliveryPartnerPhone: data['deliveryPartnerPhone'] as String?,
      garmentRecordDraft: _dynamicMapFromFirestore(data['garmentRecordDraft']),
      garmentRecord: _dynamicMapFromFirestore(data['garmentRecord']),
      garmentRecordPublishedAt: (data['garmentRecordPublishedAt'] as Timestamp?)
          ?.toDate(),
      assignedTailorName: data['assignedTailorName'] as String?,
      adminQueueReason: data['adminQueueReason'] as String?,
      nextDispatchAt: (data['nextDispatchAt'] as Timestamp?)?.toDate(),
      customerDecisionExpiresAt:
          (data['customerDecisionExpiresAt'] as Timestamp?)?.toDate(),
      orderFinalizedAt: (data['orderFinalizedAt'] as Timestamp?)?.toDate(),
      expectedReadyAt: (data['expectedReadyAt'] as Timestamp?)?.toDate(),
      deliveredAt: (data['deliveredAt'] as Timestamp?)?.toDate(),
      closedAt: (data['closedAt'] as Timestamp?)?.toDate(),
      warrantyEndsAt: (data['warrantyEndsAt'] as Timestamp?)?.toDate(),
      warrantyIssueReportedAt: (data['warrantyIssueReportedAt'] as Timestamp?)
          ?.toDate(),
      feedbackSubmittedAt: (data['feedbackSubmittedAt'] as Timestamp?)
          ?.toDate(),
      feedbackRating: (data['feedbackRating'] as num?)?.toInt(),
      feedbackText: data['feedbackText'] as String?,
      warrantyClaimStatus: data['warrantyClaimStatus'] as String?,
      warrantyIssueDescription: data['warrantyIssueDescription'] as String?,
      warrantyResolution: data['warrantyResolution'] as String?,
      cancellationFeeAmount:
          (data['cancellationFeeAmount'] as num?)?.toDouble() ?? 0,
      cancellationFeePercent:
          (data['cancellationFeePercent'] as num?)?.toDouble() ?? 10,
      cancellationRefundDue:
          (data['cancellationRefundDue'] as num?)?.toDouble() ?? 0,
      cancellationFeeOutstanding:
          (data['cancellationFeeOutstanding'] as num?)?.toDouble() ?? 0,
      cancellationFeeWaived: data['cancellationFeeWaived'] as bool? ?? false,
      customerAccountId: data['customerAccountId'] as String?,
      customerProfileId: data['customerProfileId'] as String?,
      deliveryPincode: data['deliveryPincode'] as String?,
      advancePercent: advPct.clamp(30, 50).toInt(),
      advanceAmount: computedAdvance,
      balanceAmount: computedBalance,
      orderModuleType: orderModuleTypeFromFirestore(
        data['orderModuleType'] as String?,
      ),
      occasionCategory: data['occasionCategory'] as String?,
      kidsFlow: data['kidsFlow'] as bool? ?? false,
      clientName: data['clientName'] as String?,
      personId: data['personId'] as String?,
      personName: data['personName'] as String?,
      relationship: data['relationship'] as String?,

      requestedByName:
          (data['requestedByName'] ??
                  data['customerName'] ??
                  data['clientName'])
              ?.toString(),
      eventType:
          (data['eventType'] ??
                  data['bulkEventType'] ??
                  data['packageType'] ??
                  data['occasionCategory'])
              ?.toString(),
      consultationType:
          (data['consultationType'] ??
                  data['consultationMode'] ??
                  data['consultation'])
              ?.toString(),
      eventDate: (data['eventDate'] as Timestamp?)?.toDate(),

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
