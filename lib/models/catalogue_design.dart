import 'package:cloud_firestore/cloud_firestore.dart';

import 'catalogue_agreement.dart';
import 'design_metadata.dart';

enum CatalogueDesignOwnerType {
  suisakhi,
  designer,
  boutique,
  brand,
  commissioned,
  licensed,
}

enum CatalogueCommercialType { free, paid, premium, subscription, royalty }

enum CatalogueDesignLifecycleStatus {
  draft,
  uploaded,
  processing,
  readyForReview,
  changesRequested,
  approved,
  rejected,
  archived,
}

enum CataloguePublicationStatus { unpublished, published, archived }

class CatalogueDesignCommercial {
  const CatalogueDesignCommercial({
    required this.commercialType,
    this.currency = 'INR',
    this.designerExpectedPrice,
    this.approvedDesignCharge,
    this.royaltyRuleId,
    this.commercialVersion,
  });

  final CatalogueCommercialType commercialType;
  final String currency;
  final double? designerExpectedPrice;
  final double? approvedDesignCharge;
  final String? royaltyRuleId;
  final String? commercialVersion;

  Map<String, dynamic> toMap() => {
    'commercialType': commercialType.name,
    'currency': currency.trim().isEmpty ? 'INR' : currency.trim(),
    'designerExpectedPrice': _money(designerExpectedPrice),
    'approvedDesignCharge': _money(approvedDesignCharge),
    'royaltyRuleId': _text(royaltyRuleId),
    'commercialVersion': _text(commercialVersion),
  };

  factory CatalogueDesignCommercial.fromMap(Map<String, dynamic> data) {
    return CatalogueDesignCommercial(
      commercialType: CatalogueCommercialType.values.firstWhere(
        (item) => item.name == data['commercialType']?.toString(),
        orElse: () => CatalogueCommercialType.free,
      ),
      currency: _text(data['currency']?.toString()) ?? 'INR',
      designerExpectedPrice: _double(data['designerExpectedPrice']),
      approvedDesignCharge: _double(data['approvedDesignCharge']),
      royaltyRuleId: _text(data['royaltyRuleId']?.toString()),
      commercialVersion: _text(data['commercialVersion']?.toString()),
    );
  }

  static double? _money(double? value) =>
      value == null || value < 0 ? null : value;

