import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/partner_workspace_profile.dart';

class PartnerWorkspaceService {
  PartnerWorkspaceService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<PartnerWorkspaceProfile> requirePartnerProfile({
    required String accountId,
    required String profileId,
  }) async {
    if (FirebaseAuth.instance.currentUser == null) {
      throw StateError('Sign in is required to open the Partner Workspace.');
    }
    final normalizedAccountId = accountId.trim();
    final normalizedProfileId = profileId.trim();
    if (normalizedAccountId.isEmpty || normalizedProfileId.isEmpty) {
      throw StateError('Partner account and profile context are required.');
    }
    final snapshot = await _db
        .collection('accounts')
        .doc(normalizedAccountId)
        .collection('profiles')
        .doc(normalizedProfileId)
        .get();
    if (!snapshot.exists) {
      throw StateError('The selected Partner profile could not be found.');
    }
    final data = snapshot.data() ?? const <String, dynamic>{};
    if ((data['role'] ?? '').toString() != 'partner' ||
        (data['profileType'] ?? '').toString() != 'partner') {
      throw StateError('The selected profile is not a Partner profile.');
    }
    if ((data['accountId'] ?? '').toString() != normalizedAccountId) {
      throw StateError('The Partner profile does not belong to this account.');
    }
    final profile = PartnerWorkspaceProfile.fromDoc(snapshot);
    if (!profile.isApproved || !profile.isKycVerified) {
      throw StateError(
        'The Partner Workspace is available after Admin approval and KYC verification.',
      );
    }
    return profile;
  }
}
