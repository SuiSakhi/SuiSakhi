import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/prd_catalog.dart';

/// Creates customer-facing orders in Firestore (`orders` collection).
class OrderService {
  OrderService._();
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;

  /// Allocate the support-friendly reference after the order exists. The
  /// customer order document remains valid if the optional callable is not
  /// deployed yet; the UI can still identify it by its Firestore ID.
  static Future<void> _ensureOrderTrackingId(String orderId) async {
    try {
      await FirebaseFunctions.instance
          .httpsCallable('ensureCustomerOrderTrackingId')
          .call(<String, dynamic>{'orderId': orderId});
    } catch (_) {
      // Keep order placement successful if reference allocation is temporarily
      // unavailable. Helpdesk can still locate the order by its document ID.
    }
  }

  /// Snapshots the common Customer account/profile onto each newly created order.
  /// Keep this optional for older or temporarily incomplete account records; the
  /// Firebase UID remains the existing order ownership key during migration.
  static Future<Map<String, String>> _customerOwnershipFields(
    String uid,
  ) async {
    try {
      final userDoc = await _db.collection('users').doc(uid).get();
      final userData = userDoc.data();
      final accountId = userData?['accountId']?.toString().trim();
      final profileId = userData?['defaultProfileId']?.toString().trim();
      if (accountId == null ||
          accountId.isEmpty ||
          profileId == null ||
          profileId.isEmpty) {
        return const {};
      }

      final profileDoc = await _db
          .collection('accounts')
          .doc(accountId)
          .collection('profiles')
          .doc(profileId)
          .get();
      final profileData = profileDoc.data();
      if (!profileDoc.exists ||
          profileData?['role'] != 'customer' ||
          profileData?['status'] != 'active') {
        return const {};
      }

      return {'customerAccountId': accountId, 'customerProfileId': profileId};
    } catch (_) {
      // Preserve existing order placement for legacy account records.
      return const {};
    }
  }

