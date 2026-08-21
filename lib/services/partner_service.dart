import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/partner_application.dart';

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

    for (final document in existing.docs) {
      final application = PartnerApplication.fromDoc(document);

      if (application.status == PartnerApplicationStatus.draft ||
          application.status == PartnerApplicationStatus.submitted ||
          application.status == PartnerApplicationStatus.underReview ||
          application.status == PartnerApplicationStatus.approved) {
        return application;
      }
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
