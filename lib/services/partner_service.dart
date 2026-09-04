import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/partner_application.dart';
import '../models/partner_capability_selection.dart';

class PartnerService {
  PartnerService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>>
  get _applicationsCollection => _db.collection('partner_applications');

  /// Creates a Customer-owned Partner Application draft.
  ///
  /// Creating a draft does not create or activate a Partner profile.
  static Future<PartnerApplication> createDraft({
    required String accountId,
    required String customerProfileId,
    required PartnerType partnerType,
    String? businessName,
    String? contactName,
    String? mobileE164,
    String? email,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError(
        'A signed-in user is required to create a partner application.',
      );
    }

    final normalizedAccountId = accountId.trim();
    final normalizedCustomerProfileId = customerProfileId.trim();

    if (normalizedAccountId.isEmpty) {
      throw ArgumentError.value(
        accountId,
        'accountId',
        'Account ID is required.',
      );
    }

    if (normalizedCustomerProfileId.isEmpty) {
      throw ArgumentError.value(
        customerProfileId,
        'customerProfileId',
        'Customer profile ID is required.',
      );
    }

    final existing = await _applicationsCollection
        .where('createdByUid', isEqualTo: user.uid)
        .where('accountId', isEqualTo: normalizedAccountId)
        .where('customerProfileId', isEqualTo: normalizedCustomerProfileId)
        .where('partnerType', isEqualTo: partnerType.name)
        .get();

    final existingApplications = existing.docs
        .map(PartnerApplication.fromDoc)
        .where(
          (application) =>
              application.status == PartnerApplicationStatus.draft ||
              application.status == PartnerApplicationStatus.submitted ||
              application.status == PartnerApplicationStatus.underReview ||
              application.status == PartnerApplicationStatus.changesRequested ||
              application.status == PartnerApplicationStatus.approved ||
              application.status == PartnerApplicationStatus.rejected,
        )
        .toList();

    if (existingApplications.isNotEmpty) {
      existingApplications.sort((left, right) {
        final updatedComparison = right.updatedAt.compareTo(left.updatedAt);

        if (updatedComparison != 0) {
          return updatedComparison;
        }

        final leftScore = _applicationResumeScore(left);
        final rightScore = _applicationResumeScore(right);

        return rightScore.compareTo(leftScore);
      });

      return existingApplications.first;
    }

    final document = _applicationsCollection.doc();
    final now = DateTime.now();

    final application = PartnerApplication(
      id: document.id,
      accountId: normalizedAccountId,
      customerProfileId: normalizedCustomerProfileId,
      createdByUid: user.uid,
      partnerType: partnerType,
      status: PartnerApplicationStatus.draft,
      businessName: _normalizedOptionalText(businessName),
      contactName: _normalizedOptionalText(contactName),
      mobileE164: _normalizedOptionalText(mobileE164),
      email: _normalizedOptionalText(email),
      createdAt: now,
      updatedAt: now,
    );

    await document.set(application.toMap());

    return application;
  }

