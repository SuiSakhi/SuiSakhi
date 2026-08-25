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

enum PartnerKycStatus {
  notStarted,
  pendingDocuments,
  underVerification,
  verified,
  failed,
  expired,
}

enum PartnerOnboardingSection {
  basicDetails,
  workshopDetails,
  servicesAndSpecialization,
  capacityAndAvailability,
  measurementPreferences,
  qualityAndRework,
  expectedRates,
  documentsAndDeclaration,
  commercialTerms,
}

enum PartnerOnboardingSectionStatus {
  notStarted,
  inProgress,
  completed,
  verified,
  changesRequired,
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
    this.rejectedByUid,
    this.rejectedAt,
    this.kycStatus = PartnerKycStatus.notStarted,
    this.kycVerifiedByUid,
    this.kycVerifiedAt,
    this.kycUpdatedAt,
    this.kycFailureReason,
    this.onboardingSections = const {},
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

  /// Customer-visible rejection reason for a final rejection.
  final String? rejectionReason;
  final String? rejectedByUid;
  final DateTime? rejectedAt;

  /// Current KYC and verification lifecycle state.
  final PartnerKycStatus kycStatus;

  /// Admin UID that successfully verified KYC.
  final String? kycVerifiedByUid;

  /// Date and time when KYC was successfully verified.
  final DateTime? kycVerifiedAt;

  /// Date and time when the KYC lifecycle was last updated.
  final DateTime? kycUpdatedAt;

  /// Customer-visible reason when KYC verification fails.
  final String? kycFailureReason;

  /// Status of every Partner onboarding section.
  ///
  /// Existing applications may not yet contain this map. The effective
  /// section-status helpers provide safe defaults for those applications.
  final Map<PartnerOnboardingSection, PartnerOnboardingSectionStatus>
  onboardingSections;

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

  PartnerOnboardingSectionStatus onboardingStatusFor(
    PartnerOnboardingSection section,
  ) {
    final storedStatus = onboardingSections[section];

    if (storedStatus != null) {
      return storedStatus;
    }

    if (section == PartnerOnboardingSection.basicDetails) {
      return PartnerOnboardingSectionStatus.completed;
    }

    return PartnerOnboardingSectionStatus.notStarted;
  }

  int get completedOnboardingSectionCount {
    return PartnerOnboardingSection.values.where((section) {
      final sectionStatus = onboardingStatusFor(section);

      return sectionStatus == PartnerOnboardingSectionStatus.completed ||
          sectionStatus == PartnerOnboardingSectionStatus.verified;
    }).length;
  }

  int get verifiedOnboardingSectionCount {
    return PartnerOnboardingSection.values.where((section) {
      return onboardingStatusFor(section) ==
          PartnerOnboardingSectionStatus.verified;
    }).length;
  }

  int get totalOnboardingSectionCount {
    return PartnerOnboardingSection.values.length;
  }

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
      'rejectedByUid': rejectedByUid,
      'rejectedAt': rejectedAt == null ? null : Timestamp.fromDate(rejectedAt!),
      //KYC
      'kycStatus': kycStatus.name,
      'kycVerifiedByUid': kycVerifiedByUid,
      'kycVerifiedAt': kycVerifiedAt == null
          ? null
          : Timestamp.fromDate(kycVerifiedAt!),
      'kycUpdatedAt': kycUpdatedAt == null
          ? null
          : Timestamp.fromDate(kycUpdatedAt!),
      'kycFailureReason': kycFailureReason,
      'onboardingSections': {
        for (final entry in onboardingSections.entries)
          entry.key.name: entry.value.name,
      },
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
      rejectedByUid: data['rejectedByUid']?.toString(),
      rejectedAt: _dateFromValue(data['rejectedAt']),
      kycStatus: _kycStatusFromValue(data['kycStatus']),
      kycVerifiedByUid: data['kycVerifiedByUid']?.toString(),
      kycVerifiedAt: _dateFromValue(data['kycVerifiedAt']),
      kycUpdatedAt: _dateFromValue(data['kycUpdatedAt']),
      kycFailureReason: data['kycFailureReason']?.toString(),
      onboardingSections: _onboardingSectionsFromValue(
        data['onboardingSections'],
      ),
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

  static PartnerKycStatus _kycStatusFromValue(dynamic value) {
    final raw = value?.toString() ?? '';

    for (final status in PartnerKycStatus.values) {
      if (status.name == raw) {
        return status;
      }
    }

    return PartnerKycStatus.notStarted;
  }

  static Map<PartnerOnboardingSection, PartnerOnboardingSectionStatus>
  _onboardingSectionsFromValue(dynamic value) {
    if (value is! Map) {
      return const {};
    }

    final result = <PartnerOnboardingSection, PartnerOnboardingSectionStatus>{};

    for (final entry in value.entries) {
      final sectionName = entry.key.toString();
      final statusName = entry.value?.toString() ?? '';

      PartnerOnboardingSection? matchedSection;
      PartnerOnboardingSectionStatus? matchedStatus;

      for (final section in PartnerOnboardingSection.values) {
        if (section.name == sectionName) {
          matchedSection = section;
          break;
        }
      }

      for (final status in PartnerOnboardingSectionStatus.values) {
        if (status.name == statusName) {
          matchedStatus = status;
          break;
        }
      }

      if (matchedSection != null && matchedStatus != null) {
        result[matchedSection] = matchedStatus;
      }
    }

    return result;
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