  static Future<String?> createCoreTailoringOrder({
    required String dressType,
    required double price,
    required String fit,
    required Map<String, String> measurements,
    required String notes,
    String? clientName,
    String? personId,
    String? personName,
    String? relationship,
    String? occasionCategory,
    bool kidsFlow = false,
    String? fabricDescription,
    String? designTemplateId,
    String? designTemplateTitle,
    String? designImageUrl,
    String? catalogueVersionId,
    String? catalogueCommercialType,
    double? approvedDesignCharge,
    double? stitchingBaseCharge,
    Map<String, dynamic>? fabricPurchaseEstimate,
    Map<String, dynamic>? customerFabricAssets,
    String? orderId,
    String? designSource,
    String? fabricChoice,
    String? accentColorHex,

    /// Shown to delivery partners (doorstep handover).
    String? deliveryAddress,

    /// Used to match the order against a Tailor's declared service area.
    String? deliveryPincode,
    String? deliveryCityCode,
    String? deliveryCityName,
    String? deliveryStateCode,
    String? deliveryStateName,
  }) async {
    final uid = _uid;
    if (uid == null) return null;

    final ownershipFields = await _customerOwnershipFields(uid);

    const pct = 50;

    final ref = orderId?.trim().isNotEmpty == true
        ? _db.collection('orders').doc(orderId!.trim())
        : _db.collection('orders').doc();
    await ref.set({
      'customerId': uid,
      ...ownershipFields,
      'dressType': dressType,
      'status': 'pending',
      'orderDate': FieldValue.serverTimestamp(),
      'price': price,
      'paymentStatus': 'unpaid',
      'advancePercent': pct,
      // The advance becomes payable only after a Tailor accepts.
      'advanceAmount': 0,
      'balanceAmount': price,
      'assignmentVersion': 'v1',
      'assignmentStatus': 'searching',
      'assignmentRequestedAt': FieldValue.serverTimestamp(),
      'orderModuleType': OrderModuleType.coreTailoring.name,
      'occasionCategory': occasionCategory,
      'kidsFlow': kidsFlow,
      'fit': fit,
      'measurements': measurements,
      'notes': notes,
      if (personId?.trim().isNotEmpty == true) 'personId': personId!.trim(),
      if (personName?.trim().isNotEmpty == true)
        'personName': personName!.trim(),
      if (relationship?.trim().isNotEmpty == true)
        'relationship': relationship!.trim(),
      if (clientName != null && clientName.isNotEmpty) 'clientName': clientName,
      if (fabricDescription != null && fabricDescription.isNotEmpty)
        'fabricDescription': fabricDescription,
      if (designTemplateId != null && designTemplateId.isNotEmpty)
        'designTemplateId': designTemplateId,
      if (designTemplateTitle != null && designTemplateTitle.isNotEmpty)
        'designTemplateTitle': designTemplateTitle,
      if (designImageUrl != null && designImageUrl.isNotEmpty)
        'designImageUrl': designImageUrl,
      if (catalogueVersionId?.trim().isNotEmpty == true)
        'catalogueVersionId': catalogueVersionId!.trim(),
      if (catalogueCommercialType?.trim().isNotEmpty == true)
        'catalogueCommercialType': catalogueCommercialType!.trim(),
      'approvedDesignCharge': ?approvedDesignCharge,
      'stitchingBaseCharge': ?stitchingBaseCharge,
      'fabricPurchaseEstimate': ?fabricPurchaseEstimate,
      'customerFabricAssets': ?customerFabricAssets,
      if (catalogueVersionId?.trim().isNotEmpty == true)
        'catalogueDesignSnapshot': {
          'designId': designTemplateId,
          'catalogueVersionId': catalogueVersionId!.trim(),
          'commercialType': catalogueCommercialType,
          'approvedDesignCharge': approvedDesignCharge ?? 0,
          'monochromeReferenceImageUrl': designImageUrl,
          'cataloguePriceVersion': 'version:${catalogueVersionId.trim()}',
        },
      if (designSource?.trim().isNotEmpty == true)
        'designSource': designSource!.trim(),
      if (fabricChoice != null && fabricChoice.isNotEmpty)
        'fabricChoice': fabricChoice,
      if (accentColorHex != null && accentColorHex.isNotEmpty)
        'accentColorHex': accentColorHex,
      if (deliveryAddress != null && deliveryAddress.trim().isNotEmpty)
        'deliveryAddress': deliveryAddress.trim(),
      if (deliveryPincode != null && deliveryPincode.trim().isNotEmpty)
        'deliveryPincode': deliveryPincode.trim(),
      if ((deliveryCityCode?.trim().isNotEmpty ?? false) ||
          (deliveryCityName?.trim().isNotEmpty ?? false) ||
          (deliveryStateCode?.trim().isNotEmpty ?? false) ||
          (deliveryStateName?.trim().isNotEmpty ?? false))
        'deliveryLocation': {
          'countryCode': 'IN',
          if (deliveryCityCode?.trim().isNotEmpty == true)
            'cityCode': deliveryCityCode!.trim(),
          if (deliveryCityName?.trim().isNotEmpty == true)
            'cityName': deliveryCityName!.trim(),
          if (deliveryStateCode?.trim().isNotEmpty == true)
            'stateCode': deliveryStateCode!.trim(),
          if (deliveryStateName?.trim().isNotEmpty == true)
            'stateName': deliveryStateName!.trim(),
          if (deliveryPincode?.trim().isNotEmpty == true)
            'pincode': deliveryPincode!.trim(),
        },
    });
    await _ensureOrderTrackingId(ref.id);
    return ref.id;
  }

