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
    static Future<void> saveAiEstimate({
    required String draftId,
    required Map<String, double> measurementValues,
    required List<String> validationIssues,
    required String confidenceLevel,
  }) async {
    await _db.collection('measurements').doc(draftId).set({
      'measurementValues': measurementValues,
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

    return 'high';
  }
}
