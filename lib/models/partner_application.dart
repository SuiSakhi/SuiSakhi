import 'package:cloud_firestore/cloud_firestore.dart';

enum PartnerType {
  tailor,
  boutique,
  designer,
  fabricSupplier,
  printing,
  embroidery,
  rental,
  accessories,
  brand,
  deliveryPartner,
  doorstepServices,
  other,
}

enum PartnerApplicationStatus {
  draft,
  submitted,
  underReview,
  changesRequested,
  approved,
  rejected,
  suspended,
  inactive,
}

class PartnerApplication {
  const PartnerApplication({
    required this.id,
    required this.accountId,
    required this.customerProfileId,
    required this.createdByUid,
    required this.partnerType,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.businessName,
    this.contactName,
    this.mobileE164,
    this.email,
    this.submittedAt,
    this.reviewedAt,
    this.reviewedByUid,
    this.reviewNotes,
    this.rejectionReason,
    this.approvedPartnerProfileId,
  });

  final String id;

  /// Generated SuiSakhi account that owns this application.
  final String accountId;

  /// Default Customer profile that submitted the application.
  final String customerProfileId;

  /// Firebase Authentication UID of the submitting account user.
  final String createdByUid;

  /// Requested partner category.
  final PartnerType partnerType;

  /// Current application lifecycle state.
  final PartnerApplicationStatus status;

  /// Optional shop, business, boutique or professional name.
  final String? businessName;

  /// Primary contact person for the application.
  final String? contactName;

  /// Normalized authenticated or verified mobile number.
  final String? mobileE164;

  /// Optional business or communication email.
  final String? email;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;

  /// Admin UID that last reviewed the application.
  final String? reviewedByUid;

  /// Internal Admin review notes.
  final String? reviewNotes;

  /// Customer-visible or internal rejection reason.
  final String? rejectionReason;

  /// Populated only after approval and partner-profile creation.
  final String? approvedPartnerProfileId;

  bool get isDraft => status == PartnerApplicationStatus.draft;

  bool get isSubmitted =>
      status == PartnerApplicationStatus.submitted ||
      status == PartnerApplicationStatus.underReview;

  bool get isApproved => status == PartnerApplicationStatus.approved;

  bool get canEdit =>
      status == PartnerApplicationStatus.draft ||
      status == PartnerApplicationStatus.changesRequested;

  bool get canSubmit =>
      status == PartnerApplicationStatus.draft ||
      status == PartnerApplicationStatus.changesRequested;

  Map<String, dynamic> toMap() {
    return {
      'applicationId': id,
      'accountId': accountId,
      'customerProfileId': customerProfileId,
      'createdByUid': createdByUid,
      'partnerType': partnerType.name,
      'status': status.name,
      'businessName': businessName,
      'contactName': contactName,
      'mobileE164': mobileE164,
      'email': email,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'submittedAt': submittedAt == null
          ? null
          : Timestamp.fromDate(submittedAt!),
      'reviewedAt': reviewedAt == null ? null : Timestamp.fromDate(reviewedAt!),
      'reviewedByUid': reviewedByUid,
      'reviewNotes': reviewNotes,
      'rejectionReason': rejectionReason,
      'approvedPartnerProfileId': approvedPartnerProfileId,
    };
  }

  factory PartnerApplication.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? {};

    return PartnerApplication(
      id: document.id,
      accountId: (data['accountId'] ?? '').toString(),
      customerProfileId: (data['customerProfileId'] ?? '').toString(),
      createdByUid: (data['createdByUid'] ?? '').toString(),
      partnerType: _partnerTypeFromValue(data['partnerType']),
      status: _statusFromValue(data['status']),
      businessName: data['businessName']?.toString(),
      contactName: data['contactName']?.toString(),
      mobileE164: data['mobileE164']?.toString(),
      email: data['email']?.toString(),
      createdAt: _dateFromValue(data['createdAt']) ?? DateTime.now(),
      updatedAt: _dateFromValue(data['updatedAt']) ?? DateTime.now(),
      submittedAt: _dateFromValue(data['submittedAt']),
      reviewedAt: _dateFromValue(data['reviewedAt']),
      reviewedByUid: data['reviewedByUid']?.toString(),
      reviewNotes: data['reviewNotes']?.toString(),
      rejectionReason: data['rejectionReason']?.toString(),
      approvedPartnerProfileId: data['approvedPartnerProfileId']?.toString(),
    );
  }

  static PartnerType _partnerTypeFromValue(dynamic value) {
    final raw = value?.toString() ?? '';

    for (final type in PartnerType.values) {
      if (type.name == raw) {
        return type;
      }
    }

    return PartnerType.other;
  }

  static PartnerApplicationStatus _statusFromValue(dynamic value) {
    final raw = value?.toString() ?? '';

    for (final status in PartnerApplicationStatus.values) {
      if (status.name == raw) {
        return status;
      }
    }

    return PartnerApplicationStatus.draft;
  }

  static DateTime? _dateFromValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }
}
