import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/prd_catalog.dart';

/// Creates customer-facing orders in Firestore (`orders` collection).
class OrderService {
  OrderService._();
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;

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
    String? fabricChoice,
    String? accentColorHex,
    /// Shown to delivery partners (doorstep handover).
    String? deliveryAddress,
    /// PRD Step 11 — advance 30–50%.
    int advancePercent = 40,
  }) async {
    final uid = _uid;
    if (uid == null) return null;

    final pct = advancePercent.clamp(30, 50);
    final advance = price * pct / 100.0;
    final balance = (price - advance).clamp(0.0, double.infinity);

    final ref = await _db.collection('orders').add({
      'customerId': uid,
      'dressType': dressType,
      'tailorName': '',
      'status': 'pending',
      'orderDate': FieldValue.serverTimestamp(),
      'price': price,
      'paymentStatus': 'pending_payment',
      'advancePercent': pct,
      'advanceAmount': advance,
      'balanceAmount': balance,
      'orderModuleType': OrderModuleType.coreTailoring.name,
      'occasionCategory': occasionCategory,
      'kidsFlow': kidsFlow,
      'fit': fit,
      'measurements': measurements,
      'notes': notes,
      if (personId?.trim().isNotEmpty == true)
        'personId': personId!.trim(),
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
      if (fabricChoice != null && fabricChoice.isNotEmpty)
        'fabricChoice': fabricChoice,
      if (accentColorHex != null && accentColorHex.isNotEmpty)
        'accentColorHex': accentColorHex,
      if (deliveryAddress != null && deliveryAddress.trim().isNotEmpty)
        'deliveryAddress': deliveryAddress.trim(),
    });
    return ref.id;
  }

  static Future<String?> createQuickFixOrder({
    required List<String> serviceIds,
    required double estimatedTotal,
    required String notes,
    required String slotLabel,
    required String addressLine,
    String? landmark,
    bool express = false,
  }) async {
    final uid = _uid;
    if (uid == null) return null;

    final titles = serviceIds
        .map((id) => QuickFixService.byId(id)?.title ?? id)
        .join(', ');
    final advPct = 50;
    final advance = estimatedTotal * advPct / 100.0;
    final balance = (estimatedTotal - advance).clamp(0.0, double.infinity);
    final ref = await _db.collection('orders').add({
      'customerId': uid,
      'dressType': 'Quick Fix — $titles',
      'tailorName': '',
      'status': 'pending',
      'orderDate': FieldValue.serverTimestamp(),
      'price': estimatedTotal,
      'paymentStatus': 'unpaid',
      'advancePercent': advPct,
      'advanceAmount': advance,
      'balanceAmount': balance,
      'orderModuleType': OrderModuleType.quickFix.name,
      'quickFixServiceIds': serviceIds,
      'notes': notes,
      'pickupSlot': slotLabel,
      'deliveryAddress': [
        addressLine,
        if (landmark != null && landmark.isNotEmpty) 'Landmark: $landmark',
      ].join('\n'),
      'expressQuickFix': express,
    });
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

    final ref = await _db.collection('orders').add({
      'customerId': uid,
      'dressType': 'Bulk — ${kind.displayName}',
      'tailorName': '',
      'status': 'pending',
      'orderDate': FieldValue.serverTimestamp(),
      'price': 0,
      'paymentStatus': 'unpaid',
      'advancePercent': 40,
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

    final ref = await _db.collection('orders').add({
      'customerId': uid,
      'dressType': 'Shop — $title',
      'tailorName': '',
      'status': 'pending',
      'orderDate': FieldValue.serverTimestamp(),
      'price': 0,
      'paymentStatus': 'unpaid',
      'advancePercent': 40,
      'advanceAmount': 0,
      'balanceAmount': 0,
      'orderModuleType': OrderModuleType.marketplace.name,
      'marketplaceCategoryId': shopCategoryId,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return ref.id;
  }
}