  static Future<String?> createQuickFixOrder({
    required List<String> serviceIds,
    required double estimatedTotal,
    required String notes,
    required String slotLabel,
    required String addressLine,
    String? addressId,
    String? landmark,
    String? pincode,
    DateTime? scheduledAt,
    bool express = false,
  }) async {
    final uid = _uid;
    if (uid == null) return null;

    final ownershipFields = await _customerOwnershipFields(uid);

    final titles = serviceIds
        .map((id) => QuickFixService.byId(id)?.title ?? id)
        .join(', ');
    final requiresQuote = serviceIds.any(
      (id) => QuickFixService.byId(id)?.requiresPartnerQuote ?? false,
    );
    final ref = await _db.collection('orders').add({
      'customerId': uid,
      ...ownershipFields,
      'dressType': 'Quick Fix — $titles',
      'tailorName': '',
      'status': 'pending',
      'orderDate': FieldValue.serverTimestamp(),
      'price': estimatedTotal,
      'estimatedPrice': estimatedTotal,
      'priceEstimateOnly': true,
      'paymentStatus': 'unpaid',
      'advancePercent': 0,
      'advanceAmount': 0,
      'balanceAmount': estimatedTotal,
      'paymentTiming': 'afterServiceCompletion',
      'orderModuleType': OrderModuleType.quickFix.name,
      'quickFixServiceIds': serviceIds,
      'notes': notes,
      'pickupSlot': slotLabel,
      if (scheduledAt != null)
        'quickCareScheduledAt': Timestamp.fromDate(scheduledAt),
      'quickCareWorkflowStatus': 'requestSubmitted',
      'quickCareAssignmentStatus': 'searching',
      'quickCareQuoteStatus': requiresQuote
          ? 'partnerQuoteRequired'
          : 'partnerEstimateConfirmationRequired',
      'deliveryAddress': addressLine.trim(),
      if (addressId?.trim().isNotEmpty == true)
        'deliveryAddressId': addressId!.trim(),
      if (landmark?.trim().isNotEmpty == true)
        'serviceVisitLandmark': landmark!.trim(),
      if (pincode != null && pincode.trim().isNotEmpty)
        'deliveryPincode': pincode.trim(),
      if (pincode?.trim().isNotEmpty == true)
        'deliveryLocation': {'countryCode': 'IN', 'pincode': pincode!.trim()},
      'expressQuickFix': express,
    });
    await _ensureOrderTrackingId(ref.id);
    return ref.id;
  }

  static Future<String?> createBulkOrderRequest({
    required BulkOrderKind kind,
    required String eventType,
    required int dressCount,
    required String categoryLabel,
    required DateTime eventDate,
    required String location,
    required String consultationPreference,
    String? notes,
  }) async {
    final uid = _uid;
    if (uid == null) return null;

    final ownershipFields = await _customerOwnershipFields(uid);

    final ref = await _db.collection('orders').add({
      'customerId': uid,
      ...ownershipFields,
      'dressType': 'Bulk — ${kind.displayName}',
      'tailorName': '',
      'status': 'pending',
      'orderDate': FieldValue.serverTimestamp(),
      'price': 0,
      'paymentStatus': 'unpaid',
      'advancePercent': 50,
      'advanceAmount': 0,
      'balanceAmount': 0,
      'orderModuleType': OrderModuleType.bulkOrder.name,
      'bulkKind': kind.name,
      'eventType': eventType,
      'dressCount': dressCount,
      'bulkCategory': categoryLabel,
      'eventDate': Timestamp.fromDate(eventDate),
      'bulkLocation': location,
      'consultationPreference': consultationPreference,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    await _ensureOrderTrackingId(ref.id);
    return ref.id;
  }

  /// Marketplace interest — tracked as order stub for admin follow-up (PRD phase-1 manual).
  static Future<String?> createMarketplaceInterest({
    required String shopCategoryId,
    required String title,
    String? notes,
  }) async {
    final uid = _uid;
    if (uid == null) return null;

    final ownershipFields = await _customerOwnershipFields(uid);

    final ref = await _db.collection('orders').add({
      'customerId': uid,
      ...ownershipFields,
      'dressType': 'Shop — $title',
      'tailorName': '',
      'status': 'pending',
      'orderDate': FieldValue.serverTimestamp(),
      'price': 0,
      'paymentStatus': 'unpaid',
      'advancePercent': 50,
      'advanceAmount': 0,
      'balanceAmount': 0,
      'orderModuleType': OrderModuleType.marketplace.name,
      'marketplaceCategoryId': shopCategoryId,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    await _ensureOrderTrackingId(ref.id);
    return ref.id;
  }
}
