import 'package:cloud_firestore/cloud_firestore.dart';

/// Customer-facing groups and approved service choices for Garment Care.
/// These IDs are stable data keys; labels may be localized independently.
enum GarmentCareServiceGroup {
  washingCleaning('washing_cleaning', 'Laundry & Dry Cleaning', [
    'Wash and Fold',
    'Wash and Iron',
    'Premium / Wet Cleaning',
    'Dry Cleaning',
    'Antiseptic / Antibacterial Wash',
  ]),
  pressingFinishing('pressing_finishing', 'Ironing & Finishing', [
    'Steam Ironing',
    'Roll Pressing',
    'Form / Dummy Pressing',
  ]),
  specialTreatments('special_treatments', 'Special Treatments & Fabric Care', [
    'Advanced Stain Removal / Spotting',
    'Fabric Starching',
    'Saree Polishing',
    'Fabric Conditioning and Softening',
  ]),
  designerLuxury('designer_luxury', 'Designer & Luxury Care', [
    'Couture and Designer Wear Care',
    'Bridal and Wedding Wear Care',
    'Embroidery / Zari / Zardozi Protection',
    'Leather, Suede, and Fur Care',
  ]),
  homeTextile('home_textile', 'Home Textile Care', [
    'Curtains and Draperies',
    'Blankets and Duvets',
    'Sofa Covers',
    'Rugs and Carpets',
  ]),
  shoesAccessories('shoes_accessories', 'Shoes & Accessories Care', [
    'Sneakers and Athletic Shoes',
    'Leather Shoes and Boots',
    'Handbags and Designer Purses',
    'Backpacks',
  ]);

  const GarmentCareServiceGroup(this.code, this.label, this.services);

  final String code;
  final String label;
  final List<String> services;

  static GarmentCareServiceGroup? fromCode(String? value) {
    for (final group in values) {
      if (group.code == value) return group;
    }
    return null;
  }
}

/// Processing-only state. Payment, shipment, custody and settlement are
/// intentionally represented by separate fields/records and enums below.
enum GarmentCareServiceJobStatus {
  queued,
  offered,
  accepted,
  inspectionPending,
  awaitingConsent,
  readyToStart,
  inProgress,
  qualityCheck,
  completed,
  rejected,
  cancelled,
  blocked,
}

enum GarmentCarePaymentStatus {
  notDue,
  created,
  requiresCustomerAction,
  processing,
  captured,
  failed,
  partiallyRefunded,
  refunded,
  disputed,
}

enum GarmentCareShipmentStatus {
  planned,
  assigned,
  accepted,
  inTransit,
  delivered,
  failedAttempt,
  cancelled,
}

enum GarmentCareConsentStatus {
  pending,
  accepted,
  rejected,
  expired,
  withdrawn,
}

enum GarmentCareSettlementStatus {
  accrued,
  held,
  eligible,
  processing,
  settled,
  failed,
  reversed,
}

/// Permanent identity for one physical garment. This is never a package/bag.
class GarmentCareIdentity {
  const GarmentCareIdentity({
    required this.garmentId,
    required this.customerUid,
    required this.displayName,
    required this.itemTypeCode,
    this.customerAccountId,
    this.customerProfileId,
    this.brand,
    this.material,
    this.colour,
    this.pattern,
    this.careLabel,
    this.currentCustodianType,
    this.currentCustodianAccountId,
    this.currentCustodianProfileId,
    this.currentCustodyShipmentId,
    this.createdAt,
    this.updatedAt,
    this.dnaVersion = 1,
  });

  final String garmentId;
  final String customerUid;
  final String? customerAccountId;
  final String? customerProfileId;
  final String displayName;
  final String itemTypeCode;
  final String? brand;
  final String? material;
  final String? colour;
  final String? pattern;
  final String? careLabel;
  final String? currentCustodianType;
  final String? currentCustodianAccountId;
  final String? currentCustodianProfileId;
  final String? currentCustodyShipmentId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int dnaVersion;

