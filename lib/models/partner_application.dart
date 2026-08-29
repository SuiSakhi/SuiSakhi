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

class PartnerWorkshopDetails {
  const PartnerWorkshopDetails({
    this.workshopTypeCode,
    this.addressLine1,
    this.addressLine2,
    this.locality,
    this.city,
    this.state,
    this.pincode,
    this.placeId,
    this.latitude,
    this.longitude,
    this.serviceAreaPincodes = const [],
    this.operatingDays = const [],
    this.openingTime,
    this.closingTime,
    this.teamSize,
    this.normalDailyCapacity,
    this.peakDailyCapacity,
    this.machineCodes = const [],
    this.pickupAvailable = false,
    this.deliveryAvailable = false,
    this.homeVisitAvailable = false,
    this.additionalNotes,
  });

  final String? workshopTypeCode;

  final String? addressLine1;
  final String? addressLine2;
  final String? locality;
  final String? city;
  final String? state;
  final String? pincode;

  /// Map provider place reference.
  final String? placeId;

  /// Coordinates are populated through map selection, not manual entry.
  final double? latitude;
  final double? longitude;

  final List<String> serviceAreaPincodes;
  final List<String> operatingDays;

  /// Stored using 24-hour HH:mm format.
  final String? openingTime;
  final String? closingTime;

  final int? teamSize;
  final int? normalDailyCapacity;
  final int? peakDailyCapacity;

  /// Metadata-driven machine and equipment codes.
  final List<String> machineCodes;

  final bool pickupAvailable;
  final bool deliveryAvailable;
  final bool homeVisitAvailable;

  final String? additionalNotes;

  bool get hasMinimumRequiredData {
    return workshopTypeCode?.trim().isNotEmpty == true &&
        addressLine1?.trim().isNotEmpty == true &&
        city?.trim().isNotEmpty == true &&
        state?.trim().isNotEmpty == true &&
        pincode?.trim().isNotEmpty == true &&
        teamSize != null &&
        teamSize! > 0 &&
        normalDailyCapacity != null &&
        normalDailyCapacity! > 0;
  }

  Map<String, dynamic> toMap() {
    return {
      'workshopTypeCode': workshopTypeCode,
      'addressLine1': addressLine1,
      'addressLine2': addressLine2,
      'locality': locality,
      'city': city,
      'state': state,
      'pincode': pincode,
      'placeId': placeId,
      'latitude': latitude,
      'longitude': longitude,
      'serviceAreaPincodes': serviceAreaPincodes,
      'operatingDays': operatingDays,
      'openingTime': openingTime,
      'closingTime': closingTime,
      'teamSize': teamSize,
      'normalDailyCapacity': normalDailyCapacity,
      'peakDailyCapacity': peakDailyCapacity,
      'machineCodes': machineCodes,
      'pickupAvailable': pickupAvailable,
      'deliveryAvailable': deliveryAvailable,
      'homeVisitAvailable': homeVisitAvailable,
      'additionalNotes': additionalNotes,
    };
  }

  factory PartnerWorkshopDetails.fromMap(Map<String, dynamic> data) {
    return PartnerWorkshopDetails(
      workshopTypeCode: data['workshopTypeCode']?.toString(),
      addressLine1: data['addressLine1']?.toString(),
      addressLine2: data['addressLine2']?.toString(),
      locality: data['locality']?.toString(),
      city: data['city']?.toString(),
      state: data['state']?.toString(),
      pincode: data['pincode']?.toString(),
      placeId: data['placeId']?.toString(),
      latitude: _doubleFromValue(data['latitude']),
      longitude: _doubleFromValue(data['longitude']),
      serviceAreaPincodes: _stringListFromValue(data['serviceAreaPincodes']),
      operatingDays: _stringListFromValue(data['operatingDays']),
      openingTime: data['openingTime']?.toString(),
      closingTime: data['closingTime']?.toString(),
      teamSize: _intFromValue(data['teamSize']),
      normalDailyCapacity: _intFromValue(data['normalDailyCapacity']),
      peakDailyCapacity: _intFromValue(data['peakDailyCapacity']),
      machineCodes: _stringListFromValue(data['machineCodes']),
      pickupAvailable: data['pickupAvailable'] == true,
      deliveryAvailable: data['deliveryAvailable'] == true,
      homeVisitAvailable: data['homeVisitAvailable'] == true,
      additionalNotes: data['additionalNotes']?.toString(),
    );
  }

  static List<String> _stringListFromValue(dynamic value) {
    if (value is! Iterable) {
      return const [];
    }

    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static int? _intFromValue(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '');
  }

  static double? _doubleFromValue(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '');
  }
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
    this.onboardingData = const {},
    this.onboardingUpdatedByUid,
    this.onboardingUpdatedAt,
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

  /// Metadata-driven content entered for common Partner sections
  /// and Partner-category extensions.
  ///
  /// Large files and photographs are not stored in this map.
  /// Only structured information and Storage references belong here.
  final Map<String, dynamic> onboardingData;

  /// Admin UID that last updated an onboarding-section status.
  final String? onboardingUpdatedByUid;

  /// Date and time when an onboarding-section status was last updated.
  final DateTime? onboardingUpdatedAt;

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

  PartnerWorkshopDetails? get workshopDetails {
    final extensions = onboardingData['extensions'];

    if (extensions is! Map) {
      return null;
    }

    final tailor = extensions['tailor'];

    if (tailor is! Map) {
      return null;
    }

    final workshop = tailor['workshopDetails'];

    if (workshop is! Map) {
      return null;
    }

    return PartnerWorkshopDetails.fromMap(Map<String, dynamic>.from(workshop));
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
      'onboardingData': onboardingData,
      'onboardingUpdatedByUid': onboardingUpdatedByUid,
      'onboardingUpdatedAt': onboardingUpdatedAt == null
          ? null
          : Timestamp.fromDate(onboardingUpdatedAt!),
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
      onboardingData: _stringMapFromValue(data['onboardingData']),
      onboardingUpdatedByUid: data['onboardingUpdatedByUid']?.toString(),
      onboardingUpdatedAt: _dateFromValue(data['onboardingUpdatedAt']),
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

  static Map<String, dynamic> _stringMapFromValue(dynamic value) {
    if (value is! Map) {
      return const {};
    }

    return Map<String, dynamic>.from(value);
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