  /// Streams every application created by the signed-in account user.
  static Stream<List<PartnerApplication>> watchMyApplications({
    required String accountId,
    required String customerProfileId,
  }) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Stream.value(const <PartnerApplication>[]);
    }

    final normalizedAccountId = accountId.trim();
    final normalizedCustomerProfileId = customerProfileId.trim();

    if (normalizedAccountId.isEmpty || normalizedCustomerProfileId.isEmpty) {
      return Stream.value(const <PartnerApplication>[]);
    }

    return _applicationsCollection
        .where('createdByUid', isEqualTo: user.uid)
        .where('accountId', isEqualTo: normalizedAccountId)
        .where('customerProfileId', isEqualTo: normalizedCustomerProfileId)
        .snapshots()
        .map((snapshot) {
          final applications = snapshot.docs
              .map(PartnerApplication.fromDoc)
              .toList();

          applications.sort(
            (left, right) => right.updatedAt.compareTo(left.updatedAt),
          );

          return applications;
        });
  }

  /// Updates editable fields of an existing draft or rejected application.
  static Future<void> updateDraft({
    required String applicationId,
    required String accountId,
    required String customerProfileId,
    String? businessName,
    String? contactName,
    String? mobileE164,
    String? email,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError(
        'A signed-in user is required to update an application.',
      );
    }

    final document = _applicationsCollection.doc(applicationId.trim());
    final snapshot = await document.get();

    if (!snapshot.exists) {
      throw StateError('Partner application could not be found.');
    }

    final application = PartnerApplication.fromDoc(snapshot);

    _validateCustomerOwnership(
      application: application,
      uid: user.uid,
      accountId: accountId,
      customerProfileId: customerProfileId,
    );

    if (!application.canEdit) {
      throw StateError('This partner application can no longer be edited.');
    }

    await document.set({
      'businessName': _normalizedOptionalText(businessName),
      'contactName': _normalizedOptionalText(contactName),
      'mobileE164': _normalizedOptionalText(mobileE164),
      'email': _normalizedOptionalText(email),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Saves structured Tailor Workshop Details in the existing application.
  ///
  /// The applicant may update this section only while the application is
  /// Draft or Changes Requested.
  ///
  /// Saving complete mandatory information marks the section Completed.
  /// Partial information marks the section In Progress.
  ///
  /// This action never verifies the section, approves the application,
  /// or creates or activates a Partner profile.
  static Future<void> updateWorkshopDetails({
    required String applicationId,
    required String accountId,
    required String customerProfileId,
    required PartnerWorkshopDetails workshopDetails,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError(
        'A signed-in user is required to update Workshop Details.',
      );
    }

    final normalizedApplicationId = applicationId.trim();

    if (normalizedApplicationId.isEmpty) {
      throw ArgumentError.value(
        applicationId,
        'applicationId',
        'Application ID is required.',
      );
    }

    final document = _applicationsCollection.doc(normalizedApplicationId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(document);

      if (!snapshot.exists) {
        throw StateError('Partner application could not be found.');
      }

      final application = PartnerApplication.fromDoc(snapshot);

      _validateCustomerOwnership(
        application: application,
        uid: user.uid,
        accountId: accountId,
        customerProfileId: customerProfileId,
      );

      if (!application.canEdit) {
        throw StateError(
          'Workshop Details can be edited only while the '
          'application is Draft or Changes Requested.',
        );
      }

      if (application.partnerType != PartnerType.tailor) {
        throw StateError(
          'Workshop Details are currently supported only '
          'for Tailor applications.',
        );
      }

      final targetStatus = workshopDetails.hasMinimumRequiredData
          ? PartnerOnboardingSectionStatus.completed
          : PartnerOnboardingSectionStatus.inProgress;

      final updatedOnboardingData = _withTailorWorkshopDetails(
        application.onboardingData,
        workshopDetails,
      );

      final updatedOnboardingSections =
          Map<PartnerOnboardingSection, PartnerOnboardingSectionStatus>.from(
            application.onboardingSections,
          );

      updatedOnboardingSections[PartnerOnboardingSection.workshopDetails] =
          targetStatus;

      transaction.set(document, {
        'onboardingData': updatedOnboardingData,
        'onboardingSections': {
          for (final entry in updatedOnboardingSections.entries)
            entry.key.name: entry.value.name,
        },
        'onboardingUpdatedByUid': user.uid,
        'onboardingUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  /// Saves the Tailor's declared Skills and Expertise.
  ///
  /// The applicant may update this section only while the application is
  /// Draft or Changes Requested.
  ///
  /// At least one governed capability code marks the section Completed.
  /// Additional free-text expertise alone does not complete the section.
  ///
  /// This method records Partner-declared capabilities only. It does not
  /// verify a capability, grant certification, approve the application,
  /// or make the Partner eligible for assignments.
  static Future<void> updateTailorCapabilities({
    required String applicationId,
    required String accountId,
    required String customerProfileId,
    required PartnerCapabilitySelection selection,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError(
        'A signed-in user is required to update '
        'Skills and Expertise.',
      );
    }

    final normalizedApplicationId = applicationId.trim();

    if (normalizedApplicationId.isEmpty) {
      throw ArgumentError.value(
        applicationId,
        'applicationId',
        'Application ID is required.',
      );
    }

    final document = _applicationsCollection.doc(normalizedApplicationId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(document);

      if (!snapshot.exists) {
        throw StateError('Partner application could not be found.');
      }

      final rawData = snapshot.data() ?? <String, dynamic>{};

      debugPrint(
        '[CAPABILITY_RAW_TOP_LEVEL_KEYS] '
        '${rawData.keys.toList()..sort()}',
      );

      debugPrint(
        '[CAPABILITY_RAW_ONBOARDING_DATA] '
        '${rawData['onboardingData']}',
      );

      debugPrint(
        '[CAPABILITY_RAW_ONBOARDING_SECTIONS] '
        '${rawData['onboardingSections']}',
      );

      debugPrint(
        '[CAPABILITY_RAW_APPROVED_PROFILE] '
        'containsKey='
        '${rawData.containsKey('approvedPartnerProfileId')}, '
        'value=${rawData['approvedPartnerProfileId']}',
      );

      final application = PartnerApplication.fromDoc(snapshot);

      debugPrint(
        '[CAPABILITY_BEFORE_DATA] '
        '${application.onboardingData}',
      );

      debugPrint(
        '[CAPABILITY_BEFORE_STATUS] '
        '${application.onboardingSections.map((key, value) => MapEntry(key.name, value.name))}',
      );

      debugPrint(
        '[CAPABILITY_OWNERSHIP] '
        'uid=${user.uid}, '
        'createdByUid=${application.createdByUid}, '
        'accountId=${application.accountId}, '
        'customerProfileId=${application.customerProfileId}, '
        'status=${application.status.name}, '
        'partnerType=${application.partnerType.name}',
      );
      _validateCustomerOwnership(
        application: application,
        uid: user.uid,
        accountId: accountId,
        customerProfileId: customerProfileId,
      );

      if (!application.canEdit) {
        throw StateError(
          'Skills and Expertise can be edited only '
          'while the application is Draft or '
          'Changes Requested.',
        );
      }

      if (application.partnerType != PartnerType.tailor) {
        throw StateError(
          'This capability workflow is currently '
          'supported only for Tailor applications.',
        );
      }

      final normalizedSelection = PartnerCapabilitySelection(
        declaredCapabilityCodes: selection.normalizedCapabilityCodes,
        additionalCapabilityDescriptions:
            selection.normalizedAdditionalDescriptions,
      );

      final targetStatus = normalizedSelection.hasDeclaredCapabilities
          ? PartnerOnboardingSectionStatus.completed
          : PartnerOnboardingSectionStatus.inProgress;

      final updatedOnboardingData = _withTailorCapabilities(
        application.onboardingData,
        normalizedSelection,
      );

      final updatedOnboardingSections =
          Map<PartnerOnboardingSection, PartnerOnboardingSectionStatus>.from(
            application.onboardingSections,
          );

      updatedOnboardingSections[PartnerOnboardingSection
              .servicesAndSpecialization] =
          targetStatus;
      //SUD debug
      debugPrint('[CAPABILITY_DATA] $updatedOnboardingData');
      debugPrint(
        '[CAPABILITY_STATUS] '
        '${updatedOnboardingSections.map((key, value) => MapEntry(key.name, value.name))}',
      );
      final payload = <String, dynamic>{
        'onboardingData': updatedOnboardingData,
        'onboardingSections': {
          for (final entry in updatedOnboardingSections.entries)
            entry.key.name: entry.value.name,
        },
        'onboardingUpdatedByUid': user.uid,
        'onboardingUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      debugPrint(
        '[CAPABILITY_PAYLOAD_KEYS] '
        '${payload.keys.toList()..sort()}',
      );

      debugPrint('[CAPABILITY_PAYLOAD] $payload');
      debugPrint(
        '[CAPABILITY_APPLICATION_STATUS] '
        '${application.status.name}',
      );

      debugPrint(
        '[CAPABILITY_CAN_EDIT] '
        '${application.canEdit}',
      );
      transaction.set(document, payload, SetOptions(merge: true));
    });
  }

  /// Submits a draft or rejected application for Admin review.
  ///
  /// Submission does not activate a Partner profile.
  static Future<void> submitApplication({
    required String applicationId,
    required String accountId,
    required String customerProfileId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError(
        'A signed-in user is required to submit an application.',
      );
    }

    final document = _applicationsCollection.doc(applicationId.trim());

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(document);

      if (!snapshot.exists) {
        throw StateError('Partner application could not be found.');
      }

      final application = PartnerApplication.fromDoc(snapshot);

      _validateCustomerOwnership(
        application: application,
        uid: user.uid,
        accountId: accountId,
        customerProfileId: customerProfileId,
      );

      if (!application.canSubmit) {
        throw StateError('This partner application cannot be submitted again.');
      }

      transaction.set(document, {
        'status': PartnerApplicationStatus.submitted.name,
        'submittedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),

        // A corrected rejected application starts a fresh review.
        'reviewedAt': null,
        'reviewedByUid': null,
        'reviewNotes': null,
        'rejectionReason': null,
      }, SetOptions(merge: true));
    });
  }

  /// Moves a submitted Partner application into Admin review.
  ///
  /// This action does not approve the application and does not create
  /// or activate a Partner profile.
  static Future<void> startReview({required String applicationId}) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError(
        'A signed-in Admin is required to review an application.',
      );
    }

    final normalizedApplicationId = applicationId.trim();

    if (normalizedApplicationId.isEmpty) {
      throw ArgumentError.value(
        applicationId,
        'applicationId',
        'Application ID is required.',
      );
    }

    final document = _applicationsCollection.doc(normalizedApplicationId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(document);

      if (!snapshot.exists) {
        throw StateError('Partner application could not be found.');
      }

      final application = PartnerApplication.fromDoc(snapshot);

      if (application.status != PartnerApplicationStatus.submitted) {
        throw StateError('Only a submitted application can enter review.');
      }

      transaction.set(document, {
        'status': PartnerApplicationStatus.underReview.name,
        'reviewedByUid': user.uid,
        'reviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  /// Returns an application to the applicant for required corrections.
  ///
  /// This action does not reject the application permanently and does not
  /// create or activate a Partner profile.
  static Future<void> requestChanges({
    required String applicationId,
    required String instructions,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('A signed-in Admin is required to request changes.');
    }

    final normalizedApplicationId = applicationId.trim();
    final normalizedInstructions = instructions.trim();

    if (normalizedApplicationId.isEmpty) {
      throw ArgumentError.value(
        applicationId,
        'applicationId',
        'Application ID is required.',
      );
    }

    if (normalizedInstructions.isEmpty) {
      throw ArgumentError.value(
        instructions,
        'instructions',
        'Correction instructions are required.',
      );
    }

    final document = _applicationsCollection.doc(normalizedApplicationId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(document);

      if (!snapshot.exists) {
        throw StateError('Partner application could not be found.');
      }

      final application = PartnerApplication.fromDoc(snapshot);

      if (application.status != PartnerApplicationStatus.underReview) {
        throw StateError(
          'Changes can be requested only while an application '
          'is under review.',
        );
      }

      transaction.set(document, {
        'status': PartnerApplicationStatus.changesRequested.name,
        'reviewedByUid': user.uid,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewNotes': normalizedInstructions,
        'rejectionReason': null,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  /// Permanently rejects an application with a customer-visible reason.
  ///
  /// Rejection does not delete the application and does not create
  /// or activate a Partner profile.
  static Future<void> rejectApplication({
    required String applicationId,
    required String reason,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError(
        'A signed-in Admin is required to reject an application.',
      );
    }

    final normalizedApplicationId = applicationId.trim();
    final normalizedReason = reason.trim();

    if (normalizedApplicationId.isEmpty) {
      throw ArgumentError.value(
        applicationId,
        'applicationId',
        'Application ID is required.',
      );
    }

    if (normalizedReason.isEmpty) {
      throw ArgumentError.value(
        reason,
        'reason',
        'Rejection reason is required.',
      );
    }

    final document = _applicationsCollection.doc(normalizedApplicationId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(document);

      if (!snapshot.exists) {
        throw StateError('Partner application could not be found.');
      }

      final application = PartnerApplication.fromDoc(snapshot);

      if (application.status != PartnerApplicationStatus.underReview) {
        throw StateError('Only an application under review can be rejected.');
      }

      transaction.set(document, {
        'status': PartnerApplicationStatus.rejected.name,
        'rejectionReason': normalizedReason,
        'rejectedByUid': user.uid,
        'rejectedAt': FieldValue.serverTimestamp(),
        'reviewedByUid': user.uid,
        'reviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  /// Starts KYC verification for an application under Admin review.
  ///
  /// This action does not verify KYC, approve the application,
  /// or create an active Partner profile.
  static Future<void> startKycVerification({
    required String applicationId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError(
        'A signed-in Admin is required to start KYC verification.',
      );
    }

    final normalizedApplicationId = applicationId.trim();

    if (normalizedApplicationId.isEmpty) {
      throw ArgumentError.value(
        applicationId,
        'applicationId',
        'Application ID is required.',
      );
    }

    final document = _applicationsCollection.doc(normalizedApplicationId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(document);

      if (!snapshot.exists) {
        throw StateError('Partner application could not be found.');
      }

      final application = PartnerApplication.fromDoc(snapshot);

      if (application.status != PartnerApplicationStatus.underReview) {
        throw StateError(
          'KYC verification can start only while the '
          'application is under review.',
        );
      }

      if (application.kycStatus != PartnerKycStatus.notStarted) {
        throw StateError('KYC verification has already been started.');
      }

      transaction.set(document, {
        'kycStatus': PartnerKycStatus.underVerification.name,
        'kycUpdatedAt': FieldValue.serverTimestamp(),
        'kycFailureReason': null,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  /// Marks KYC as successfully verified by the signed-in Admin.
  ///
  /// This action does not approve the Partner application and does not
  /// create or activate a Partner profile.
  static Future<void> markKycVerified({required String applicationId}) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('A signed-in Admin is required to verify KYC.');
    }

    final normalizedApplicationId = applicationId.trim();

    if (normalizedApplicationId.isEmpty) {
      throw ArgumentError.value(
        applicationId,
        'applicationId',
        'Application ID is required.',
      );
    }

    final document = _applicationsCollection.doc(normalizedApplicationId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(document);

      if (!snapshot.exists) {
        throw StateError('Partner application could not be found.');
      }

      final application = PartnerApplication.fromDoc(snapshot);

      if (application.status != PartnerApplicationStatus.underReview) {
        throw StateError(
          'KYC can be verified only while the application '
          'is under review.',
        );
      }

      if (application.kycStatus != PartnerKycStatus.underVerification) {
        throw StateError(
          'KYC must be under verification before it can be verified.',
        );
      }

      transaction.set(document, {
        'kycStatus': PartnerKycStatus.verified.name,
        'kycVerifiedByUid': user.uid,
        'kycVerifiedAt': FieldValue.serverTimestamp(),
        'kycUpdatedAt': FieldValue.serverTimestamp(),
        'kycFailureReason': null,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  /// Marks KYC verification as failed with a customer-visible reason.
  ///
  /// This action does not automatically reject the Partner application.
  /// Admin may request corrected documents or reject the application
  /// separately.
  static Future<void> markKycFailed({
    required String applicationId,
    required String reason,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError(
        'A signed-in Admin is required to fail KYC verification.',
      );
    }

    final normalizedApplicationId = applicationId.trim();
    final normalizedReason = reason.trim();

    if (normalizedApplicationId.isEmpty) {
      throw ArgumentError.value(
        applicationId,
        'applicationId',
        'Application ID is required.',
      );
    }

    if (normalizedReason.isEmpty) {
      throw ArgumentError.value(
        reason,
        'reason',
        'KYC failure reason is required.',
      );
    }

    if (normalizedReason.length < 10) {
      throw ArgumentError.value(
        reason,
        'reason',
        'Please provide a clear KYC failure reason.',
      );
    }

    final document = _applicationsCollection.doc(normalizedApplicationId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(document);

      if (!snapshot.exists) {
        throw StateError('Partner application could not be found.');
      }

      final application = PartnerApplication.fromDoc(snapshot);

      if (application.status != PartnerApplicationStatus.underReview) {
        throw StateError(
          'KYC can fail only while the application is under review.',
        );
      }

      if (application.kycStatus != PartnerKycStatus.underVerification) {
        throw StateError(
          'KYC must be under verification before it can be failed.',
        );
      }

      transaction.set(document, {
        'kycStatus': PartnerKycStatus.failed.name,
        'kycVerifiedByUid': null,
        'kycVerifiedAt': null,
        'kycUpdatedAt': FieldValue.serverTimestamp(),
        'kycFailureReason': normalizedReason,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  /// Updates one Partner onboarding-section status.
  ///
  /// The first controlled implementation supports Workshop Details only.
  /// This action does not approve the application or create a Partner profile.
  static Future<void> updateOnboardingSectionStatus({
    required String applicationId,
    required PartnerOnboardingSection section,
    required PartnerOnboardingSectionStatus targetStatus,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('A signed-in Admin is required to update onboarding.');
    }

    final normalizedApplicationId = applicationId.trim();

    if (normalizedApplicationId.isEmpty) {
      throw ArgumentError.value(
        applicationId,
        'applicationId',
        'Application ID is required.',
      );
    }

    if (section != PartnerOnboardingSection.workshopDetails) {
      throw StateError(
        'Only Workshop Details is enabled in this onboarding phase.',
      );
    }

    final document = _applicationsCollection.doc(normalizedApplicationId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(document);

      if (!snapshot.exists) {
        throw StateError('Partner application could not be found.');
      }

      final application = PartnerApplication.fromDoc(snapshot);

      if (application.status != PartnerApplicationStatus.underReview) {
        throw StateError(
          'Onboarding can be updated only while the application '
          'is under review.',
        );
      }

      final currentStatus = application.onboardingStatusFor(section);

      if (!_isAllowedOnboardingTransition(
        currentStatus: currentStatus,
        targetStatus: targetStatus,
      )) {
        throw StateError(
          'The onboarding section cannot move from '
          '${currentStatus.name} to ${targetStatus.name}.',
        );
      }

      transaction.update(document, {
        'onboardingSections.${section.name}': targetStatus.name,
        'onboardingUpdatedByUid': user.uid,
        'onboardingUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static bool _isAllowedOnboardingTransition({
    required PartnerOnboardingSectionStatus currentStatus,
    required PartnerOnboardingSectionStatus targetStatus,
  }) {
    switch (currentStatus) {
      case PartnerOnboardingSectionStatus.notStarted:
        return targetStatus == PartnerOnboardingSectionStatus.inProgress;

      case PartnerOnboardingSectionStatus.inProgress:
        return targetStatus == PartnerOnboardingSectionStatus.completed;

      case PartnerOnboardingSectionStatus.completed:
        return targetStatus == PartnerOnboardingSectionStatus.verified;

      case PartnerOnboardingSectionStatus.verified:
        return false;

      case PartnerOnboardingSectionStatus.changesRequired:
        return targetStatus == PartnerOnboardingSectionStatus.inProgress;
    }
  }

  static Map<String, dynamic> _withTailorWorkshopDetails(
    Map<String, dynamic> existingOnboardingData,
    PartnerWorkshopDetails workshopDetails,
  ) {
    final onboardingData = Map<String, dynamic>.from(existingOnboardingData);

    final existingExtensions = onboardingData['extensions'];

    final extensions = existingExtensions is Map
        ? Map<String, dynamic>.from(existingExtensions)
        : <String, dynamic>{};

    final existingTailor = extensions['tailor'];

    final tailor = existingTailor is Map
        ? Map<String, dynamic>.from(existingTailor)
        : <String, dynamic>{};

    tailor['workshopDetails'] = workshopDetails.toMap();

    extensions['tailor'] = tailor;
    onboardingData['extensions'] = extensions;

    return onboardingData;
  }

  static Map<String, dynamic> _withTailorCapabilities(
    Map<String, dynamic> existingOnboardingData,
    PartnerCapabilitySelection selection,
  ) {
    final onboardingData = Map<String, dynamic>.from(existingOnboardingData);

    final existingExtensions = onboardingData['extensions'];

    final extensions = existingExtensions is Map
        ? Map<String, dynamic>.from(existingExtensions)
        : <String, dynamic>{};

    final existingTailor = extensions['tailor'];

    final tailor = existingTailor is Map
        ? Map<String, dynamic>.from(existingTailor)
        : <String, dynamic>{};

    tailor['capabilities'] = selection.toMap();
    extensions['tailor'] = tailor;
    onboardingData['extensions'] = extensions;

    return onboardingData;
  }

  static int _applicationResumeScore(PartnerApplication application) {
    var score = switch (application.status) {
      PartnerApplicationStatus.approved => 600,
      PartnerApplicationStatus.underReview => 500,
      PartnerApplicationStatus.changesRequested => 400,
      PartnerApplicationStatus.submitted => 300,
      PartnerApplicationStatus.draft => 200,
      PartnerApplicationStatus.rejected => 100,
      PartnerApplicationStatus.suspended => 50,
      PartnerApplicationStatus.inactive => 0,
    };

    if (application.reviewNotes?.trim().isNotEmpty == true) {
      score += 40;
    }

    if (application.businessName?.trim().isNotEmpty == true) {
      score += 20;
    }

    if (application.contactName?.trim().isNotEmpty == true) {
      score += 10;
    }

    return score;
  }

  static void _validateCustomerOwnership({
    required PartnerApplication application,
    required String uid,
    required String accountId,
    required String customerProfileId,
  }) {
    final ownsApplication =
        application.createdByUid == uid &&
        application.accountId == accountId.trim() &&
        application.customerProfileId == customerProfileId.trim();

    if (!ownsApplication) {
      throw StateError(
        'This partner application does not belong to '
        'the selected Customer profile.',
      );
    }
  }

  static String? _normalizedOptionalText(String? value) {
    final normalized = value?.trim();

    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }
}
