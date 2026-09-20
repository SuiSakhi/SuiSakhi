import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/catalogue_contributor_summary.dart';
import '../models/catalogue_design.dart';

class CatalogueContributorService {
  CatalogueContributorService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<CatalogueContributorSummary> resolve(
    CatalogueDesign design,
  ) async {
    if (design.ownerType == CatalogueDesignOwnerType.suisakhi) {
      return const CatalogueContributorSummary(
        sourceCode: 'suisakhi',
        sourceLabel: 'SuiSakhi Admin',
        displayName: 'SuiSakhi',
      );
    }

    final accountId = design.ownerAccountId?.trim() ?? '';
    final profileId = design.ownerProfileId?.trim() ?? '';
    if (accountId.isEmpty || profileId.isEmpty) {
      return CatalogueContributorSummary(
        sourceCode: design.ownerType.name,
        sourceLabel: _ownerLabel(design.ownerType),
        displayName: 'Partner profile unavailable',
        accountId: design.ownerAccountId,
        profileId: design.ownerProfileId,
      );
    }

    final profile = await _db
        .collection('accounts')
        .doc(accountId)
        .collection('profiles')
        .doc(profileId)
        .get();
    final data = profile.data();
    if (!profile.exists || data == null) {
      return CatalogueContributorSummary(
        sourceCode: design.ownerType.name,
        sourceLabel: _ownerLabel(design.ownerType),
        displayName: 'Partner profile unavailable',
        accountId: accountId,
        profileId: profileId,
      );
    }

    final partnerType = data['partnerType']?.toString().trim();
    final displayName =
        (data['businessName'] ??
                data['shopName'] ??
                data['displayName'] ??
                data['name'] ??
                'SuiSakhi Partner')
            .toString()
            .trim();

    return CatalogueContributorSummary(
      sourceCode: partnerType?.isNotEmpty == true
          ? partnerType!
          : design.ownerType.name,
      sourceLabel: _partnerLabel(partnerType, design.ownerType),
      displayName: displayName.isEmpty ? 'SuiSakhi Partner' : displayName,
      accountId: accountId,
      profileId: profileId,
      partnerType: partnerType,
      approvalStatus: data['approvalStatus']?.toString(),
      kycStatus: data['kycStatus']?.toString(),
    );
  }

  static String _ownerLabel(CatalogueDesignOwnerType type) {
    switch (type) {
      case CatalogueDesignOwnerType.suisakhi:
        return 'SuiSakhi Admin';
      case CatalogueDesignOwnerType.designer:
        return 'Designer Partner';
      case CatalogueDesignOwnerType.boutique:
        return 'Boutique Partner';
      case CatalogueDesignOwnerType.brand:
        return 'Brand Partner';
      case CatalogueDesignOwnerType.commissioned:
        return 'Commissioned Contributor';
      case CatalogueDesignOwnerType.licensed:
        return 'Licensed Contributor';
    }
  }

  static String _partnerLabel(
    String? partnerType,
    CatalogueDesignOwnerType fallback,
  ) {
    switch (partnerType) {
      case 'designer':
        return 'Designer Partner';
      case 'boutique':
        return 'Boutique Partner';
      case 'brand':
        return 'Brand Partner';
      case 'tailor':
        return 'Tailor Partner';
      case 'garmentCare':
        return 'Garment Care Partner';
      default:
        return _ownerLabel(fallback);
    }
  }
}
