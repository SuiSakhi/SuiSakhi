import 'package:cloud_firestore/cloud_firestore.dart';

class MeasurementDraftService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<String> createDraft({
    required String accountId,
    required String customerProfileId,
    required String personId,
    required String personName,
    required String relationship,
    required String source,
  }) async {
    final ref = _db.collection('measurements').doc();

    await ref.set({
      'draftId': ref.id,
      'accountId': accountId,
      'customerProfileId': customerProfileId,
      'personId': personId,
      'personName': personName,
      'relationship': relationship,
      'source': source,
      'status': 'draft',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return ref.id;
  }
}
