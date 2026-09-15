import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/partner_application.dart';

// ============================================================================
// PARTNER BUSINESS PROFILE ACTIVATION SERVICE
// ============================================================================
//
// Atomically:
//
// 1. Creates an independent Partner Business Profile.
// 2. Approves the source Partner Application.
// 3. Links the application through approvedPartnerProfileId.
//
// KYC verification alone does not activate a Partner profile.
//
// This service is category-independent and supports Tailor, Measurement
// Partner, Designer, Boutique, Laundry, Delivery, Doorstep Services, and
// future governed Partner categories.
//
// Partner profile creation does not depend on category-specific UI readiness.
// ============================================================================

class PartnerProfileActivationService {
  PartnerProfileActivationService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<String> approveAndActivate({
    required String applicationId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError(
        'A signed-in Admin is required to approve a Partner application.',
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

    final applicationRef = _db
        .collection('partner_applications')
        .doc(normalizedApplicationId);

    final profileId = 'partner_$normalizedApplicationId';

    await _db.runTransaction((transaction) async {
      final applicationSnapshot = await transaction.get(applicationRef);

      if (!applicationSnapshot.exists) {
        throw StateError('Partner application could not be found.');
      }

      final application = PartnerApplication.fromDoc(applicationSnapshot);

      final existingApprovedProfileId = application.approvedPartnerProfileId
          ?.trim();

      if (application.status == PartnerApplicationStatus.approved &&
          existingApprovedProfileId != null &&
          existingApprovedProfileId.isNotEmpty) {
        return;
      }

      if (application.status != PartnerApplicationStatus.underReview) {
        throw StateError('Only an application under review can be approved.');
      }

      if (application.kycStatus != PartnerKycStatus.verified) {
        throw StateError(
          'KYC must be verified before the Partner application '
          'can be approved.',
        );
      }

      final profileRef = _db
          .collection('accounts')
          .doc(application.accountId)
          .collection('profiles')
          .doc(profileId);

      final profileSnapshot = await transaction.get(profileRef);

      if (profileSnapshot.exists) {
        final profileData = profileSnapshot.data() ?? <String, dynamic>{};

        final sourceApplicationId = profileData['sourceApplicationId']
            ?.toString();

        if (sourceApplicationId != application.id) {
          throw StateError(
            'The target Partner profile is linked to another application.',
          );
        }
      }

      final displayName = application.businessName?.trim().isNotEmpty == true
          ? application.businessName!.trim()
          : application.contactName?.trim().isNotEmpty == true
          ? application.contactName!.trim()
          : 'SuiSakhi Partner';

      // All transaction reads occur before writes.
      transaction.set(profileRef, {
        'profileId': profileId,
        'partnerProfileId': profileId,
        'accountId': application.accountId,

        // Generic access role and independent business classification.
        'role': 'partner',
        'profileType': 'partner',
        'partnerType': application.partnerType.name,

        'displayName': displayName,
        'name': displayName,
        'businessName': application.businessName,
        'shopName': application.businessName,
        'contactName': application.contactName,
        'mobileE164': application.mobileE164,
        'email': application.email,

        'status': 'active',
        'operationalStatus': 'active',
        'activationStatus': 'active',
        'approvalStatus': 'approved',
        'kycStatus': PartnerKycStatus.verified.name,

        'isDefaultProfile': false,
        'lastSelectedAt': null,

        'sourceApplicationId': application.id,
        'approvedByUid': user.uid,
        'approvedAt': FieldValue.serverTimestamp(),

        // Approved business-specific operational snapshot.
        'partnerData': application.onboardingData,

        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      transaction.set(applicationRef, {
        'status': PartnerApplicationStatus.approved.name,
        'approvedPartnerProfileId': profileId,
        'reviewedByUid': user.uid,
        'reviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    debugPrint(
      '[PARTNER_PROFILE_ACTIVATED] '
      'applicationId=$normalizedApplicationId, '
      'profileId=$profileId',
    );

    return profileId;
  }
}
