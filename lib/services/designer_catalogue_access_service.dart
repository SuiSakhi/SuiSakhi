import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DesignerCatalogueAccessContext {
  const DesignerCatalogueAccessContext({
    required this.accountId,
    required this.profileId,
    required this.displayName,
  });

  final String accountId;
  final String profileId;
  final String displayName;
}

class DesignerCatalogueAccessService {
  DesignerCatalogueAccessService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<DesignerCatalogueAccessContext> requireApprovedDesigner({
    required String accountId,
    required String profileId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('A signed-in Designer Partner is required.');
    }

    final normalizedAccountId = accountId.trim();
    final normalizedProfileId = profileId.trim();
    if (normalizedAccountId.isEmpty || normalizedProfileId.isEmpty) {
      throw StateError('Designer account and profile context are required.');
    }

    final account = await _db
        .collection('accounts')
        .doc(normalizedAccountId)
        .get();
    if (!account.exists) {
      throw StateError('Designer account could not be found.');
    }

    final authenticatedPhone = user.phoneNumber?.trim() ?? '';
    final accountPhone = account.data()?['mobileE164']?.toString().trim() ?? '';
    if (authenticatedPhone.isEmpty || accountPhone != authenticatedPhone) {
      throw StateError('The Designer profile does not belong to this account.');
    }

    final profile = await account.reference
        .collection('profiles')
        .doc(normalizedProfileId)
        .get();
    if (!profile.exists) {
      throw StateError('Designer Partner profile could not be found.');
    }

    final data = profile.data()!;
    final approved =
        data['role'] == 'partner' &&
        data['partnerType'] == 'designer' &&
        data['status'] == 'active' &&
        data['operationalStatus'] == 'active' &&
        data['activationStatus'] == 'active' &&
        data['approvalStatus'] == 'approved' &&
        data['kycStatus'] == 'verified';

    if (!approved) {
      throw StateError(
        'An active, approved, KYC-verified Designer profile is required.',
      );
    }

    return DesignerCatalogueAccessContext(
      accountId: normalizedAccountId,
      profileId: normalizedProfileId,
      displayName: (data['displayName'] ?? data['businessName'] ?? 'Designer')
          .toString()
          .trim(),
    );
  }
}