  Map<String, dynamic> toMap() => {
    'garmentId': garmentId,
    'customerUid': customerUid,
    if (customerAccountId != null) 'customerAccountId': customerAccountId,
    if (customerProfileId != null) 'customerProfileId': customerProfileId,
    'displayName': displayName,
    'itemTypeCode': itemTypeCode,
    if (brand != null) 'brand': brand,
    if (material != null) 'material': material,
    if (colour != null) 'colour': colour,
    if (pattern != null) 'pattern': pattern,
    if (careLabel != null) 'careLabel': careLabel,
    if (currentCustodianType != null)
      'currentCustodianType': currentCustodianType,
    if (currentCustodianAccountId != null)
      'currentCustodianAccountId': currentCustodianAccountId,
    if (currentCustodianProfileId != null)
      'currentCustodianProfileId': currentCustodianProfileId,
    if (currentCustodyShipmentId != null)
      'currentCustodyShipmentId': currentCustodyShipmentId,
    if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
    if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    'dnaVersion': dnaVersion,
  };

  factory GarmentCareIdentity.fromMap(
    String id,
    Map<String, dynamic> data,
  ) => GarmentCareIdentity(
    garmentId: id,
    customerUid: (data['customerUid'] ?? '').toString(),
    customerAccountId: data['customerAccountId']?.toString(),
    customerProfileId: data['customerProfileId']?.toString(),
    displayName: (data['displayName'] ?? '').toString(),
    itemTypeCode: (data['itemTypeCode'] ?? '').toString(),
    brand: data['brand']?.toString(),
    material: data['material']?.toString(),
    colour: data['colour']?.toString(),
    pattern: data['pattern']?.toString(),
    careLabel: data['careLabel']?.toString(),
    currentCustodianType: data['currentCustodianType']?.toString(),
    currentCustodianAccountId: data['currentCustodianAccountId']?.toString(),
    currentCustodianProfileId: data['currentCustodianProfileId']?.toString(),
    currentCustodyShipmentId: data['currentCustodyShipmentId']?.toString(),
    createdAt: _date(data['createdAt']),
    updatedAt: _date(data['updatedAt']),
    dnaVersion: (data['dnaVersion'] as num?)?.toInt() ?? 1,
  );
}

/// An order item is one physical garment, even when a temporary package holds
/// multiple items. Photos and notes are item-specific.
class GarmentCareOrderItem {
  const GarmentCareOrderItem({
    required this.itemId,
    required this.garmentId,
    required this.deliveryGroupId,
    required this.serviceIds,
    this.itemTypeCode,
    this.material,
    this.conditionNotes,
    this.careNotes,
    this.conditionPhotoPaths = const [],
  });

  final String itemId;
  final String garmentId;
  final String deliveryGroupId;
  final List<String> serviceIds;
  final String? itemTypeCode;
  final String? material;
  final String? conditionNotes;
  final String? careNotes;
  final List<String> conditionPhotoPaths;

  Map<String, dynamic> toMap() => {
    'itemId': itemId,
    'garmentId': garmentId,
    'deliveryGroupId': deliveryGroupId,
    'serviceIds': serviceIds,
    if (itemTypeCode != null) 'itemTypeCode': itemTypeCode,
    if (material != null) 'material': material,
    if (conditionNotes != null) 'conditionNotes': conditionNotes,
    if (careNotes != null) 'careNotes': careNotes,
    'conditionPhotoPaths': conditionPhotoPaths,
  };
}

/// Partner-specific work record. It has no payment, shipment, custody, or
/// settlement status; those are separate authoritative domain records.
class GarmentCareServiceJob {
  const GarmentCareServiceJob({
    required this.jobId,
    required this.orderId,
    required this.itemId,
    required this.garmentId,
    required this.serviceId,
    required this.status,
    this.partnerAccountId,
    this.partnerProfileId,
    this.dependsOnJobId,
    this.quoteVersionId,
    this.knowledgeCardVersionId,
    this.inspectionRequired = true,
  });

  final String jobId;
  final String orderId;
  final String itemId;
  final String garmentId;
  final String serviceId;
  final GarmentCareServiceJobStatus status;
  final String? partnerAccountId;
  final String? partnerProfileId;
  final String? dependsOnJobId;
  final String? quoteVersionId;
  final String? knowledgeCardVersionId;
  final bool inspectionRequired;

