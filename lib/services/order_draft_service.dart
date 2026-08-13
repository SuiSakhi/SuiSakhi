import 'package:cloud_firestore/cloud_firestore.dart';

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
  required String designSource,
  required int advancePercent,
  required String? occasionCategory,
  required bool kidsFlow,
}) async {
    final ref = draftId == null || draftId.trim().isEmpty
        ? _db.collection('order_drafts').doc()
        : _db.collection('order_drafts').doc(draftId.trim());

    await ref.set(
      {
        'draftId': ref.id,
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
        'designSource': designSource,
        'advancePercent': advancePercent,
        'status': 'draft',
        'updatedAt': FieldValue.serverTimestamp(),
        if (draftId == null || draftId.trim().isEmpty)
          'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    return ref.id;
  }
}
