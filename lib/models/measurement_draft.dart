import 'package:cloud_firestore/cloud_firestore.dart';

class MeasurementDraft {
  final String draftId;
  final String accountId;
  final String customerProfileId;

  final String personId;
  final String personName;
  final String relationship;

  final String source;
  final String status;

  final DateTime createdAt;
  final DateTime updatedAt;

  MeasurementDraft({
    required this.draftId,
    required this.accountId,
    required this.customerProfileId,
    required this.personId,
    required this.personName,
    required this.relationship,
    required this.source,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'draftId': draftId,
      'accountId': accountId,
      'customerProfileId': customerProfileId,

      'personId': personId,
      'personName': personName,
      'relationship': relationship,

      'source': source,
      'status': status,

      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