  static double? _double(Object? value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');

  static String? _text(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}

class CatalogueDesign {
  const CatalogueDesign({
    required this.designId,
    required this.ownerType,
    required this.submittedByUid,
    required this.title,
    required this.commercial,
    this.ownerProfileId,
    this.description,
    this.garmentTypeCodes = const [],
    this.occasionCodes = const [],
    this.styleCodes = const [],
    this.fabricCompatibilityCodes = const [],
    this.eventCapabilityTags = const [],
    this.constructionMetadata,
    this.activeVersionId,
    this.lifecycleStatus = CatalogueDesignLifecycleStatus.draft,
    this.publicationStatus = CataloguePublicationStatus.unpublished,
    this.catalogueAgreement,
    this.rightsDeclaration,
    this.reviewNotes,
    this.rejectionReason,
    this.createdAt,
    this.updatedAt,
  });

  final String designId;
  final CatalogueDesignOwnerType ownerType;
  final String submittedByUid;
  final String? ownerProfileId;
  final String title;
  final String? description;
  final List<String> garmentTypeCodes;
  final List<String> occasionCodes;
  final List<String> styleCodes;
  final List<String> fabricCompatibilityCodes;
  final List<String> eventCapabilityTags;
  final DesignMetadata? constructionMetadata;
  final CatalogueDesignCommercial commercial;
  final String? activeVersionId;
  final CatalogueDesignLifecycleStatus lifecycleStatus;
  final CataloguePublicationStatus publicationStatus;
  final CatalogueAgreementAcceptance? catalogueAgreement;
  final CatalogueRightsDeclaration? rightsDeclaration;
  final String? reviewNotes;
  final String? rejectionReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isPublished =>
      publicationStatus == CataloguePublicationStatus.published &&
      lifecycleStatus == CatalogueDesignLifecycleStatus.approved;

  Map<String, dynamic> toMap() => {
    'designId': designId.trim(),
    'ownerType': ownerType.name,
    'submittedByUid': submittedByUid.trim(),
    'ownerProfileId': _text(ownerProfileId),
    'title': title.trim(),
    'description': _text(description),
    'garmentTypeCodes': _strings(garmentTypeCodes),
    'occasionCodes': _strings(occasionCodes),
    'styleCodes': _strings(styleCodes),
    'fabricCompatibilityCodes': _strings(fabricCompatibilityCodes),
    'eventCapabilityTags': _strings(eventCapabilityTags),
    'constructionMetadata': _metadataToMap(constructionMetadata),
    'commercial': commercial.toMap(),
    'activeVersionId': _text(activeVersionId),
    'lifecycleStatus': lifecycleStatus.name,
    'publicationStatus': publicationStatus.name,
    'catalogueAgreement': catalogueAgreement?.toMap(),
    'rightsDeclaration': rightsDeclaration?.toMap(),
    'reviewNotes': _text(reviewNotes),
    'rejectionReason': _text(rejectionReason),
    'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
    'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
  };

  factory CatalogueDesign.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return CatalogueDesign.fromMap({...data, 'designId': doc.id});
  }

  factory CatalogueDesign.fromMap(Map<String, dynamic> data) {
    return CatalogueDesign(
      designId: data['designId']?.toString().trim() ?? '',
      ownerType: CatalogueDesignOwnerType.values.firstWhere(
        (item) => item.name == data['ownerType']?.toString(),
        orElse: () => CatalogueDesignOwnerType.suisakhi,
      ),
      submittedByUid: data['submittedByUid']?.toString().trim() ?? '',
      ownerProfileId: _text(data['ownerProfileId']?.toString()),
      title: data['title']?.toString().trim() ?? 'Design',
      description: _text(data['description']?.toString()),
      garmentTypeCodes: _list(data['garmentTypeCodes']),
      occasionCodes: _list(data['occasionCodes']),
      styleCodes: _list(data['styleCodes']),
      fabricCompatibilityCodes: _list(data['fabricCompatibilityCodes']),
      eventCapabilityTags: _list(data['eventCapabilityTags']),
      constructionMetadata: _metadataFromMap(
        _map(data['constructionMetadata']),
      ),
      commercial: CatalogueDesignCommercial.fromMap(_map(data['commercial'])),
      activeVersionId: _text(data['activeVersionId']?.toString()),
      lifecycleStatus: CatalogueDesignLifecycleStatus.values.firstWhere(
        (item) => item.name == data['lifecycleStatus']?.toString(),
        orElse: () => CatalogueDesignLifecycleStatus.draft,
      ),
      publicationStatus: CataloguePublicationStatus.values.firstWhere(
        (item) => item.name == data['publicationStatus']?.toString(),
        orElse: () => CataloguePublicationStatus.unpublished,
      ),
      catalogueAgreement: _agreement(data['catalogueAgreement']),
      rightsDeclaration: _rights(data['rightsDeclaration']),
      reviewNotes: _text(data['reviewNotes']?.toString()),
      rejectionReason: _text(data['rejectionReason']?.toString()),
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
    );
  }

  static Map<String, dynamic>? _metadataToMap(DesignMetadata? value) {
    if (value == null) return null;
    return {
      'dressType': value.dressType,
      'silhouette': value.silhouette.name,
      'lengthType': value.lengthType.name,
      'sleeveType': value.sleeveType.name,
      'neckType': value.neckType.name,
      'liningRequired': value.liningRequired,
      'complexity': value.complexity.name,
      'recommendedFabrics': value.recommendedFabrics,
    };
  }

  static DesignMetadata? _metadataFromMap(Map<String, dynamic> data) {
    if (data.isEmpty) return null;
    return DesignMetadata(
      dressType: data['dressType']?.toString() ?? 'Other',
      silhouette: DesignSilhouette.values.firstWhere(
        (item) => item.name == data['silhouette']?.toString(),
        orElse: () => DesignSilhouette.other,
      ),
      lengthType: DesignLengthType.values.firstWhere(
        (item) => item.name == data['lengthType']?.toString(),
        orElse: () => DesignLengthType.other,
      ),
      sleeveType: DesignSleeveType.values.firstWhere(
        (item) => item.name == data['sleeveType']?.toString(),
        orElse: () => DesignSleeveType.other,
      ),
      neckType: DesignNeckType.values.firstWhere(
        (item) => item.name == data['neckType']?.toString(),
        orElse: () => DesignNeckType.other,
      ),
      liningRequired: data['liningRequired'] == true,
      complexity: DesignComplexity.values.firstWhere(
        (item) => item.name == data['complexity']?.toString(),
        orElse: () => DesignComplexity.medium,
      ),
      recommendedFabrics: _list(data['recommendedFabrics']),
    );
  }

  static CatalogueAgreementAcceptance? _agreement(Object? value) {
    final map = _map(value);
    return map.isEmpty ? null : CatalogueAgreementAcceptance.fromMap(map);
  }

  static CatalogueRightsDeclaration? _rights(Object? value) {
    final map = _map(value);
    return map.isEmpty ? null : CatalogueRightsDeclaration.fromMap(map);
  }

  static Map<String, dynamic> _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  static List<String> _list(Object? value) => value is List
      ? value
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toSet()
            .toList()
      : <String>[];

  static List<String> _strings(List<String> values) => values
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList();

  static DateTime? _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '');
  }

  static String? _text(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}