  Map<String, dynamic> toMap() => {
    'jobId': jobId,
    'orderId': orderId,
    'itemId': itemId,
    'garmentId': garmentId,
    'serviceId': serviceId,
    'status': status.name,
    if (partnerAccountId != null) 'partnerAccountId': partnerAccountId,
    if (partnerProfileId != null) 'partnerProfileId': partnerProfileId,
    if (dependsOnJobId != null) 'dependsOnJobId': dependsOnJobId,
    if (quoteVersionId != null) 'quoteVersionId': quoteVersionId,
    if (knowledgeCardVersionId != null)
      'knowledgeCardVersionId': knowledgeCardVersionId,
    'inspectionRequired': inspectionRequired,
  };
}

/// Temporary container identity. Membership references garment IDs and is
/// recorded separately as time-stamped package events.
class GarmentCarePackage {
  const GarmentCarePackage({
    required this.packageId,
    required this.orderId,
    required this.garmentIds,
    this.label,
    this.currentCustodianType,
    this.currentCustodianAccountId,
    this.currentCustodianProfileId,
    this.currentCustodyShipmentId,
  });

  final String packageId;
  final String orderId;
  final List<String> garmentIds;
  final String? label;
  final String? currentCustodianType;
  final String? currentCustodianAccountId;
  final String? currentCustodianProfileId;
  final String? currentCustodyShipmentId;

  Map<String, dynamic> toMap() => {
    'packageId': packageId,
    'orderId': orderId,
    'garmentIds': garmentIds,
    if (label != null) 'label': label,
    if (currentCustodianType != null)
      'currentCustodianType': currentCustodianType,
    if (currentCustodianAccountId != null)
      'currentCustodianAccountId': currentCustodianAccountId,
    if (currentCustodianProfileId != null)
      'currentCustodianProfileId': currentCustodianProfileId,
    if (currentCustodyShipmentId != null)
      'currentCustodyShipmentId': currentCustodyShipmentId,
  };
}

DateTime? _date(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

/// Stable service IDs shared with trusted Firebase Functions.
class GarmentCareServiceCatalog {
  GarmentCareServiceCatalog._();

  static const Map<String, List<String>> serviceIdsByGroup = {
    'washing_cleaning': [
      'wash_fold',
      'wash_iron',
      'premium_wet_cleaning',
      'dry_cleaning',
    ],
    'pressing_finishing': ['steam_ironing', 'roll_pressing', 'form_pressing'],
    'special_treatments': [
      'advanced_stain_removal',
      'fabric_starching',
      'saree_polishing',
      'fabric_conditioning',
    ],
    'designer_luxury': [
      'couture_care',
      'bridal_care',
      'embellishment_protection',
      'leather_suede_fur_care',
    ],
    'home_textile': [
      'curtains_draperies',
      'blankets_duvets',
      'sofa_covers',
      'rugs_carpets',
    ],
    'shoes_accessories': [
      'sneakers_care',
      'leather_shoes_care',
      'handbags_care',
      'backpacks_care',
    ],
  };

  static String labelFor(String serviceId) => switch (serviceId) {
    'wash_fold' => 'Wash and Fold',
    'wash_iron' => 'Wash and Iron',
    'premium_wet_cleaning' => 'Premium / Wet Cleaning',
    'dry_cleaning' => 'Dry Cleaning',
    'antibacterial_wash' => 'Antiseptic / Antibacterial Wash',
    'steam_ironing' => 'Steam Ironing',
    'roll_pressing' => 'Roll Pressing',
    'form_pressing' => 'Form / Dummy Pressing',
    'advanced_stain_removal' => 'Advanced Stain Removal / Spotting',
    'fabric_starching' => 'Fabric Starching',
    'saree_polishing' => 'Saree Polishing',
    'fabric_conditioning' => 'Fabric Conditioning and Softening',
    'couture_care' => 'Couture and Designer Wear Care',
    'bridal_care' => 'Bridal and Wedding Wear Care',
    'embellishment_protection' => 'Embroidery / Zari / Zardozi Protection',
    'leather_suede_fur_care' => 'Leather, Suede, and Fur Care',
    'curtains_draperies' => 'Curtains and Draperies',
    'blankets_duvets' => 'Blankets and Duvets',
    'sofa_covers' => 'Sofa Covers',
    'rugs_carpets' => 'Rugs and Carpets',
    'sneakers_care' => 'Sneakers and Athletic Shoes',
    'leather_shoes_care' => 'Leather Shoes and Boots',
    'handbags_care' => 'Handbags and Designer Purses',
    'backpacks_care' => 'Backpacks',
    _ => serviceId,
  };
}
