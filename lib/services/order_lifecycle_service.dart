import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/payment_models.dart';

class OrderLifecyclePolicy {
  const OrderLifecyclePolicy({
    this.cancellationFeePercent = 10,
    this.warrantyDays = 15,
  });

  final double cancellationFeePercent;
  final int warrantyDays;

  static OrderLifecyclePolicy fromMap(Map<String, dynamic>? data) {
    final percent = (data?['cancellationFeePercent'] as num?)?.toDouble();
    final days = (data?['warrantyDays'] as num?)?.toInt();
    return OrderLifecyclePolicy(
      cancellationFeePercent: percent == null
          ? 10
          : percent.clamp(0, 100).toDouble(),
      warrantyDays: days == null ? 15 : days.clamp(1, 365).toInt(),
    );
  }

  static Future<OrderLifecyclePolicy> fetch() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('config')
        .doc('order_lifecycle')
        .get();
    return OrderLifecyclePolicy.fromMap(snapshot.data());
  }
}

class OrderLifecycleService {
  OrderLifecycleService._();

  static final _functions = FirebaseFunctions.instance;

  static Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data,
  ) async {
    final result = await _functions.httpsCallable(name).call(data);
    return result.data is Map
        ? Map<String, dynamic>.from(result.data as Map)
        : const <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> cancelOrder(String orderId) =>
      _call('cancelCoreTailoringOrder', {'orderId': orderId});

  static Future<Map<String, dynamic>> getCustomerOrderPartnerContacts(
    String orderId,
  ) => _call('getCustomerOrderPartnerContacts', {'orderId': orderId});

  static Future<List<Map<String, dynamic>>> getTailorInboundPickupCandidates({
    required String orderId,
    required String accountId,
    required String profileId,
  }) async {
    final result = await _call('getTailorInboundPickupCandidates', {
      'orderId': orderId,
      'accountId': accountId,
      'profileId': profileId,
    });
    final rawCandidates = result['candidates'];
    if (rawCandidates is! List) return const [];
    return rawCandidates
        .whereType<Map>()
        .map((candidate) => Map<String, dynamic>.from(candidate))
        .toList(growable: false);
  }

  static Future<void> assignTailorInboundPickupPartner({
    required String orderId,
    required String tailorAccountId,
    required String tailorProfileId,
    required String accountId,
    required String profileId,
    required String partnerType,
  }) async {
    await _call('assignTailorInboundPickupPartner', {
      'orderId': orderId,
      'tailorAccountId': tailorAccountId,
      'tailorProfileId': tailorProfileId,
      'accountId': accountId,
      'profileId': profileId,
      'partnerType': partnerType,
    });
  }

  static Future<List<Map<String, dynamic>>>
  getTailorOutboundHandoverCandidates({
    required String orderId,
    required String accountId,
    required String profileId,
  }) async {
    final result = await _call('getTailorOutboundHandoverCandidates', {
      'orderId': orderId,
      'accountId': accountId,
      'profileId': profileId,
    });
    final rawCandidates = result['candidates'];
    if (rawCandidates is! List) return const [];
    return rawCandidates
        .whereType<Map>()
        .map((candidate) => Map<String, dynamic>.from(candidate))
        .toList(growable: false);
  }

  static Future<void> assignTailorOutboundHandoverPartner({
    required String orderId,
    required String tailorAccountId,
    required String tailorProfileId,
    required String accountId,
    required String profileId,
    required String partnerType,
  }) async {
    await _call('assignTailorOutboundHandoverPartner', {
      'orderId': orderId,
      'tailorAccountId': tailorAccountId,
      'tailorProfileId': tailorProfileId,
      'accountId': accountId,
      'profileId': profileId,
      'partnerType': partnerType,
    });
  }

  static Future<List<Map<String, dynamic>>> getAdminOutboundHandoverCandidates(
    String orderId,
  ) async {
    final result = await _call('getAdminOutboundHandoverCandidates', {
      'orderId': orderId,
    });
    final rawCandidates = result['candidates'];
    if (rawCandidates is! List) return const [];
    return rawCandidates
        .whereType<Map>()
        .map((candidate) => Map<String, dynamic>.from(candidate))
        .toList(growable: false);
  }

  static Future<void> assignAdminOutboundHandoverPartner({
    required String orderId,
    required String accountId,
    required String profileId,
    required String partnerType,
  }) async {
    await _call('assignAdminOutboundHandoverPartner', {
      'orderId': orderId,
      'accountId': accountId,
      'profileId': profileId,
      'partnerType': partnerType,
    });
  }

  static Future<String> getCustomerDeliveryPin(String orderId) async {
    final result = await _call('getCustomerOrderDeliveryPin', {
      'orderId': orderId,
    });
    return result['pin']?.toString() ?? '';
  }

  static Future<Map<String, dynamic>> payBalance({
    required String orderId,
    required OnlinePaymentMethod method,
  }) => _call('completeSandboxOrderBalance', {
    'orderId': orderId,
    'paymentMethod': method.name,
  });

  static Future<void> advanceTailorOrder({
    required String orderId,
    required String accountId,
    required String profileId,
    required String nextStatus,
  }) async {
    await _call('advanceProductionTailorOrderStatus', {
      'orderId': orderId,
      'accountId': accountId,
      'profileId': profileId,
      'nextStatus': nextStatus,
    });
  }

  static Future<Map<String, dynamic>> saveTailorFabricRequirementReview({
    required String orderId,
    required String accountId,
    required String profileId,
    required double actualRequiredMeters,
    required String note,
  }) => _call('saveTailorFabricRequirementReview', {
    'orderId': orderId,
    'accountId': accountId,
    'profileId': profileId,
    'actualRequiredMeters': actualRequiredMeters,
    'note': note,
  });

  static Future<void> confirmCustomerFabricShortfall(String orderId) async {
    await _call('confirmCustomerFabricShortfall', {'orderId': orderId});
  }

  static Future<void> saveTailorGarmentRecord({
    required String orderId,
    required String accountId,
    required String profileId,
    required String fiberComposition,
    required String compositionSource,
    required String careInstructions,
    required String constructionNotes,
    required String qualityCheckNotes,
  }) async {
    await _call('saveTailorGarmentRecord', {
      'orderId': orderId,
      'accountId': accountId,
      'profileId': profileId,
      'fiberComposition': fiberComposition,
      'compositionSource': compositionSource,
      'careInstructions': careInstructions,
      'constructionNotes': constructionNotes,
      'qualityCheckNotes': qualityCheckNotes,
    });
  }

  static Future<void> confirmTailorProductionTask({
    required String orderId,
    required String accountId,
    required String profileId,
    required String action,
    required String orderTrackingId,
  }) async {
    await _call('confirmTailorProductionTask', {
      'orderId': orderId,
      'accountId': accountId,
      'profileId': profileId,
      'action': action,
      'orderTrackingId': orderTrackingId,
    });
  }

  static Future<void> saveTailorMeasurementPlan({
    required String orderId,
    required String accountId,
    required String profileId,
    required String method,
    String? measurementPartnerAccountId,
    String? measurementPartnerProfileId,
    DateTime? appointmentAt,
    String? notes,
  }) async {
    await _call('saveTailorMeasurementPlan', {
      'orderId': orderId,
      'accountId': accountId,
      'profileId': profileId,
      'method': method,
      if (measurementPartnerAccountId?.trim().isNotEmpty == true)
        'measurementPartnerAccountId': measurementPartnerAccountId!.trim(),
      if (measurementPartnerProfileId?.trim().isNotEmpty == true)
        'measurementPartnerProfileId': measurementPartnerProfileId!.trim(),
      if (appointmentAt != null)
        'appointmentAt': appointmentAt.toUtc().toIso8601String(),
      if (notes?.trim().isNotEmpty == true) 'notes': notes!.trim(),
    });
  }

  static Future<List<Map<String, dynamic>>> getMeasurementPartnerCandidates({
    required String orderId,
    required String accountId,
    required String profileId,
    required String method,
  }) async {
    final result = await _call('getMeasurementPartnerCandidates', {
      'orderId': orderId,
      'accountId': accountId,
      'profileId': profileId,
      'method': method,
    });
    final rawCandidates = result['candidates'];
    if (rawCandidates is! List) return const [];
    return rawCandidates
        .whereType<Map>()
        .map((candidate) => Map<String, dynamic>.from(candidate))
        .toList(growable: false);
  }

  static Future<void> setMeasurementPartnerAppointment({
    required String orderId,
    required String accountId,
    required String profileId,
    required DateTime appointmentAt,
    required bool isVideo,
  }) async {
    final payload = {
      'orderId': orderId,
      'accountId': accountId,
      'profileId': profileId,
      'appointmentAt': appointmentAt.toUtc().toIso8601String(),
    };
    await _call(
      isVideo
          ? 'scheduleVideoMeasurementAppointment'
          : 'setMeasurementPartnerAppointment',
      payload,
    );
  }

  static Future<void> submitMeasurementPartnerMeasurements({
    required String orderId,
    required String accountId,
    required String profileId,
    required Map<String, double> measurements,
    required String measurementUnit,
    required String note,
  }) async {
    await _call('submitMeasurementPartnerMeasurements', {
      'orderId': orderId,
      'accountId': accountId,
      'profileId': profileId,
      'measurements': measurements,
      'measurementUnit': measurementUnit,
      'note': note.trim(),
    });
  }

  static Future<List<Map<String, dynamic>>> getMeasurementPartnerAssignments({
    required String accountId,
    required String profileId,
  }) async {
    final result = await _call('getMeasurementPartnerAssignments', {
      'accountId': accountId,
      'profileId': profileId,
    });
    final rawAssignments = result['assignments'];
    if (rawAssignments is! List) return const [];
    return rawAssignments
        .whereType<Map>()
        .map((assignment) => Map<String, dynamic>.from(assignment))
        .toList(growable: false);
  }

  static Future<void> assignInboundPickupPartner({
    required String orderId,
    required String accountId,
    required String profileId,
    String partnerType = 'deliveryPartner',
  }) async {
    await _call('assignInboundPickupPartner', {
      'orderId': orderId,
      'accountId': accountId,
      'profileId': profileId,
      'partnerType': partnerType,
    });
  }

  static Future<void> advanceDeliveryOrder({
    required String orderId,
    required String accountId,
    required String profileId,
    required String action,
    String? orderTrackingId,
    String? deliveryPin,
    String? pickupPhotoPath,
  }) async {
    final trackingFields = orderTrackingId == null
        ? const <String, dynamic>{}
        : <String, dynamic>{'orderTrackingId': orderTrackingId};
    await _call('advanceProductionDeliveryOrder', {
      'orderId': orderId,
      'accountId': accountId,
      'profileId': profileId,
      'action': action,
      ...trackingFields,
      if (deliveryPin?.trim().isNotEmpty == true)
        'deliveryPin': deliveryPin!.trim(),
      if (pickupPhotoPath?.trim().isNotEmpty == true)
        'pickupPhotoPath': pickupPhotoPath!.trim(),
    });
  }

  static Future<void> submitFeedback({
    required String orderId,
    required int rating,
    required String feedback,
  }) async {
    await _call('submitOrderFeedback', {
      'orderId': orderId,
      'rating': rating,
      'feedback': feedback,
    });
  }

  static Future<void> reportWarrantyIssue({
    required String orderId,
    required String description,
  }) async {
    await _call('reportOrderWarrantyIssue', {
      'orderId': orderId,
      'description': description,
    });
  }

  static Future<void> waiveCancellationFee(String orderId) async {
    await _call('waiveOrderCancellationFee', {'orderId': orderId});
  }

  static Future<void> resolveWarrantyIssue({
    required String orderId,
    required String resolution,
  }) async {
    await _call('resolveOrderWarrantyIssue', {
      'orderId': orderId,
      'resolution': resolution,
    });
  }

  static Future<void> resolveTailorWarrantyIssue({
    required String orderId,
    required String accountId,
    required String profileId,
    required String resolution,
  }) async {
    await _call('resolveTailorWarrantyIssue', {
      'orderId': orderId,
      'accountId': accountId,
      'profileId': profileId,
      'resolution': resolution,
    });
  }

  static Future<void> savePolicy(OrderLifecyclePolicy policy) async {
    await FirebaseFirestore.instance
        .collection('config')
        .doc('order_lifecycle')
        .set({
          'cancellationFeePercent': policy.cancellationFeePercent,
          'warrantyDays': policy.warrantyDays,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }
}
