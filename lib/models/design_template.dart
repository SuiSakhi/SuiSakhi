import 'package:cloud_firestore/cloud_firestore.dart';

enum DesignCatalogType { free, premium, customerUpload }

class DesignTemplate {
  const DesignTemplate({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.catalogType,
    this.dressType,
    this.occasionIds = const [],
    this.priceInr,
    this.createdBy,
    this.ownerProfileId,
    this.isActive = true,
  });

  final String id;
  final String title;
  final String imageUrl;

  /// Free catalog design, premium catalog design,
  /// or customer-uploaded reference design.
  final DesignCatalogType catalogType;

  /// Dress type used for catalog filtering.
  ///
  /// Examples:
  /// Kurti
  /// Gown
  /// Lehenga Choli
  final String? dressType;

  /// OccasionCategory.name values used for filtering.
  ///
  /// Examples:
  /// dailyWear
  /// partyWear
  /// weddingGuest
  final List<String> occasionIds;

  /// Price applies only to premium designs.
  final double? priceInr;

  /// Firebase Auth UID that created the design.
  final String? createdBy;

  /// Profile that owns a customer-uploaded design.
  final String? ownerProfileId;

  /// Inactive designs remain available for historical orders
  /// but should not appear in new catalog selections.
  final bool isActive;

  bool get isFree => catalogType == DesignCatalogType.free;

  bool get isPremium => catalogType == DesignCatalogType.premium;

  bool get isCustomerUpload => catalogType == DesignCatalogType.customerUpload;

  bool matchesDressType(String? selectedDressType) {
    final selected = selectedDressType?.trim().toLowerCase() ?? '';
    final designDressType = dressType?.trim().toLowerCase() ?? '';

    if (selected.isEmpty) {
      return true;
    }

    // Backward compatibility for existing unclassified templates.
    if (designDressType.isEmpty) {
      return true;
    }

    return designDressType == selected;
  }

  bool matchesOccasion(String? selectedOccasionId) {
    final selected = selectedOccasionId?.trim() ?? '';

    if (selected.isEmpty) {
      return true;
    }

    // Backward compatibility for existing templates that
    // do not yet have occasion metadata.
    if (occasionIds.isEmpty) {
      return true;
    }

    return occasionIds.contains(selected);
  }

  factory DesignTemplate.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    final rawTitle = (data['title'] as String?)?.trim() ?? '';
    final rawCatalogType = (data['catalogType'] as String?)?.trim() ?? '';

    final catalogType = switch (rawCatalogType) {
      'premium' => DesignCatalogType.premium,
      'customerUpload' => DesignCatalogType.customerUpload,
      _ => DesignCatalogType.free,
    };

    final rawOccasionIds = data['occasionIds'];

    final occasionIds = rawOccasionIds is List
        ? rawOccasionIds
              .map((value) => value.toString().trim())
              .where((value) => value.isNotEmpty)
              .toList()
        : <String>[];

    final rawPrice = data['priceInr'];

    return DesignTemplate(
      id: doc.id,
      title: rawTitle.isEmpty ? 'Design' : rawTitle,
      imageUrl: (data['imageUrl'] as String?)?.trim() ?? '',
      catalogType: catalogType,
      dressType: (data['dressType'] as String?)?.trim(),
      occasionIds: occasionIds,
      priceInr: rawPrice is num ? rawPrice.toDouble() : null,
      createdBy: (data['createdBy'] as String?)?.trim(),
      ownerProfileId: (data['ownerProfileId'] as String?)?.trim(),
      isActive: data['isActive'] is bool ? data['isActive'] as bool : true,
    );
  }
}
