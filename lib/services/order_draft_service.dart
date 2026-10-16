import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'customer_fabric_asset_service.dart';

class OrderDraftService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<String> saveDraft({
    String? draftId,
    required String accountId,
    required String customerProfileId,
    required String personId,
    required String personName,
    required String relationship,
    required String? measurementDraftId,
    required String? deliveryAddressId,
    required String deliveryAddress,
    required String dressType,
    required String fitPreference,
    required Map<String, String> measurements,
    required String notes,
    required String? fabricChoice,
    required String? designTemplateId,
    required String? designTemplateTitle,
    required String? designImageUrl,
    String? catalogueVersionId,
    String? catalogueCommercialType,
    double? approvedDesignCharge,
    required String designSource,
    required int advancePercent,
    required String? occasionCategory,
    required bool kidsFlow,
    Map<String, dynamic>? fabricPurchaseEstimate,
    CustomerFabricPreviewSelection? fabricPreviewSelection,
    Map<String, dynamic>? customerFabricAssets,
  }) async {
    final customerUid = FirebaseAuth.instance.currentUser?.uid;
    if (customerUid == null) throw StateError('Sign in to save an order draft.');
    final ref = draftId == null || draftId.trim().isEmpty
        ? _db.collection('order_drafts').doc()
        : _db.collection('order_drafts').doc(draftId.trim());
    final uploadedFabricAssets = fabricPreviewSelection == null
        ? null
        : await CustomerFabricAssetService.uploadSelection(
            customerUid: customerUid,
            scopeType: 'drafts',
            scopeId: ref.id,
            selection: fabricPreviewSelection,
          );
    final fabricAssets = uploadedFabricAssets ?? customerFabricAssets;

    try {
      await ref.set({
      'draftId': ref.id,
      'customerUid': customerUid,
      'accountId': accountId,
      'customerProfileId': customerProfileId,
      'personId': personId,
      'personName': personName,
      'relationship': relationship,
      'measurementDraftId': measurementDraftId,
      'deliveryAddressId': deliveryAddressId,
      'deliveryAddress': deliveryAddress,
      'dressType': dressType,
      'fitPreference': fitPreference,
      'occasionCategory': occasionCategory,
      'kidsFlow': kidsFlow,
      'measurements': measurements,
      'notes': notes,
      'fabricChoice': fabricChoice,
      'designTemplateId': designTemplateId,
      'designTemplateTitle': designTemplateTitle,
      'designImageUrl': designImageUrl,
      'fabricPurchaseEstimate': ?fabricPurchaseEstimate,
      'customerFabricAssets': ?fabricAssets,
      if (catalogueVersionId?.trim().isNotEmpty == true)
        'catalogueVersionId': catalogueVersionId!.trim(),
      if (catalogueCommercialType?.trim().isNotEmpty == true)
        'catalogueCommercialType': catalogueCommercialType!.trim(),
      'approvedDesignCharge': ?approvedDesignCharge,
      'designSource': designSource,
      'advancePercent': advancePercent,
      'status': 'draft',
      'updatedAt': FieldValue.serverTimestamp(),
      if (draftId == null || draftId.trim().isEmpty)
        'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    } catch (_) {
      await CustomerFabricAssetService.deleteAssets(uploadedFabricAssets);
      rethrow;
    }

    return ref.id;
  }
}
