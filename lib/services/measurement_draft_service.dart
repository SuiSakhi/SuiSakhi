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
    double? profileHeightCm,
  }) async {
    final activeSnap = await _db
        .collection('measurements')
        .where('accountId', isEqualTo: accountId)
        .where('personId', isEqualTo: personId)
        .get();

    final batch = _db.batch();

    for (final doc in activeSnap.docs) {
      final data = doc.data();
      if ((data['customerProfileId'] ?? '').toString() != customerProfileId) {
        continue;
      }
      final status = (data['status'] ?? '').toString();

      final isActive =
          status == 'draft' ||
          status == 'ai_estimated' ||
          status == 'customer_review_required';

      if (isActive) {
        batch.set(doc.reference, {
          'status': 'superseded',
          'supersededAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }

    final ref = _db.collection('measurements').doc();

    batch.set(ref, {
      'schemaVersion': 1,
      'draftId': ref.id,
      'accountId': accountId,
      'customerProfileId': customerProfileId,
      'personId': personId,
      'personName': personName,
      'relationship': relationship,
      'source': source,
      'measurementType': 'ai_estimate',
      'measurementSchema': 'suisakhi_body_estimate_v1',
      'measurementUnit': 'cm',
      if (profileHeightCm != null &&
          profileHeightCm >= 100 &&
          profileHeightCm <= 220)
        'profileHeightCm': profileHeightCm,
      'status': 'draft',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    return ref.id;
  }

  static Future<double?> profileHeightForDraft(String draftId) async {
    try {
      final snapshot = await _db.collection('measurements').doc(draftId).get();
      final value = snapshot.data()?['profileHeightCm'];
      final height = value is num
          ? value.toDouble()
          : double.tryParse('$value');
      if (height == null || height < 100 || height > 220) return null;
      return height;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveAiEstimate({
    required String draftId,
    required Map<String, double> measurementValues,
    required List<String> validationIssues,
    required String confidenceLevel,
    double? calibrationHeightCm,
  }) async {
    await _db.collection('measurements').doc(draftId).set({
      'schemaVersion': 1,
      'measurementType': 'ai_estimate',
      'measurementSchema': 'suisakhi_body_estimate_v1',
      'measurementValues': measurementValues,
      'measurementUnit': 'cm',
      if (calibrationHeightCm != null)
        'calibration': {
          'heightSource': 'customer_profile',
          'heightCm': calibrationHeightCm,
          'weightUsed': false,
        },
      'validationIssues': validationIssues,
      'confidenceLevel': confidenceLevel,
      'requiresReview': true,
      'status': 'ai_estimated',
      'source': 'ai_camera',
      'aiEstimatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static List<String> validateAiMeasurements({
    required Map<String, double> values,
    double? profileHeightCm,
  }) {
    final issues = <String>[];

    double? value(String key) => values[key];

    final height = value('height');
    final chest = value('chest');
    final waist = value('waist');
    final hips = value('hips');
    final shoulder = value('shoulder');
    final armLength = value('armLength');
    final neck = value('neck');
    final thigh = value('thigh');

    if (height != null && (height < 100 || height > 220)) {
      issues.add('Height value appears unrealistic');
    }

    if (profileHeightCm != null &&
        height != null &&
        (height - profileHeightCm).abs() > 5) {
      issues.add('Height differs significantly from profile height');
    }

    if (chest != null && (chest < 50 || chest > 160)) {
      issues.add('Chest value appears unrealistic');
    }

    if (waist != null && (waist < 40 || waist > 160)) {
      issues.add('Waist value appears unrealistic');
    }

    if (hips != null && (hips < 50 || hips > 180)) {
      issues.add('Hip value appears unrealistic');
    }

    if (shoulder != null && (shoulder < 20 || shoulder > 70)) {
      issues.add('Shoulder value appears unrealistic');
    }

    if (armLength != null && (armLength < 30 || armLength > 90)) {
      issues.add('Arm length value appears unrealistic');
    }

    if (neck != null && (neck < 20 || neck > 60)) {
      issues.add('Neck value appears unrealistic');
    }

    if (thigh != null && (thigh < 25 || thigh > 90)) {
      issues.add('Thigh value appears unrealistic');
    }

    if (waist != null && hips != null && waist > hips + 30) {
      issues.add('Waist and hip values appear inconsistent');
    }

    if (waist != null && hips != null && waist > hips) {
      issues.add('Waist is greater than hip. Please review these values.');
    }

    if (waist != null && chest != null && waist > chest + 20) {
      issues.add('Waist appears too high compared to chest.');
    }

    if (hips != null && chest != null && hips < chest - 20) {
      issues.add('Hip appears too low compared to chest.');
    }

    if (neck != null && neck < 28) {
      issues.add('Neck may be underestimated. Please verify manually.');
    }

    return issues;
  }

  static String confidenceFromIssues(List<String> issues) {
    if (issues.length >= 3) {
      return 'low';
    }

    if (issues.isNotEmpty) {
      return 'medium';
    }

    // Passing plausibility checks is not evidence of accuracy. Until this
    // heuristic is validated against tailor tape measurements, keep its best
    // displayed confidence at medium.
    return 'medium';
  }
}
