import 'package:cloud_firestore/cloud_firestore.dart';

import 'catalogue_design_asset.dart';
import 'catalogue_design_view.dart';
import 'catalogue_processing_status.dart';

class CatalogueDesignVersion {
  const CatalogueDesignVersion({
    required this.versionId,
    required this.designId,
    required this.versionNumber,
    this.primaryViewId,
    this.viewCount = 0,
    this.processing = const CatalogueProcessingResult(),

    // Existing single-view constructor compatibility.
    CatalogueDesignAsset? originalAsset,
    CatalogueDesignAsset? normalizedPreviewAsset,
    CatalogueDesignAsset? structuredSvgAsset,
    CatalogueDesignAsset? thumbnailAsset,

    // Explicit legacy-storage compatibility.
    CatalogueDesignAsset? legacyOriginalAsset,
    CatalogueDesignAsset? legacyNormalizedPreviewAsset,
    CatalogueDesignAsset? legacyStructuredSvgAsset,
    CatalogueDesignAsset? legacyThumbnailAsset,

    this.submittedByUid,
    this.submittedAt,
    this.reviewedByUid,
    this.reviewedAt,
    this.publishedAt,
    this.createdAt,
    this.updatedAt,
  }) : legacyOriginalAsset =
          legacyOriginalAsset ?? originalAsset,
      legacyNormalizedPreviewAsset =
          legacyNormalizedPreviewAsset ??
          normalizedPreviewAsset,
      legacyStructuredSvgAsset =
          legacyStructuredSvgAsset ??
          structuredSvgAsset,
      legacyThumbnailAsset =
          legacyThumbnailAsset ?? thumbnailAsset;

  final String versionId;
  final String designId;
  final int versionNumber;
  final String? primaryViewId;
  final int viewCount;
  final CatalogueProcessingResult processing;

  // Backward compatibility for records created before ARCH-CAT-006.
  final CatalogueDesignAsset? legacyOriginalAsset;
  final CatalogueDesignAsset? legacyNormalizedPreviewAsset;
  final CatalogueDesignAsset? legacyStructuredSvgAsset;
  final CatalogueDesignAsset? legacyThumbnailAsset;
    // Backward-compatible getters for existing screens and services.
  CatalogueDesignAsset? get originalAsset =>
      legacyOriginalAsset;

  CatalogueDesignAsset? get normalizedPreviewAsset =>
      legacyNormalizedPreviewAsset;

  CatalogueDesignAsset? get structuredSvgAsset =>
      legacyStructuredSvgAsset;

  CatalogueDesignAsset? get thumbnailAsset =>
      legacyThumbnailAsset; 

  final String? submittedByUid;
  final DateTime? submittedAt;
  final String? reviewedByUid;
  final DateTime? reviewedAt;
  final DateTime? publishedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isLegacySingleView => viewCount == 0 && legacyOriginalAsset != null;

  CatalogueDesignView? get legacyView => legacyOriginalAsset == null
      ? null
      : CatalogueDesignView(
          viewId: 'legacy-single-view',
          designId: designId,
          versionId: versionId,
          viewType: CatalogueDesignViewType.singleView,
          displayOrder: 1,
          isPrimary: true,
          originalAsset: legacyOriginalAsset!,
          normalizedPreviewAsset: legacyNormalizedPreviewAsset,
          structuredSvgAsset: legacyStructuredSvgAsset,
          thumbnailAsset: legacyThumbnailAsset,
          processing: processing,
          createdAt: createdAt,
          updatedAt: updatedAt,
        );

  Map<String, dynamic> toMap() => {
    'versionId': versionId.trim(),
    'designId': designId.trim(),
    'versionNumber': versionNumber < 1 ? 1 : versionNumber,
    'primaryViewId': _text(primaryViewId),
    'viewCount': viewCount < 0 ? 0 : viewCount,
    'processing': processing.toMap(),

    if (legacyOriginalAsset != null)
      'originalAsset': legacyOriginalAsset!.toMap(),

    if (legacyNormalizedPreviewAsset != null)
      'normalizedPreviewAsset':
          legacyNormalizedPreviewAsset!.toMap(),

    if (legacyStructuredSvgAsset != null)
      'structuredSvgAsset':
          legacyStructuredSvgAsset!.toMap(),

    if (legacyThumbnailAsset != null)
      'thumbnailAsset':
          legacyThumbnailAsset!.toMap(),
    'submittedByUid': _text(submittedByUid),
    'submittedAt': _timestamp(submittedAt),
    'reviewedByUid': _text(reviewedByUid),
    'reviewedAt': _timestamp(reviewedAt),
    'publishedAt': _timestamp(publishedAt),
    'createdAt': _timestamp(createdAt),
    'updatedAt': _timestamp(updatedAt),
  };

  factory CatalogueDesignVersion.fromMap(Map<String, dynamic> data) {
    return CatalogueDesignVersion(
      versionId: data['versionId']?.toString().trim() ?? '',
      designId: data['designId']?.toString().trim() ?? '',
      versionNumber: _int(data['versionNumber']) ?? 1,
      primaryViewId: _text(data['primaryViewId']?.toString()),
      viewCount: _int(data['viewCount']) ?? 0,
      processing: CatalogueProcessingResult.fromMap(_map(data['processing'])),
      legacyOriginalAsset: _asset(data['originalAsset']),
      legacyNormalizedPreviewAsset: _asset(data['normalizedPreviewAsset']),
      legacyStructuredSvgAsset: _asset(data['structuredSvgAsset']),
      legacyThumbnailAsset: _asset(data['thumbnailAsset']),
      submittedByUid: _text(data['submittedByUid']?.toString()),
      submittedAt: _date(data['submittedAt']),
      reviewedByUid: _text(data['reviewedByUid']?.toString()),
      reviewedAt: _date(data['reviewedAt']),
      publishedAt: _date(data['publishedAt']),
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
    );
  }

  static CatalogueDesignAsset? _asset(Object? value) {
    final map = _map(value);
    return map.isEmpty ? null : CatalogueDesignAsset.fromMap(map);
  }

  static Map<String, dynamic> _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  static int? _int(Object? value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '');

  static Timestamp? _timestamp(DateTime? value) =>
      value == null ? null : Timestamp.fromDate(value);

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
