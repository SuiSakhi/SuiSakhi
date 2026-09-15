import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/measurement_partner_details.dart';
import '../models/partner_application.dart';

// ============================================================================
// MEASUREMENT PARTNER APPLICATION SERVICE
// ============================================================================
//
// This service persists only Measurement Partner operational extension data.
//
// Storage path:
//
// partner_applications/{applicationId}
//   onboardingData
//     extensions
//       measurementPartner
//
// This service must not:
//
// - Update Tailor extension data.
// - Change application status.
// - Start or complete KYC.
// - Approve or reject an application.
// - Create or activate a Partner profile.
// - Modify application ownership or linkage fields.
//
// Measurement Partner KYC and approval remain independent from Tailor KYC.
// ============================================================================

class MeasurementPartnerApplicationService {
  MeasurementPartnerApplicationService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>>
  get _applicationsCollection => _db.collection('partner_applications');

  // ==========================================================================
  // MEASUREMENT PARTNER EXTENSION: SAVE OPERATIONAL DETAILS
  // ==========================================================================

  static Future<void> saveDetails({
    required String applicationId,
    required String accountId,
    required String customerProfileId,
    required MeasurementPartnerDetails details,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError(
        'A signed-in user is required to save Measurement Partner details.',
      );
    }

    final normalizedApplicationId = applicationId.trim();
    final normalizedAccountId = accountId.trim();
    final normalizedCustomerProfileId = customerProfileId.trim();

    if (normalizedApplicationId.isEmpty) {
      throw ArgumentError.value(
        applicationId,
        'applicationId',
        'Application ID is required.',
      );
    }

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

    final document = _applicationsCollection.doc(normalizedApplicationId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(document);

      if (!snapshot.exists) {
        throw StateError('Measurement Partner application could not be found.');
      }

      final application = PartnerApplication.fromDoc(snapshot);

      _validateOwnership(
        application: application,
        uid: user.uid,
        accountId: normalizedAccountId,
        customerProfileId: normalizedCustomerProfileId,
      );

      if (application.partnerType != PartnerType.measurementPartner) {
        throw StateError(
          'Operational Measurement Partner details can be saved only '
          'for a Measurement Partner application.',
        );
      }

      if (!application.canEdit) {
        throw StateError(
          'Measurement Partner details can be edited only while the '
          'application is Draft or Changes Requested.',
        );
      }

      final updatedOnboardingData = _withMeasurementPartnerDetails(
        existingOnboardingData: application.onboardingData,
        details: details,
      );

      final payload = <String, dynamic>{
        'onboardingData': updatedOnboardingData,
        'onboardingUpdatedByUid': user.uid,
        'onboardingUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      debugPrint(
        '[MEASUREMENT_PARTNER_SAVE] '
        'applicationId=$normalizedApplicationId, '
        'status=${application.status.name}, '
        'capabilityCount='
        '${details.capabilitySelection.normalizedCapabilityCodes.length}, '
        'serviceAreaCount=${details.normalizedServiceAreaPincodes.length}',
      );

      transaction.set(document, payload, SetOptions(merge: true));
    });
  }

  // ==========================================================================
  // MEASUREMENT PARTNER EXTENSION: PRESERVE OTHER EXTENSIONS
  // ==========================================================================

  static Map<String, dynamic> _withMeasurementPartnerDetails({
    required Map<String, dynamic> existingOnboardingData,
    required MeasurementPartnerDetails details,
  }) {
    final onboardingData = Map<String, dynamic>.from(existingOnboardingData);

    final existingExtensions = onboardingData['extensions'];

    final extensions = existingExtensions is Map
        ? Map<String, dynamic>.from(existingExtensions)
        : <String, dynamic>{};

    extensions[PartnerType.measurementPartner.name] = details.toMap();

    onboardingData['extensions'] = extensions;

    return onboardingData;
  }

  // ==========================================================================
  // COMMON PARTNER FOUNDATION: OWNERSHIP VALIDATION
  // ==========================================================================

  static void _validateOwnership({
    required PartnerApplication application,
    required String uid,
    required String accountId,
    required String customerProfileId,
  }) {
    final ownsApplication =
        application.createdByUid == uid &&
        application.accountId == accountId &&
        application.customerProfileId == customerProfileId;

    if (!ownsApplication) {
      throw StateError(
        'This Measurement Partner application does not belong to '
        'the selected Customer profile.',
      );
    }
  }
}
